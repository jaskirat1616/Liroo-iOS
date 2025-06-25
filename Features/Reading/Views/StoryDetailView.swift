import SwiftUI

// Sub-view to display FirebaseStory details
struct StoryDetailView: View {
    @EnvironmentObject var viewModel: FullReadingViewModel
    @Environment(\.colorScheme) private var colorScheme
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Story Header
                storyHeader
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // Story Overview
                if let overview = story.overview, !overview.isEmpty {
                    storyOverview(overview)
                        .padding(.bottom, 24)
                }

                // Chapters
                if let chapters = story.chapters, !chapters.isEmpty {
                    chaptersSection(chapters)
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 16)
        }
    }
        
        
    
       
    
    // MARK: - Story Header
    private var storyHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.title)
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundColor(primaryTextColor)
            
            Text("AI-Generated Story")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Story Overview
    private func storyOverview(_ overview: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story Overview")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(primaryTextColor)
            
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Chapters Section
    private func chaptersSection(_ chapters: [FirebaseChapter]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chapters")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(primaryTextColor)
            
            ForEach(chapters.sorted(by: { ($0.order ?? 0) < ($1.order ?? 0) })) { chapter in
                ReadingChapterView(
                    chapter: chapter,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle,
                    onTapGesture: {
                        if let content = chapter.content, !content.isEmpty {
                            viewModel.initiateDialogue(paragraph: content, originalContent: fullStoryText)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Reading Chapter View
struct ReadingChapterView: View {
    let chapter: FirebaseChapter
    let baseFontSize: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let fontStyle: ReadingFontStyle
    let onTapGesture: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chapter Header
            HStack {
                Text("Chapter \(chapter.order ?? 0)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(secondaryTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Spacer()
            }
            
            // Chapter Title
            if let chapterTitle = chapter.title, !chapterTitle.isEmpty {
                Text(chapterTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(primaryTextColor)
            }
            
            // Chapter Image
            if let imageUrlString = chapter.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading chapter image...")
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
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.gray)
                            Text("Failed to load chapter image")
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
            
            // Chapter Content
            if let content = chapter.content, !content.isEmpty {
                MarkdownRenderer.MarkdownTextView(
                    markdownText: content,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle,
                    onTapGesture: onTapGesture
                )
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}
