import SwiftUI

// Sub-view to display FirebaseUserContent details
struct UserContentDetailView: View {
    @EnvironmentObject var viewModel: FullReadingViewModel
    let userContent: FirebaseUserContent
    let baseFontSize: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let fontStyle: ReadingFontStyle

    // Helper to construct full user content text for context
    private var fullUserContentText: String {
        var content = ""
        if let topic = userContent.topic, !topic.isEmpty {
            content += topic + "\n\n"
        }
        if let blocks = userContent.blocks, !blocks.isEmpty {
            for block in blocks {
                if let type = block.type {
                    content += "Type: " + type + "\n"
                }
                if let blockContent = block.content, !blockContent.isEmpty {
                    content += blockContent + "\n\n"
                }
            }
        }
        return content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Content Header
                contentHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // Content Blocks
                if let blocks = userContent.blocks, !blocks.isEmpty {
                    contentBlocksSection(blocks)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - Content Header
    private var contentHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(userContent.topic ?? "Generated Content")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(primaryTextColor)
            
            Text("AI-Generated Content")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(secondaryTextColor)
            
            if let level = userContent.level {
                HStack {
                    Text("Level: \(level)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Content Blocks Section
    private func contentBlocksSection(_ blocks: [FirebaseContentBlock]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Content Blocks")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(primaryTextColor)
            
            ForEach(blocks) { block in
                UserContentBlockView(
                    block: block,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle,
                    onTapGesture: {
                        if let content = block.content, !content.isEmpty {
                            viewModel.initiateDialogue(paragraph: content, originalContent: fullUserContentText)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - User Content Block View
struct UserContentBlockView: View {
    let block: FirebaseContentBlock
    let baseFontSize: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let fontStyle: ReadingFontStyle
    let onTapGesture: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Block Type Header
            if let type = block.type, type.lowercased() != "multiplechoicequestion" {
                HStack {
                    Text(type.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Spacer()
                }
            }
            
            // Block Image
            if let imageUrlString = block.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading content image...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(secondaryTextColor)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.gray)
                            Text("Failed to load content image")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Block Content
            if block.type?.lowercased() != "multiplechoicequestion" && 
               block.type?.lowercased() != "image" && 
               block.type?.lowercased() != "quizheading", 
               let content = block.content, 
               !content.isEmpty {
                MarkdownRenderer.MarkdownTextView(
                    markdownText: content,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle,
                    onTapGesture: onTapGesture
                )
            }
            
            // Quiz Block
            if block.type?.lowercased() == "multiplechoicequestion" {
                QuizBlockView(
                    block: block,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle
                )
            }
        }
        .padding(8)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
