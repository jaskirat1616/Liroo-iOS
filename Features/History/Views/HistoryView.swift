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
    @StateObject private var globalManager = GlobalBackgroundProcessingManager.shared
    @State private var selectedFilter: HistoryFilter = .all
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSelectionMode: Bool = false
    @State private var selectedItems: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isIPadLandscape: Bool {
        isIPad && UIDevice.current.orientation.isLandscape
    }

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
                        .font(isIPad ? .title2 : .body)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: isIPad ? 16 : 12) {
                        Text("Error")
                            .font(isIPad ? .title : .headline)
                        Text(errorMessage)
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.red)
                        Button("Retry") {
                            viewModel.fetchHistory()
                        }
                        .padding(.top, isIPad ? 16 : 8)
                    }
                } else if viewModel.historyItems.isEmpty {
                    Text("No history found.")
                        .font(isIPad ? .title2 : .body)
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
                        .padding(.horizontal, isIPad ? 24 : 16)
                        .padding(.top, isIPad ? 16 : 8)
                        .environment(\.layoutDirection, .leftToRight)

                        if filteredItems.isEmpty {
                            Text("No \(selectedFilter.rawValue.lowercased()) found.")
                                .font(isIPad ? .title2 : .body)
                                .foregroundColor(.secondary)
                                .padding(isIPad ? 32 : 16)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: isIPad ? 16 : 12) {
                                    ForEach(filteredItems) { item in
                                        let isSelected = selectedItems.contains(item.id)
                                        HStack {
                                            if isSelectionMode {
                                                Button(action: {
                                                    if isSelected {
                                                        selectedItems.remove(item.id)
                                                    } else {
                                                        selectedItems.insert(item.id)
                                                    }
                                                }) {
                                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                        .foregroundColor(isSelected ? .blue : .gray)
                                                }
                                            }
                                            Group {
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
                                            .disabled(isSelectionMode)
                                        }
                                    }
                                }
                                .padding(.horizontal, isIPad ? 24 : 16)
                                .padding(.top, isIPad ? 16 : 8)
                            }
                        }
                    }
                }
            }
            
            // Global Background Processing Indicator
            if globalManager.isBackgroundProcessing && globalManager.isIndicatorVisible {
                VStack {
                    Spacer()
                    globalBackgroundProcessingIndicator(dismissAction: {
                        globalManager.dismissIndicator()
                    })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isSelectionMode {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedItems.isEmpty)
                    }
                    Button(action: {
                        isSelectionMode.toggle()
                        if !isSelectionMode { selectedItems.removeAll() }
                    }) {
                        Image(systemName: isSelectionMode ? "xmark.circle" : "checkmark.circle")
                    }
                    Button {
                        viewModel.fetchHistory()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(isIPad ? .title2 : .body)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .alert("Delete Selected Items?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteHistoryItems(withIDs: selectedItems)
                    if viewModel.errorMessage != nil {
                        showDeleteError = true
                    }
                    selectedItems.removeAll()
                    isSelectionMode = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Failed to delete some items.", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error.")
        }
        .onAppear {
            globalManager.restoreFromUserDefaults()
        }
    }

    // MARK: - Global Background Processing Indicator
    private func globalBackgroundProcessingIndicator(dismissAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Generating \(globalManager.generationType)...")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("\(Int(globalManager.progress * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Button(action: dismissAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.leading, 8)
                }
                .accessibilityLabel("Dismiss background processing indicator")
            }
            // Progress Bar
            ProgressView(value: globalManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .frame(height: 3)
            if !globalManager.currentStep.isEmpty {
                Text(globalManager.currentStep)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .animation(.easeInOut(duration: 0.3), value: globalManager.isBackgroundProcessing)
    }

    // Polished lecture row
    private struct LectureHistoryRow: View {
        let item: UserHistoryEntry
        @Environment(\.colorScheme) private var colorScheme
        
        // MARK: - iPad Detection
        private var isIPad: Bool {
            UIDevice.current.userInterfaceIdiom == .pad
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(isIPad ? .title3 : .headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(item.date, style: .date)
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Lecture")
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, isIPad ? 12 : 8)
                        .padding(.vertical, isIPad ? 4 : 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(isIPad ? .subheadline : .caption)
                }
            }
            .padding(.vertical, isIPad ? 16 : 12)
            .padding(.horizontal, isIPad ? 20 : 16)
            .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    // Existing row for other types
    private struct HistoryRow: View {
        let item: UserHistoryEntry
        @Environment(\.colorScheme) private var colorScheme
        
        // MARK: - iPad Detection
        private var isIPad: Bool {
            UIDevice.current.userInterfaceIdiom == .pad
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
                HStack(alignment: .top) {
                    Text(item.title)
                        .font(isIPad ? .title3 : .headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(item.date, style: .date)
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text(item.type.rawValue)
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(iconColor(for: item.type))
                        .padding(.horizontal, isIPad ? 12 : 8)
                        .padding(.vertical, isIPad ? 4 : 2)
                        .background(iconColor(for: item.type).opacity(0.1))
                        .cornerRadius(4)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.5))
                        .font(isIPad ? .subheadline : .caption)
                }
            }
            .padding(.vertical, isIPad ? 16 : 12)
            .padding(.horizontal, isIPad ? 20 : 16)
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
                LectureView(lecture: lecture, audioFiles: audioFiles, dismissAction: nil)
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
