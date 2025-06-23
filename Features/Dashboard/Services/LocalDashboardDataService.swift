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
    
    // MARK: - Challenge Stats Implementation
    func fetchChallengeStats() -> AnyPublisher<ChallengeStats, Error> {
        let currentStreak = localStats.currentStreakInDays
        let longestStreak = localStats.longestStreak
        let streakStartDate = Calendar.current.date(byAdding: .day, value: -(currentStreak - 1), to: Calendar.current.startOfDay(for: Date()))
        let lastReadingDate = Calendar.current.startOfDay(for: Date())
        
        // Create challenges based on local stats
        let challenges = createLocalChallenges(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalBooksRead: localStats.totalBooksRead,
            totalWordsRead: localStats.totalWordsRead,
            averageWPM: localStats.averageReadingSpeed,
            totalSessions: localStats.totalSessions
        )
        
        // Calculate total points and determine level
        let totalPoints = challenges.filter { $0.isCompleted }.reduce(0) { $0 + $1.points }
        let level: ChallengeLevel = totalPoints >= 1000 ? .diamond :
                                   totalPoints >= 500 ? .platinum :
                                   totalPoints >= 250 ? .gold :
                                   totalPoints >= 100 ? .silver : .bronze
        
        // Get recent completions (last 5 completed challenges)
        let recentCompletions = challenges
            .filter { $0.isCompleted }
            .sorted { ($0.completedDate ?? Date.distantPast) > ($1.completedDate ?? Date.distantPast) }
            .prefix(5)
            .map { $0 }
        
        // Get upcoming challenges (next 3 locked challenges)
        let upcomingChallenges = challenges
            .filter { $0.isLocked }
            .prefix(3)
            .map { $0 }
        
        let challengeStats = ChallengeStats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            streakStartDate: streakStartDate,
            lastReadingDate: lastReadingDate,
            totalChallenges: challenges.count,
            completedChallenges: challenges.filter { $0.isCompleted }.count,
            inProgressChallenges: challenges.filter { $0.isInProgress }.count,
            totalPoints: totalPoints,
            level: level,
            challenges: challenges,
            recentCompletions: Array(recentCompletions),
            upcomingChallenges: Array(upcomingChallenges)
        )
        
        return Just(challengeStats)
            .setFailureType(to: Error.self)
            .delay(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Local Challenge Creation Helper
    private func createLocalChallenges(
        currentStreak: Int,
        longestStreak: Int,
        totalBooksRead: Int,
        totalWordsRead: Int,
        averageWPM: Double,
        totalSessions: Int
    ) -> [Challenge] {
        var challenges: [Challenge] = []
        
        // Streak Challenges (Progressive)
        challenges.append(Challenge(
            name: "Reading Streak",
            description: "Read for consecutive days",
            type: .streak,
            status: currentStreak >= 7 ? .completed : (currentStreak > 0 ? .inProgress : .locked),
            level: currentStreak >= 100 ? .diamond : 
                   currentStreak >= 50 ? .platinum :
                   currentStreak >= 30 ? .gold :
                   currentStreak >= 7 ? .silver : .bronze,
            frequency: .progressive,
            currentProgress: min(currentStreak, 7),
            targetProgress: 7,
            iconName: "flame.fill",
            iconColor: "orange",
            reward: "🔥 Streak Master",
            points: 50,
            unlockedDate: currentStreak >= 7 ? Date() : nil,
            completedDate: currentStreak >= 7 ? Date() : nil,
            expiresAt: nil,
            nextLevelTarget: currentStreak >= 7 ? 30 : nil,
            completionCount: currentStreak >= 7 ? 1 : 0
        ))
        
        // Weekly Challenge
        let weeklyTarget = 5
        let weeklySessions = Int.random(in: 2...6)
        
        challenges.append(Challenge(
            name: "Weekly Reader",
            description: "Complete \(weeklyTarget) reading sessions this week",
            type: .weekly,
            status: weeklySessions >= weeklyTarget ? .completed : (weeklySessions > 0 ? .inProgress : .locked),
            level: .bronze,
            frequency: .weekly,
            currentProgress: min(weeklySessions, weeklyTarget),
            targetProgress: weeklyTarget,
            iconName: "calendar",
            iconColor: "blue",
            reward: "📅 Weekly Warrior",
            points: 25,
            unlockedDate: weeklySessions > 0 ? Date() : nil,
            completedDate: weeklySessions >= weeklyTarget ? Date() : nil,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            nextLevelTarget: nil,
            completionCount: weeklySessions >= weeklyTarget ? 1 : 0
        ))
        
        // Reading Challenges (Progressive)
        challenges.append(Challenge(
            name: "Book Completion",
            description: "Complete books",
            type: .reading,
            status: totalBooksRead >= 5 ? .completed : (totalBooksRead > 0 ? .inProgress : .locked),
            level: totalBooksRead >= 50 ? .diamond :
                   totalBooksRead >= 25 ? .platinum :
                   totalBooksRead >= 10 ? .gold :
                   totalBooksRead >= 5 ? .silver : .bronze,
            frequency: .progressive,
            currentProgress: min(totalBooksRead, 5),
            targetProgress: 5,
            iconName: "book.fill",
            iconColor: "green",
            reward: "📚 Book Worm",
            points: 100,
            unlockedDate: totalBooksRead > 0 ? Date() : nil,
            completedDate: totalBooksRead >= 5 ? Date() : nil,
            expiresAt: nil,
            nextLevelTarget: totalBooksRead >= 5 ? 10 : nil,
            completionCount: totalBooksRead >= 5 ? 1 : 0
        ))
        
        // Speed Challenges (Progressive)
        challenges.append(Challenge(
            name: "Speed Reader",
            description: "Read at high WPM",
            type: .speed,
            status: averageWPM >= 250 ? .completed : (averageWPM > 200 ? .inProgress : .locked),
            level: averageWPM >= 400 ? .diamond :
                   averageWPM >= 300 ? .platinum :
                   averageWPM >= 250 ? .gold :
                   averageWPM >= 200 ? .silver : .bronze,
            frequency: .progressive,
            currentProgress: Int(min(averageWPM, 250)),
            targetProgress: 250,
            iconName: "bolt.fill",
            iconColor: "yellow",
            reward: "⚡ Speed Demon",
            points: 75,
            unlockedDate: averageWPM > 200 ? Date() : nil,
            completedDate: averageWPM >= 250 ? Date() : nil,
            expiresAt: nil,
            nextLevelTarget: averageWPM >= 250 ? 300 : nil,
            completionCount: averageWPM >= 250 ? 1 : 0
        ))
        
        // Engagement Challenges (Progressive)
        challenges.append(Challenge(
            name: "Consistent Reader",
            description: "Complete reading sessions",
            type: .engagement,
            status: totalSessions >= 50 ? .completed : (totalSessions > 10 ? .inProgress : .locked),
            level: totalSessions >= 500 ? .diamond :
                   totalSessions >= 200 ? .platinum :
                   totalSessions >= 100 ? .gold :
                   totalSessions >= 50 ? .silver : .bronze,
            frequency: .progressive,
            currentProgress: min(totalSessions, 50),
            targetProgress: 50,
            iconName: "clock.fill",
            iconColor: "indigo",
            reward: "⏰ Consistent",
            points: 60,
            unlockedDate: totalSessions > 10 ? Date() : nil,
            completedDate: totalSessions >= 50 ? Date() : nil,
            expiresAt: nil,
            nextLevelTarget: totalSessions >= 50 ? 100 : nil,
            completionCount: totalSessions >= 50 ? 1 : 0
        ))
        
        // Word Count Challenge (Progressive)
        challenges.append(Challenge(
            name: "Word Devourer",
            description: "Read words",
            type: .reading,
            status: totalWordsRead >= 100000 ? .completed : (totalWordsRead > 10000 ? .inProgress : .locked),
            level: totalWordsRead >= 1000000 ? .diamond :
                   totalWordsRead >= 500000 ? .platinum :
                   totalWordsRead >= 250000 ? .gold :
                   totalWordsRead >= 100000 ? .silver : .bronze,
            frequency: .progressive,
            currentProgress: min(totalWordsRead, 100000),
            targetProgress: 100000,
            iconName: "textformat",
            iconColor: "teal",
            reward: "📖 Word Devourer",
            points: 150,
            unlockedDate: totalWordsRead > 10000 ? Date() : nil,
            completedDate: totalWordsRead >= 100000 ? Date() : nil,
            expiresAt: nil,
            nextLevelTarget: totalWordsRead >= 100000 ? 250000 : nil,
            completionCount: totalWordsRead >= 100000 ? 1 : 0
        ))
        
        return challenges
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
