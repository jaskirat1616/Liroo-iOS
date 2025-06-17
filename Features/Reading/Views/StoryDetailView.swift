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
                Text(overview)
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                    .foregroundColor(primaryTextColor)
                    .lineSpacing(CGFloat(baseFontSize * 0.3))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.initiateDialogue(paragraph: overview, originalContent: fullStoryText)
                    }
            }

            if let chapters = story.chapters, !chapters.isEmpty {
                Text("Chapters")
                    .font(fontStyle.getFont(size: CGFloat(baseFontSize + 4), weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .padding(.top)
                
                ForEach(chapters) { chapter in
                    VStack(alignment: .leading, spacing: 8) {
                        if let chapterTitle = chapter.title, !chapterTitle.isEmpty {
                            Text(chapterTitle)
                                .font(fontStyle.getFont(size: CGFloat(baseFontSize + 2), weight: .medium))
                                .foregroundColor(primaryTextColor)
                        }
                        if let content = chapter.content, !content.isEmpty {
                            Text(content)
                                .font(fontStyle.getFont(size: CGFloat(baseFontSize)))
                                .foregroundColor(primaryTextColor)
                                .lineSpacing(CGFloat(baseFontSize * 0.3))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.initiateDialogue(paragraph: content, originalContent: fullStoryText)
                                }
                        }
                        if let imageUrlString = chapter.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
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
                    }
                    .padding(.vertical)
                    Divider().background(secondaryTextColor)
                }
            }
        }
    }
}
