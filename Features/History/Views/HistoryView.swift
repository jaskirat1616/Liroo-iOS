import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading History...")
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .foregroundColor(.red)
                        Button("Retry") {
                            viewModel.fetchHistory()
                        }
                        .padding(.top)
                    }
                } else if viewModel.historyItems.isEmpty {
                    Text("No history found.")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.historyItems) { item in
                            NavigationLink(destination: FullReadingView(
                                itemID: item.originalDocumentID,
                                collectionName: item.originalCollectionName,
                                itemTitle: item.title
                            )
                                           
                            ) {
                                HistoryRow(item: item)
                            }
                        }
                    }
                }
                
            }
            
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.fetchHistory()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .onAppear {
            // Optionally refresh if view appears and items are empty or stale
            // For now, data is fetched on init.
        }
    }

    // Placeholder for the row view
    private struct HistoryRow: View {
        let item: UserHistoryEntry

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.headline)
                    Text("\(item.type.rawValue) - \(item.date, style: .date)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: item.type == .story ? "book.closed.fill" : "doc.text.fill")
                    .foregroundColor(item.type == .story ? .orange : .blue)
            }
            .padding(.vertical, 4)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
