import Foundation
import CoreData
import Combine

class CoreDataDashboardService: DashboardDataServiceProtocol {
    private let context: NSManagedObjectContext
    private let calendar = Calendar.current

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error> {
        Future<ReadingStats, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown))
                return
            }
            
            self.context.perform {
                do {
                    let request: NSFetchRequest<ReadingLog> = ReadingLog.fetchRequest()
                    let readingLogs = try self.context.fetch(request)

                    let totalReadingTime = readingLogs.reduce(0) { $0 + $1.duration } // Int64
                    let totalWordsRead = readingLogs.reduce(0) { $0 + Int($1.wordsRead) } // Int
                    
                    // MODIFIED: Calculate average reading speed from stored WPM per session
                    let averageReadingSpeed = self.calculateAverageReadingSpeedFromLogs(logs: readingLogs)
                    
                    let totalBooksRead = self.calculateTotalBooksRead()
                    let totalSessions = readingLogs.count
                    let averageSessionLength = totalSessions > 0 ? Double(totalReadingTime) / Double(totalSessions) : 0
                    
                    let currentStreak = self.calculateCurrentStreak(logs: readingLogs)
                    let longestStreak = self.calculateLongestStreak(logs: readingLogs)

                    let stats = ReadingStats(
                        totalReadingTime: Double(totalReadingTime),
                        currentStreakInDays: currentStreak,
                        totalWordsRead: totalWordsRead,
                        averageReadingSpeed: averageReadingSpeed, // Now uses new calculation
                        totalBooksRead: totalBooksRead,
                        totalSessions: totalSessions,
                        averageSessionLength: averageSessionLength,
                        longestStreak: longestStreak
                    )
                    promise(.success(stats))

                } catch {
                    promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch ReadingLogs for OverallStats: \(error.localizedDescription)")))
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
                    let today = self.calendar.startOfDay(for: Date())
                    guard let startDate = self.calendar.date(byAdding: .day, value: -(count - 1), to: today) else {
                        promise(.success([]))
                        return
                    }
                    // Fetch logs up to the end of today
                    guard let endDate = self.calendar.date(byAdding: .day, value: 1, to: today) else {
                         promise(.success([]))
                        return
                    }
                    request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \ReadingLog.date, ascending: true)]
                    
                    let fetchedLogs = try self.context.fetch(request)
                    
                    var activityByDay = [Date: (duration: TimeInterval, wordsRead: Int)]()
                    for log in fetchedLogs {
                        guard let logDate = log.date else { continue }
                        let day = self.calendar.startOfDay(for: logDate)
                        let current = activityByDay[day] ?? (0, 0)
                        activityByDay[day] = (current.duration + Double(log.duration), current.wordsRead + Int(log.wordsRead))
                    }
                    
                    var activityPoints: [ReadingActivityDataPoint] = []
                    for dayOffset in 0..<count {
                        guard let specificDate = self.calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                        let dataForDay = activityByDay[specificDate] ?? (0,0)
                        activityPoints.append(ReadingActivityDataPoint(
                            date: specificDate,
                            duration: dataForDay.duration,
                            wordsRead: dataForDay.wordsRead
                        ))
                    }
                    // Ensure the points are sorted by date as the chart might expect this.
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
                    request.predicate = NSPredicate(format: "lastReadDate != NIL")
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \Book.lastReadDate, ascending: false)]
                    request.fetchLimit = limit
                    let fetchedBooks = try self.context.fetch(request)
                    let recentItems = fetchedBooks.map { bookEntity -> RecentlyReadItem in
                        RecentlyReadItem(
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

    // MARK: - NEW: Real Historical/Analytical Data Fetching

    func fetchReadingSpeedTrendData(forLastDays count: Int) -> AnyPublisher<[ReadingSpeedDataPoint], Error> {
        Future<[ReadingSpeedDataPoint], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown))
                return
            }
            self.context.perform {
                do {
                    let request: NSFetchRequest<ReadingLog> = ReadingLog.fetchRequest()
                    let today = self.calendar.startOfDay(for: Date())
                    guard let startDate = self.calendar.date(byAdding: .day, value: -(count - 1), to: today) else {
                        promise(.success([])); return
                    }
                    guard let endDate = self.calendar.date(byAdding: .day, value: 1, to: today) else {
                         promise(.success([])); return
                    }
                    request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate)
                    // Fetch logs with WPM > 0 as WPM is the key metric here
                    // request.predicate = NSPredicate(format: "date >= %@ AND date < %@ AND wordsPerMinute > 0", startDate as NSDate, endDate as NSDate)
                    request.sortDescriptors = [NSSortDescriptor(keyPath: \ReadingLog.date, ascending: true)]
                    
                    let fetchedLogs = try self.context.fetch(request)
                    
                    // For simplicity, create one point per log. Could also average WPM per day.
                    let trendPoints = fetchedLogs.compactMap { log -> ReadingSpeedDataPoint? in
                        guard let logDate = log.date, log.wordsPerMinute > 0 else { return nil }
                        return ReadingSpeedDataPoint(
                            date: logDate,
                            wordsPerMinute: Double(log.wordsPerMinute),
                            sessionDuration: Double(log.duration)
                        )
                    }
                    promise(.success(trendPoints))
                } catch {
                    promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch reading speed trend: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchTimeDistributionData() -> AnyPublisher<[TimeDistributionDataPoint], Error> {
        Future<[TimeDistributionDataPoint], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown))
                return
            }
            self.context.perform {
                do {
                    let request: NSFetchRequest<ReadingLog> = ReadingLog.fetchRequest()
                    let readingLogs = try self.context.fetch(request)
                    
                    var timeDistribution = [Int: (totalTime: TimeInterval, sessions: Int)]()
                    for hour in 0..<24 { timeDistribution[hour] = (0, 0) } // Initialize
                    
                    for log in readingLogs {
                        guard let logDate = log.date else { continue }
                        let hour = self.calendar.component(.hour, from: logDate)
                        var current = timeDistribution[hour] ?? (0,0)
                        current.totalTime += Double(log.duration)
                        current.sessions += 1
                        timeDistribution[hour] = current
                    }
                    
                    let distributionPoints = timeDistribution.map { hour, data -> TimeDistributionDataPoint in
                        TimeDistributionDataPoint(hourOfDay: hour, totalTimeSpent: data.totalTime, sessionsCount: data.sessions)
                    }.sorted(by: { $0.hourOfDay < $1.hourOfDay })
                    
                    promise(.success(distributionPoints))
                } catch {
                    promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch time distribution: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchWeeklyProgressData(forLastWeeks count: Int) -> AnyPublisher<[WeeklyProgressDataPoint], Error> {
        Future<[WeeklyProgressDataPoint], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown))
                return
            }
            self.context.perform {
                do {
                    let request: NSFetchRequest<ReadingLog> = ReadingLog.fetchRequest()
                    let today = self.calendar.startOfDay(for: Date())
                    // Calculate start date for the entire period
                    guard let overallStartDate = self.calendar.date(byAdding: .weekOfYear, value: -(count - 1), to: today) else {
                        promise(.success([])); return
                    }
                     guard let overallStartDateForPeriod = self.calendar.date(from: self.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: overallStartDate)) else {
                        promise(.success([])); return
                    }

                    request.predicate = NSPredicate(format: "date >= %@", overallStartDateForPeriod as NSDate)
                    let readingLogs = try self.context.fetch(request)
                    
                    var weeklyData = [Date: (time: TimeInterval, words: Int, books: Int)]()
                    
                    for log in readingLogs {
                        guard let logDate = log.date else { continue }
                        guard let weekStartDate = self.calendar.date(from: self.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: logDate)) else { continue }
                        
                        var current = weeklyData[weekStartDate] ?? (0,0,0)
                        current.time += Double(log.duration)
                        current.words += Int(log.wordsRead)
                        // Note: booksCompleted is harder to track per log; this needs a more robust solution
                        // if you want to count books actually *finished* in that week.
                        // For now, it's illustrative or would need to be 0 unless explicitly tracked.
                        weeklyData[weekStartDate] = current
                    }
                    
                    var progressPoints: [WeeklyProgressDataPoint] = []
                    for i in 0..<count {
                        guard let weekLoopDate = self.calendar.date(byAdding: .weekOfYear, value: -i, to: today) else { continue }
                        guard let currentWeekStartDate = self.calendar.date(from: self.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekLoopDate)) else { continue }

                        let data = weeklyData[currentWeekStartDate] ?? (0,0,0)
                        progressPoints.append(WeeklyProgressDataPoint(
                            weekStartDate: currentWeekStartDate,
                            totalTimeSpent: data.time,
                            wordsRead: data.words,
                            booksCompleted: data.books // Placeholder until better tracking
                        ))
                    }
                    promise(.success(progressPoints.sorted(by: { $0.weekStartDate < $1.weekStartDate })))
                } catch {
                    promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch weekly progress: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchMonthlyProgressData(forLastMonths count: Int) -> AnyPublisher<[MonthlyProgressDataPoint], Error> {
        Future<[MonthlyProgressDataPoint], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(DataServiceError.unknown))
                return
            }
            self.context.perform {
                do {
                    let request: NSFetchRequest<ReadingLog> = ReadingLog.fetchRequest()
                    let today = self.calendar.startOfDay(for: Date())
                    guard let overallStartDate = self.calendar.date(byAdding: .month, value: -(count - 1), to: today) else {
                        promise(.success([])); return
                    }
                    guard let overallStartDateForPeriod = self.calendar.date(from: self.calendar.dateComponents([.year, .month], from: overallStartDate)) else {
                        promise(.success([])); return
                    }

                    request.predicate = NSPredicate(format: "date >= %@", overallStartDateForPeriod as NSDate)
                    let readingLogs = try self.context.fetch(request)

                    var monthlyData = [Date: (time: TimeInterval, words: Int, books: Int)]()

                    for log in readingLogs {
                        guard let logDate = log.date else { continue }
                        guard let monthStartDate = self.calendar.date(from: self.calendar.dateComponents([.year, .month], from: logDate)) else { continue }
                        
                        var current = monthlyData[monthStartDate] ?? (0,0,0)
                        current.time += Double(log.duration)
                        current.words += Int(log.wordsRead)
                        monthlyData[monthStartDate] = current
                    }

                    var progressPoints: [MonthlyProgressDataPoint] = []
                     for i in 0..<count {
                        guard let monthLoopDate = self.calendar.date(byAdding: .month, value: -i, to: today) else { continue }
                        guard let currentMonthStartDate = self.calendar.date(from: self.calendar.dateComponents([.year, .month], from: monthLoopDate)) else { continue }
                        
                        let data = monthlyData[currentMonthStartDate] ?? (0,0,0)
                        progressPoints.append(MonthlyProgressDataPoint(
                            month: currentMonthStartDate,
                            totalTimeSpent: data.time,
                            wordsRead: data.words,
                            booksCompleted: data.books // Placeholder
                        ))
                    }
                    promise(.success(progressPoints.sorted(by: { $0.month < $1.month })))
                } catch {
                    promise(.failure(DataServiceError.coreDataError(reason: "Failed to fetch monthly progress: \(error.localizedDescription)")))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    // MODIFIED: To use stored wordsPerMinute from ReadingLog
    private func calculateAverageReadingSpeedFromLogs(logs: [ReadingLog]) -> Double {
        let logsWithWPM = logs.filter { $0.wordsPerMinute > 0 }
        guard !logsWithWPM.isEmpty else { return 0 }
        
        let totalWPM = logsWithWPM.reduce(0.0) { $0 + Double($1.wordsPerMinute) }
        return totalWPM / Double(logsWithWPM.count)
    }
    
    private func calculateTotalBooksRead() -> Int {
        let request: NSFetchRequest<Book> = Book.fetchRequest()
        // Consider a book "read" if it has any progress or is marked completed.
        // If you add an `isCompleted` flag to Book, you can use that.
        request.predicate = NSPredicate(format: "progress > 0") 
        do {
            return try context.fetch(request).count
        } catch {
            print("Failed to fetch total books read: \(error)")
            return 0
        }
    }
    
    private func calculateCurrentStreak(logs: [ReadingLog]) -> Int {
        guard !logs.isEmpty else { return 0 }
        let uniqueSortedDates = Set(logs.compactMap { $0.date }.map { self.calendar.startOfDay(for: $0) }).sorted(by: >)
        if uniqueSortedDates.isEmpty { return 0 }
        
        var streak = 0
        var expectedDate = self.calendar.startOfDay(for: Date())
        
        for date in uniqueSortedDates {
            if date == expectedDate {
                streak += 1
                expectedDate = self.calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else if date < expectedDate { // A gap means the streak ended before this log
                break
            }
            // If date > expectedDate, it means logs from the future (should not happen) or multiple logs on the same day already processed.
        }
        // If the most recent reading day wasn't today, the current streak is 0 unless today is the start of a new streak.
        if let mostRecentLogDate = uniqueSortedDates.first, !self.calendar.isDateInToday(mostRecentLogDate) {
             // If the streak didn't start today, and the last log wasn't today, it's 0.
             // However, if the streak logic correctly counts back from today, this check might be redundant.
             // The loop structure itself should handle this. if expectedDate (which starts as today) is never matched, streak remains 0.
        }
        return streak
    }
    
    private func calculateLongestStreak(logs: [ReadingLog]) -> Int {
        guard !logs.isEmpty else { return 0 }
        let uniqueSortedDates = Set(logs.compactMap { $0.date }.map { self.calendar.startOfDay(for: $0) }).sorted() // Ascending
        if uniqueSortedDates.isEmpty { return 0 }
        
        var longestStreak = 0
        var currentStreak = 0
        var previousDate: Date?
        
        for date in uniqueSortedDates {
            if let prev = previousDate {
                if let diff = self.calendar.dateComponents([.day], from: prev, to: date).day, diff == 1 {
                    currentStreak += 1
                } else { // Gap or same day (Set handles same day, so this is a gap > 1 day)
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1 // Start new streak
                }
            } else {
                currentStreak = 1 // First day of any streak
            }
            previousDate = date
        }
        return max(longestStreak, currentStreak) // Check once more for the last ongoing streak
    }
}


