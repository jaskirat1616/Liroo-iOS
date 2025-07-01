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
    case quiz
    case dialogue
} 