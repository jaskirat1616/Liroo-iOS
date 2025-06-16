import Foundation
import Combine
import FirebaseFirestore

@MainActor
class FullReadingViewModel: ObservableObject {
    @Published var story: FirebaseStory?
    @Published var userContent: FirebaseUserContent?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let itemID: String
    private let collectionName: String

    init(itemID: String, collectionName: String) {
        self.itemID = itemID
        self.collectionName = collectionName
        fetchFullContent()
    }

    func fetchFullContent() {
        isLoading = true
        errorMessage = nil
        story = nil
        userContent = nil

        Task {
            do {
                if collectionName == "stories" {
                    let fetchedStory: FirebaseStory = try await firestoreService.fetch(FirebaseStory.self, from: collectionName, documentId: itemID)
                    self.story = fetchedStory
                    print("[FullReadingViewModel] Fetched story: \(fetchedStory.title)")
                } else if collectionName == "userGeneratedContent" {
                    let fetchedContent: FirebaseUserContent = try await firestoreService.fetch(FirebaseUserContent.self, from: collectionName, documentId: itemID)
                    self.userContent = fetchedContent
                    print("[FullReadingViewModel] Fetched user content: \(fetchedContent.topic ?? "N/A")")
                } else {
                    throw NSError(domain: "AppError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown collection type"])
                }
                self.isLoading = false
            } catch {
                print("[FullReadingViewModel] Error fetching full content: \(error.localizedDescription)")
                self.errorMessage = "Failed to load content: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
