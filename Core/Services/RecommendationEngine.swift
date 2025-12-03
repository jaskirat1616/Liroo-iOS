import Foundation
import FirebaseFirestore
import FirebaseAuth

/// AI-powered recommendation engine for personalized content suggestions
@MainActor
class RecommendationEngine {
    static let shared = RecommendationEngine()
    
    private let db = Firestore.firestore()
    private var userPreferences: UserPreferences?
    private var readingHistory: [ReadingHistoryItem] = []
    
    private init() {
        Task {
            await loadUserPreferences()
            await loadReadingHistory()
        }
    }
    
    // MARK: - Models
    
    struct UserPreferences: Codable {
        var favoriteGenres: [String]
        var favoriteStyles: [String]
        var preferredReadingLevel: String
        var topics: [String]
        var readingPatterns: [String: Int] // topic -> count
    }
    
    struct ReadingHistoryItem: Codable {
        let contentId: String
        let contentType: String
        let genre: String?
        let style: String?
        let level: String?
        let timestamp: Date
        let engagementScore: Double
    }
    
    struct Recommendation: Identifiable {
        let id: String
        let type: RecommendationType
        let title: String
        let description: String
        let relevanceScore: Double
        let reason: String
        
        enum RecommendationType {
            case similarContent
            case trendingTopic
            case personalizedStory
            case continueReading
            case newGenre
        }
    }
    
    // MARK: - Recommendations
    
    /// Get personalized recommendations for user
    func getRecommendations(userId: String, limit: Int = 10) async throws -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // 1. Similar content based on reading history
        let similarRecommendations = await getSimilarContentRecommendations(userId: userId)
        recommendations.append(contentsOf: similarRecommendations)
        
        // 2. Trending topics
        let trendingRecommendations = await getTrendingTopicRecommendations(userId: userId)
        recommendations.append(contentsOf: trendingRecommendations)
        
        // 3. Continue reading suggestions
        let continueRecommendations = await getContinueReadingRecommendations(userId: userId)
        recommendations.append(contentsOf: continueRecommendations)
        
        // 4. New genre suggestions (based on user's current preferences)
        let newGenreRecommendations = await getNewGenreRecommendations(userId: userId)
        recommendations.append(contentsOf: newGenreRecommendations)
        
        // Sort by relevance and return top N
        return Array(recommendations.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(limit))
    }
    
    // MARK: - Recommendation Types
    
    private func getSimilarContentRecommendations(userId: String) async -> [Recommendation] {
        guard !readingHistory.isEmpty else { return [] }
        
        // Find most engaged content
        let topContent = readingHistory
            .sorted { $0.engagementScore > $1.engagementScore }
            .prefix(3)
        
        var recommendations: [Recommendation] = []
        
        for item in topContent {
            // Find similar content based on genre/style/level
            let similarContent = await findSimilarContent(
                to: item,
                userId: userId
            )
            
            for content in similarContent {
                recommendations.append(Recommendation(
                    id: content.id,
                    type: .similarContent,
                    title: content.title,
                    description: content.description,
                    relevanceScore: content.relevanceScore,
                    reason: "Similar to content you enjoyed: \(item.contentId)"
                ))
            }
        }
        
        return recommendations
    }
    
    private func getTrendingTopicRecommendations(userId: String) async -> [Recommendation] {
        // Get trending topics from all users' recent content
        let trendingTopics = await getTrendingTopics()
        
        return trendingTopics.prefix(5).map { topic in
            Recommendation(
                id: UUID().uuidString,
                type: .trendingTopic,
                title: "Explore: \(topic.name)",
                description: "\(topic.count) users are reading about this topic",
                relevanceScore: Double(topic.count) * 0.1,
                reason: "Trending topic in the community"
            )
        }
    }
    
    private func getContinueReadingRecommendations(userId: String) async -> [Recommendation] {
        // Find content user started but didn't finish
        let incompleteContent = await findIncompleteContent(userId: userId)
        
        return incompleteContent.map { content in
            Recommendation(
                id: content.id,
                type: .continueReading,
                title: content.title,
                description: "Continue from \(Int(content.completionPercentage))%",
                relevanceScore: 0.9 - (content.completionPercentage / 100.0),
                reason: "You've already started reading this"
            )
        }
    }
    
    private func getNewGenreRecommendations(userId: String) async -> [Recommendation] {
        guard let preferences = userPreferences else { return [] }
        
        // Find genres user hasn't explored
        let allGenres = ["adventure", "mystery", "sci-fi", "fantasy", "educational", "historical"]
        let unexploredGenres = allGenres.filter { !preferences.favoriteGenres.contains($0) }
        
        return unexploredGenres.prefix(2).map { genre in
            Recommendation(
                id: UUID().uuidString,
                type: .newGenre,
                title: "Try \(genre.capitalized)",
                description: "Discover content in a new genre you haven't explored",
                relevanceScore: 0.7,
                reason: "Expand your reading horizons"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func findSimilarContent(to item: ReadingHistoryItem, userId: String) async -> [SimilarContent] {
        // Query Firestore for similar content
        // This is a simplified version - real implementation would use vector similarity
        return []
    }
    
    private func getTrendingTopics() async -> [(name: String, count: Int)] {
        // Get trending topics from Firestore
        // This would aggregate recent content topics
        return []
    }
    
    private func findIncompleteContent(userId: String) async -> [IncompleteContent] {
        // Find content with < 100% completion from reading sessions
        return []
    }
    
    private func loadUserPreferences() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let doc = try await db.collection("users").document(userId)
                .collection("preferences")
                .document("reading")
                .getDocument()
            
            if let data = doc.data() {
                userPreferences = try? JSONDecoder().decode(UserPreferences.self, from: JSONSerialization.data(withJSONObject: data))
            }
        } catch {
            print("[RecommendationEngine] Error loading preferences: \(error)")
        }
    }
    
    private func loadReadingHistory() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("readingHistory")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            readingHistory = try snapshot.documents.compactMap { doc in
                try doc.data(as: ReadingHistoryItem.self)
            }
        } catch {
            print("[RecommendationEngine] Error loading history: \(error)")
        }
    }
    
    // MARK: - Helper Types
    
    struct SimilarContent {
        let id: String
        let title: String
        let description: String
        let relevanceScore: Double
    }
    
    struct IncompleteContent {
        let id: String
        let title: String
        let completionPercentage: Double
    }
}

