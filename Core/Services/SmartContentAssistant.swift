import Foundation
import FirebaseFirestore
import FirebaseAuth

/// AI-powered smart content assistant with suggestions and auto-complete
@MainActor
class SmartContentAssistant: ObservableObject {
    static let shared = SmartContentAssistant()
    
    @Published var suggestions: [ContentSuggestion] = []
    @Published var isLoading: Bool = false
    
    private let db = Firestore.firestore()
    private var userHistory: [String] = []
    private var popularPrompts: [String] = []
    
    private init() {
        Task {
            await loadPopularPrompts()
            await loadUserHistory()
        }
    }
    
    // MARK: - Models
    
    struct ContentSuggestion: Identifiable {
        let id: String
        let prompt: String
        let type: SuggestionType
        let confidence: Double
        let context: String?
        
        enum SuggestionType {
            case autoComplete
            case template
            case personalized
            case trending
        }
    }
    
    // MARK: - Suggestions
    
    /// Get suggestions based on current input
    func getSuggestions(for input: String, contentType: ContentType) async {
        guard !input.isEmpty else {
            suggestions = []
            return
        }
        
        isLoading = true
        
        var newSuggestions: [ContentSuggestion] = []
        
        // 1. Auto-complete based on user history
        let autoComplete = await getAutoCompleteSuggestions(input: input, contentType: contentType)
        newSuggestions.append(contentsOf: autoComplete)
        
        // 2. Template suggestions
        let templates = getTemplateSuggestions(input: input, contentType: contentType)
        newSuggestions.append(contentsOf: templates)
        
        // 3. Personalized suggestions based on reading history
        let personalized = await getPersonalizedSuggestions(input: input, contentType: contentType)
        newSuggestions.append(contentsOf: personalized)
        
        // 4. Trending prompts
        let trending = getTrendingSuggestions(input: input, contentType: contentType)
        newSuggestions.append(contentsOf: trending)
        
        suggestions = Array(newSuggestions.sorted { $0.confidence > $1.confidence }.prefix(5))
        isLoading = false
    }
    
    // MARK: - Content Types
    
    enum ContentType {
        case story
        case lecture
        case general
        case comic
    }
    
    // MARK: - Suggestion Types
    
    private func getAutoCompleteSuggestions(input: String, contentType: ContentType) async -> [ContentSuggestion] {
        let inputLower = input.lowercased()
        
        return userHistory
            .filter { $0.lowercased().contains(inputLower) }
            .prefix(3)
            .map { prompt in
                ContentSuggestion(
                    id: UUID().uuidString,
                    prompt: prompt,
                    type: .autoComplete,
                    confidence: 0.8,
                    context: "From your history"
                )
            }
    }
    
    private func getTemplateSuggestions(input: String, contentType: ContentType) -> [ContentSuggestion] {
        let templates: [String: [String]]
        
        switch contentType {
        case .story:
            templates = [
                "Create a story about": ["a young wizard", "space exploration", "time travel", "magical creatures"],
                "Write a tale of": ["adventure", "friendship", "discovery", "courage"]
            ]
        case .lecture:
            templates = [
                "Explain": ["how photosynthesis works", "the water cycle", "the solar system", "gravity"],
                "Teach me about": ["ancient history", "biology", "mathematics", "physics"]
            ]
        case .comic:
            templates = [
                "Create a comic about": ["superheroes", "daily life", "fantasy adventure", "sci-fi"],
                "Draw a story of": ["friendship", "comedy", "action", "mystery"]
            ]
        default:
            return []
        }
        
        var suggestions: [ContentSuggestion] = []
        
        for (prefix, completions) in templates {
            if input.lowercased().hasPrefix(prefix.lowercased()) {
                for completion in completions.prefix(2) {
                    suggestions.append(ContentSuggestion(
                        id: UUID().uuidString,
                        prompt: "\(prefix) \(completion)",
                        type: .template,
                        confidence: 0.7,
                        context: "Template suggestion"
                    ))
                }
            }
        }
        
        return suggestions
    }
    
    private func getPersonalizedSuggestions(input: String, contentType: ContentType) async -> [ContentSuggestion] {
        // Analyze user's reading history to suggest similar topics
        // This would use the RecommendationEngine
        return []
    }
    
    private func getTrendingSuggestions(input: String, contentType: ContentType) -> [ContentSuggestion] {
        let inputLower = input.lowercased()
        
        return popularPrompts
            .filter { $0.lowercased().contains(inputLower) }
            .prefix(2)
            .map { prompt in
                ContentSuggestion(
                    id: UUID().uuidString,
                    prompt: prompt,
                    type: .trending,
                    confidence: 0.6,
                    context: "Trending prompt"
                )
            }
    }
    
    // MARK: - Data Loading
    
    private func loadPopularPrompts() async {
        // Load popular prompts from Firestore
        do {
            let snapshot = try await db.collection("popularPrompts")
                .order(by: "usageCount", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            popularPrompts = snapshot.documents.compactMap { doc in
                doc.data()["prompt"] as? String
            }
        } catch {
            print("[SmartContentAssistant] Error loading popular prompts: \(error)")
        }
    }
    
    private func loadUserHistory() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("contentHistory")
                .order(by: "timestamp", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            userHistory = snapshot.documents.compactMap { doc in
                doc.data()["prompt"] as? String
            }
        } catch {
            print("[SmartContentAssistant] Error loading user history: \(error)")
        }
    }
    
    /// Save prompt to user history
    func savePrompt(_ prompt: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Add to local history if not already present
        if !userHistory.contains(prompt) {
            userHistory.insert(prompt, at: 0)
            userHistory = Array(userHistory.prefix(100))
        }
        
        // Save to Firestore
        do {
            try await db.collection("users").document(userId)
                .collection("contentHistory")
                .addDocument(data: [
                    "prompt": prompt,
                    "timestamp": FieldValue.serverTimestamp()
                ])
        } catch {
            print("[SmartContentAssistant] Error saving prompt: \(error)")
        }
    }
}

