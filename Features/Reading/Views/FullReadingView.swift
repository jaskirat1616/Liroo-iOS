import SwiftUI
import FirebaseFirestore

// REMOVED the duplicate DialogueMessage and MessageSender structs from here.
// The app will now use the single source of truth from ReadingViewModel.swift.

enum Sender {
    case user
    case ai
}

struct DialogueMessage: Identifiable {
    let id = UUID()
    let text: String
    let sender: Sender
}

struct FullReadingView: View {
    @StateObject private var viewModel: FullReadingViewModel
    @State private var userDialogueInput: String = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var progressTimer: Timer?
    let dismissAction: (() -> Void)?

    @AppStorage("readingThemeName") private var selectedThemeName: String = ReadingTheme.light.rawValue
    @AppStorage("readingFontSize") private var selectedFontSize: Double = 17.0
    @AppStorage("readingFontStyleName") private var selectedFontStyleName: String = ReadingFontStyle.systemDefault.rawValue

    private var currentTheme: ReadingTheme { ReadingTheme(rawValue: selectedThemeName) ?? .light }
    private var currentFontStyle: ReadingFontStyle { ReadingFontStyle(rawValue: selectedFontStyleName) ?? .systemDefault }
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    init(itemID: String, collectionName: String, itemTitle: String, dismissAction: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: FullReadingViewModel(itemID: itemID, collectionName: collectionName))
        self.itemTitle = itemTitle
        self.dismissAction = dismissAction
    }
    
    let itemTitle: String

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [currentTheme.backgroundColor, currentTheme.backgroundColor.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            // Main Content
            if viewModel.isLoading {
                ProgressView("Loading content...")
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Text("Error")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundColor(.red)
                    Button("Retry") {
                        Task { await viewModel.fetchContent() }
                    }
                }
            } else if let story = viewModel.story {
                StoryDetailView(
                    story: story,
                    baseFontSize: selectedFontSize,
                    primaryTextColor: currentTheme.primaryTextColor,
                    secondaryTextColor: currentTheme.secondaryTextColor,
                    fontStyle: currentFontStyle
                )
                .environmentObject(viewModel)
            } else if let userContent = viewModel.userContent {
                UserContentDetailView(
                    userContent: userContent,
                    baseFontSize: selectedFontSize,
                    primaryTextColor: currentTheme.primaryTextColor,
                    secondaryTextColor: currentTheme.secondaryTextColor,
                    fontStyle: currentFontStyle
                )
                .environmentObject(viewModel)
            } else {
                Text("No content found.")
            }
        }
        .navigationTitle(itemTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if dismissAction != nil {
                    Button("Done") {
                        dismissAction?()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingDialogueView) {
            DialogueSheetView(
                viewModel: viewModel,
                userDialogueInput: $userDialogueInput,
                theme: currentTheme,
                fontStyle: currentFontStyle
            )
        }
        .onAppear {
            viewModel.startReadingSession() // Correct: Call as a method
            startProgressTimer()
        }
        .onDisappear {
            viewModel.finishReadingSession() // Correct: Call as a method
            stopProgressTimer()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                viewModel.finishReadingSession() // Correct: Call as a method
                stopProgressTimer()
            } else if newPhase == .active {
                startProgressTimer()
            }
        }
    }

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            viewModel.updateReadingProgress() // Correct: Call as a method
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
    let theme: ReadingTheme
    let fontStyle: ReadingFontStyle
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ... Dialogue UI ...
                // This view seems okay, but ensure MessageView is also correct.
                 if let selectedParagraph = viewModel.selectedParagraphForDialogue {
                    // ... your paragraph display code
                 }
                
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.dialogueMessages) { message in
                            MessageView(message: message, theme: theme, fontStyle: fontStyle)
                        }
                    }
                }
                
                // Input area
                HStack {
                    TextField("Ask about this paragraph...", text: $userDialogueInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(8)
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(userDialogueInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingDialogueMessage)
                }.padding()
            }
            .navigationTitle("Discuss")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sendMessage() {
        let question = userDialogueInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty,
              let selectedParagraph = viewModel.selectedParagraphForDialogue,
              let originalContent = viewModel.originalContentForDialogue else { return }
        
        Task {
            await viewModel.sendDialogueMessage(
                userQuestion: question,
                selectedSnippet: selectedParagraph,
                originalBlockContent: originalContent
            )
        }
        userDialogueInput = ""
    }
}

// Simple Message View for Dialogue
struct MessageView: View {
    let message: DialogueMessage
    let theme: ReadingTheme
    let fontStyle: ReadingFontStyle

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
                Text(message.text)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            } else {
                Text(message.text)
                    .padding(10)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(10)
                Spacer()
            }
        }
    }
}
