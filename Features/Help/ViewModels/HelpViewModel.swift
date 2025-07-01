import Foundation
import SwiftUI

@MainActor
class HelpViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedCategory: HelpCategory = .general
    @Published var showingContactForm = false
    @Published var showingVideoTutorials = false
    
    private let userDefaults = UserDefaults.standard
    private let helpViewedKey = "helpViewedCount"
    
    var filteredFAQs: [FAQItem] {
        if searchText.isEmpty {
            return selectedCategory.faqs
        } else {
            return selectedCategory.faqs.filter { faq in
                faq.question.localizedCaseInsensitiveContains(searchText) ||
                faq.answer.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var helpViewedCount: Int {
        get { userDefaults.integer(forKey: helpViewedKey) }
        set { userDefaults.set(newValue, forKey: helpViewedKey) }
    }
    
    func incrementHelpViewed() {
        helpViewedCount += 1
    }
    
    func getContextualHelp(for context: String) -> [ContextualHelpItem] {
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
    
    func submitFeedback(subject: String, message: String, email: String) async throws {
        // In a real app, this would send feedback to a server
        // For now, we'll just simulate success
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Log feedback locally
        let feedback = FeedbackItem(
            subject: subject,
            message: message,
            email: email,
            timestamp: Date()
        )
        
        // Save to UserDefaults for demo purposes
        saveFeedback(feedback)
    }
    
    private func saveFeedback(_ feedback: FeedbackItem) {
        var feedbacks = getSavedFeedbacks()
        feedbacks.append(feedback)
        
        if let encoded = try? JSONEncoder().encode(feedbacks) {
            userDefaults.set(encoded, forKey: "savedFeedbacks")
        }
    }
    
    private func getSavedFeedbacks() -> [FeedbackItem] {
        guard let data = userDefaults.data(forKey: "savedFeedbacks"),
              let feedbacks = try? JSONDecoder().decode([FeedbackItem].self, from: data) else {
            return []
        }
        return feedbacks
    }
}

// MARK: - Data Models
struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let category: HelpCategory
    var isExpanded: Bool = false
}

struct FeedbackItem: Codable {
    let subject: String
    let message: String
    let email: String
    let timestamp: Date
}

enum HelpCategory: String, CaseIterable {
    case general = "General"
    case importing = "Importing"
    case reading = "Reading"
    case ai = "AI Features"
    case accessibility = "Accessibility"
    case troubleshooting = "Troubleshooting"
    
    var icon: String {
        switch self {
        case .general: return "questionmark.circle.fill"
        case .importing: return "doc.text.fill"
        case .reading: return "book.fill"
        case .ai: return "brain.head.profile"
        case .accessibility: return "accessibility"
        case .troubleshooting: return "wrench.and.screwdriver.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .importing: return .green
        case .reading: return .purple
        case .ai: return .orange
        case .accessibility: return .cyan
        case .troubleshooting: return .red
        }
    }
    
    var faqs: [FAQItem] {
        switch self {
        case .general:
            return [
                FAQItem(
                    question: "What is Liroo?",
                    answer: "Liroo is an AI-powered reading companion that helps you read, understand, and learn from any document. It supports PDFs, images, and text files with advanced accessibility features.",
                    category: self
                ),
                FAQItem(
                    question: "How much does Liroo cost?",
                    answer: "Liroo offers a free tier with basic features. Premium features are available through subscription plans. Check the pricing section for current rates.",
                    category: self
                ),
                FAQItem(
                    question: "Is my data secure?",
                    answer: "Yes, we take data security seriously. All documents are encrypted and processed securely. We don't store your personal documents permanently.",
                    category: self
                )
            ]
        case .importing:
            return [
                FAQItem(
                    question: "What file types does Liroo support?",
                    answer: "Liroo supports PDF files, images (JPEG, PNG, HEIC), and text files. You can also paste text directly into the app.",
                    category: self
                ),
                FAQItem(
                    question: "How do I import a document?",
                    answer: "Tap the + button in the main interface. You can then choose to import from your device, take a photo, or paste text.",
                    category: self
                ),
                FAQItem(
                    question: "Can I import multiple files at once?",
                    answer: "Currently, you can import one file at a time. We're working on batch import functionality for future updates.",
                    category: self
                )
            ]
        case .reading:
            return [
                FAQItem(
                    question: "How do I navigate through pages?",
                    answer: "Swipe left or right to navigate between pages. You can also use the page indicator at the bottom to jump to specific pages.",
                    category: self
                ),
                FAQItem(
                    question: "Can I bookmark pages?",
                    answer: "Yes! Tap the bookmark icon on any page to save it for later. Access your bookmarks from the History tab.",
                    category: self
                ),
                FAQItem(
                    question: "How do I search within a document?",
                    answer: "Use the search bar at the top of the reading interface. Type your search term and tap the search button to find matches.",
                    category: self
                )
            ]
        case .ai:
            return [
                FAQItem(
                    question: "What AI features are available?",
                    answer: "Liroo offers AI-powered summaries, question generation, interactive Q&A, key point extraction, and content explanations.",
                    category: self
                ),
                FAQItem(
                    question: "How accurate are the AI summaries?",
                    answer: "Our AI provides high-quality summaries, but they should be used as supplements to reading, not replacements. Always verify important information.",
                    category: self
                ),
                FAQItem(
                    question: "Can I ask questions about my documents?",
                    answer: "Yes! Tap the AI button while reading and type your question. The AI will analyze your document and provide relevant answers.",
                    category: self
                )
            ]
        case .accessibility:
            return [
                FAQItem(
                    question: "What accessibility features are available?",
                    answer: "Liroo includes OpenDyslexic font, adjustable font sizes, line spacing, high contrast mode, screen reader support, and motion reduction options.",
                    category: self
                ),
                FAQItem(
                    question: "How do I enable OpenDyslexic font?",
                    answer: "Go to Settings > Accessibility > Font Family and select OpenDyslexic. This font is specially designed for readers with dyslexia.",
                    category: self
                ),
                FAQItem(
                    question: "Does Liroo work with VoiceOver?",
                    answer: "Yes, Liroo is fully compatible with VoiceOver and other screen readers. Enable screen reader support in accessibility settings.",
                    category: self
                )
            ]
        case .troubleshooting:
            return [
                FAQItem(
                    question: "The app is slow when loading documents",
                    answer: "Large documents may take time to process. Try closing other apps to free up memory, or break large documents into smaller sections.",
                    category: self
                ),
                FAQItem(
                    question: "AI features aren't working",
                    answer: "Check your internet connection. AI features require an active connection. If problems persist, try restarting the app.",
                    category: self
                ),
                FAQItem(
                    question: "I can't import a file",
                    answer: "Ensure the file type is supported (PDF, images, text). Check that you have sufficient storage space and try importing a smaller file first.",
                    category: self
                )
            ]
        }
    }
}
