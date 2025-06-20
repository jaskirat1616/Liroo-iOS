import Foundation
import Combine

// Protocol defining the contract for our dashboard data service
protocol DashboardDataServiceProtocol {
    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error>
    func fetchDailyReadingActivity(forLastDays count: Int) -> AnyPublisher<[ReadingActivityDataPoint], Error>
    func fetchRecentlyReadItems(limit: Int) -> AnyPublisher<[RecentlyReadItem], Error>

    // New methods for real historical/analytical data
    func fetchReadingSpeedTrendData(forLastDays count: Int) -> AnyPublisher<[ReadingSpeedDataPoint], Error>
    func fetchTimeDistributionData() -> AnyPublisher<[TimeDistributionDataPoint], Error>
    func fetchWeeklyProgressData(forLastWeeks count: Int) -> AnyPublisher<[WeeklyProgressDataPoint], Error>
    func fetchMonthlyProgressData(forLastMonths count: Int) -> AnyPublisher<[MonthlyProgressDataPoint], Error>
    
    // A combined fetch method might also be useful for fetching all dashboard data at once
    // func fetchFullDashboardDataPackage() -> AnyPublisher<FullDashboardData, Error>
    // struct FullDashboardData {
    //     let stats: ReadingStats
    //     let dailyActivity: [ReadingActivityDataPoint]
    //     let recentItems: [RecentlyReadItem]
    //     let readingSpeedTrend: [ReadingSpeedDataPoint]
    //     let timeDistribution: [TimeDistributionDataPoint]
    //     let weeklyProgress: [WeeklyProgressDataPoint]
    //     let monthlyProgress: [MonthlyProgressDataPoint]
    // }
}

// Mock implementation of the data service for UI development and testing
class MockDashboardDataService: DashboardDataServiceProtocol {

    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error> {
        Future<ReadingStats, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                let totalReadingTime = TimeInterval.random(in: 3600...36000) // 1 to 10 hours
                let currentStreak = Int.random(in: 0...30)
                let totalWordsRead = Int.random(in: 10000...500000)
                // In a real scenario, this would be an average of actual session WPMs
                let averageReadingSpeed = Double.random(in: 180...280) 
                let totalBooksRead = Int.random(in: 5...50)
                let totalSessions = Int.random(in: 20...200)
                let averageSessionLength = totalSessions > 0 ? totalReadingTime / Double(totalSessions) : 0
                let longestStreak = max(currentStreak, Int.random(in: 0...100))
                
                let stats = ReadingStats(
                    totalReadingTime: totalReadingTime,
                    currentStreakInDays: currentStreak,
                    totalWordsRead: totalWordsRead,
                    averageReadingSpeed: averageReadingSpeed,
                    totalBooksRead: totalBooksRead,
                    totalSessions: totalSessions,
                    averageSessionLength: averageSessionLength,
                    longestStreak: longestStreak
                )
                promise(.success(stats))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchDailyReadingActivity(forLastDays count: Int) -> AnyPublisher<[ReadingActivityDataPoint], Error> {
        Future<[ReadingActivityDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) {
                var activity: [ReadingActivityDataPoint] = []
                let today = Calendar.current.startOfDay(for: Date())
                for i in 0..<count {
                    if Bool.random() || i < 3 { 
                        activity.append(
                            ReadingActivityDataPoint(
                                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                                duration: TimeInterval.random(in: 600...10800), // 10 mins to 3 hours
                                wordsRead: Int.random(in: 200...5000) // Estimated words for that day's sessions
                            )
                        )
                    }
                }
                promise(.success(activity.sorted(by: { $0.date < $1.date })))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchRecentlyReadItems(limit: Int) -> AnyPublisher<[RecentlyReadItem], Error> {
        Future<[RecentlyReadItem], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                var items: [RecentlyReadItem] = []
                for i in 0..<limit {
                    items.append(
                        RecentlyReadItem(
                            title: "Mock Book \(i+1)",
                            author: "Author \(Character(UnicodeScalar("A".unicodeScalars.first!.value + UInt32(i))!))",
                            progress: Double.random(in: 0.1...0.95),
                            lastReadDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...20), to: Date())!
                        )
                    )
                }
                promise(.success(Array(items.prefix(limit).shuffled())))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - New Mock Implementations for Analytics

    func fetchReadingSpeedTrendData(forLastDays count: Int) -> AnyPublisher<[ReadingSpeedDataPoint], Error> {
        Future<[ReadingSpeedDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.7) {
                var trendData: [ReadingSpeedDataPoint] = []
                let today = Date()
                for i in 0..<count {
                    // Simulate some days with data
                    if Bool.random() || i < count / 2 { 
                        trendData.append(ReadingSpeedDataPoint(
                            date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                            wordsPerMinute: Double.random(in: 180...250), // Mocked WPM
                            sessionDuration: TimeInterval.random(in: 1200...3600) // Mocked avg session duration for that day
                        ))
                    }
                }
                promise(.success(trendData.sorted(by: { $0.date < $1.date })))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchTimeDistributionData() -> AnyPublisher<[TimeDistributionDataPoint], Error> {
        Future<[TimeDistributionDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
                var distributionData: [TimeDistributionDataPoint] = []
                for hour in 0..<24 {
                     // Simulate more reading during typical waking/evening hours
                    if (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 22) {
                        if Bool.random() { // Higher chance
                             distributionData.append(TimeDistributionDataPoint(
                                hourOfDay: hour,
                                totalTimeSpent: TimeInterval.random(in: 1800...7200), // 30m to 2h
                                sessionsCount: Int.random(in: 1...2)
                            ))
                        }
                    } else if Bool.random(probability: 0.2) { // Lower chance for other hours
                        distributionData.append(TimeDistributionDataPoint(
                            hourOfDay: hour,
                            totalTimeSpent: TimeInterval.random(in: 600...1800), // 10m to 30m
                            sessionsCount: 1
                        ))
                    }
                }
                promise(.success(distributionData.sorted(by: { $0.hourOfDay < $1.hourOfDay })))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchWeeklyProgressData(forLastWeeks count: Int) -> AnyPublisher<[WeeklyProgressDataPoint], Error> {
        Future<[WeeklyProgressDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.9) {
                var progressData: [WeeklyProgressDataPoint] = []
                let today = Date()
                let calendar = Calendar.current
                for i in 0..<count {
                    let weekStartDate = calendar.date(byAdding: .weekOfYear, value: -i, to: today)!
                    progressData.append(WeeklyProgressDataPoint(
                        weekStartDate: calendar.startOfDay(for: weekStartDate), // Ensure it's start of the day for consistency
                        totalTimeSpent: TimeInterval.random(in: 3600*2...3600*10), // 2 to 10 hours a week
                        wordsRead: Int.random(in: 20000...100000),
                        booksCompleted: Int.random(in: 0...2)
                    ))
                }
                promise(.success(progressData.sorted(by: { $0.weekStartDate < $1.weekStartDate })))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchMonthlyProgressData(forLastMonths count: Int) -> AnyPublisher<[MonthlyProgressDataPoint], Error> {
        Future<[MonthlyProgressDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                var progressData: [MonthlyProgressDataPoint] = []
                let today = Date()
                let calendar = Calendar.current
                for i in 0..<count {
                     let monthDate = calendar.date(byAdding: .month, value: -i, to: today)!
                    progressData.append(MonthlyProgressDataPoint(
                        month: calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!, // Start of the month
                        totalTimeSpent: TimeInterval.random(in: 3600*10...3600*40), // 10 to 40 hours a month
                        wordsRead: Int.random(in: 100000...400000),
                        booksCompleted: Int.random(in: 1...5)
                    ))
                }
                promise(.success(progressData.sorted(by: { $0.month < $1.month })))
            }
        }
        .eraseToAnyPublisher()
    }
}

// Custom Bool random with probability
extension Bool {
    static func random(probability: Double) -> Bool {
        return Double.random(in: 0...1) < probability
    }
}


// Example Error for service
enum DataServiceError: Error, LocalizedError {
    case networkError(reason: String)
    case coreDataError(reason: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError(let reason):
            return "Network Error: \(reason)"
        case .coreDataError(let reason):
            return "Database Error: \(reason)"
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
