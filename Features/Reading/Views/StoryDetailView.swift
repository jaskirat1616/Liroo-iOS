import SwiftUI

// Sub-view to display FirebaseStory details
struct StoryDetailView: View {
    @EnvironmentObject var viewModel: FullReadingViewModel
    let story: FirebaseStory
    let baseFontSize: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let fontStyle: ReadingFontStyle

    // Helper to construct full story text for context
    private var fullStoryText: String {
        var content = story.title + "\n\n"
        if let overview = story.overview, !overview.isEmpty {
            content += "Overview:\n" + overview + "\n\n"
        }
        if let chapters = story.chapters, !chapters.isEmpty {
            content += "Chapters:\n"
            for chapter in chapters {
                if let title = chapter.title, !title.isEmpty {
                    content += title + "\n"
                }
                if let chapterContent = chapter.content, !chapterContent.isEmpty {
                    content += chapterContent + "\n\n"
                }
            }
        }
        return content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !story.title.isEmpty {
                Text(story.title)
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize + 8), weight: .bold))
                    .foregroundColor(primaryTextColor)
            }
            
            if let overview = story.overview, !overview.isEmpty {
                Text("Overview")
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize + 4), weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .padding(.top)
                
                MarkdownRenderer.MarkdownTextView(
                    markdownText: overview,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle,
                    onTapGesture: {
                        viewModel.initiateDialogue(paragraph: overview, originalContent: fullStoryText)
                    }
                )
            }

            if let chapters = story.chapters, !chapters.isEmpty {
                Text("Chapters")
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize + 4), weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .padding(.top)
                
                ForEach(chapters) { chapter in
                    VStack(alignment: .leading, spacing: 8) {
                        if let imageUrlString = chapter.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
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
                        
                        if let chapterTitle = chapter.title, !chapterTitle.isEmpty {
                            Text(chapterTitle)
                                .font(fontStyle.getFont(size: CGFloat(baseFontSize + 2), weight: .medium))
                                .foregroundColor(primaryTextColor)
                        }
                        
                        if let content = chapter.content, !content.isEmpty {
                            MarkdownRenderer.MarkdownTextView(
                                markdownText: content,
                                baseFontSize: baseFontSize,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                                fontStyle: fontStyle,
                                onTapGesture: {
                                    viewModel.initiateDialogue(paragraph: content, originalContent: fullStoryText)
                                }
                            )
                        }
                    }
                    .padding(.vertical)
                    Divider().background(secondaryTextColor)
                }
            }
        }
    }
}
