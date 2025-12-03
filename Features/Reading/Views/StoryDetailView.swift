import SwiftUI

// Sub-view to display FirebaseStory details
struct StoryDetailView: View {
    @EnvironmentObject var viewModel: FullReadingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var narratorService = NarratorTTSService.shared
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
                if !chapter.title.isEmpty {
                    content += chapter.title + "\n"
                }
                if !chapter.content.isEmpty {
                    content += chapter.content + "\n\n"
                }
            }
        }
        return content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Story Header with Sound Button
                storyHeaderWithSound
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // Story Overview
                if let overview = story.overview, !overview.isEmpty {
                    storyOverview(overview)
                        .padding(.bottom, 24)
                }
                
                // Main Characters Section
                if let characters = story.mainCharacters, !characters.isEmpty {
                    charactersSection(characters)
                        .padding(.bottom, 24)
                }

                // Chapters
                if let chapters = story.chapters, !chapters.isEmpty {
                    chaptersSection(chapters)
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, isIPad ? 40 : 16)
        }
        .onDisappear {
            narratorService.stop()
        }
    }
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // MARK: - Story Header with Sound Button
    private var storyHeaderWithSound: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(story.title)
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(primaryTextColor)
                    
                    Text("AI-Generated Story")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(secondaryTextColor)
                }
                
                Spacer()
                
                // Sound Button with glass morphism
                Button(action: {
                    Task {
                        if narratorService.isPlaying {
                            narratorService.stop()
                        } else {
                            await narratorService.narrate(text: fullStoryText)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Characters Section
    private func charactersSection(_ characters: [FirebaseCharacter]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Main Characters")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(primaryTextColor)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(characters) { character in
                    CharacterCard(
                        character: character,
                        baseFontSize: baseFontSize,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor
                    )
                }
            }
        }
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
                        if !chapter.content.isEmpty {
                            viewModel.initiateDialogue(paragraph: chapter.content, originalContent: fullStoryText)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Character Card
struct CharacterCard: View {
    let character: FirebaseCharacter
    let baseFontSize: Double
    let primaryTextColor: Color
    let secondaryTextColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Character Image
            if let imageUrl = character.imageUrl, !imageUrl.isEmpty {
                CachedAsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
                .frame(height: 120)
                .clipped()
                .cornerRadius(12)
                .id(imageUrl) // Force reload only when URL changes
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    )
                    .cornerRadius(12)
            }
            
            // Character Info
            VStack(alignment: .leading, spacing: 8) {
                Text(character.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)
                
                if !character.description.isEmpty {
                    Text(character.description)
                        .font(.system(size: 12))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(2)
                }
                
                if !character.personality.isEmpty {
                    Text("Personality: \(character.personality)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(2)
                }
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

// MARK: - Reading Chapter View
struct ReadingChapterView: View {
    let chapter: FirebaseChapter
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
            if !chapter.title.isEmpty {
                Text(chapter.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(primaryTextColor)
            }
            
            // Chapter Main Image
            if let imageUrl = chapter.imageUrl, !imageUrl.isEmpty {
                CachedAsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(12)
                .id(imageUrl) // Force reload only when URL changes
            }
            
            // Key Events Section
            if let keyEvents = chapter.keyEvents, !keyEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Events")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    ForEach(keyEvents, id: \.self) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                                .padding(.top, 4)
                            
                            Text(event)
                                .font(.system(size: 14))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .padding(12)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Key Event Images
            if let keyEventImages = chapter.keyEventImages, !keyEventImages.isEmpty {
                ForEach(keyEventImages) { eventImage in
                    CachedAsyncImage(url: URL(string: eventImage.imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .id(eventImage.imageUrl) // Force reload only when URL changes
                }
            }
            
            // Character Interactions Section
            if let interactions = chapter.characterInteractions, !interactions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Character Interactions")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    ForEach(interactions, id: \.self) { interaction in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                            
                            Text(interaction)
                                .font(.system(size: 14))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Emotional Moments Section
            if let emotionalMoments = chapter.emotionalMoments, !emotionalMoments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emotional Moments")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(primaryTextColor)
                    
                    ForEach(emotionalMoments, id: \.self) { moment in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.red)
                                .padding(.top, 4)
                            
                            Text(moment)
                                .font(.system(size: 14))
                                .foregroundColor(secondaryTextColor)
                        }
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Emotional Moment Images
            if let emotionalMomentImages = chapter.emotionalMomentImages, !emotionalMomentImages.isEmpty {
                ForEach(emotionalMomentImages) { momentImage in
                    CachedAsyncImage(url: URL(string: momentImage.imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .id(momentImage.imageUrl) // Force reload only when URL changes
                }
            }
            
            // Chapter Content
            if !chapter.content.isEmpty {
                MarkdownRenderer.MarkdownTextView(
                    markdownText: chapter.content,
                    baseFontSize: baseFontSize,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    fontStyle: fontStyle,
                    onTapGesture: onTapGesture
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
