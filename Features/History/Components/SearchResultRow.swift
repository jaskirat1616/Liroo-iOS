import SwiftUI

/// Row view for search results in history
struct SearchResultRow: View {
    let result: SearchService.SearchResult
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                // Type icon
                Image(systemName: iconForType(result.type))
                    .font(.title3)
                    .foregroundColor(colorForType(result.type))
                    .frame(width: 40, height: 40)
                    .background(colorForType(result.type).opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(result.snippet)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Relevance indicator
                if result.relevanceScore > 0.7 {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var destinationView: some View {
        Group {
            switch result.type {
            case .story:
                FullReadingView(
                    itemID: result.id,
                    collectionName: result.metadata["collection"] ?? "stories",
                    itemTitle: result.title
                )
            case .lecture:
                FullReadingView(
                    itemID: result.id,
                    collectionName: result.metadata["collection"] ?? "lectures",
                    itemTitle: result.title
                )
            case .userContent:
                FullReadingView(
                    itemID: result.id,
                    collectionName: result.metadata["collection"] ?? "userGeneratedContent",
                    itemTitle: result.title
                )
            case .comic:
                FullReadingView(
                    itemID: result.id,
                    collectionName: result.metadata["collection"] ?? "comics",
                    itemTitle: result.title
                )
            }
        }
    }
    
    private func iconForType(_ type: SearchService.SearchResult.ContentType) -> String {
        switch type {
        case .story:
            return "book.fill"
        case .lecture:
            return "mic.fill"
        case .userContent:
            return "doc.text.fill"
        case .comic:
            return "rectangle.stack.fill"
        }
    }
    
    private func colorForType(_ type: SearchService.SearchResult.ContentType) -> Color {
        switch type {
        case .story:
            return .blue
        case .lecture:
            return .purple
        case .userContent:
            return .green
        case .comic:
            return .orange
        }
    }
}

