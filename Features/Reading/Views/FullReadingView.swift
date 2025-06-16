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

// Preview (optional, might need mock data)
// struct FullReadingView_Previews: PreviewProvider {
//     static var previews: some View {
//          NavigationView {
//              FullReadingView(itemID: "sampleStoryId", collectionName: "stories", itemTitle: "Sample Story")
//          }
//     }
// }
