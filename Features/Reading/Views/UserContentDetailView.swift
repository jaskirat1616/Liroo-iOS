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
                        if let type = block.type {
                            if type.lowercased() != "multiplechoicequestion" {
                                Text(type.capitalized)
                                    .font(fontStyle.getFont(size: CGFloat(baseFontSize - 3)))
                                    .foregroundColor(secondaryTextColor)
                                    .padding(.bottom, 2)
                            }
                        }

                        if block.type?.lowercased() != "multiplechoicequestion" && block.type?.lowercased() != "image" && block.type?.lowercased() != "quizheading", let content = block.content, !content.isEmpty {
                            Text(content)
                                .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                                .foregroundColor(primaryTextColor)
                                .lineSpacing(CGFloat(baseFontSize * 0.3))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        viewModel.initiateDialogue(paragraph: content, originalContent: fullUserContentText)
                                    }
                                }
                        }
                        
                        if block.type?.lowercased() != "multiplechoicequestion", let imageUrlString = block.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(height: 200)
                                case .success(let image):
                                    image.resizable()
                                         .aspectRatio(contentMode: .fit)
                                         .cornerRadius(8)
                                         .frame(maxHeight: 200)
                                case .failure:
                                    Image(systemName: "photo.artframe")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .foregroundColor(secondaryTextColor)
                                @unknown default:
                                    EmptyView()
                                        .frame(height: 200)
                                }
                            }
                            .padding(.vertical)
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
