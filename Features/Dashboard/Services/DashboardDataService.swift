import Foundation
import Combine

// Protocol defining the contract for our dashboard data service
protocol DashboardDataServiceProtocol {
    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error>
    func fetchDailyReadingActivity(forLastDays count: Int) -> AnyPublisher<[ReadingActivityDataPoint], Error>
    // func fetchWeeklyReadingActivity() -> AnyPublisher<[ReadingActivityDataPoint], Error> // Could be derived or specific
    func fetchRecentlyReadItems(limit: Int) -> AnyPublisher<[RecentlyReadItem], Error>
    
    // A combined fetch method might also be useful
    // func fetchDashboardData() -> AnyPublisher<DashboardDataBundle, Error>
    // struct DashboardDataBundle {
    //     let stats: ReadingStats
    //     let dailyActivity: [ReadingActivityDataPoint]
    //     let recentItems: [RecentlyReadItem]
    // }
}

// Mock implementation of the data service for UI development and testing
class MockDashboardDataService: DashboardDataServiceProtocol {

    func fetchOverallStats() -> AnyPublisher<ReadingStats, Error> {
        // Simulate a network delay
        Future<ReadingStats, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) {
                let stats = ReadingStats(
                    totalReadingTime: TimeInterval.random(in: 3600...36000), // 1 to 10 hours
                    currentStreakInDays: Int.random(in: 0...30),
                    totalWordsRead: Int.random(in: 10000...500000)
                )
                promise(.success(stats))
                // To simulate an error:
                // promise(.failure(URLError(.badServerResponse)))
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
                    // Simulate some days with no activity
                    if Bool.random() || i < 3 { // Ensure recent days often have data
                        activity.append(
                            ReadingActivityDataPoint(
                                date: Calendar.current.date(byAdding: .day, value: -i, to: today)!,
                                duration: TimeInterval.random(in: 600...10800), // 10 mins to 3 hours
                                wordsRead: Int.random(in: 200...5000)
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
                let items: [RecentlyReadItem] = [
                    RecentlyReadItem(
                        title: "The Art of Learning",
                        author: "Josh Waitzkin",
                        progress: Double.random(in: 0.1...0.95),
                        lastReadDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...5), to: Date())!
                    ),
                    RecentlyReadItem(
                        title: "Sapiens: A Brief History of Humankind",
                        author: "Yuval Noah Harari",
                        progress: Double.random(in: 0.1...0.95),
                        lastReadDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...10), to: Date())!
                    ),
                    RecentlyReadItem(
                        title: "Why We Sleep",
                        author: "Matthew Walker",
                        progress: Double.random(in: 0.1...0.95),
                        lastReadDate: Calendar.current.date(byAdding: .hour, value: -Int.random(in: 2...24), to: Date())!
                    )
                ].prefix(limit).shuffled() // Shuffle to make it look dynamic
                 .map { $0 } // Convert SubSequence back to Array
                promise(.success(Array(items)))
            }
        }
        .eraseToAnyPublisher()
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
