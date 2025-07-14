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
                var totalErrors = 0

                // Fetch stories
                do {
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
                } catch {
                    print("[HistoryViewModel] Error fetching stories: \(error.localizedDescription)")
                    totalErrors += 1
                }

                // Fetch user generated content
                do {
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
                } catch {
                    print("[HistoryViewModel] Error fetching user content: \(error.localizedDescription)")
                    totalErrors += 1
                }

                // Fetch lectures
                do {
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
                } catch {
                    print("[HistoryViewModel] Error fetching lectures: \(error.localizedDescription)")
                    totalErrors += 1
                }

                // Fetch comics
                do {
                let comics: [FirebaseComic] = try await firestoreService.query(
                    FirebaseComic.self,
                    from: "comics",
                    field: "userId",
                    isEqualTo: userId
                )
                print("[HistoryViewModel] DEBUG: Raw fetched comics count: \(comics.count)")
                for (index, comic) in comics.enumerated() {
                    print("[HistoryViewModel] DEBUG: Raw comic[\(index)] - ID: \(comic.id ?? "NIL ID"), Title: \(comic.comicTitle)")
                }
                let beforeComicCount = fetchedItems.count
                fetchedItems.append(contentsOf: comics.compactMap { comic in
                    guard let docId = comic.id, !docId.isEmpty else {
                        print("[HistoryViewModel] Warning: Skipping comic with nil or empty ID.")
                        return nil
                    }
                    return UserHistoryEntry(from: comic)
                })
                let comicItemCount = fetchedItems.count - beforeComicCount
                print("[HistoryViewModel] Fetched \(comics.count) comics for user \(userId), valid items: \(comicItemCount)")
                } catch {
                    print("[HistoryViewModel] Error fetching comics: \(error.localizedDescription)")
                    totalErrors += 1
                }

                // Sort items by date, newest first
                self.historyItems = fetchedItems.sorted { $0.date > $1.date }
                
                // Set error message if there were any failures, but still show partial results
                if totalErrors > 0 {
                    self.errorMessage = "Some content could not be loaded. Showing available items."
                    
                    // Run diagnostic check to identify problematic documents
                    if let userId = Auth.auth().currentUser?.uid {
                        await identifyProblematicDocuments(userId: userId)
                    }
                }
                
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

    func identifyProblematicDocuments(userId: String) async {
        print("[HistoryViewModel] Identifying problematic documents for user: \(userId)")
        
        // Check stories collection
        let problematicStories = await firestoreService.identifyProblematicDocuments(
            FirebaseStory.self,
            from: "stories",
            field: "userId",
            isEqualTo: userId
        )
        
        // Check userGeneratedContent collection
        let problematicContent = await firestoreService.identifyProblematicDocuments(
            FirebaseUserContent.self,
            from: "userGeneratedContent",
            field: "userId",
            isEqualTo: userId
        )
        
        // Check lectures collection
        let problematicLectures = await firestoreService.identifyProblematicDocuments(
            FirebaseLecture.self,
            from: "lectures",
            field: "userId",
            isEqualTo: userId
        )
        
        // Check comics collection
        let problematicComics = await firestoreService.identifyProblematicDocuments(
            FirebaseComic.self,
            from: "comics",
            field: "userId",
            isEqualTo: userId
        )
        
        let totalProblematic = problematicStories.count + problematicContent.count + problematicLectures.count + problematicComics.count
        
        if totalProblematic > 0 {
            print("[HistoryViewModel] Found \(totalProblematic) problematic documents:")
            print("[HistoryViewModel] - Stories: \(problematicStories.count)")
            print("[HistoryViewModel] - User Content: \(problematicContent.count)")
            print("[HistoryViewModel] - Lectures: \(problematicLectures.count)")
            print("[HistoryViewModel] - Comics: \(problematicComics.count)")
            
            // Log to Crashlytics for monitoring
            CrashlyticsManager.shared.logNonFatalError(
                message: "Problematic documents found in user history",
                context: "history_validation",
                additionalData: [
                    "user_id": userId,
                    "total_problematic": totalProblematic,
                    "problematic_stories": problematicStories,
                    "problematic_content": problematicContent,
                    "problematic_lectures": problematicLectures,
                    "problematic_comics": problematicComics
                ]
            )
        } else {
            print("[HistoryViewModel] No problematic documents found for user: \(userId)")
        }
    }

    /// Test method to verify Firestore decoding is working properly
    func testFirestoreDecoding() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[HistoryViewModel] No authenticated user for testing")
            return
        }
        
        print("[HistoryViewModel] Testing Firestore decoding for user: \(userId)")
        
        // Test each collection individually
        do {
            let stories = try await firestoreService.query(
                FirebaseStory.self,
                from: "stories",
                field: "userId",
                isEqualTo: userId
            )
            print("[HistoryViewModel] ✅ Successfully decoded \(stories.count) stories")
        } catch {
            print("[HistoryViewModel] ❌ Failed to decode stories: \(error)")
        }
        
        do {
            let content = try await firestoreService.query(
                FirebaseUserContent.self,
                from: "userGeneratedContent",
                field: "userId",
                isEqualTo: userId
            )
            print("[HistoryViewModel] ✅ Successfully decoded \(content.count) user content items")
        } catch {
            print("[HistoryViewModel] ❌ Failed to decode user content: \(error)")
        }
        
        do {
            let lectures = try await firestoreService.query(
                FirebaseLecture.self,
                from: "lectures",
                field: "userId",
                isEqualTo: userId
            )
            print("[HistoryViewModel] ✅ Successfully decoded \(lectures.count) lectures")
        } catch {
            print("[HistoryViewModel] ❌ Failed to decode lectures: \(error)")
        }
        
        do {
            let comics = try await firestoreService.query(
                FirebaseComic.self,
                from: "comics",
                field: "userId",
                isEqualTo: userId
            )
            print("[HistoryViewModel] ✅ Successfully decoded \(comics.count) comics")
        } catch {
            print("[HistoryViewModel] ❌ Failed to decode comics: \(error)")
        }
    }
}