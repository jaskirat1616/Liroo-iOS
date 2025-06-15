import Foundation

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    var email: String
    var displayName: String
    var profileImageURL: URL?
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var fontSize: Double
    var fontFamily: String
    var theme: AppTheme
    var notificationsEnabled: Bool
}

// MARK: - Reading Content
struct ReadingContent: Identifiable {
    let id: String
    var title: String
    var content: String
    var createdAt: Date
    var lastRead: Date?
    var tags: [String]
}

// MARK: - Flashcard
struct Flashcard: Identifiable {
    let id: String
    var question: String
    var answer: String
    var category: String
    var difficulty: Difficulty
    var lastReviewed: Date?
}

enum Difficulty: String, Codable {
    case easy
    case medium
    case hard
}

// MARK: - History Item
struct HistoryItem: Identifiable {
    let id: String
    var type: HistoryType
    var title: String
    var timestamp: Date
    var metadata: [String: Any]
}

enum HistoryType: String, Codable {
    case reading
    case flashcard
    case quiz
    case dialogue
} 