import Foundation
import Combine

// This service simulates fetching real, consistent data from a local source.
// In a full implementation, this service would interact with Core Data, SwiftData, or another local database.
class LocalDashboardDataService: DashboardDataServiceProtocol {

    // Basic local data, can be expanded for more thorough local testing
    private var localStats = ReadingStats(
        totalReadingTime: 3600 * 5.5, // 5.5 hours
        currentStreakInDays: 3,
        totalWordsRead: 75000,
        averageReadingSpeed: 220,
        totalBooksRead: 2,
        totalSessions: 15,
        averageSessionLength: (3600 * 5.5) / 15,
        longestStreak: 10,
        comprehensionScore: 0.75, // Added mock value
        readingLevel: "Grade 5"   // Added mock value
    )
    
    private var localActivity: [ReadingActivityDataPoint] = {
        var activity: [ReadingActivityDataPoint] = []
        let today = Calendar.current.startOfDay(for: Date())
        for i in 0..<7 {
            activity.append(
                ReadingActivityDataPoint(
                    date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                    duration: TimeInterval.random(in: 1800...7200), // 30 mins to 2 hours
                    wordsRead: Int.random(in: 1000...3000)
                )
            )
        }
        return activity.sorted(by: { $0.date < $1.date })
    }()
    
    private var localRecentItems: [RecentlyReadItem] = [
        RecentlyReadItem(itemID: "local1", title: "Local Adventures", author: "Dev User", progress: 0.6, lastReadDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, collectionName: "stories"),
        RecentlyReadItem(itemID: "local2", title: "Coding for Fun", author: "Test User", progress: 0.25, lastReadDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, collectionName: "stories")
    ]

    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error> {
        return Just(localStats)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.3), scheduler: DispatchQueue.main) // Simulate network delay
            .eraseToAnyPublisher()
    }

    func fetchDailyReadingActivity(forLastDays count: Int) -> AnyPublisher<[ReadingActivityDataPoint], Error> {
        let relevantActivity = Array(localActivity.suffix(count))
        return Just(relevantActivity)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.4), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func fetchRecentlyReadItems(limit: Int) -> AnyPublisher<[RecentlyReadItem], Error> {
        let items = Array(localRecentItems.prefix(limit))
        return Just(items)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Analytics Data (Local Mocks)
    // These can be simple for local testing or more detailed if needed.

    func fetchReadingSpeedTrendData(forLastDays count: Int) -> AnyPublisher<[ReadingSpeedDataPoint], Error> {
        let trendData = (0..<count).map { i -> ReadingSpeedDataPoint in
            ReadingSpeedDataPoint(
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                wordsPerMinute: Double.random(in: 200...240),
                sessionDuration: TimeInterval.random(in: 1500...3000)
            )
        }.sorted(by: { $0.date < $1.date })
        return Just(trendData)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func fetchTimeDistributionData() -> AnyPublisher<[TimeDistributionDataPoint], Error> {
        let distribution = (0..<24).compactMap { hour -> TimeDistributionDataPoint? in
            if (hour > 7 && hour < 22) && Bool.random() { // Simulate some activity
                return TimeDistributionDataPoint(
                    hourOfDay: hour,
                    totalTimeSpent: TimeInterval.random(in: 600...3600),
                    sessionsCount: Int.random(in: 1...2)
                )
            }
            return nil
        }.sorted(by: { $0.hourOfDay < $1.hourOfDay })
        return Just(distribution)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func fetchWeeklyProgressData(forLastWeeks count: Int) -> AnyPublisher<[WeeklyProgressDataPoint], Error> {
        let weeklyData = (0..<count).map { i -> WeeklyProgressDataPoint in
            WeeklyProgressDataPoint(
                weekStartDate: Calendar.current.date(byAdding: .weekOfYear, value: -i, to: Date())!,
                totalTimeSpent: TimeInterval.random(in: 3600*3...3600*7),
                wordsRead: Int.random(in: 15000...35000),
                booksCompleted: Int.random(in: 0...1)
            )
        }.sorted(by: { $0.weekStartDate < $1.weekStartDate })
        return Just(weeklyData)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func fetchMonthlyProgressData(forLastMonths count: Int) -> AnyPublisher<[MonthlyProgressDataPoint], Error> {
        let monthlyData = (0..<count).map { i -> MonthlyProgressDataPoint in
            MonthlyProgressDataPoint(
                month: Calendar.current.date(byAdding: .month, value: -i, to: Date())!,
                totalTimeSpent: TimeInterval.random(in: 3600*10...3600*25),
                wordsRead: Int.random(in: 50000...150000),
                booksCompleted: Int.random(in: 1...3)
            )
        }.sorted(by: { $0.month < $1.month })
        return Just(monthlyData)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.3), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // Stub implementation for fetchStreakInfo
    func fetchStreakInfo() -> AnyPublisher<StreakInfo, Error> {
        let currentStreak = localStats.currentStreakInDays
        let longestStreak = localStats.longestStreak
        let streakMilestones = [7, 30, 100, 365]
        let nextMilestone = streakMilestones.first(where: { currentStreak < $0 })
        let daysUntilNextMilestone = nextMilestone.map { $0 - currentStreak }
        let streakStartDate = Calendar.current.date(byAdding: .day, value: -(currentStreak - 1), to: Calendar.current.startOfDay(for: Date()))
        let lastReadingDate = Calendar.current.startOfDay(for: Date())
        // Create achievements for each milestone
        let achievements = streakMilestones.map { milestone in
            Achievement(
                name: "Streak: \(milestone) Days",
                description: "Maintain a reading streak for \(milestone) days in a row!",
                requiredStreak: milestone,
                unlocked: currentStreak >= milestone
            )
        }
        let localStreakInfo = StreakInfo(
            currentStreak: currentStreak, // Use from localStats
            longestStreak: longestStreak,     // Use from localStats
            streakStartDate: streakStartDate,
            lastReadingDate: lastReadingDate, // Assume last read today for local
            streakMilestones: streakMilestones,
            nextMilestone: nextMilestone,
            daysUntilNextMilestone: daysUntilNextMilestone,
            achievements: achievements
        )
        return Just(localStreakInfo)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// You might want to expand DataServiceError for local store specific errors
// enum DataServiceError: Error, LocalizedError {
//     case networkError(reason: String)
//     case coreDataError(reason: String)
//     case localStoreUnavailable // Example
//     case unknown
// ...
// }
