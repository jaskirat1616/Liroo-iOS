import SwiftUI

/// Reusable empty state view component
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .symbolEffect(.bounce, value: icon)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticFeedbackManager.shared.buttonTap()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    static func noContent(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: "No Content Yet",
            message: "Start by generating your first story, lecture, or content",
            actionTitle: "Generate Content",
            action: action
        )
    }
    
    static func noHistory() -> EmptyStateView {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No History",
            message: "Your generated content will appear here"
        )
    }
    
    static func noSearchResults() -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results",
            message: "Try adjusting your search terms"
        )
    }
    
    static func noFavorites() -> EmptyStateView {
        EmptyStateView(
            icon: "heart.slash",
            title: "No Favorites",
            message: "Tap the heart icon to save your favorite content",
            actionTitle: "Browse Content",
            action: nil
        )
    }
    
    static func offline() -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "You're Offline",
            message: "Connect to the internet to generate new content. Your queued items will sync automatically when you're back online."
        )
    }
    
    static func error(message: String, retry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Something Went Wrong",
            message: message,
            actionTitle: "Retry",
            action: retry
        )
    }
}

