import Foundation
import Combine
import FirebaseFirestore
import CoreData // Add this import for CoreData access

import FirebaseFirestore // Assuming Firebase for content fetching

// Define these structs if they don't exist elsewhere in your project
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var sender: MessageSender
    var text: String
    var isLoading: Bool = false // To show a loading indicator for AI messages

    init(id: UUID = UUID(), sender: MessageSender, text: String, isLoading: Bool = false) {
        self.id = id
        self.sender = sender
        self.text = text
        self.isLoading = isLoading
    }
}

enum MessageSender: String, Codable { // Added Codable for potential future use
    case user
    case ai
}

// For sending to backend, matching the Python backend's expected format for conversation_history
struct BackendChatMessage: Encodable {
    let sender: String // "user" or "ai"
    let text: String
}

class FullReadingViewModel: ObservableObject {
    @Published var story: FirebaseStory?
    @Published var userContent: FirebaseUserContent?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Dialogue related properties
    @Published var isShowingDialogueView: Bool = false
    @Published var dialogueMessages: [ChatMessage] = []
    @Published var selectedParagraphForDialogue: String?
    @Published var originalContentForDialogue: String? // Full text for context
    @Published var isSendingDialogueMessage: Bool = false

    // --- Real Reading session tracking ---
    private var sessionStartTime: Date?
    private var sessionWordsRead: Int = 0
    private var sessionProgress: Double = 0.0
    private var lastProgressUpdate: Date = Date()
    private var progressUpdateInterval: TimeInterval = 30 // Update progress every 30 seconds

    private var db = Firestore.firestore()
    private let itemID: String
    private let collectionName: String

    // User profile and level - these would be fetched or passed in
    // For now, let's use placeholders. These are crucial for the backend.
    var currentUserLevel: String = "Teen" // Example
    var currentUserProfile: [String: Any] = ["studentLevel": "High School", "topicsOfInterest": ["history", "science"]] // Example

    init(itemID: String, collectionName: String) {
        self.itemID = itemID
        self.collectionName = collectionName
        fetchFullContent()
    }

    // MARK: - CoreData Book Update
    private func markBookAsRead(withID id: String?, orTitle title: String?, progress: Double? = nil, author: String? = nil) {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        if let id = id, let uuid = UUID(uuidString: id) {
            fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        } else if let title = title, !title.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "title == %@", title)
        } else {
            return // No valid identifier
        }
        fetchRequest.fetchLimit = 1
        do {
            let book = try context.fetch(fetchRequest).first ?? Book(context: context)
            if let id = id, let uuid = UUID(uuidString: id) { book.id = uuid }
            book.title = title
            book.lastReadDate = Date()
            book.isArchived = false
            if let progress = progress { book.progress = Float(progress) }
            if let author = author { book.author = author }
            try context.save()
            print("[Reading] Updated/Created Book: id=\(String(describing: book.id)), title=\(book.title ?? "nil"), progress=\(book.progress), author=\(book.author ?? "nil"), lastReadDate=\(String(describing: book.lastReadDate)), isArchived=\(book.isArchived)")
            NotificationCenter.default.post(name: .dashboardNeedsRefresh, object: nil)
        } catch {
            print("Failed to update or create Book: \(error)")
        }
    }

    /// Log a reading session to CoreData for dashboard stats and charts
    private func logReadingSession(bookId: UUID?, date: Date = Date(), duration: TimeInterval, wordsRead: Int, wordsPerMinute: Int) {
        let context = PersistenceController.shared.container.viewContext
        let log = ReadingLog(context: context)
        log.id = UUID()
        log.date = date
        log.duration = Int64(duration) // in seconds
        log.wordsRead = Int64(wordsRead) // Estimated words for this specific session
        
        // Ensure you have added 'wordsPerMinute' attribute to your ReadingLog entity in Core Data Model
        // For example, as an Int16 or Double. Adjust cast if needed.
        log.wordsPerMinute = Int16(wordsPerMinute) // Calculated WPM for this specific session

        // TODO: Establish and save relationship to Book entity if bookId is not nil
        // if let bookUUID = bookId {
        //     let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        //     fetchRequest.predicate = NSPredicate(format: "id == %@", bookUUID as CVarArg)
        //     fetchRequest.fetchLimit = 1
        //     do {
        //         if let book = try context.fetch(fetchRequest).first {
        //             log.book = book // Assuming a 'book' relationship exists on ReadingLog
        //         }
        //     } catch {
        //         print("[Reading] Error fetching book to link to ReadingLog: \(error)")
        //     }
        // }

        do {
            try context.save()
            print("[Reading] Created ReadingLog: id=\(String(describing: log.id)), date=\(date), duration=\(duration), wordsRead=\(wordsRead), sessionWPM=\(wordsPerMinute)")
        } catch {
            print("[Reading] Failed to create ReadingLog: \(error)")
        }
    }

    func fetchFullContent() {
        isLoading = true
        errorMessage = nil
        story = nil
        userContent = nil

        let docRef = db.collection(collectionName).document(itemID)

        docRef.getDocument { (document, error) in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Failed to load content: \(error.localizedDescription)"
                    return
                }

                guard let document = document, document.exists else {
                    self.errorMessage = "Document does not exist."
                    return
                }
                
                // Assuming your FirebaseStory and FirebaseUserContent have an initializer from dictionary
                if self.collectionName == "stories" {
                     do {
                        self.story = try document.data(as: FirebaseStory.self)
                        // Don't log reading session here - wait for actual reading
                        print("[Reading] Loaded story: \(self.story?.title ?? "Unknown")")
                     } catch {
                        self.errorMessage = "Failed to decode story: \(error.localizedDescription)"
                     }
                } else if self.collectionName == "userGeneratedContent" { // Adjust collection name if different
                     do {
                        self.userContent = try document.data(as: FirebaseUserContent.self)
                        // Don't log reading session here - wait for actual reading
                        print("[Reading] Loaded user content: \(self.userContent?.topic ?? "Unknown")")
                     } catch {
                        self.errorMessage = "Failed to decode user content: \(error.localizedDescription)"
                     }
                } else {
                    self.errorMessage = "Unknown content type."
                }
            }
        }
    }
    
    // MARK: - Dialogue Logic

    func initiateDialogue(paragraph: String, originalContent: String) {
        self.selectedParagraphForDialogue = paragraph
        self.originalContentForDialogue = originalContent
        self.dialogueMessages = [] // Clear previous messages
        // Add an initial greeting or prompt from AI if desired
        self.dialogueMessages.append(ChatMessage(sender: .ai, text: "Hi there! What would you like to discuss about this paragraph?"))
        self.isShowingDialogueView = true
        
        // Track dialogue interaction for engagement metrics
        self.trackDialogueInteraction()
    }

    @MainActor
    func sendDialogueMessage(userQuestion: String, selectedSnippet: String, originalBlockContent: String) async {
        guard !isSendingDialogueMessage else { return }

        isSendingDialogueMessage = true
        let userMessage = ChatMessage(sender: .user, text: userQuestion)
        dialogueMessages.append(userMessage)

        let loadingMessageId = UUID()
        dialogueMessages.append(ChatMessage(id: loadingMessageId, sender: .ai, text: "", isLoading: true))

        let historyForBackend = dialogueMessages.dropLast(2).compactMap { msg -> BackendChatMessage? in
            guard !msg.isLoading else { return nil }
            return BackendChatMessage(sender: msg.sender.rawValue, text: msg.text)
        }

        let requestBody: [String: Any] = [
            "dialogue_mode": true,
            "selected_text_snippet": selectedSnippet,
            "original_block_content": originalBlockContent,
            "user_question": userQuestion,
            "conversation_history": historyForBackend.map { ["sender": $0.sender, "text": $0.text] },
            "level": currentUserLevel,
            "profile": currentUserProfile,
        ]
        
        guard let url = URL(string: "https://backend-orasync-test.onrender.com/process") else { 
            self.handleDialogueError("Invalid API URL", loadingMessageId: loadingMessageId)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            self.handleDialogueError("Failed to encode request: \(error.localizedDescription)", loadingMessageId: loadingMessageId)
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.handleDialogueError("Invalid response", loadingMessageId: loadingMessageId)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                self.handleDialogueError("Server error: \(httpResponse.statusCode)", loadingMessageId: loadingMessageId)
                return
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                self.handleDialogueError("Invalid response format", loadingMessageId: loadingMessageId)
                return
            }
            
            // Update the loading message with the actual response
            if let index = dialogueMessages.firstIndex(where: { $0.id == loadingMessageId }) {
                dialogueMessages[index] = ChatMessage(id: loadingMessageId, sender: .ai, text: responseText, isLoading: false)
            }
            
            isSendingDialogueMessage = false
            
        } catch {
            self.handleDialogueError("Network error: \(error.localizedDescription)", loadingMessageId: loadingMessageId)
        }
    }

    private func handleDialogueError(_ message: String, loadingMessageId: UUID) {
        if let index = dialogueMessages.firstIndex(where: { $0.id == loadingMessageId }) {
             dialogueMessages[index] = ChatMessage(id: loadingMessageId, sender: .ai, text: "Error: \(message)", isLoading: false)
        } else {
             // If the loading message wasn't found, append the error as a new message.
             dialogueMessages.append(ChatMessage(sender: .ai, text: "Error: \(message)"))
        }
        isSendingDialogueMessage = false
        print("Dialogue Error: \(message)") // For debugging
    }
    
    func clearDialogue() {
        dialogueMessages = []
        selectedParagraphForDialogue = nil
        originalContentForDialogue = nil
        // isShowingDialogueView = false // Optionally hide the view when cleared
    }

    /// Call this when the user starts reading
    func startReadingSession() {
        guard sessionStartTime == nil else { return } // Prevent double-start
        sessionStartTime = Date()
        // sessionWordsRead and sessionProgress are reset by the logic in calculateRealProgressForCurrentSession
        // when a new session starts if you were using them for live UI.
        lastProgressUpdate = Date()
        print("[Reading] Session started at \(String(describing: sessionStartTime))")
    }

    /// Call this when the user finishes reading (or at a save point)
    func finishReadingSession() {
        guard let start = sessionStartTime else { return } // Prevent double-finish
        let end = Date()
        let actualSessionDuration = end.timeIntervalSince(start) // Duration in seconds
        
        // Calculate estimated words read for THIS session and the overall progress for the content
        let (estimatedWordsInThisSession, overallContentProgress) = calculateRealProgressForCurrentSession()
        
        // Calculate WPM for THIS specific session
        let durationInMinutes = actualSessionDuration / 60.0
        let sessionWPM = durationInMinutes > 0 ? Int(Double(estimatedWordsInThisSession) / durationInMinutes) : 0
        
        print("[Reading] Session finished. Duration: \(actualSessionDuration) seconds, Est. Words for Session: \(estimatedWordsInThisSession), Est. Session WPM: \(sessionWPM), Overall Content Progress: \(overallContentProgress)")
        
        // Only log session if there was actual reading activity
        if actualSessionDuration > 30 && estimatedWordsInThisSession > 0 { // Minimum 30 seconds and some words read
            if let story = self.story {
                let bookUUID = story.id.flatMap { UUID(uuidString: $0) }
                self.markBookAsRead(withID: story.id, orTitle: story.title, progress: overallContentProgress, author: nil)
                self.logReadingSession(bookId: bookUUID, duration: actualSessionDuration, wordsRead: estimatedWordsInThisSession, wordsPerMinute: sessionWPM)
            } else if let userContent = self.userContent {
                let bookUUID = userContent.id.flatMap { UUID(uuidString: $0) }
                self.markBookAsRead(withID: userContent.id, orTitle: userContent.topic, progress: overallContentProgress, author: nil)
                self.logReadingSession(bookId: bookUUID, duration: actualSessionDuration, wordsRead: estimatedWordsInThisSession, wordsPerMinute: sessionWPM)
            }
        }
        
        // Reset session tracking variables
        sessionStartTime = nil
    }
    
    /// Update reading progress periodically.
    /// This method is primarily for potential live UI updates of an *ongoing* session.
    /// The definitive calculation and saving of session data happens in `finishReadingSession`.
    func updateReadingProgress() {
        guard sessionStartTime != nil else { return } // No session active
        
        let now = Date()
        if now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval {
            let (currentEstimatedWordsInSession, currentOverallProgress) = calculateRealProgressForCurrentSession()
            // If you need to display live progress for the *current* session in the UI,
            // you could update @Published properties here.
            // For example:
            // self.currentSessionLiveWords = currentEstimatedWordsInSession
            // self.currentLiveBookProgress = currentOverallProgress
            lastProgressUpdate = now
            print("[Reading] Live progress update check: Est. words this session so far: \(currentEstimatedWordsInSession), Overall Book Progress: \(Int(currentOverallProgress * 100))%")
        }
    }
    
    /// Calculates estimated words read in the *current ongoing session* and the *overall progress* for the entire content.
    /// Word estimation is based on time spent in the current session and an assumed WPM.
    private func calculateRealProgressForCurrentSession() -> (estimatedWordsInSession: Int, overallProgress: Double) {
        guard let start = sessionStartTime else { return (0, 0.0) } // No session started
        
        let durationOfCurrentSessionSoFar = Date().timeIntervalSince(start) // Duration of the current ongoing session in seconds
        let minutesSpentInCurrentSession = durationOfCurrentSessionSoFar / 60.0
        
        // TODO: This assumedWPM should ideally be user-configurable or dynamically learned for better accuracy.
        let assumedWPMForWordEstimation = 200.0
        let estimatedWordsReadThisSession = Int(minutesSpentInCurrentSession * assumedWPMForWordEstimation)
        
        // Calculate overall progress for the content.
        // This progress is based on words estimated *for this session* relative to total content words.
        // `markBookAsRead` in `finishReadingSession` uses this to update the Book's overall progress.
        let totalContentWords = getTotalContentWords()
        let calculatedOverallProgress = totalContentWords > 0 ? min(Double(estimatedWordsReadThisSession) / Double(totalContentWords), 1.0) : 0.0
        
        return (estimatedWordsReadThisSession, calculatedOverallProgress)
    }
    
    /// Get total word count of content
    private func getTotalContentWords() -> Int {
        if let story = self.story {
            let text = story.chapters?.compactMap { $0.content }.joined(separator: " ") ?? ""
            return text.split(separator: " ").count
        } else if let userContent = self.userContent {
            let text = userContent.blocks?.compactMap { $0.content }.joined(separator: " ") ?? ""
            return text.split(separator: " ").count
        }
        return 0
    }
    
    /// Track dialogue interaction for engagement metrics
    private func trackDialogueInteraction() {
        // In a real implementation, this would be stored in Core Data or UserDefaults
        // For now, we'll use UserDefaults to track dialogue interactions
        let currentCount = UserDefaults.standard.integer(forKey: "dialogueInteractionsCount")
        UserDefaults.standard.set(currentCount + 1, forKey: "dialogueInteractionsCount")
        print("[Engagement] Dialogue interaction tracked. Total: \(currentCount + 1)")
    }
}

// Ensure you have FirebaseStory and FirebaseUserContent structs/classes defined
// with appropriate initializers (e.g., init(from decoder: Decoder) throws or init?(dictionary: [String: Any]))
// For example:
/*
struct FirebaseStory: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String?
    // other properties
}

struct FirebaseUserContent: Codable, Identifiable {
    @DocumentID var id: String?
    var textContent: String?
    // other properties
}
*/

