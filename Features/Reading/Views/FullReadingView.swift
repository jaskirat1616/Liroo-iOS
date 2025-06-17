import SwiftUI

struct FullReadingView: View {
    @StateObject private var viewModel: FullReadingViewModel
    @State private var userDialogueInput: String = "" // For the TextField in the sheet

    init(itemID: String, collectionName: String, itemTitle: String) {
        _viewModel = StateObject(wrappedValue: FullReadingViewModel(itemID: itemID, collectionName: collectionName))
        self.itemTitle = itemTitle // Store title for navigation bar
    }
    
    private var itemTitle: String


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading Content...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Button("Retry") {
                        viewModel.fetchFullContent()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if let story = viewModel.story {
                    StoryDetailView(story: story)
                        .environmentObject(viewModel) // Inject viewModel
                } else if let userContent = viewModel.userContent {
                    UserContentDetailView(userContent: userContent)
                        .environmentObject(viewModel) // Inject viewModel
                } else {
                    Text("No content found or loaded.")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
        }
        .navigationTitle(itemTitle) // Use the passed itemTitle
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isShowingDialogueView) {
            DialogueSheetView(viewModel: viewModel, userDialogueInput: $userDialogueInput)
        }
    }
}

// Simple Dialogue Sheet View
struct DialogueSheetView: View {
    @ObservedObject var viewModel: FullReadingViewModel
    @Binding var userDialogueInput: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView { // Added NavigationView for title and close button
            VStack(spacing: 0) { // Changed to spacing 0 for tighter layout if needed
                // Display the selected paragraph
                if let selectedParagraph = viewModel.selectedParagraphForDialogue {
                    VStack(alignment: .leading) {
                        Text("Discussing Paragraph:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(selectedParagraph)
                            .font(.footnote)
                            .padding(EdgeInsets(top: 5, leading: 10, bottom: 10, trailing: 10))
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(8)
                            .lineLimit(nil) // Allow multiple lines for the paragraph
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    Divider()
                }

                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.dialogueMessages) { message in
                                MessageView(message: message)
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

                Divider() // Divider before the input field
                HStack {
                    TextField("Ask about this paragraph...", text: $userDialogueInput, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...5) // Allow multi-line input
                    
                    Button(action: {
                        sendMessage()
                    }) {
                        if viewModel.isSendingDialogueMessage {
                            ProgressView()
                                .padding(.horizontal)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 20))
                        }
                    }
                    .disabled(userDialogueInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingDialogueMessage)
                    .padding(.leading, 6)
                }
                .padding()
                .background(.thinMaterial) // Give input area a slightly different background
            }
            .navigationTitle(Text("Discuss Paragraph"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.isShowingDialogueView = false // Dismiss the sheet
                        viewModel.clearDialogue() // Clear messages for next time
                        userDialogueInput = "" // Clear input field
                        dismiss()
                    }
                }
            }
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

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
                Text(message.text)
                    .padding(10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                if message.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.gray)
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(10)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)

                } else {
                    Text(message.text)
                        .padding(10)
                        .background(Color(UIColor.systemGray5))
                        .foregroundColor(Color(UIColor.label))
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
