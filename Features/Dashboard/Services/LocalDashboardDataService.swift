import Foundation
import Combine

// This service simulates fetching real, consistent data from a local source.
// In a full implementation, this service would interact with Core Data, SwiftData, or another local database.
class LocalDashboardDataService: DashboardDataServiceProtocol {

    // Predefined "real" data based on what can actually be collected
    private let sampleOverallStats = ReadingStats(
        totalReadingTime: (3600 * 15) + (60 * 45), // 15 hours 45 minutes
        currentStreakInDays: 12,
        totalWordsRead: 350000,
        averageReadingSpeed: 220.0,
        totalBooksRead: 25,
        totalSessions: 45,
        averageSessionLength: 1260.0, // 21 minutes
        longestStreak: 18
    )

    private var sampleDailyActivity: [ReadingActivityDataPoint] {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            ReadingActivityDataPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: today)!, duration: 3600 * 0.5, wordsRead: 2500), // 30 mins
            ReadingActivityDataPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: today)!, duration: 3600 * 1.2, wordsRead: 6000), // 1h 12m
            // Day with no reading
            ReadingActivityDataPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: today)!, duration: 3600 * 0.75, wordsRead: 3000),// 45 mins
            ReadingActivityDataPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: today)!, duration: 3600 * 1.5, wordsRead: 7500), // 1h 30m
            ReadingActivityDataPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: today)!, duration: 3600 * 0.8, wordsRead: 4000), // 48 mins
            ReadingActivityDataPoint(date: today, duration: 3600 * 1.0, wordsRead: 5000) // 1 hour today
        ].sorted(by: { $0.date < $1.date })
    }

    private let sampleRecentItems: [RecentlyReadItem] = [
        RecentlyReadItem(
            title: "The Silent Patient",
            author: "Alex Michaelides",
            progress: 0.85,
            lastReadDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())! // Yesterday
        ),
        RecentlyReadItem(
            title: "Educated: A Memoir",
            author: "Tara Westover",
            progress: 0.60,
            lastReadDate: Calendar.current.date(byAdding: .day, value: -4, to: Date())! // 4 days ago
        ),
        RecentlyReadItem(
            title: "Becoming",
            author: "Michelle Obama",
            progress: 0.95,
            lastReadDate: Calendar.current.date(byAdding: .hour, value: -10, to: Date())! // 10 hours ago
        )
    ]

    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error> {
        // Simulate a small delay, then return the predefined stats.
        Future<ReadingStats, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { // Shorter delay
                promise(.success(self.sampleOverallStats))
                // To simulate an error if needed:
                // promise(.failure(DataServiceError.localStoreUnavailable))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchDailyReadingActivity(forLastDays count: Int) -> AnyPublisher<[ReadingActivityDataPoint], Error> {
        Future<[ReadingActivityDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                // Filter the sample activity to match the requested day count
                let endDate = Calendar.current.startOfDay(for: Date())
                guard let startDate = Calendar.current.date(byAdding: .day, value: -(count - 1), to: endDate) else {
                    promise(.success([])) // Should not happen with valid count
                    return
                }
                
                let filteredActivity = self.sampleDailyActivity.filter { $0.date >= startDate && $0.date <= endDate }
                promise(.success(filteredActivity))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchRecentlyReadItems(limit: Int) -> AnyPublisher<[RecentlyReadItem], Error> {
        Future<[RecentlyReadItem], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                let itemsToReturn = Array(self.sampleRecentItems.prefix(limit))
                promise(.success(itemsToReturn))
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - New Analytics Methods (Stubs)

    func fetchReadingSpeedTrendData(forLastDays count: Int) -> AnyPublisher<[ReadingSpeedDataPoint], Error> {
        Future<[ReadingSpeedDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                // Return empty array for now, or you can create sample data
                promise(.success([]))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchTimeDistributionData() -> AnyPublisher<[TimeDistributionDataPoint], Error> {
        Future<[TimeDistributionDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                // Return empty array for now, or you can create sample data
                promise(.success([]))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchWeeklyProgressData(forLastWeeks count: Int) -> AnyPublisher<[WeeklyProgressDataPoint], Error> {
        Future<[WeeklyProgressDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                // Return empty array for now, or you can create sample data
                promise(.success([]))
            }
        }
        .eraseToAnyPublisher()
    }

    func fetchMonthlyProgressData(forLastMonths count: Int) -> AnyPublisher<[MonthlyProgressDataPoint], Error> {
        Future<[MonthlyProgressDataPoint], Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                // Return empty array for now, or you can create sample data
                promise(.success([]))
            }
        }
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
