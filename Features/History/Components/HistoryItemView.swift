import Foundation
import FirebaseFirestore // Required for Timestamp

// Enum to differentiate between history item types
enum UserHistoryEntryType: String, Codable, CaseIterable { // Renamed from HistoryItemType
    case story = "Story"
    case generatedContent = "Content"
}

// Unified struct for display in the history list
struct UserHistoryEntry: Identifiable, Hashable { // Renamed from HistoryItem
    let id: String // This will be the document ID from Firestore
    let title: String
    let date: Date
    let type: UserHistoryEntryType // Updated type
    let originalDocumentID: String // Firestore document ID of the original item
    let originalCollectionName: String // "stories" or "userGeneratedContent"

    // Initializer for FirebaseStory
    init(from story: FirebaseStory) {
        self.id = story.id ?? UUID().uuidString
        self.title = story.title
        self.date = story.createdAt?.dateValue() ?? Date()
        self.type = .story
        self.originalDocumentID = story.id ?? ""
        self.originalCollectionName = "stories"
    }

    // Initializer for FirebaseUserContent
    init(from content: FirebaseUserContent) {
        self.id = content.id ?? UUID().uuidString
        self.title = content.topic ?? "Generated Content"
        self.date = content.createdAt ?? Date()
        self.type = .generatedContent
        self.originalDocumentID = content.id ?? ""
        self.originalCollectionName = "userGeneratedContent"
    }

    // Explicit Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(originalDocumentID)
        hasher.combine(type)
    }

    // Explicit Equatable conformance
    static func == (lhs: UserHistoryEntry, rhs: UserHistoryEntry) -> Bool { // Renamed
        lhs.id == rhs.id &&
        lhs.originalDocumentID == rhs.originalDocumentID &&
        lhs.type == rhs.type
    }
}
