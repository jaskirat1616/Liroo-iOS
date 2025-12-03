import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Manages user favorites/bookmarks for content
@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favorites: [FavoriteItem] = []
    @Published var isLoading: Bool = false
    
    private let db = Firestore.firestore()
    private let collectionName = "favorites"
    
    private init() {
        Task {
            await loadFavorites()
        }
    }
    
    // MARK: - Models
    
    struct FavoriteItem: Identifiable, Codable {
        let id: String
        let contentId: String
        let contentType: ContentType
        let title: String
        let thumbnailUrl: String?
        let addedAt: Date
        
        enum ContentType: String, Codable {
            case story
            case lecture
            case userContent
            case comic
        }
    }
    
    // MARK: - Favorites Operations
    
    /// Add content to favorites
    func addFavorite(
        contentId: String,
        contentType: FavoriteItem.ContentType,
        title: String,
        thumbnailUrl: String? = nil
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FavoritesError.notAuthenticated
        }
        
        // Check if already favorited
        if favorites.contains(where: { $0.contentId == contentId && $0.contentType == contentType }) {
            throw FavoritesError.alreadyFavorited
        }
        
        let favorite = FavoriteItem(
            id: UUID().uuidString,
            contentId: contentId,
            contentType: contentType,
            title: title,
            thumbnailUrl: thumbnailUrl,
            addedAt: Date()
        )
        
        // Save to Firestore
        try await db.collection("users").document(userId)
            .collection(collectionName)
            .document(favorite.id)
            .setData(from: favorite)
        
        favorites.append(favorite)
        
        AnalyticsManager.shared.logEvent(name: "content_favorited", parameters: [
            "content_id": contentId,
            "content_type": contentType.rawValue
        ])
        
        HapticFeedbackManager.shared.success()
    }
    
    /// Remove content from favorites
    func removeFavorite(contentId: String, contentType: FavoriteItem.ContentType) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FavoritesError.notAuthenticated
        }
        
        guard let favorite = favorites.first(where: { $0.contentId == contentId && $0.contentType == contentType }) else {
            throw FavoritesError.notFound
        }
        
        // Remove from Firestore
        try await db.collection("users").document(userId)
            .collection(collectionName)
            .document(favorite.id)
            .delete()
        
        favorites.removeAll { $0.id == favorite.id }
        
        AnalyticsManager.shared.logEvent(name: "content_unfavorited", parameters: [
            "content_id": contentId,
            "content_type": contentType.rawValue
        ])
        
        HapticFeedbackManager.shared.buttonTap()
    }
    
    /// Check if content is favorited
    func isFavorited(contentId: String, contentType: FavoriteItem.ContentType) -> Bool {
        return favorites.contains { $0.contentId == contentId && $0.contentType == contentType }
    }
    
    /// Toggle favorite status
    func toggleFavorite(
        contentId: String,
        contentType: FavoriteItem.ContentType,
        title: String,
        thumbnailUrl: String? = nil
    ) async throws {
        if isFavorited(contentId: contentId, contentType: contentType) {
            try await removeFavorite(contentId: contentId, contentType: contentType)
        } else {
            try await addFavorite(contentId: contentId, contentType: contentType, title: title, thumbnailUrl: thumbnailUrl)
        }
    }
    
    // MARK: - Loading
    
    private func loadFavorites() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection(collectionName)
                .order(by: "addedAt", descending: true)
                .getDocuments()
            
            favorites = try snapshot.documents.compactMap { doc in
                try doc.data(as: FavoriteItem.self)
            }
        } catch {
            print("[FavoritesManager] Error loading favorites: \(error)")
            CrashlyticsManager.shared.logFirestoreError(
                error: error,
                operation: "load_favorites",
                collection: collectionName
            )
        }
        
        isLoading = false
    }
    
    // MARK: - Errors
    
    enum FavoritesError: LocalizedError {
        case notAuthenticated
        case alreadyFavorited
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be logged in to save favorites"
            case .alreadyFavorited:
                return "This content is already in your favorites"
            case .notFound:
                return "Favorite not found"
            }
        }
    }
}

