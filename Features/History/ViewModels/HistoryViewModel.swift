// Features/History/HistoryViewModel.swift
// ... existing code ...
import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var historyItems: [UserHistoryEntry] = [] // Renamed from HistoryItem
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var firestoreService = FirestoreService.shared

    init() {
        fetchHistory()
    }

    func fetchHistory() {
        guard let userId = Auth.auth().currentUser?.uid else {
            self.errorMessage = "User not authenticated."
            self.isLoading = false
            return
        }

        self.isLoading = true
        self.errorMessage = nil
        self.historyItems = []

        Task {
            do {
                var fetchedItems: [UserHistoryEntry] = []

                // Fetch stories
                let stories: [FirebaseStory] = try await firestoreService.query(
                    FirebaseStory.self,
                    from: "stories",
                    field: "userId",
                    isEqualTo: userId
                )
                fetchedItems.append(contentsOf: stories.compactMap { story in
                    guard let docId = story.id, !docId.isEmpty else {
                        print("[HistoryViewModel] Warning: Skipping story with nil or empty ID.")
                        return nil
                    }
                    return UserHistoryEntry(from: story)
                })
                print("[HistoryViewModel] Fetched \(stories.count) stories for user \(userId), valid items: \(fetchedItems.count)")

                // Fetch user generated content
                let userContents: [FirebaseUserContent] = try await firestoreService.query(
                    FirebaseUserContent.self,
                    from: "userGeneratedContent",
                    field: "userId",
                    isEqualTo: userId
                )
                print("[HistoryViewModel] DEBUG: Raw fetched userContents count: \(userContents.count)")
                for (index, content) in userContents.enumerated() {
                    print("[HistoryViewModel] DEBUG: Raw content[\(index)] - ID: \(content.id ?? "NIL ID"), Topic: \(content.topic ?? "NIL Topic")")
                }
                let storyItemCount = fetchedItems.count
                fetchedItems.append(contentsOf: userContents.compactMap { content in
                    guard let docId = content.id, !docId.isEmpty else {
                        print("[HistoryViewModel] Warning: Skipping user content with nil or empty ID. Original fetched ID was: '\(content.id ?? "nil")'. Topic: '\(content.topic ?? "NIL Topic")'")
                        return nil
                    }
                    return UserHistoryEntry(from: content)
                })
                let userContentItemCount = fetchedItems.count - storyItemCount
                print("[HistoryViewModel] Fetched \(userContents.count) user contents for user \(userId), valid items: \(userContentItemCount)")

                // Fetch lectures
                let lectures: [FirebaseLecture] = try await firestoreService.query(
                    FirebaseLecture.self,
                    from: "lectures",
                    field: "userId",
                    isEqualTo: userId
                )
                print("[HistoryViewModel] DEBUG: Raw fetched lectures count: \(lectures.count)")
                for (index, lecture) in lectures.enumerated() {
                    print("[HistoryViewModel] DEBUG: Raw lecture[\(index)] - ID: \(lecture.id ?? "NIL ID"), Title: \(lecture.title)")
                }
                let beforeLectureCount = fetchedItems.count
                fetchedItems.append(contentsOf: lectures.compactMap { lecture in
                    guard let docId = lecture.id, !docId.isEmpty else {
                        print("[HistoryViewModel] Warning: Skipping lecture with nil or empty ID.")
                        return nil
                    }
                    return UserHistoryEntry(from: lecture)
                })
                let lectureItemCount = fetchedItems.count - beforeLectureCount
                print("[HistoryViewModel] Fetched \(lectures.count) lectures for user \(userId), valid items: \(lectureItemCount)")

                // Sort items by date, newest first
                self.historyItems = fetchedItems.sorted { $0.date > $1.date }
                self.isLoading = false

            } catch {
                print("[HistoryViewModel] Error fetching history: \(error.localizedDescription)")
                self.errorMessage = "Failed to load history: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    func deleteHistoryItems(withIDs ids: Set<String>) async {
        let itemsToDelete = historyItems.filter { ids.contains($0.id) }
        print("[deleteHistoryItems] Attempting to delete \(itemsToDelete.count) items: \(itemsToDelete.map { "\($0.originalCollectionName)/\($0.originalDocumentID)" })")
        var failedDeletions: [(id: String, error: Error)] = []
        var succeededIDs: Set<String> = []
        for item in itemsToDelete {
            do {
                print("[deleteHistoryItems] Deleting from \(item.originalCollectionName), id: \(item.originalDocumentID)")
                try await firestoreService.delete(from: item.originalCollectionName, documentId: item.originalDocumentID)
                print("[deleteHistoryItems] Successfully deleted \(item.id)")
                succeededIDs.insert(item.id)
            } catch {
                print("[deleteHistoryItems] Failed to delete item \(item.id) from Firebase: \(error)")
                failedDeletions.append((item.id, error))
            }
        }
        // Remove only successfully deleted items from local list
        DispatchQueue.main.async {
            self.historyItems.removeAll { succeededIDs.contains($0.id) }
            if !failedDeletions.isEmpty {
                let errorList = failedDeletions.map { "\($0.id): \($0.error.localizedDescription)" }.joined(separator: "\n")
                self.errorMessage = "Failed to delete some items:\n\(errorList)"
            } else {
                self.errorMessage = nil
            }
        }
    }
}