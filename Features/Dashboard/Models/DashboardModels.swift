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

// MARK: - Real Reading Statistics (Based on Collectible Data)
struct ReadingStats {
    let totalReadingTime: TimeInterval // in seconds - from ReadingLog.duration
    let currentStreakInDays: Int // calculated from ReadingLog.date
    let totalWordsRead: Int // from ReadingLog.wordsRead
    let averageReadingSpeed: Double // words per minute - calculated
    let totalBooksRead: Int // count of Book entities with progress > 0
    let totalSessions: Int // count of ReadingLog entities
    let averageSessionLength: TimeInterval // calculated from total time / sessions
    let longestStreak: Int // calculated from ReadingLog.date
    let comprehensionScore: Double? // Percentage based on quiz performance
    let readingLevel: String?      // User's current reading level
}

// MARK: - Streak Information (Based on dashboardddtls.md)
struct Achievement: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let requiredStreak: Int
    let unlocked: Bool
}

struct StreakInfo: Identifiable {
    let id = UUID() // Added for Identifiable conformance if needed in UI lists
    let currentStreak: Int
    let longestStreak: Int
    let streakStartDate: Date?
    let lastReadingDate: Date?
    let streakMilestones: [Int] // e.g., [7, 30, 100, 365]
    let nextMilestone: Int?
    let daysUntilNextMilestone: Int?
    let achievements: [Achievement] // New: list of achievements
}

// MARK: - Real Engagement Metrics (Based on Collectible Data)
struct EngagementMetrics {
    let dialogueInteractions: Int // count of dialogue sessions (can be tracked)
    let contentGenerated: Int // count of generated content (can be tracked)
    let averageSessionEngagement: Double // calculated from session data
}

// MARK: - Real Reading Analytics (Based on Collectible Data)
struct ReadingAnalytics {
    let readingSpeedTrend: [ReadingSpeedDataPoint]
    let readingTimeDistribution: [TimeDistributionDataPoint]
    let weeklyProgress: [WeeklyProgressDataPoint]
    let monthlyProgress: [MonthlyProgressDataPoint]
}

struct ReadingSpeedDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let wordsPerMinute: Double
    let sessionDuration: TimeInterval
}

struct TimeDistributionDataPoint: Identifiable {
    let id = UUID()
    let hourOfDay: Int
    let totalTimeSpent: TimeInterval
    let sessionsCount: Int
}

struct WeeklyProgressDataPoint: Identifiable {
    let id = UUID()
    let weekStartDate: Date
    let totalTimeSpent: TimeInterval
    let wordsRead: Int
    let booksCompleted: Int
}

struct MonthlyProgressDataPoint: Identifiable {
    let id = UUID()
    let month: Date
    let totalTimeSpent: TimeInterval
    let wordsRead: Int
    let booksCompleted: Int
}

// MARK: - Real Activity Tracking (Based on Collectible Data)
struct RecentActivityItem: Identifiable {
    let id = UUID()
    let type: ActivityType
    let title: String
    let description: String
    let timestamp: Date
    let duration: TimeInterval?
}

enum ActivityType: String {
    case reading = "Reading"
    case dialogue = "Dialogue"
    case contentGeneration = "Content Generation"
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
    let itemID: String?
    let title: String
    let author: String?
    let progress: Double // 0.0 to 1.0
    let lastReadDate: Date
    let collectionName: String // NEW: e.g., 'stories' or 'userContent'

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: RecentlyReadItem, rhs: RecentlyReadItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Dashboard View Types
enum DashboardViewType: String, CaseIterable {
    case student = "Student"
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

// Helper to format large numbers with K, M suffixes
func formatLargeNumber(_ number: Int) -> String {
    if number >= 1_000_000 {
        return String(format: "%.1fM", Double(number) / 1_000_000)
    } else if number >= 1_000 {
        return String(format: "%.1fK", Double(number) / 1_000)
    } else {
        return "\(number)"
    }
}

// Helper to calculate reading speed in WPM
func calculateReadingSpeed(wordsRead: Int, timeSpent: TimeInterval) -> Double {
    guard timeSpent > 0 else { return 0 }
    let minutesSpent = timeSpent / 60
    return Double(wordsRead) / minutesSpent
}