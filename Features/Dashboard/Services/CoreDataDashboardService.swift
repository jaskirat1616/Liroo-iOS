import Foundation
import CoreData
import Combine

class CoreDataDashboardService: DashboardDataServiceProtocol {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error> {
        Future<ReadingStats, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown)) // Or a specific deallocated error
                return
            }
            
            self.context.perform { // Perform on context's queue
                do {
                    // Fetch all ReadingLogs
                    let request: NSFetchRequest<ReadingLog> = ReadingLog.fetchRequest()
                    let readingLogs = try self.context.fetch(request)

                    let totalReadingTime = readingLogs.reduce(0) { $0 + $1.duration }
                    let totalWordsRead = readingLogs.reduce(0) { $0 + Int($1.wordsRead) }
                    
                    // Streak calculation (simplified: assumes logs are somewhat ordered or we group by day)
                    // For a robust streak, you'd need more complex daily aggregation.
                    var currentStreak = 0
                    if !readingLogs.isEmpty {
                        let uniqueSortedDates = Set(readingLogs.map { Calendar.current.startOfDay(for: $0.date ?? Date()) })
                            .sorted(by: >) // Sort in descending order (most recent first)
                        
                        if !uniqueSortedDates.isEmpty {
                            var streak = 0
                            var currentDate = Calendar.current.startOfDay(for: Date())
                            var expectedDate = currentDate
                            
                            for dateInLog in uniqueSortedDates {
                                if dateInLog == expectedDate {
                                    streak += 1
                                    expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: expectedDate)!
                                } else if dateInLog < expectedDate {
                                    // Streak broken before this log if it's not consecutive
                                    // and not for today or yesterday if today had no log
                                    if streak > 0 && dateInLog != Calendar.current.date(byAdding: .day, value: -1, to: currentDate) && dateInLog != currentDate {
                                        break // Break if gap and streak was already started
                                    } else if streak == 0 && (dateInLog != currentDate && dateInLog != Calendar.current.date(byAdding: .day, value: -1, to: currentDate)) {
                                        // if no streak yet and log is not today or yesterday, it doesn't start a current streak
                                        break
                                    } else if streak == 0 && (dateInLog == currentDate || dateInLog == Calendar.current.date(byAdding: .day, value: -1, to: currentDate)) {
                                       // if no streak yet, and it's today or yesterday, start it
                                       streak += 1
                                       expectedDate = Calendar.current.date(byAdding: .day, value: -1, to: dateInLog)!
                                    }
                                } else { // dateInLog > expectedDate (should not happen if sorted correctly and expectedDate moves back)
                                    break
                                }
                            }
                            // If the most recent log isn't today or yesterday, streak is 0
                            if let mostRecentLogDate = uniqueSortedDates.first {
                               let todayStart = Calendar.current.startOfDay(for: Date())
                               let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: todayStart)!
                               if mostRecentLogDate != todayStart && mostRecentLogDate != yesterdayStart {
                                   if !(streak > 0 && mostRecentLogDate == expectedDate) { // check if streak was broken before today but continued up to mostRecentLogDate
                                     currentStreak = 0
                                   } else {
                                     currentStreak = streak
                                   }
                               } else {
                                   currentStreak = streak
                               }
                            } else {
                                currentStreak = 0
                            }
                        }
                    }


                    let stats = ReadingStats(
                        totalReadingTime: Double(totalReadingTime),
                        currentStreakInDays: currentStreak,
                        totalWordsRead: totalWordsRead
                    )
                    promise(.success(stats))

                } catch {
                    promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch ReadingLogs: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchDailyReadingActivity(forLastDays count: Int) -> AnyPublisher<[ReadingActivityDataPoint], Error> {
        Future<[ReadingActivityDataPoint], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown))
                return
            }
            
            self.context.perform {
                do {
                    let request: NSFetchRequest<ReadingLog> = ReadingLog.fetchRequest()
                    
                    // Set date predicate for the last 'count' days
                    let today = Calendar.current.startOfDay(for: Date())
                    guard let startDate = Calendar.current.date(byAdding: .day, value: -(count - 1), to: today) else {
                        promise(.success([])) // Should not happen
                        return
                    }
                    request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, Calendar.current.date(byAdding: .day, value: 1, to: today)! as NSDate) // <= end of today
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \ReadingLog.date, ascending: true)]
                    
                    let fetchedLogs = try self.context.fetch(request)
                    
                    // Group logs by day
                    let groupedByDay = Dictionary(grouping: fetchedLogs) { log -> Date in
                        return Calendar.current.startOfDay(for: log.date ?? Date()) // Group by start of day
                    }
                    
                    var activityPoints: [ReadingActivityDataPoint] = []
                    for dayOffset in 0..<count {
                        guard let specificDate = Calendar.current.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                        let logsForDay = groupedByDay[specificDate] ?? []
                        
                        let totalDurationForDay = logsForDay.reduce(0) { $0 + $1.duration }
                        let totalWordsForDay = logsForDay.reduce(0) { $0 + Int($1.wordsRead) }
                        
                        // Add a point even if there's no activity, for chart continuity
                        activityPoints.append(ReadingActivityDataPoint(
                            date: specificDate,
                            duration: Double(totalDurationForDay),
                            wordsRead: totalWordsForDay
                        ))
                    }
                    
                    promise(.success(activityPoints.sorted(by: { $0.date < $1.date })))
                    
                } catch {
                     promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch daily activity: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchRecentlyReadItems(limit: Int) -> AnyPublisher<[RecentlyReadItem], Error> {
        Future<[RecentlyReadItem], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown))
                return
            }
            
            self.context.perform {
                do {
                    let request: NSFetchRequest<Book> = Book.fetchRequest()
                    // Fetch books that have been read recently and are not archived
                    request.predicate = NSPredicate(format: "lastReadDate != NIL AND isArchived == NO")
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \Book.lastReadDate, ascending: false)]
                    request.fetchLimit = limit
                    
                    let fetchedBooks = try self.context.fetch(request)
                    
                    let recentItems = fetchedBooks.map { bookEntity -> RecentlyReadItem in
                        RecentlyReadItem(
                            // id: bookEntity.id ?? UUID(), // Assuming Book entity has an id
                            title: bookEntity.title ?? "Unknown Title",
                            author: bookEntity.author,
                            progress: Double(bookEntity.progress),
                            lastReadDate: bookEntity.lastReadDate ?? Date()
                        )
                    }
                    promise(.success(recentItems))
                    
                } catch {
                    promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch recent books: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// Ensure DataServiceError is defined (likely in DashboardDataService.swift or a shared location)
// enum DataServiceError: Error, LocalizedError {
//     case networkError(reason: String)
//     case coreDataError(reason: String)
//     case unknown
// ...
// }
