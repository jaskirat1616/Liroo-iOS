import Foundation

// Enum for time range selection in Dashboard charts
// THIS IS THE ONLY PLACE THIS ENUM SHOULD BE DEFINED
enum ActivityTimeRange: String, CaseIterable, Identifiable {
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case last90Days = "Last 90 Days"

    var id: String { self.rawValue }

    var dayCount: Int {
        switch self {
        case .last7Days: return 7
        case .last30Days: return 30
        case .last90Days: return 90
        }
    }
}

// Represents overall reading statistics
struct ReadingStats {
    let totalReadingTime: TimeInterval // in seconds
    let currentStreakInDays: Int
    let totalWordsRead: Int
}

// Represents a single data point for charts (e.g., daily reading)
struct ReadingActivityDataPoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval // in seconds
    let wordsRead: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: ReadingActivityDataPoint, rhs: ReadingActivityDataPoint) -> Bool {
        lhs.id == rhs.id
    }
}

// Represents a recently read item
struct RecentlyReadItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let author: String?
    let progress: Double // 0.0 to 1.0
    let lastReadDate: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: RecentlyReadItem, rhs: RecentlyReadItem) -> Bool {
        lhs.id == rhs.id
    }
}

// Helper to format TimeInterval into a user-friendly string like "Xh Ym"
func formatTimeInterval(_ interval: TimeInterval) -> String {
    let totalSeconds = Int(interval)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    
    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    } else if hours > 0 {
        return "\(hours)h"
    } else {
        return "\(minutes)m"
    }
}