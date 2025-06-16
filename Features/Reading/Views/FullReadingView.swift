import SwiftUI

struct FullReadingView: View {
    @StateObject private var viewModel: FullReadingViewModel

    init(itemID: String, collectionName: String, itemTitle: String) {
        _viewModel = StateObject(wrappedValue: FullReadingViewModel(itemID: itemID, collectionName: collectionName))
        self.itemTitle = itemTitle // Store title for navigation bar
    }
    
    private var itemTitle: String


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading Content...")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Button("Retry") {
                        viewModel.fetchFullContent()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else if let story = viewModel.story {
                    StoryDetailView(story: story)
                } else if let userContent = viewModel.userContent {
                    UserContentDetailView(userContent: userContent)
                } else {
                    Text("No content found or loaded.")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
        }
        .navigationTitle(itemTitle) // Use the passed itemTitle
        .navigationBarTitleDisplayMode(.inline)
    }
}

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

// Sub-view to display FirebaseUserContent details
struct UserContentDetailView: View {
    let userContent: FirebaseUserContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let topic = userContent.topic, !topic.isEmpty {
                Text(topic)
                    .font(.largeTitle)
                    .bold()
            } else {
                Text("Generated Content")
                    .font(.largeTitle)
                    .bold()
            }
            
            if let level = userContent.level {
                 Text("Level: \(level)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            if let blocks = userContent.blocks, !blocks.isEmpty {
                Text("Content Blocks")
                    .font(.title2)
                    .padding(.top)
                
                ForEach(blocks) { block in
                    VStack(alignment: .leading, spacing: 8) {
                        if let type = block.type {
                             Text(type.capitalized) // E.g., "Text", "Image"
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.bottom, 2)
                        }
                        if let content = block.content, !content.isEmpty {
                            Text(content)
                                .font(.body)
                        }
                        if let imageUrlString = block.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
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
                        // Add more rendering for other block types like quizzes if necessary
                    }
                    .padding(.vertical)
                    Divider()
                }
            }
        }
    }
}

// Preview (optional, might need mock data)
// struct FullReadingView_Previews: PreviewProvider {
//     static var previews: some View {
//          NavigationView {
//              FullReadingView(itemID: "sampleStoryId", collectionName: "stories", itemTitle: "Sample Story")
//          }
//     }
// }
