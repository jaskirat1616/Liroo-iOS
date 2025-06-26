import SwiftUI

extension Notification.Name {
    static let dashboardNeedsRefresh = Notification.Name("dashboardNeedsRefresh")
}

struct FullReadingView: View {
    @StateObject private var viewModel: FullReadingViewModel
    @State private var userDialogueInput: String = "" // For the TextField in the sheet
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var progressTimer: Timer?

    // Reading Settings
    @AppStorage("readingThemeName") private var selectedThemeName: String = ReadingTheme.light.rawValue
    @AppStorage("readingFontSize") private var selectedFontSize: Double = 17.0 // Default font size
    @AppStorage("readingFontStyleName") private var selectedFontStyleName: String = ReadingFontStyle.systemDefault.rawValue // Added

    private var currentTheme: ReadingTheme {
        ReadingTheme(rawValue: selectedThemeName) ?? .light
    }
    private var currentFontStyle: ReadingFontStyle { // Added
        ReadingFontStyle(rawValue: selectedFontStyleName) ?? .systemDefault
    }
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    init(itemID: String, collectionName: String, itemTitle: String) {
        _viewModel = StateObject(wrappedValue: FullReadingViewModel(itemID: itemID, collectionName: collectionName))
        self.itemTitle = itemTitle // Store title for navigation bar
    }
    
    private var itemTitle: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading content...")
                            .font(currentFontStyle.getFont(size: CGFloat(selectedFontSize)))
                            .foregroundColor(currentTheme.primaryTextColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let story = viewModel.story {
                    StoryDetailView(story: story,
                                    baseFontSize: selectedFontSize,
                                    primaryTextColor: currentTheme.primaryTextColor,
                                    secondaryTextColor: currentTheme.secondaryTextColor,
                                    fontStyle: currentFontStyle)
                        .environmentObject(viewModel) // Inject viewModel
                } else if let userContent = viewModel.userContent {
                    UserContentDetailView(userContent: userContent,
                                          baseFontSize: selectedFontSize,
                                          primaryTextColor: currentTheme.primaryTextColor,
                                          secondaryTextColor: currentTheme.secondaryTextColor,
                                          fontStyle: currentFontStyle) // Pass font style
                        .environmentObject(viewModel) // Inject viewModel
                } else {
                    Text("No content found or loaded.")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(currentTheme.primaryTextColor) // Apply text color
                        .font(currentFontStyle.getFont(size: CGFloat(selectedFontSize))) // Apply font style
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow VStack to expand
            .padding(.horizontal, isIPad ? 20 : 0) // Add iPad-specific horizontal padding
        }
        .background(
            LinearGradient(
                gradient: Gradient(
                    colors: colorScheme == .dark ?
                    [.cyan.opacity(0.1), .cyan.opacity(0.05), Color(.systemBackground), Color(.systemBackground)] :
                    [.cyan.opacity(0.2), .cyan.opacity(0.1),  .white, .white]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(itemTitle) // Use the passed itemTitle
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            LinearGradient(
                gradient: Gradient(
                    colors: colorScheme == .dark ?
                        [.cyan.opacity(0.1), .cyan.opacity(0.05), Color(.systemBackground), Color(.systemBackground)] :
                        [.cyan.opacity(0.2), .cyan.opacity(0.1),  .white, .white]
                ),
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigationBar
        )
        .sheet(isPresented: $viewModel.isShowingDialogueView) {
            DialogueSheetView(viewModel: viewModel, userDialogueInput: $userDialogueInput, theme: currentTheme, fontStyle: currentFontStyle) // Pass fontStyle
        }
        // This is a simple way to make the navigation bar match the theme.
        // For more complex styling, you'd use UIAppearance or custom modifiers.
        .toolbarColorScheme(currentTheme == .dark ? .dark : .light, for: .navigationBar)
        .onAppear {
            viewModel.startReadingSession()
            // Start progress tracking timer
            startProgressTimer()
        }
        .onDisappear {
            viewModel.finishReadingSession()
            // Stop progress tracking timer
            stopProgressTimer()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                viewModel.finishReadingSession()
                stopProgressTimer()
            } else if newPhase == .active {
                startProgressTimer()
            }
        }
    }
    
    // MARK: - Progress Tracking
    
    private func startProgressTimer() {
        // Update progress every 30 seconds
        progressTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            viewModel.updateReadingProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// Simple Dialogue Sheet View
struct DialogueSheetView: View {
    @ObservedObject var viewModel: FullReadingViewModel
    @Binding var userDialogueInput: String
    let theme: ReadingTheme // Receive the theme
    let fontStyle: ReadingFontStyle // Added
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) { // Changed to spacing 0 for tighter layout if needed
                // Display the selected paragraph
                if let selectedParagraph = viewModel.selectedParagraphForDialogue {
                    VStack(alignment: .leading) {
                        Text("Discussing Paragraph:")
                            .font(fontStyle.getFont(size: 12, weight: .medium)) // Apply font style to caption
                            .foregroundColor(theme.secondaryTextColor) // Use theme color
                        
                        MarkdownRenderer.MarkdownTextView(
                            markdownText: selectedParagraph,
                            baseFontSize: 14,
                            primaryTextColor: theme.primaryTextColor,
                            secondaryTextColor: theme.secondaryTextColor,
                            fontStyle: fontStyle
                        )
                        .padding(EdgeInsets(top: 5, leading: 10, bottom: 10, trailing: 10))
                        .background(theme.backgroundColor == ReadingTheme.dark.backgroundColor ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6)) // Adjust background for contrast
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    Divider().background(theme.secondaryTextColor)
                }

                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.dialogueMessages) { message in
                                MessageView(message: message, theme: theme, fontStyle: fontStyle) // Pass fontStyle
                                    .id(message.id) // For scrolling
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top) // Add some padding if paragraph is shown
                    }
                    .onChange(of: viewModel.dialogueMessages.count) { _ in
                        // Scroll to the newest message
                        if let lastMessageId = viewModel.dialogueMessages.last?.id {
                            withAnimation {
                                scrollViewProxy.scrollTo(lastMessageId, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider().background(theme.secondaryTextColor)
                HStack {
                    TextField("Ask about this paragraph...", text: $userDialogueInput, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle()) // Simpler style for theming
                        .padding(8)
                        .font(fontStyle.getFont(size: 16)) // Apply font style to TextField
                        .background(theme.backgroundColor == ReadingTheme.dark.backgroundColor ? Color(UIColor.systemGray5) : Color(UIColor.systemGray6))
                        .cornerRadius(8)
                        .foregroundColor(theme.primaryTextColor)
                        .lineLimit(1...5) // Allow multi-line input
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        if viewModel.isSendingDialogueMessage {
                            ProgressView().tint(theme.primaryTextColor)
                                .padding(.horizontal)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20))
                                .foregroundColor(theme.primaryTextColor)
                        }
                    }
                    .disabled(userDialogueInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingDialogueMessage)
                    .padding(.leading, 6)
                }
                .padding()
                .background(theme.backgroundColor.opacity(0.8).edgesIgnoringSafeArea(.bottom)) // Use theme background for input area
            }
            .background(theme.backgroundColor) // Set background for the entire sheet content
            .navigationTitle(Text("Discuss Paragraph").font(fontStyle.getFont(size: 17, weight: .semibold))) // Apply to nav title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.isShowingDialogueView = false // Dismiss the sheet
                        viewModel.clearDialogue() // Clear messages for next time
                        userDialogueInput = "" // Clear input field
                        dismiss()
                    }
                    .tint(theme.primaryTextColor)
                    .font(fontStyle.getFont(size: 17)) // Apply to toolbar button
                }
            }
            // Adapt toolbar color scheme
            .toolbarColorScheme(theme == .dark ? .dark : .light, for: .navigationBar)
        }
    }

    private func sendMessage() {
        let question = userDialogueInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !question.isEmpty,
           let selectedParagraph = viewModel.selectedParagraphForDialogue,
           let originalContent = viewModel.originalContentForDialogue {
            
            Task {
                await viewModel.sendDialogueMessage(
                    userQuestion: question,
                    selectedSnippet: selectedParagraph,
                    originalBlockContent: originalContent
                )
            }
            userDialogueInput = "" // Clear input field after sending
        }
    }
}

// Simple Message View for Dialogue
struct MessageView: View {
    let message: ChatMessage
    let theme: ReadingTheme // Receive theme
    let fontStyle: ReadingFontStyle // Added

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
                Text(message.text)
                    .padding(10)
                    .font(fontStyle.getFont(size: 16)) // Apply font style to user message
                    .background(Color.customPrimary) // User messages with custom teal color
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                if message.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(theme.secondaryTextColor) // Use theme color
                        Text("Thinking...")
                            .font(fontStyle.getFont(size: 12, weight: .medium)) // Apply font style
                            .foregroundColor(theme.secondaryTextColor) // Use theme color
                    }
                    .padding(10)
                    // Adapt AI message bubble background
                    .background(theme.backgroundColor == ReadingTheme.dark.backgroundColor ? Color(UIColor.systemGray4) : Color(UIColor.systemGray5))
                    .cornerRadius(10)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)

                } else {
                    MarkdownRenderer.MarkdownTextView(
                        markdownText: message.text,
                        baseFontSize: 16,
                        primaryTextColor: theme.primaryTextColor,
                        secondaryTextColor: theme.secondaryTextColor,
                        fontStyle: fontStyle
                    )
                    .padding(10)
                    .background(theme.backgroundColor == ReadingTheme.dark.backgroundColor ? Color(UIColor.systemGray4) : Color(UIColor.systemGray5))
                    .cornerRadius(10)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                }
                Spacer()
            }
        }
    }
}

// Preview (optional, might need mock data)
// struct FullReadingView_Previews: PreviewProvider {
//     static var previews: some View {
//          NavigationView {
//              FullReadingView(itemID: "sampleStoryId", collectionName: "stories", itemTitle: "Sample Story")
//          }
//     }
// }
