import SwiftUI

// Sub-view to display FirebaseUserContent details
struct UserContentDetailView: View {
    @EnvironmentObject var viewModel: FullReadingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var narratorService = NarratorTTSService.shared
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
                // Content Header with Sound Button
                contentHeaderWithSound
                    .padding(.horizontal, isIPad ? 40 : 16)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // Content Blocks
                if let blocks = userContent.blocks, !blocks.isEmpty {
                    contentBlocksSection(blocks)
                        .padding(.horizontal, isIPad ? 40 : 16)
                        .padding(.bottom, 24)
                }
            }
        }
        .onDisappear {
            narratorService.stop()
        }
    }
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // MARK: - Content Header with Sound Button
    private var contentHeaderWithSound: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(userContent.topic ?? "Generated Content")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(primaryTextColor)
                    
                    if let level = userContent.level {
                        Text("Level: \(level)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                    }
                }
                
                Spacer()
                
                // Sound Button with glass morphism
                Button(action: {
                    Task {
                        if narratorService.isPlaying {
                            narratorService.stop()
                        } else {
                            await narratorService.narrate(text: fullUserContentText)
                        }
                    }
                }) {
                    ZStack {
                        // Glass morphism background
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        HStack(spacing: 8) {
                            if narratorService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: narratorService.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Text(narratorService.isPlaying ? "Playing" : "Sound")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .frame(height: 44)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            ZStack {
                // Glass morphism background
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.2 : 0.4),
                                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
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
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
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
                CachedAsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: isIPad ? 400 : .infinity)
                        .frame(height: isIPad ? 400 : 300)
                        .clipped()
                        .cornerRadius(12)
                } placeholder: {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading content image...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: isIPad ? 300 : 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .frame(maxWidth: .infinity)
                .id(imageUrlString) // Force reload only when URL changes
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
        .padding(16)
        .background(
            ZStack {
                // Glass morphism background
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.2 : 0.4),
                                        Color.white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
    }
}
