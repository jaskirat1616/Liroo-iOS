import SwiftUI

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
                             // Display type only if it's not a quiz, as QuizBlockView handles its own title/question
                            if type.lowercased() != "multiplechoicequestion" {
                                Text(type.capitalized) // E.g., "Text", "Image"
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.bottom, 2)
                            }
                        }

                        // Handle standard text content if not a quiz
                        if block.type?.lowercased() != "multiplechoicequestion", let content = block.content, !content.isEmpty {
                            Text(content)
                                .font(.body)
                        }
                        
                        // Handle image if not a quiz (or if quizzes can also have images - adjust as needed)
                         if block.type?.lowercased() != "multiplechoicequestion", let imageUrlString = block.firebaseImageUrl, let imageUrl = URL(string: imageUrlString) {
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

                        // Render Quiz if block type is multipleChoiceQuestion
                        if block.type?.lowercased() == "multiplechoicequestion" {
                            QuizBlockView(block: block)
                        }
                    }
                    .padding(.vertical)
                    Divider()
                }
            }
        }
    }
}
