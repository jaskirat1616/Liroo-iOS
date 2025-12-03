import SwiftUI
import FirebaseFirestore
import FirebaseAuth

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case story = "Stories"
    case generatedContent = "Content"
    case lecture = "Lectures"
    case comic = "Comics"
    var id: String { rawValue }
}

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @StateObject private var globalManager = GlobalBackgroundProcessingManager.shared
    private let searchService = SearchService.shared
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var selectedFilter: HistoryFilter = .all
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSelectionMode: Bool = false
    @State private var selectedItems: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var searchText: String = ""
    @State private var showSearch: Bool = false
    @State private var searchResults: [SearchService.SearchResult] = []
    @State private var isSearching: Bool = false
    
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
        case .comic:
            return viewModel.historyItems.filter { $0.type == .comic }
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient
            
            mainContent
        }
        .navigationTitle("History")
        .onAppear {
            Task {
                await viewModel.fetchHistory()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    withAnimation {
                        showSearch.toggle()
                        if !showSearch {
                            searchText = ""
                            searchResults = []
                        }
                    }
                    HapticFeedbackManager.shared.buttonTap()
                }) {
                    Image(systemName: showSearch ? "xmark.circle" : "magnifyingglass")
                }
                .accessibilityLabel(showSearch ? "Close search" : "Search history")
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isSelectionMode {
                        Button(role: .destructive) {
                            HapticFeedbackManager.shared.destructiveAction()
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(selectedItems.isEmpty)
                        .accessibilityLabel("Delete selected items")
                    }
                    Button(action: {
                        HapticFeedbackManager.shared.toggle()
                        isSelectionMode.toggle()
                        if !isSelectionMode { selectedItems.removeAll() }
                    }) {
                        Image(systemName: isSelectionMode ? "xmark.circle" : "checkmark.circle")
                    }
                    .accessibilityLabel(isSelectionMode ? "Cancel selection" : "Select items")
                    
                    Button {
                        HapticFeedbackManager.shared.refresh()
                        Task {
                            await viewModel.fetchHistory()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(isIPad ? .title2 : .body)
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh history")
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
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        let darkColors: [Color] = [.cyan.opacity(0.15), .cyan.opacity(0.15), Color(.systemBackground), Color(.systemBackground)]
        let lightColors: [Color] = [.cyan.opacity(0.2), .cyan.opacity(0.1), .white, .white]
        
        return LinearGradient(
            gradient: Gradient(colors: colorScheme == .dark ? darkColors : lightColors),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading History...")
                .font(isIPad ? .title2 : .body)
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.historyItems.isEmpty {
            EmptyStateView.noHistory()
                .onAppear {
                    HapticFeedbackManager.shared.lightImpact()
                }
        } else {
            historyContentView
        }
        
        // Offline indicator
        if offlineManager.isOffline {
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Offline")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.bottom, 100)
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: isIPad ? 16 : 12) {
            Text("Error")
                .font(isIPad ? .title : .headline)
            Text(message)
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.red)
            Button("Retry") {
                Task {
                    await viewModel.fetchHistory()
                }
            }
            .padding(.top, isIPad ? 16 : 8)
        }
    }
    
    @ViewBuilder
    private var historyContentView: some View {
        VStack(spacing: 0) {
            // Search bar
            if showSearch {
                searchBar
            }
            
            // Segmented control for filtering
            Picker("Filter", selection: $selectedFilter) {
                ForEach(HistoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, isIPad ? 24 : 16)
            .padding(.top, showSearch ? 8 : (isIPad ? 16 : 8))
            .environment(\.layoutDirection, .leftToRight)
            .onChange(of: selectedFilter) { _ in
                HapticFeedbackManager.shared.selection()
            }

            if filteredItems.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No \(selectedFilter.rawValue.lowercased()) found",
                    message: "Try changing the filter or generate some content"
                )
                .padding(isIPad ? 32 : 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: isIPad ? 16 : 12) {
                        // Search results section
                        if !searchResults.isEmpty {
                            ForEach(searchResults) { result in
                                SearchResultRow(result: result)
                                    .padding(.vertical, 4)
                            }
                        }
                        
                        // Regular history items (when not searching)
                        if searchText.isEmpty || searchResults.isEmpty {
                            ForEach(filteredItems) { item in
                                historyItemRow(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, isIPad ? 24 : 16)
                    .padding(.top, isIPad ? 16 : 8)
                }
                .pullToRefresh {
                    await viewModel.fetchHistory()
                }
            }
        }
    }
    
    @ViewBuilder
    private func historyItemRow(item: UserHistoryEntry) -> some View {
        let isSelected = selectedItems.contains(item.id)
        HStack {
            if isSelectionMode {
                Button(action: {
                    HapticFeedbackManager.shared.buttonTap()
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
                } else if item.type == .comic {
                    NavigationLink(destination: ComicDestinationView(
                        comicID: item.originalDocumentID,
                        comicTitle: item.title
                    )) {
                        HistoryRow(item: item)
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
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search history...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { newValue in
                    if newValue.isEmpty {
                        searchResults = []
                        isSearching = false
                    } else {
                        performSearch()
                    }
                }
            Button(action: {
                showSearch = false
                searchText = ""
                searchResults = []
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.top, isIPad ? 16 : 8)
        .transition(.move(edge: .top))
    }
}

// MARK: - Supporting Views
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

struct HistoryRow: View {
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
            case .comic:
                return "rectangle.stack.fill"
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
            case .comic:
                return .blue
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
                        print("[LectureDestinationView] Section \(index + 1): imageUrl = \(section.imageUrl ?? "nil")")
                        return LectureSection(
                            id: UUID(uuidString: section.sectionId) ?? UUID(),
                            title: section.title ?? "Section \(index + 1)",
                            script: section.script ?? "",
                            imagePrompt: section.imagePrompt ?? "",
                            imageUrl: section.imageUrl,
                            order: section.order ?? (index + 1),
                            firebaseImageUrl: section.imageUrl // Use the Firebase URL as firebaseImageUrl
                        )
                    }
                    let lecture = Lecture(
                        id: UUID(uuidString: firebaseLecture.id ?? "") ?? UUID(),
                        title: firebaseLecture.title,
                        sections: sections,
                        level: ReadingLevel(rawValue: firebaseLecture.level) ?? .moderate,
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

// MARK: - Comic Destination View
struct ComicDestinationView: View {
    let comicID: String
    let comicTitle: String
    @State private var comic: Comic? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading comic...")
                        .foregroundColor(.secondary)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load comic")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let comic = comic {
                ComicView(comic: comic, dismissAction: {})
            }
        }
        .navigationTitle("Comic")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadComic()
        }
    }
    
    private func loadComic() {
        isLoading = true
        errorMessage = nil
        
        print("[ComicDestinationView] Loading comic with ID: \(comicID)")
        
        let db = Firestore.firestore()
        db.collection("comics").document(comicID).getDocument { snapshot, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("[ComicDestinationView] Error loading comic: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    return
                }
                
                print("[ComicDestinationView] Document exists: \(snapshot?.exists ?? false)")
                
                do {
                    guard let firebaseComic = try snapshot?.data(as: FirebaseComic.self) else {
                        print("[ComicDestinationView] Failed to decode comic data")
                        errorMessage = "Comic not found or could not decode."
                        return
                    }
                    
                    print("[ComicDestinationView] Successfully decoded comic - ID: \(firebaseComic.id ?? "nil"), Title: \(firebaseComic.comicTitle)")
                    print("[ComicDestinationView] Panel count: \(firebaseComic.panelLayout.count)")
                    
                    // Convert to Comic model
                    let panels = firebaseComic.panelLayout.map { panel in
                        print("[ComicDestinationView] Panel \(panel.panelId): imageUrl = \(panel.imageUrl ?? "nil")")
                        return ComicPanel(
                            panelId: panel.panelId,
                            scene: panel.scene,
                            imagePrompt: panel.imagePrompt,
                            dialogue: panel.dialogue,
                            imageUrl: panel.imageUrl,
                            firebaseImageUrl: panel.imageUrl // Use the Firebase URL as firebaseImageUrl
                        )
                    }
                    
                    let comic = Comic(
                        id: UUID(uuidString: firebaseComic.id ?? "") ?? UUID(),
                        comicTitle: firebaseComic.comicTitle,
                        theme: firebaseComic.theme,
                        characterStyleGuide: firebaseComic.characterStyleGuide,
                        panelLayout: panels
                    )
                    
                    self.comic = comic
                    
                    print("[ComicDestinationView] Comic loaded successfully - Panels: \(panels.count)")
                    for (index, panel) in panels.enumerated() {
                        print("[ComicDestinationView] Panel \(index + 1): firebaseImageUrl = \(panel.firebaseImageUrl ?? "nil")")
                    }
                } catch {
                    print("[ComicDestinationView] Decoding error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Helper Methods
extension HistoryView {
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    isSearching = false
                    return
                }
                
                let results = try await searchService.search(query: searchText, userId: userId)
                
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                    HapticFeedbackManager.shared.lightImpact()
                }
            } catch {
                print("[HistoryView] Search error: \(error)")
                await MainActor.run {
                    searchResults = []
                    isSearching = false
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
