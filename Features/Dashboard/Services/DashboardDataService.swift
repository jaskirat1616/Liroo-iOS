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
    
    // Added for detailed challenge information
    func fetchChallengeStats() -> AnyPublisher<ChallengeStats, Error>
    
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
                    longestStreak: longestStreak,
                    comprehensionScore: Bool.random() ? Double.random(in: 0.6...0.95) : nil, // Mocked optional
                    readingLevel: Bool.random() ? "Level \(Int.random(in: 5...10))" : nil   // Mocked optional
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
                    // Create a mix of books and lectures
                    let isLecture = i % 3 == 0 // Every 3rd item is a lecture
                    
                    if isLecture {
                        items.append(
                            RecentlyReadItem(
                                itemID: "lecture\(i+1)",
                                title: "Mock Lecture \(i+1)",
                                author: nil,
                                progress: 1.0,
                                lastReadDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...20), to: Date())!,
                                collectionName: "lectures",
                                type: .lecture,
                                sectionCount: Int.random(in: 3...8),
                                duration: TimeInterval(Int.random(in: 300...900)), // 5-15 minutes
                                level: ["Beginner", "Intermediate", "Advanced"].randomElement()
                            )
                        )
                    } else {
                        items.append(
                            RecentlyReadItem(
                                itemID: "book\(i+1)",
                                title: "Mock Book \(i+1)",
                                author: "Author \(Character(UnicodeScalar("A".unicodeScalars.first!.value + UInt32(i))!))",
                                progress: Double.random(in: 0.1...0.95),
                                lastReadDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...20), to: Date())!,
                                collectionName: "stories",
                                type: .story,
                                sectionCount: nil,
                                duration: nil,
                                level: nil
                            )
                        )
                    }
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

    // Mock implementation for fetchChallengeStats
    func fetchChallengeStats() -> AnyPublisher<ChallengeStats, Error> {
        Future<ChallengeStats, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.7) {
                let currentStreak = Int.random(in: 0...30)
                let longestStreak = max(currentStreak, Int.random(in: 0...100))
                
                // Create sample challenges with new structure
                let challenges = [
                    Challenge(
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
                    ),
                    Challenge(
                        name: "Weekly Reader",
                        description: "Complete 5 reading sessions this week",
                        type: .weekly,
                        status: .inProgress,
                        level: .bronze,
                        frequency: .weekly,
                        currentProgress: Int.random(in: 1...4),
                        targetProgress: 5,
                        iconName: "calendar",
                        iconColor: "blue",
                        reward: "📅 Weekly Warrior",
                        points: 25,
                        unlockedDate: Date(),
                        completedDate: nil,
                        expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
                        nextLevelTarget: nil,
                        completionCount: 0
                    ),
                    Challenge(
                        name: "Book Completion",
                        description: "Complete books",
                        type: .reading,
                        status: .locked,
                        level: .bronze,
                        frequency: .progressive,
                        currentProgress: Int.random(in: 0...4),
                        targetProgress: 5,
                        iconName: "book.fill",
                        iconColor: "green",
                        reward: "📚 Book Worm",
                        points: 100,
                        unlockedDate: nil,
                        completedDate: nil,
                        expiresAt: nil,
                        nextLevelTarget: nil,
                        completionCount: 0
                    ),
                    Challenge(
                        name: "Speed Reader",
                        description: "Read at high WPM",
                        type: .speed,
                        status: .completed,
                        level: .gold,
                        frequency: .progressive,
                        currentProgress: 300,
                        targetProgress: 250,
                        iconName: "bolt.fill",
                        iconColor: "yellow",
                        reward: "⚡ Speed Demon",
                        points: 75,
                        unlockedDate: Date(),
                        completedDate: Date(),
                        expiresAt: nil,
                        nextLevelTarget: 400,
                        completionCount: 1
                    ),
                    Challenge(
                        name: "Word Devourer",
                        description: "Read words",
                        type: .reading,
                        status: .completed,
                        level: .silver,
                        frequency: .progressive,
                        currentProgress: 150000,
                        targetProgress: 100000,
                        iconName: "textformat",
                        iconColor: "teal",
                        reward: "📖 Word Devourer",
                        points: 150,
                        unlockedDate: Date(),
                        completedDate: Date(),
                        expiresAt: nil,
                        nextLevelTarget: 250000,
                        completionCount: 1
                    )
                ]
                
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
                    streakStartDate: currentStreak > 0 ? Calendar.current.date(byAdding: .day, value: -currentStreak, to: Date()) : nil,
                    lastReadingDate: currentStreak > 0 ? Date() : nil,
                    totalChallenges: challenges.count,
                    completedChallenges: challenges.filter { $0.isCompleted }.count,
                    inProgressChallenges: challenges.filter { $0.isInProgress }.count,
                    totalPoints: totalPoints,
                    level: level,
                    challenges: challenges,
                    recentCompletions: Array(recentCompletions),
                    upcomingChallenges: Array(upcomingChallenges)
                )
                promise(.success(challengeStats))
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
    case firestoreError(reason: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError(let reason):
            return "Network Error: \(reason)"
        case .coreDataError(let reason):
            return "Database Error: \(reason)"
        case .firestoreError(let reason):
            return "Firestore Error: \(reason)"
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
