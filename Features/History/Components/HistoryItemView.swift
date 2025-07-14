import Foundation
import FirebaseFirestore // Required for Timestamp

// Enum to differentiate between history item types
enum UserHistoryEntryType: String, Codable, CaseIterable { // Renamed from HistoryItemType
    case story = "Story"
    case generatedContent = "Content"
    case lecture = "Lecture"
    case comic = "Comic"
}

// Unified struct for display in the history list
struct UserHistoryEntry: Identifiable, Hashable { // Renamed from HistoryItem
    let id: String // This will be the document ID from Firestore
    let title: String
    let date: Date
    let type: UserHistoryEntryType // Updated type
    let originalDocumentID: String // Firestore document ID of the original item
    let originalCollectionName: String // "stories", "userGeneratedContent", "lectures", or "comics"

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
        self.date = content.createdAt?.dateValue() ?? Date()
        self.type = .generatedContent
        self.originalDocumentID = content.id ?? ""
        self.originalCollectionName = "userGeneratedContent"
    }

    // Initializer for FirebaseLecture
    init(from lecture: FirebaseLecture) {
        self.id = lecture.id ?? UUID().uuidString
        self.title = lecture.title
        self.date = lecture.createdAt?.dateValue() ?? Date()
        self.type = .lecture
        self.originalDocumentID = lecture.id ?? ""
        self.originalCollectionName = "lectures"
    }

    // Initializer for FirebaseComic
    init(from comic: FirebaseComic) {
        self.id = comic.id ?? UUID().uuidString
        self.title = comic.comicTitle
        self.date = comic.createdAt?.dateValue() ?? Date()
        self.type = .comic
        self.originalDocumentID = comic.id ?? ""
        self.originalCollectionName = "comics"
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
