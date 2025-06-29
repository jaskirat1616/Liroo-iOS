import SwiftUI
import FirebaseFirestore

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case story = "Stories"
    case generatedContent = "Content"
    case lecture = "Lectures"
    var id: String { rawValue }
}

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedFilter: HistoryFilter = .all
    @Environment(\.colorScheme) private var colorScheme

    var filteredItems: [UserHistoryEntry] {
        switch selectedFilter {
        case .all:
            return viewModel.historyItems
        case .story:
            return viewModel.historyItems.filter { $0.type == .story }
        case .generatedContent:
            return viewModel.historyItems.filter { $0.type == .generatedContent }
        case .lecture:
            return viewModel.historyItems.filter { $0.type == .lecture }
        }
    }

    var body: some View {
        ZStack {
            // Background gradient matching other screens
            LinearGradient(
                gradient: Gradient(
                    colors: colorScheme == .dark ?
                    [.cyan.opacity(0.15), .cyan.opacity(0.15), Color(.systemBackground), Color(.systemBackground)] :
                    [.cyan.opacity(0.2), .cyan.opacity(0.1),  .white, .white]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
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
                    VStack(spacing: 0) {
                        // Segmented control for filtering
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(HistoryFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding([.horizontal, .top])
                        .environment(\.layoutDirection, .leftToRight)

                        if filteredItems.isEmpty {
                            Text("No \(selectedFilter.rawValue.lowercased()) found.")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredItems) { item in
                                        if item.type == .lecture {
                                            NavigationLink(destination: LectureDestinationView(
                                                lectureID: item.originalDocumentID,
                                                lectureTitle: item.title
                                            )) {
                                                LectureHistoryRow(item: item)
                                            }
                                        } else {
                                            NavigationLink(destination: FullReadingView(
                                                itemID: item.originalDocumentID,
                                                collectionName: item.originalCollectionName,
                                                itemTitle: item.title
                                            )) {
                                                HistoryRow(item: item)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
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

    // Polished lecture row
    private struct LectureHistoryRow: View {
        let item: UserHistoryEntry
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(item.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Lecture")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.caption)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // Existing row for other types
    private struct HistoryRow: View {
        let item: UserHistoryEntry
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(item.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text(item.type.rawValue)
                        .font(.caption)
                        .foregroundColor(iconColor(for: item.type))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(iconColor(for: item.type).opacity(0.1))
                        .cornerRadius(4)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(.caption)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        private func iconName(for type: UserHistoryEntryType) -> String {
            switch type {
            case .story:
                return "book.closed.fill"
            case .generatedContent:
                return "doc.text.fill"
            case .lecture:
                return "mic.fill"
            }
        }
        private func iconColor(for type: UserHistoryEntryType) -> Color {
            switch type {
            case .story:
                return .orange
            case .generatedContent:
                return .purple
            case .lecture:
                return .purple
            }
        }
    }
}

// MARK: - Lecture Destination View
struct LectureDestinationView: View {
    let lectureID: String
    let lectureTitle: String
    @State private var lecture: Lecture? = nil
    @State private var audioFiles: [AudioFile] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading lecture...")
                        .foregroundColor(.secondary)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load lecture")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let lecture = lecture {
                LectureView(lecture: lecture, audioFiles: audioFiles)
            }
        }
        .navigationTitle("Lecture")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadLecture()
        }
    }
    
    private func loadLecture() {
        isLoading = true
        errorMessage = nil
        
        print("[LectureDestinationView] Loading lecture with ID: \(lectureID)")
        
        let db = Firestore.firestore()
        db.collection("lectures").document(lectureID).getDocument { snapshot, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("[LectureDestinationView] Error loading lecture: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    return
                }
                
                print("[LectureDestinationView] Document exists: \(snapshot?.exists ?? false)")
                
                do {
                    guard let firebaseLecture = try snapshot?.data(as: FirebaseLecture.self) else {
                        print("[LectureDestinationView] Failed to decode lecture data")
                        errorMessage = "Lecture not found or could not decode."
                        return
                    }
                    
                    print("[LectureDestinationView] Successfully decoded lecture - ID: \(firebaseLecture.id ?? "nil"), Title: \(firebaseLecture.title)")
                    print("[LectureDestinationView] Audio files count: \(firebaseLecture.audioFiles?.count ?? 0)")
                    
                    // Convert to Lecture and AudioFile models
                    let sections = (firebaseLecture.sections ?? []).enumerated().map { index, section in
                        LectureSection(
                            id: UUID(uuidString: section.sectionId) ?? UUID(),
                            title: section.title ?? "Section \(index + 1)",
                            script: section.script ?? "",
                            imagePrompt: section.imagePrompt ?? "",
                            imageUrl: section.imageUrl,
                            order: section.order ?? (index + 1)
                        )
                    }
                    let lecture = Lecture(
                        id: UUID(uuidString: firebaseLecture.id ?? "") ?? UUID(),
                        title: firebaseLecture.title,
                        sections: sections,
                        level: ReadingLevel(rawValue: firebaseLecture.level) ?? .standard,
                        imageStyle: firebaseLecture.imageStyle
                    )
                    let audioFiles = (firebaseLecture.audioFiles ?? []).map { audio in
                        AudioFile(
                            id: UUID(),
                            type: AudioFileType(rawValue: audio.type ?? "section_script") ?? .sectionScript,
                            text: audio.text ?? "",
                            url: audio.url ?? "",
                            filename: audio.filename ?? "",
                            section: audio.section
                        )
                    }
                    self.lecture = lecture
                    self.audioFiles = audioFiles
                    
                    print("[LectureDestinationView] Lecture loaded successfully - Sections: \(sections.count), AudioFiles: \(audioFiles.count)")
                } catch {
                    print("[LectureDestinationView] Decoding error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
