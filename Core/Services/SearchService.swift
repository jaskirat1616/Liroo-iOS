import Foundation
import FirebaseFirestore

/// Service for searching across all user content
@MainActor
class SearchService: ObservableObject {
    static let shared = SearchService()
    
    private let db = Firestore.firestore()
    private var searchCache: [String: [SearchResult]] = [:]
    private let cacheExpiryTime: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    // MARK: - Search Models
    
    struct SearchResult: Identifiable, Codable {
        let id: String
        let type: ContentType
        let title: String
        let snippet: String
        let metadata: [String: String]
        let relevanceScore: Double
        
        enum ContentType: String, Codable {
            case story
            case lecture
            case userContent
            case comic
        }
    }
    
    // MARK: - Search Operations
    
    /// Search across all user content
    func search(query: String, userId: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }
        
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check cache
        if let cached = searchCache[normalizedQuery] {
            return cached
        }
        
        var allResults: [SearchResult] = []
        
        // Search stories
        let storyResults = try await searchStories(query: normalizedQuery, userId: userId)
        allResults.append(contentsOf: storyResults)
        
        // Search lectures
        let lectureResults = try await searchLectures(query: normalizedQuery, userId: userId)
        allResults.append(contentsOf: lectureResults)
        
        // Search user content
        let contentResults = try await searchUserContent(query: normalizedQuery, userId: userId)
        allResults.append(contentsOf: contentResults)
        
        // Search comics
        let comicResults = try await searchComics(query: normalizedQuery, userId: userId)
        allResults.append(contentsOf: comicResults)
        
        // Sort by relevance
        let sortedResults = allResults.sorted { $0.relevanceScore > $1.relevanceScore }
        
        // Cache results
        searchCache[normalizedQuery] = sortedResults
        
        // Clear cache after expiry
        Task {
            try? await Task.sleep(nanoseconds: UInt64(cacheExpiryTime * 1_000_000_000))
            searchCache.removeValue(forKey: normalizedQuery)
        }
        
        return sortedResults
    }
    
    // MARK: - Type-Specific Search
    
    private func searchStories(query: String, userId: String) async throws -> [SearchResult] {
        let storiesRef = db.collection("stories")
            .whereField("userId", isEqualTo: userId)
        
        let snapshot = try await storiesRef.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let content = data["overview"] as? String ?? data["content"] as? String else {
                return nil
            }
            
            let titleLower = title.lowercased()
            let contentLower = content.lowercased()
            
            // Calculate relevance score
            var score: Double = 0.0
            if titleLower.contains(query) {
                score += 2.0
            }
            if contentLower.contains(query) {
                score += 1.0
            }
            
            guard score > 0 else { return nil }
            
            // Find snippet with query
            let snippet = findSnippet(text: content, query: query, maxLength: 150)
            
            return SearchResult(
                id: doc.documentID,
                type: .story,
                title: title,
                snippet: snippet,
                metadata: [
                    "collection": "stories",
                    "documentId": doc.documentID
                ],
                relevanceScore: score
            )
        }
    }
    
    private func searchLectures(query: String, userId: String) async throws -> [SearchResult] {
        let lecturesRef = db.collection("lectures")
            .whereField("userId", isEqualTo: userId)
        
        let snapshot = try await lecturesRef.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let sections = data["sections"] as? [[String: Any]] else {
                return nil
            }
            
            // Search through sections
            var content = ""
            for section in sections {
                if let script = section["script"] as? String {
                    content += script + " "
                }
            }
            
            let titleLower = title.lowercased()
            let contentLower = content.lowercased()
            
            var score: Double = 0.0
            if titleLower.contains(query) {
                score += 2.0
            }
            if contentLower.contains(query) {
                score += 1.0
            }
            
            guard score > 0 else { return nil }
            
            let snippet = findSnippet(text: content, query: query, maxLength: 150)
            
            return SearchResult(
                id: doc.documentID,
                type: .lecture,
                title: title,
                snippet: snippet,
                metadata: [
                    "collection": "lectures",
                    "documentId": doc.documentID
                ],
                relevanceScore: score
            )
        }
    }
    
    private func searchUserContent(query: String, userId: String) async throws -> [SearchResult] {
        let contentRef = db.collection("userGeneratedContent")
            .whereField("userId", isEqualTo: userId)
        
        let snapshot = try await contentRef.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let topic = data["topic"] as? String,
                  let blocks = data["blocks"] as? [[String: Any]] else {
                return nil
            }
            
            var content = topic + " "
            for block in blocks {
                if let blockContent = block["content"] as? String {
                    content += blockContent + " "
                }
            }
            
            let topicLower = topic.lowercased()
            let contentLower = content.lowercased()
            
            var score: Double = 0.0
            if topicLower.contains(query) {
                score += 2.0
            }
            if contentLower.contains(query) {
                score += 1.0
            }
            
            guard score > 0 else { return nil }
            
            let snippet = findSnippet(text: content, query: query, maxLength: 150)
            
            return SearchResult(
                id: doc.documentID,
                type: .userContent,
                title: topic,
                snippet: snippet,
                metadata: [
                    "collection": "userGeneratedContent",
                    "documentId": doc.documentID
                ],
                relevanceScore: score
            )
        }
    }
    
    private func searchComics(query: String, userId: String) async throws -> [SearchResult] {
        let comicsRef = db.collection("comics")
            .whereField("userId", isEqualTo: userId)
        
        let snapshot = try await comicsRef.getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let panels = data["panels"] as? [[String: Any]] else {
                return nil
            }
            
            var content = title + " "
            for panel in panels {
                if let caption = panel["caption"] as? String {
                    content += caption + " "
                }
            }
            
            let titleLower = title.lowercased()
            let contentLower = content.lowercased()
            
            var score: Double = 0.0
            if titleLower.contains(query) {
                score += 2.0
            }
            if contentLower.contains(query) {
                score += 1.0
            }
            
            guard score > 0 else { return nil }
            
            let snippet = findSnippet(text: content, query: query, maxLength: 150)
            
            return SearchResult(
                id: doc.documentID,
                type: .comic,
                title: title,
                snippet: snippet,
                metadata: [
                    "collection": "comics",
                    "documentId": doc.documentID
                ],
                relevanceScore: score
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func findSnippet(text: String, query: String, maxLength: Int) -> String {
        let textLower = text.lowercased()
        let queryLower = query.lowercased()
        
        if let range = textLower.range(of: queryLower) {
            let startIndex = max(text.startIndex, text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex)
            let endIndex = min(text.endIndex, text.index(range.upperBound, offsetBy: maxLength, limitedBy: text.endIndex) ?? text.endIndex)
            
            var snippet = String(text[startIndex..<endIndex])
            
            if startIndex != text.startIndex {
                snippet = "..." + snippet
            }
            if endIndex != text.endIndex {
                snippet = snippet + "..."
            }
            
            // Highlight query in snippet (for display)
            return snippet
        }
        
        // Fallback: return beginning of text
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }
    
    /// Clear search cache
    func clearCache() {
        searchCache.removeAll()
    }
}

