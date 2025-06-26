import Foundation
import SwiftUI

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

// MARK: - Enhanced Unified Challenges System
enum ChallengeType: String, CaseIterable {
    case streak = "Streak"
    case reading = "Reading"
    case engagement = "Engagement"
    case speed = "Speed"
    case comprehension = "Comprehension"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

enum ChallengeStatus: String, CaseIterable {
    case locked = "Locked"
    case inProgress = "In Progress"
    case completed = "Completed"
    case mastered = "Mastered"
    case expired = "Expired"
}

enum ChallengeLevel: Int, CaseIterable {
    case bronze = 1
    case silver = 2
    case gold = 3
    case platinum = 4
    case diamond = 5
    
    var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .bronze: return 1.0
        case .silver: return 1.5
        case .gold: return 2.0
        case .platinum: return 3.0
        case .diamond: return 5.0
        }
    }
}

enum ChallengeFrequency: String, CaseIterable {
    case oneTime = "One Time"
    case recurring = "Recurring"
    case progressive = "Progressive"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct Challenge: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let type: ChallengeType
    let status: ChallengeStatus
    let level: ChallengeLevel
    let frequency: ChallengeFrequency
    let currentProgress: Int
    let targetProgress: Int
    let iconName: String
    let iconColor: String
    let reward: String?
    let points: Int // Points earned for completion
    let unlockedDate: Date?
    let completedDate: Date?
    let expiresAt: Date? // For time-limited challenges
    let nextLevelTarget: Int? // For progressive challenges
    let completionCount: Int // How many times this challenge has been completed
    
    var progressPercentage: Double {
        guard targetProgress > 0 else { return 0 }
        return min(Double(currentProgress) / Double(targetProgress), 1.0)
    }
    
    var isCompleted: Bool {
        return status == .completed || status == .mastered
    }
    
    var isInProgress: Bool {
        return status == .inProgress
    }
    
    var isLocked: Bool {
        return status == .locked
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    var canProgress: Bool {
        return frequency == .progressive && isCompleted
    }
    
    var nextLevelName: String? {
        guard canProgress, let nextLevel = ChallengeLevel(rawValue: level.rawValue + 1) else { return nil }
        return "\(name) - \(nextLevel.name)"
    }
    
    var displayName: String {
        if level == .bronze {
            return name
        } else {
            return "\(name) - \(level.name)"
        }
    }
}

struct ChallengeStats {
    let currentStreak: Int
    let longestStreak: Int
    let streakStartDate: Date?
    let lastReadingDate: Date?
    let totalChallenges: Int
    let completedChallenges: Int
    let inProgressChallenges: Int
    let totalPoints: Int
    let level: ChallengeLevel
    let challenges: [Challenge]
    let recentCompletions: [Challenge] // Last 5 completed challenges
    let upcomingChallenges: [Challenge] // Next available challenges
    
    var completionRate: Double {
        guard totalChallenges > 0 else { return 0 }
        return Double(completedChallenges) / Double(totalChallenges)
    }
    
    var nextMilestone: Challenge? {
        return challenges.first { $0.status == .inProgress }
    }
    
    var canLevelUp: Bool {
        return totalPoints >= pointsNeededForNextLevel
    }
    
    var pointsNeededForNextLevel: Int {
        switch level {
        case .bronze: return 100
        case .silver: return 250
        case .gold: return 500
        case .platinum: return 1000
        case .diamond: return 2000
        }
    }
    
    var nextLevel: ChallengeLevel? {
        return ChallengeLevel(rawValue: level.rawValue + 1)
    }
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
    let collectionName: String // e.g., 'stories', 'userContent', 'lectures'
    let type: RecentlyReadItemType // NEW: to distinguish between different content types
    let sectionCount: Int? // NEW: for lectures - number of sections
    let duration: TimeInterval? // NEW: for lectures - estimated duration
    let level: String? // NEW: for lectures - reading level

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: RecentlyReadItem, rhs: RecentlyReadItem) -> Bool {
        lhs.id == rhs.id
    }
}

// NEW: Enum to distinguish between different content types
enum RecentlyReadItemType: String, CaseIterable {
    case book = "Book"
    case story = "Story"
    case userContent = "UserContent"
    case lecture = "Lecture"
    
    var iconName: String {
        switch self {
        case .book, .story:
            return "book.closed.fill"
        case .userContent:
            return "doc.text.fill"
        case .lecture:
            return "mic.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .book, .story:
            return .orange
        case .userContent:
            return .customPrimary
        case .lecture:
            return .purple
        }
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