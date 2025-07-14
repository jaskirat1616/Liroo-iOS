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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Comic Header
                    comicHeader
                    
                    // Character Style Guide (if available)
                    if !comic.characterStyleGuide.isEmpty {
                        characterStyleGuideSection
                    }
                    
                    // Comic Panels
                    comicPanelsSection
                }
                .padding(.horizontal, isIPad ? 24 : 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("Comic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismissAction()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Share comic
                        Button(action: shareComic) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                        }
                        
                        // Save comic
                        Button(action: saveComic) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
    
    // MARK: - Comic Header
    private var comicHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        .padding(20)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Character Style Guide Section
    private var characterStyleGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Characters")
                .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(comic.characterStyleGuide.keys.sorted()), id: \.self) { characterName in
                    if let description = comic.characterStyleGuide[characterName] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(characterName)
                                .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(description)
                                .font(.system(size: isIPad ? 14 : 12, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Comic Panels Section
    private var comicPanelsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Comic Panels")
                .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 32) {
                ForEach(Array(comic.panelLayout.enumerated()), id: \.element.id) { index, panel in
                    ComicPanelView(
                        panel: panel,
                        panelIndex: index + 1,
                        totalPanels: comic.panelLayout.count
                    )
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
        VStack(spacing: 16) {
            // Panel Header
            HStack {
                Text("Panel \(panelIndex) of \(totalPanels)")
                    .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(panel.scene)
                    .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            
            // Comic Image
            if let imageUrl = panel.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading panel image...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 400 : 300)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Failed to load panel image")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 400 : 300)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Placeholder for missing image
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No image available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: isIPad ? 400 : 300)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Dialogue Section
            if !panel.dialogue.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Dialogue")
                        .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(Array(panel.dialogue.keys.sorted()), id: \.self) { character in
                            if let dialogue = panel.dialogue[character] {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(character)
                                        .font(.system(size: isIPad ? 14 : 12, weight: .semibold))
                                        .foregroundColor(.accentColor)
                                        .frame(width: isIPad ? 80 : 60, alignment: .leading)
                                    
                                    Text("\"\(dialogue)\"")
                                        .font(.system(size: isIPad ? 14 : 12, weight: .regular))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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