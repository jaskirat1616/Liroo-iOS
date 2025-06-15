import Foundation

// MARK: - Chapter Model
struct Chapter: Identifiable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    var firebaseImageUrl: String?
    
    init(id: UUID = UUID(), title: String, content: String, order: Int, firebaseImageUrl: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.firebaseImageUrl = firebaseImageUrl
    }
} 