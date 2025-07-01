import SwiftUI

struct ContextualHelpView: View {
    let context: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var helpViewModel = HelpViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Help for \(context.capitalized)")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Get contextual help for this feature")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Contextual help items
                    LazyVStack(spacing: 16) {
                        ForEach(helpViewModel.getContextualHelp(for: context), id: \.id) { item in
                            ContextualHelpCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Related help
                    RelatedHelpSection(context: context)
                        .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Contextual Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContextualHelpCard: View {
    let item: ContextualHelpItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.title2)
                        .foregroundColor(.cyan)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(item.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    switch item.action {
                    case "import":
                        ImportHelpContent()
                    case "camera":
                        CameraHelpContent()
                    case "filetypes":
                        FileTypesHelpContent()
                    case "navigation":
                        NavigationHelpContent()
                    case "selection":
                        SelectionHelpContent()
                    case "bookmarks":
                        BookmarksHelpContent()
                    case "summaries":
                        SummariesHelpContent()
                    case "questions":
                        QuestionsHelpContent()
                    case "generate":
                        GenerateHelpContent()
                    case "fonts":
                        FontsHelpContent()
                    case "accessibility":
                        AccessibilityHelpContent()
                    case "notifications":
                        NotificationsHelpContent()
                    default:
                        Text("Detailed help content coming soon...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

struct RelatedHelpSection: View {
    let context: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Related Help")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                RelatedHelpCard(
                    title: "FAQ",
                    description: "Find answers to common questions",
                    icon: "questionmark.circle.fill"
                )
                
                RelatedHelpCard(
                    title: "Video Tutorial",
                    description: "Watch step-by-step guides",
                    icon: "play.circle.fill"
                )
                
                RelatedHelpCard(
                    title: "Contact Support",
                    description: "Get personalized help",
                    icon: "envelope.fill"
                )
            }
        }
    }
}

struct RelatedHelpCard: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        Button(action: {
            // Navigate to related help
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.cyan)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Context-Specific Help Content
struct ImportHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Import Documents")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Tap the + button in the main interface")
                Text("2. Choose your import method:")
                Text("   • Select from device")
                Text("   • Take a photo")
                Text("   • Paste text")
                Text("3. Wait for processing to complete")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct CameraHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Import Tips")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Ensure good lighting")
                Text("• Hold camera steady")
                Text("• Capture the entire document")
                Text("• Avoid shadows and glare")
                Text("• Use high contrast if possible")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct FileTypesHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported File Types")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• PDF files (.pdf)")
                Text("• Images (.jpg, .png, .heic)")
                Text("• Text files (.txt)")
                Text("• Rich text (.rtf)")
                Text("• Word documents (.docx)")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct NavigationHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigation Controls")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Swipe left/right to change pages")
                Text("• Pinch to zoom in/out")
                Text("• Double-tap to fit to screen")
                Text("• Use page indicator at bottom")
                Text("• Tap arrows for precise navigation")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct SelectionHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text Selection")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Tap and hold to start selection")
                Text("• Drag to extend selection")
                Text("• Use handles to adjust selection")
                Text("• Tap 'Copy' to copy text")
                Text("• Tap 'AI' to analyze selection")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct BookmarksHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Using Bookmarks")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Tap bookmark icon to save page")
                Text("• Access bookmarks in History tab")
                Text("• Add notes to bookmarks")
                Text("• Organize by folders")
                Text("• Share bookmarks with others")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct SummariesHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Summaries")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Tap AI button for summary")
                Text("• Choose summary length")
                Text("• Focus on key points")
                Text("• Include important details")
                Text("• Save summaries for later")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct QuestionsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Asking Questions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Type your question in AI chat")
                Text("• Be specific for better answers")
                Text("• Ask about concepts, facts, or details")
                Text("• Get explanations and examples")
                Text("• Save Q&A for reference")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct GenerateHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Question Generation")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• AI creates practice questions")
                Text("• Multiple choice and open-ended")
                Text("• Based on document content")
                Text("• Test your understanding")
                Text("• Perfect for studying")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct FontsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Adjust font size (12-24pt)")
                Text("• Choose font family")
                Text("• OpenDyslexic for dyslexia")
                Text("• System fonts for clarity")
                Text("• Preview changes in real-time")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct AccessibilityHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accessibility Features")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• High contrast mode")
                Text("• Reduce motion")
                Text("• Screen reader support")
                Text("• VoiceOver compatibility")
                Text("• Customizable line spacing")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

struct NotificationsHelpContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notification Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Reading reminders")
                Text("• Progress updates")
                Text("• New feature alerts")
                Text("• Custom notification times")
                Text("• Quiet hours settings")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Contextual Help Overlay
struct ContextualHelpOverlay: View {
    let context: String
    let isPresented: Binding<Bool>
    
    var body: some View {
        if isPresented.wrappedValue {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented.wrappedValue = false
                    }
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.cyan)
                        
                        Text("Need Help?")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Tap to get contextual help for this feature")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Get Help") {
                            // Present contextual help
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.cyan)
                        .cornerRadius(22)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding()
                }
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    ContextualHelpView(context: "import")
} 