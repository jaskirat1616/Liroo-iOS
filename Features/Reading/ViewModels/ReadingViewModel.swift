import Foundation
import Combine
import FirebaseFirestore

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
                     } catch {
                        self.errorMessage = "Failed to decode story: \(error.localizedDescription)"
                     }
                } else if self.collectionName == "userGeneratedContent" { // Adjust collection name if different
                     do {
                        self.userContent = try document.data(as: FirebaseUserContent.self)
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

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                var responseBody: String = ""
                if let responseData = data as? Data, let bodyString = String(data: responseData, encoding: .utf8) {
                    responseBody = bodyString
                }
                self.handleDialogueError("Server error: \(statusCode). Body: \(responseBody)", loadingMessageId: loadingMessageId)
                return
            }
            
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let aiText = jsonResponse["dialogue_response"] as? String { // Assuming the key is "dialogue_response"
                if let index = dialogueMessages.firstIndex(where: { $0.id == loadingMessageId }) {
                    dialogueMessages[index] = ChatMessage(id: loadingMessageId, sender: .ai, text: aiText, isLoading: false)
                } else {
                    // Fallback if loading message was somehow removed
                    dialogueMessages.append(ChatMessage(sender: .ai, text: aiText))
                }
            } else {
                self.handleDialogueError("Failed to parse AI response.", loadingMessageId: loadingMessageId)
            }

        } catch {
            self.handleDialogueError("Network request failed: \(error.localizedDescription)", loadingMessageId: loadingMessageId)
        }
        isSendingDialogueMessage = false
    }

    @MainActor // Ensure UI updates are on main thread
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

