import SwiftUI

struct ComicView: View {
    let comic: Comic
    let dismissAction: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Comic Header
                comicHeader
                
                // Character Style Guide (if available)
                if !comic.characterStyleGuide.isEmpty {
                    characterStyleGuideSection
                }
                
                // Comic Panels
                comicPanelsSection
                
                Spacer(minLength: 120)
            }
            .padding(.horizontal, 0)
            .padding(.vertical, 0)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    // MARK: - Comic Header
    private var comicHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comic.comicTitle)
                .font(.system(size: isIPad ? 32 : 28, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Text("Theme: \(comic.theme)")
                .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(comic.panelLayout.count) panels", systemImage: "rectangle.stack")
                    .font(.system(size: isIPad ? 16 : 14, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Scroll to read")
                    .font(.system(size: isIPad ? 14 : 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    // MARK: - Character Style Guide Section
    private var characterStyleGuideSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Characters")
                .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 4) {
                ForEach(Array(comic.characterStyleGuide.keys.sorted()), id: \.self) { characterName in
                    if let description = comic.characterStyleGuide[characterName] {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(characterName)
                                .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(description)
                                .font(.system(size: isIPad ? 14 : 12, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    // MARK: - Comic Panels Section
    private var comicPanelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comic Panels")
                .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 16) {
                ForEach(Array(comic.panelLayout.enumerated()), id: \.element.id) { index, panel in
                    ComicPanelView(
                        panel: panel,
                        panelIndex: index + 1,
                        totalPanels: comic.panelLayout.count
                    )
                }
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
    }
    
    // MARK: - Actions
    private func shareComic() {
        // Create shareable content
        var shareText = "\(comic.comicTitle)\n\n"
        shareText += "Theme: \(comic.theme)\n\n"
        
        for (index, panel) in comic.panelLayout.enumerated() {
            shareText += "Panel \(index + 1): \(panel.scene)\n"
            for (character, dialogue) in panel.dialogue {
                shareText += "\(character): \"\(dialogue)\"\n"
            }
            shareText += "\n"
        }
        
        shareItems = [shareText]
        showingShareSheet = true
    }
    
    private func saveComic() {
        // Save comic to user's library
        print("Save comic: \(comic.comicTitle)")
        // TODO: Implement save functionality
    }
}

// MARK: - Comic Panel View
struct ComicPanelView: View {
    let panel: ComicPanel
    let panelIndex: Int
    let totalPanels: Int
    
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Panel Header (removed Panel X of Y)
            // HStack {
            //     Text("Panel \(panelIndex) of \(totalPanels)")
            //         .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
            //         .foregroundColor(.primary)
            //     Spacer()
            //     Text(panel.scene)
            //         .font(.system(size: isIPad ? 14 : 12, weight: .medium))
            //         .foregroundColor(.secondary)
            //         .lineLimit(2)
            //         .multilineTextAlignment(.trailing)
            // }
            // Only show scene if you want
            if !panel.scene.isEmpty {
                Text(panel.scene)
                    .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
            }
            
            // Comic Image
            if let imageUrl = panel.firebaseImageUrl ?? panel.imageUrl {
                CachedAsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } placeholder: {
                    ProgressView()
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                }
                .id(imageUrl) // Force reload only when URL changes
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
            
            // Dialogue Section
            if !panel.dialogue.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(panel.dialogue.keys.sorted()), id: \.self) { character in
                        if let dialogue = panel.dialogue[character] {
                            HStack(alignment: .top, spacing: 8) {
                                Text(character)
                                    .font(.custom("ComicNeue-Bold", size: isIPad ? 16 : 14, relativeTo: .body))
                                    .foregroundColor(.accentColor)
                                    .frame(width: isIPad ? 80 : 60, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                Text("\"\(dialogue)\"")
                                    .font(.custom("ComicNeue-Regular", size: isIPad ? 16 : 14, relativeTo: .body))
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 18)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.85))
                                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    // Create a sample comic for preview
    let sampleComic = Comic(
        comicTitle: "Sample Comic",
        theme: "Adventure",
        characterStyleGuide: [
            "Hero": "Brave protagonist with blue cape",
            "Villain": "Dark figure with mysterious powers"
        ],
        panelLayout: [
            ComicPanel(
                panelId: 1,
                scene: "Hero discovers a mysterious artifact",
                imagePrompt: "A hero finding an ancient artifact",
                dialogue: ["Hero": "What is this strange object?"],
                imageUrl: nil
            ),
            ComicPanel(
                panelId: 2,
                scene: "Villain appears from the shadows",
                imagePrompt: "A villain emerging from darkness",
                dialogue: ["Villain": "That belongs to me!", "Hero": "Not if I can help it!"],
                imageUrl: nil
            )
        ]
    )
    
    ComicView(comic: sampleComic) {
        print("Dismissed")
    }
} 
