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
                // Filter stories to ensure they have an ID, then map
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
                
                // Store the current count of fetchedItems before adding userContents
                let storyItemCount = fetchedItems.count
                
                // Filter user contents to ensure they have an ID, then map
                fetchedItems.append(contentsOf: userContents.compactMap { content in
                    guard let docId = content.id, !docId.isEmpty else {
                        print("[HistoryViewModel] Warning: Skipping user content with nil or empty ID. Original fetched ID was: '\(content.id ?? "nil")'. Topic: '\(content.topic ?? "NIL Topic")'")
                        return nil
                    }
                    return UserHistoryEntry(from: content)
                })
                let userContentItemCount = fetchedItems.count - storyItemCount
                print("[HistoryViewModel] Fetched \(userContents.count) user contents for user \(userId), valid items: \(userContentItemCount)")

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
}