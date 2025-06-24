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
        VStack(alignment: .leading, spacing: 12) {
            if let topic = userContent.topic, !topic.isEmpty {
                Text(topic)
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize + 8), weight: .bold))
                    .foregroundColor(primaryTextColor)
            } else {
                Text("Generated Content")
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize + 8), weight: .bold))
                    .foregroundColor(primaryTextColor)
            }
            
            if let level = userContent.level {
                 Text("Level: \(level)")
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize - 2)))
                    .foregroundColor(secondaryTextColor)
            }

            if let blocks = userContent.blocks, !blocks.isEmpty {
                Text("Content Blocks")
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize + 4), weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .padding(.top)
                
                ForEach(blocks) { block in
                    VStack(alignment: .leading, spacing: 8) {
                        if let imageUrlString = block.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
                            GeometryReader { geometry in
                                AsyncImage(url: imageUrl) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: geometry.size.width, height: geometry.size.width)
                                    case .success(let image):
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: geometry.size.width, height: geometry.size.width)
                                            .clipped()
                                            .cornerRadius(8)
                                    case .failure:
                                        EmptyView()
                                            .frame(width: geometry.size.width, height: geometry.size.width)
                                    @unknown default:
                                        EmptyView()
                                            .frame(width: geometry.size.width, height: geometry.size.width)
                                    }
                                }
                            }
                            .frame(height: 220)
                            .padding(.vertical)
                        } else {
                            Color.clear.frame(height: 0)
                        }
                        
                        if let type = block.type {
                            if type.lowercased() != "multiplechoicequestion" {
                                Text(type.capitalized)
                                    .font(fontStyle.getFont(size: CGFloat(baseFontSize - 3)))
                                    .foregroundColor(secondaryTextColor)
                                    .padding(.bottom, 2)
                            }
                        }
                        
                        if block.type?.lowercased() != "multiplechoicequestion" && block.type?.lowercased() != "image" && block.type?.lowercased() != "quizheading", let content = block.content, !content.isEmpty {
                            MarkdownRenderer.MarkdownTextView(
                                markdownText: content,
                                baseFontSize: baseFontSize,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                                fontStyle: fontStyle,
                                onTapGesture: {
                                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        viewModel.initiateDialogue(paragraph: content, originalContent: fullUserContentText)
                                    }
                                }
                            )
                        }
                        
                        if block.type?.lowercased() == "multiplechoicequestion" {
                            QuizBlockView(block: block,
                                          baseFontSize: baseFontSize,
                                          primaryTextColor: primaryTextColor,
                                          secondaryTextColor: secondaryTextColor,
                                          fontStyle: fontStyle)
                        }
                    }
                    .padding(.vertical)
                    Divider().background(secondaryTextColor)
                }
            }
        }
    }
}
