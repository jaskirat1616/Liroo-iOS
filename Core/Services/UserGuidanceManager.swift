import Foundation
import SwiftUI

@MainActor
class UserGuidanceManager: ObservableObject {
    @Published var showingContextualHelp = false
    @Published var currentContext: String = ""
    @Published var showingTooltip = false
    @Published var tooltipMessage = ""
    @Published var tooltipPosition: CGPoint = .zero
    
    private let userDefaults = UserDefaults.standard
    private let guidanceShownKey = "guidanceShown"
    private let helpViewedKey = "helpViewedCount"
    
    // Track which guidance has been shown
    private var shownGuidance: Set<String> {
        get {
            let array = userDefaults.array(forKey: guidanceShownKey) as? [String] ?? []
            return Set(array)
        }
        set {
            userDefaults.set(Array(newValue), forKey: guidanceShownKey)
        }
    }
    
    var helpViewedCount: Int {
        get { userDefaults.integer(forKey: helpViewedKey) }
        set { userDefaults.set(newValue, forKey: helpViewedKey) }
    }
    
    // MARK: - Contextual Help
    func showContextualHelp(for context: String) {
        currentContext = context
        showingContextualHelp = true
        incrementHelpViewed()
    }
    
    func hideContextualHelp() {
        showingContextualHelp = false
        currentContext = ""
    }
    
    // MARK: - Tooltips
    func showTooltip(_ message: String, at position: CGPoint) {
        tooltipMessage = message
        tooltipPosition = position
        showingTooltip = true
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.showingTooltip {
                self.hideTooltip()
            }
        }
    }
    
    func hideTooltip() {
        showingTooltip = false
        tooltipMessage = ""
    }
    
    // MARK: - Feature Guidance
    func shouldShowGuidance(for feature: String) -> Bool {
        !shownGuidance.contains(feature)
    }
    
    func markGuidanceAsShown(for feature: String) {
        shownGuidance.insert(feature)
    }
    
    func resetGuidance() {
        shownGuidance.removeAll()
    }
    
    // MARK: - Help Tracking
    private func incrementHelpViewed() {
        helpViewedCount += 1
    }
    
    // MARK: - Contextual Help Content
    func getContextualHelpContent(for context: String) -> [ContextualHelpItem] {
        switch context.lowercased() {
        case "import":
            return [
                ContextualHelpItem(
                    title: "Import Documents",
                    description: "Tap the + button to import files from your device",
                    icon: "plus.circle.fill",
                    action: "import"
                ),
                ContextualHelpItem(
                    title: "Camera Import",
                    description: "Take photos of documents to extract text",
                    icon: "camera.fill",
                    action: "camera"
                ),
                ContextualHelpItem(
                    title: "File Types",
                    description: "Supported: PDF, images, text files",
                    icon: "doc.text.fill",
                    action: "filetypes"
                )
            ]
        case "reading":
            return [
                ContextualHelpItem(
                    title: "Navigation",
                    description: "Swipe to navigate, pinch to zoom",
                    icon: "hand.draw.fill",
                    action: "navigation"
                ),
                ContextualHelpItem(
                    title: "Text Selection",
                    description: "Tap and hold to select text",
                    icon: "text.cursor",
                    action: "selection"
                ),
                ContextualHelpItem(
                    title: "Bookmarks",
                    description: "Save important pages for later",
                    icon: "bookmark.fill",
                    action: "bookmarks"
                )
            ]
        case "ai":
            return [
                ContextualHelpItem(
                    title: "AI Summaries",
                    description: "Get concise summaries of your content",
                    icon: "text.bubble.fill",
                    action: "summaries"
                ),
                ContextualHelpItem(
                    title: "Ask Questions",
                    description: "Ask questions about your documents",
                    icon: "questionmark.circle.fill",
                    action: "questions"
                ),
                ContextualHelpItem(
                    title: "Generate Questions",
                    description: "Create practice questions from content",
                    icon: "lightbulb.fill",
                    action: "generate"
                )
            ]
        case "settings":
            return [
                ContextualHelpItem(
                    title: "Font Settings",
                    description: "Adjust font size and family",
                    icon: "textformat",
                    action: "fonts"
                ),
                ContextualHelpItem(
                    title: "Accessibility",
                    description: "Customize for your needs",
                    icon: "accessibility",
                    action: "accessibility"
                ),
                ContextualHelpItem(
                    title: "Notifications",
                    description: "Manage reading reminders",
                    icon: "bell.fill",
                    action: "notifications"
                )
            ]
        default:
            return []
        }
    }
    
    // MARK: - Quick Tips
    func getQuickTips(for context: String) -> [String] {
        switch context.lowercased() {
        case "import":
            return [
                "Use good lighting for camera imports",
                "PDF files work best for long documents",
                "You can paste text directly from other apps"
            ]
        case "reading":
            return [
                "Double-tap to fit text to screen",
                "Use bookmarks to save important pages",
                "Swipe up/down to scroll through long text"
            ]
        case "ai":
            return [
                "Be specific when asking questions",
                "Summaries work best with longer content",
                "Save AI responses for later reference"
            ]
        case "settings":
            return [
                "OpenDyslexic font helps with reading",
                "Adjust line spacing for better readability",
                "High contrast mode improves visibility"
            ]
        default:
            return []
        }
    }
    
    // MARK: - Feature Introductions
    func getFeatureIntroduction(for feature: String) -> FeatureIntroduction? {
        switch feature.lowercased() {
        case "import":
            return FeatureIntroduction(
                title: "Import Your First Document",
                description: "Start by importing a document to begin reading with Liroo",
                icon: "doc.text.fill",
                color: .blue,
                steps: [
                    "Tap the + button",
                    "Choose your import method",
                    "Wait for processing to complete"
                ]
            )
        case "ai":
            return FeatureIntroduction(
                title: "AI-Powered Reading",
                description: "Get intelligent insights and summaries from your documents",
                icon: "brain.head.profile",
                color: .purple,
                steps: [
                    "Select text or tap AI button",
                    "Choose what you want to do",
                    "Get instant insights and answers"
                ]
            )
        case "accessibility":
            return FeatureIntroduction(
                title: "Accessibility Features",
                description: "Customize your reading experience for better accessibility",
                icon: "accessibility",
                color: .green,
                steps: [
                    "Go to Settings",
                    "Adjust font and spacing",
                    "Enable accessibility options"
                ]
            )
        default:
            return nil
        }
    }
}

// MARK: - Data Models
struct ContextualHelpItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let action: String
}

struct FeatureIntroduction: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let steps: [String]
}

// MARK: - Tooltip View
struct TooltipView: View {
    let message: String
    let position: CGPoint
    
    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
            
            // Arrow pointing down
            Triangle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 12, height: 6)
        }
        .position(position)
        .transition(.opacity.combined(with: .scale))
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Feature Introduction View
struct FeatureIntroductionView: View {
    let introduction: FeatureIntroduction
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: introduction.icon)
                    .font(.system(size: 60))
                    .foregroundColor(introduction.color)
                
                VStack(spacing: 8) {
                    Text(introduction.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(introduction.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("How to get started:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ForEach(Array(introduction.steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(introduction.color)
                            .clipShape(Circle())
                        
                        Text(step)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            
            Button("Got it!") {
                onDismiss()
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(introduction.color)
            .cornerRadius(22)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .padding()
    }
} 