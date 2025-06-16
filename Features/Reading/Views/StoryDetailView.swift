import SwiftUI

// Sub-view to display FirebaseStory details
struct StoryDetailView: View {
    let story: FirebaseStory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.title)
                .font(.largeTitle)
                .bold()
            
            if let overview = story.overview, !overview.isEmpty {
                Text("Overview")
                    .font(.title2)
                    .padding(.top)
                Text(overview)
                    .font(.body)
            }

            if let chapters = story.chapters, !chapters.isEmpty {
                Text("Chapters")
                    .font(.title2)
                    .padding(.top)
                
                ForEach(chapters) { chapter in
                    VStack(alignment: .leading, spacing: 8) {
                        if let chapterTitle = chapter.title, !chapterTitle.isEmpty {
                            Text(chapterTitle)
                                .font(.headline)
                        }
                        if let content = chapter.content, !content.isEmpty {
                            Text(content)
                                .font(.body)
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
                                    Image(systemName: "photo.artframe") // Placeholder for failure
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                        .frame(height: 200)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding(.vertical)
                    Divider()
                }
            }
        }
    }
}
