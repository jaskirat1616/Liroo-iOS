import SwiftUI

/// Enhanced image view with regeneration and consistency indicators
struct ImageWithRegenerationView: View {
    let imageUrl: String
    let chapterId: String?
    let storyId: String?
    let prompt: String
    let characterName: String?
    let isConsistent: Bool
    @Binding var isRegenerating: Bool
    @Binding var regenerationProgress: Double?
    let onRegenerate: () -> Void
    
    @State private var showRegenerationMenu = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            CachedAsyncImage(url: URL(string: imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Group {
                            if isRegenerating {
                                VStack(spacing: 8) {
                                    ProgressView(value: regenerationProgress, total: 1.0)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(width: 200)
                                    Text("Regenerating...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                    )
            }
            .frame(maxWidth: .infinity)
            .cornerRadius(12)
            .id(imageUrl) // Force reload when URL changes
            
            // Consistency indicator badge
            if isConsistent {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("Consistent")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(8)
            }
            
            // Regeneration menu button
            if !isRegenerating {
                Menu {
                    Button(action: {
                        onRegenerate()
                    }) {
                        Label("Regenerate Image", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button(action: {
                        // Style variation action
                        onRegenerate()
                    }) {
                        Label("Different Style", systemImage: "paintbrush.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .padding(8)
                }
                .padding(8)
            }
        }
    }
}

