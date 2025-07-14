import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import FirebaseFirestore

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

extension SummarizationTier {
    var displayName: String {
        switch self {
        case .detailedExplanation: return "Detailed"
        case .story: return "Story"
        case .lecture: return "Lecture"
        }
    }
}

extension ReadingLevel {
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .moderate: return "Moderate"
        case .intermediate: return "Intermediate"
        }
    }
}

extension ReadingLevel: CustomStringConvertible {
    var description: String { rawValue }
}

extension SummarizationTier: CustomStringConvertible {
    var description: String { rawValue }
}

struct ContentGenerationView: View {
    @StateObject private var viewModel = ContentGenerationViewModel()
    @StateObject private var globalManager = GlobalBackgroundProcessingManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var isIPadLandscape: Bool {
        isIPad && UIDevice.current.orientation.isLandscape
    }
    
    // MARK: - OCR and File Import Additions
    @StateObject private var ocrViewModel = OCRViewModel()
    @State private var showingPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    
    // MARK: - Camera OCR Additions
    @State private var showingCameraPicker = false
    @State private var capturedImageByCamera: UIImage? // Can be used for preview if needed
    @State private var cameraAccessGranted: Bool? = nil
    @State private var showCameraPermissionAlert = false

    // MARK: - Computed Properties for Success Box
    private var successBoxIconName: String {
        if globalManager.recentlyGeneratedStory != nil {
            return "book.fill"
        } else if globalManager.recentlyGeneratedLecture != nil {
            return "mic.fill"
        } else {
            return "doc.text.fill"
        }
    }
    
    private var successBoxContentType: String {
        if globalManager.recentlyGeneratedStory != nil {
            return "story"
        } else if globalManager.recentlyGeneratedLecture != nil {
            return "lecture"
        } else {
            return "content"
        }
    }
    
    private var recentContentIconName: String {
        if let recent = globalManager.lastGeneratedContent {
            switch recent.type {
            case .story:
                return "book.fill"
            case .lecture:
                return "mic.fill"
            case .userContent:
                return "doc.text.fill"
            }
        }
        return "doc.text.fill"
    }

    // MARK: - Converted User Content
    private var convertedUserContent: FirebaseUserContent {
        // Convert ContentBlock array to FirebaseContentBlock format
        let firebaseBlocks = viewModel.blocks.map { block in
            var firebaseBlock = FirebaseContentBlock(
                type: block.type.rawValue,
                content: block.content,
                alt: block.alt,
                firebaseImageUrl: block.firebaseImageUrl,
                options: block.options?.map { option in
                    FirebaseQuizOption(id: option.id, text: option.text)
                },
                correctAnswerID: block.correctAnswerID,
                explanation: block.explanation
            )
            firebaseBlock.id = block.id.uuidString
            
            return firebaseBlock
        }
        
        var userContent = FirebaseUserContent(
            id: UUID().uuidString,
            userId: nil, // Will be set by the backend
            topic: viewModel.inputText,
            level: viewModel.selectedLevel.rawValue,
            summarizationTier: viewModel.selectedSummarizationTier.rawValue,
            blocks: firebaseBlocks,
            createdAt: Timestamp(date: Date())
        )
        
        return userContent
    }

    // MARK: - Global Background Processing Indicator
    @State private var showGlobalProcessingIndicator: Bool = true

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
            
            ScrollView {
                VStack(spacing: isIPad ? 32 : 24) {
                    // Header Section
                    headerSection
                    
                    // Input Section (now includes daily limit)
                    inputSection
                    
                    // Configuration Section
                    configurationSection
                    
                    // Persistent Recently Generated Box (always visible, compact, no dismiss)
                    if let recent = globalManager.lastGeneratedContent {
                        HStack(spacing: 8) {
                            Image(systemName: recentContentIconName)
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .semibold))
                            Text(recent.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text("Recently generated")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.green.opacity(0.13))
                        .cornerRadius(10)
                        .onTapGesture {
                            // Open the correct full reading view based on type
                            switch recent.type {
                            case .story:
                                viewModel.isShowingFullScreenStory = true
                            case .lecture:
                                viewModel.isShowingFullScreenLecture = true
                            case .userContent:
                                viewModel.isShowingFullScreenContent = true
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    
                    // Generate Button
                    generateButton
                    
                    // Spacer
                    Spacer(minLength: 100)
                    
                    // Temporary Success Box for ALL content types
                    if globalManager.showSuccessBox && (
                        globalManager.recentlyGeneratedStory != nil ||
                        globalManager.recentlyGeneratedLecture != nil ||
                        globalManager.recentlyGeneratedUserContent != nil
                    ) {
                        Button(action: {
                            // Open the correct full reading view
                            if globalManager.recentlyGeneratedStory != nil {
                                viewModel.isShowingFullScreenStory = true
                            } else if globalManager.recentlyGeneratedLecture != nil {
                                viewModel.isShowingFullScreenLecture = true
                            } else if globalManager.recentlyGeneratedUserContent != nil {
                                viewModel.isShowingFullScreenContent = true
                            }
                            globalManager.clearRecentlyGeneratedContent()
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: successBoxIconName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Content Ready!")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Tap to view your new \(successBoxContentType) in full reading mode.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Button(action: { globalManager.showSuccessBox = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 4)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.12))
                                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                            )
                        }
                        .padding(.horizontal, isIPad ? 24 : 12)
                        .padding(.vertical, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: globalManager.recentlyGeneratedStory)
                    }
                    
                    // Status Message
                    if let status = viewModel.statusMessage {
                        Text(status)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    // Generated Content
                    if !viewModel.blocks.isEmpty && !viewModel.isShowingFullScreenContent {
                        generatedContentSection
                    }
                }
                .padding(.horizontal, isIPad ? 24 : 12)
                .padding(.vertical, isIPad ? 32 : 20)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { UIApplication.shared.endEditing() })
        // MARK: - OCR and File Import Sheet Modifiers
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                // Only clear if we're actually going to process a new item
                if newItem != nil {
                    ocrViewModel.setImageForProcessing(nil)
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            ocrViewModel.setImageForProcessing(uiImage)
                            return
                        }
                    }
                    ocrViewModel.errorMessage = "Could not load image from library."
                }
            }
        }
        .sheet(isPresented: $showingFileImporter) {
            FilePickerView(
                selectedFileURL: .constant(nil),
                allowedFileTypes: [.image, .pdf],
                onFilePicked: { url in
                    // Handle file import
                }
            )
        }
        // MARK: - Camera Picker Sheet Modifier
        .sheet(isPresented: $showingCameraPicker) {
            CameraPickerView(
                selectedImage: $capturedImageByCamera, // Still bind for potential preview
                onImagePicked: { pickedImage in
                    print("📸 ContentGenerationView: CameraPickerView onImagePicked callback received. Image is nil? \(pickedImage == nil)")
                    if let img = pickedImage {
                        print("📸 ContentGenerationView: Valid image received from callback. Sending to OCR.")
                        self.ocrViewModel.setImageForProcessing(img)
                        // Optionally, still set capturedImageByCamera if you want it for a preview display
                        // self.capturedImageByCamera = img 
                    } else {
                        print("📸 ContentGenerationView: Image from callback is nil (picker cancelled or error).")
                        // Optionally, clear any existing preview if an image was picked then cancelled
                        // self.capturedImageByCamera = nil
                        // We might also want to clear OCR error/state if user cancels
                        // self.ocrViewModel.setImageForProcessing(nil) // This would clear recognized text too
                    }
                }
            )
        }
        // Alert for camera permission
        .alert("Camera Access Denied", isPresented: $showCameraPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("To use the camera for OCR, please grant camera access in Settings.")
        }
        .onChange(of: ocrViewModel.recognizedText) { newText in
            print("🔄 ContentGenerationView: ocrViewModel.recognizedText changed. New text: \"\(newText)\". Error message: \"\(ocrViewModel.errorMessage ?? "None")\"")
            if !newText.isEmpty && ocrViewModel.errorMessage == nil {
                print("🔄 ContentGenerationView: Updating viewModel.inputText with recognized text.")
                viewModel.inputText = newText
            } else if newText.isEmpty && ocrViewModel.errorMessage == nil {
                 print("🔄 ContentGenerationView: Recognized text is empty, but no OCR error. Not updating input text.")
            } else if ocrViewModel.errorMessage != nil {
                 print("🔄 ContentGenerationView: OCR error exists. Not updating input text from recognizedText.")
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingFullScreenStory, onDismiss: { }) {
            if let story = viewModel.currentStory {
                NavigationStack {
                    FullReadingView(
                        itemID: story.id.uuidString,
                        collectionName: "stories",
                        itemTitle: story.title,
                        dismissAction: {
                            viewModel.isShowingFullScreenStory = false
                        }
                    )
                }
            } else if let recent = globalManager.lastGeneratedContent, recent.type == .story {
                NavigationStack {
                    FullReadingView(
                        itemID: recent.id,
                        collectionName: "stories",
                        itemTitle: recent.title,
                        dismissAction: {
                            viewModel.isShowingFullScreenStory = false
                        }
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingFullScreenLecture, onDismiss: { }) {
            if let lecture = viewModel.currentLecture {
                LectureView(
                    lecture: lecture, 
                    audioFiles: viewModel.currentLectureAudioFiles,
                    dismissAction: {
                        viewModel.isShowingFullScreenLecture = false
                    }
                )
            } else if let recent = globalManager.lastGeneratedContent, recent.type == .lecture {
                // For lectures, we need to fetch the content from Firebase since we don't store the full lecture object
                NavigationStack {
                    FullReadingView(
                        itemID: recent.id,
                        collectionName: "lectures",
                        itemTitle: recent.title,
                        dismissAction: {
                            viewModel.isShowingFullScreenLecture = false
                        }
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingFullScreenContent, onDismiss: { }) {
            if !viewModel.blocks.isEmpty {
                NavigationStack {
                    FullReadingView(
                        itemID: viewModel.savedContentDocumentId ?? convertedUserContent.id ?? UUID().uuidString,
                        collectionName: "userGeneratedContent",
                        itemTitle: convertedUserContent.topic ?? "Generated Content",
                        dismissAction: {
                            viewModel.isShowingFullScreenContent = false
                        }
                    )
                }
            } else if let recent = globalManager.lastGeneratedContent, recent.type == .userContent {
                NavigationStack {
                    FullReadingView(
                        itemID: recent.id,
                        collectionName: "userGeneratedContent",
                        itemTitle: recent.title,
                        dismissAction: {
                            viewModel.isShowingFullScreenContent = false
                        }
                    )
                }
            }
        }
        .task {
            await viewModel.refreshTodayGenerationCount()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
            Text("Content Generation")
                .font(.system(size: isIPad ? 36 : 28, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            Text("Transform your text into engaging content with AI-powered generation")
                .font(.system(size: isIPad ? 18 : 16, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, isIPad ? 8 : 4)
        .padding(.bottom, isIPad ? 8 : 4)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: isIPad ? 20 : 16) {
            Text("Input Text")
                .font(.system(size: isIPad ? 20 : 18, weight: .semibold))
                .foregroundColor(.primary)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(
                    get: { String(viewModel.inputText.prefix(5000)) },
                    set: { viewModel.inputText = String($0.prefix(5000)) }
                ))
                .frame(minHeight: isIPad ? 200 : 160)
                .padding(12)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                .cornerRadius(12)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                if viewModel.inputText.isEmpty {
                    Text("Enter your text here or use OCR to scan from images...")
                        .foregroundColor(.secondary)
                        .font(.system(size: isIPad ? 17 : 16, weight: .regular))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                
                // Character count
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(viewModel.inputText.count)/5000")
                            .font(.system(size: isIPad ? 12 : 11, weight: .medium))
                            .foregroundColor(viewModel.inputText.count > 4500 ? .red : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
                            )
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
            }
            
            // Compact OCR Buttons (matching profile screen style)
            HStack(spacing: isIPad ? 12 : 8) {
                Spacer()
                Button(action: { showingPhotosPicker = true }) {
                    Text("Photos")
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.vertical, isIPad ? 8 : 6)
                        .padding(.horizontal, isIPad ? 12 : 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Button(action: { showingFileImporter = true }) {
                    Text("File Import")
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.vertical, isIPad ? 8 : 6)
                        .padding(.horizontal, isIPad ? 12 : 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Button(action: {
                    CameraPickerView.checkCameraPermission { granted in
                        self.cameraAccessGranted = granted
                        if granted {
                            self.ocrViewModel.setImageForProcessing(nil)
                            self.capturedImageByCamera = nil
                            self.showingCameraPicker = true
                        } else {
                            self.showCameraPermissionAlert = true
                        }
                    }
                }) {
                    Text("Camera")
                        .font(.system(size: isIPad ? 14 : 12, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.vertical, isIPad ? 8 : 6)
                        .padding(.horizontal, isIPad ? 12 : 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                Spacer()
            }
            
            // Compact Daily Limit Section (moved here)
            let used = viewModel.todayGenerationCount
            let limit = 12
            let atLimit = used >= limit
            let progress = Double(used) / Double(limit)
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Daily Limit")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(used)/\(limit)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(atLimit ? .red : .primary)
                    }
                    
                    // Progress Bar
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: atLimit ? .red : .orange))
                        .frame(height: 2)
                }
                
                if atLimit {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .padding(8)
            .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            
            // OCR Status
            if ocrViewModel.isProcessing {
                HStack(spacing: isIPad ? 10 : 8) {
                    ProgressView()
                        .scaleEffect(isIPad ? 0.8 : 0.7)
                    Text(ocrViewModel.totalPages > 1 ? 
                         "Processing page \(ocrViewModel.currentPage) of \(ocrViewModel.totalPages)..." :
                         "Scanning image...")
                        .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, isIPad ? 16 : 12)
                .padding(.vertical, isIPad ? 12 : 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            if let ocrError = ocrViewModel.errorMessage {
                HStack(spacing: isIPad ? 10 : 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: isIPad ? 13 : 12, weight: .medium))
                        .foregroundColor(.red)
                    Text("OCR Error: \(ocrError)")
                        .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, isIPad ? 16 : 12)
                .padding(.vertical, isIPad ? 12 : 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(isIPad ? 28 : 16)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Configuration Section
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.system(size: isIPad ? 18 : 16, weight: .medium))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Reading Level Selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reading Level")
                        .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Picker("Reading Level", selection: $viewModel.selectedLevel) {
                        ForEach(ReadingLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Content Type Selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("Content Type")
                        .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Picker("Content Type", selection: $viewModel.selectedSummarizationTier) {
                        ForEach(SummarizationTier.allCases, id: \.self) { tier in
                            Text(tier.displayName).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Story-specific options
                if viewModel.selectedSummarizationTier == .story {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.vertical, 2)
                        
                        // Genre Selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Genre")
                                .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(StoryGenre.allCases, id: \.self) { genre in
                                    Button(action: {
                                        viewModel.selectedGenre = genre
                                    }) {
                                        HStack {
                                            Text(genre.rawValue)
                                            if viewModel.selectedGenre == genre {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.selectedGenre.rawValue)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Main Character Input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Main Character (Optional)")
                                .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("Enter character name", text: $viewModel.mainCharacter)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        
                        // Image Style Selection
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Image Style")
                                .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(ImageStyle.allCases, id: \.self) { style in
                                    Button(action: {
                                        viewModel.selectedImageStyle = style
                                    }) {
                                        HStack {
                                            Text(style.displayName)
                                            if viewModel.selectedImageStyle == style {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.selectedImageStyle.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                
                // Lecture-specific options
                if viewModel.selectedSummarizationTier == .lecture {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.vertical, 2)
                        
                        // Image Style Selection for Lecture
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Image Style")
                                .font(.system(size: isIPad ? 14 : 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Menu {
                                ForEach(ImageStyle.allCases, id: \.self) { style in
                                    Button(action: {
                                        viewModel.selectedImageStyle = style
                                    }) {
                                        HStack {
                                            Text(style.displayName)
                                            if viewModel.selectedImageStyle == style {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.selectedImageStyle.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(isIPad ? 20 : 14)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        Button(action: {
            Task {
                await viewModel.generateContent()
            }
        }) {
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Text(viewModel.isLoading ? "Generating..." : "Generate Content")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                ZStack {
                    BlurView(style: .systemUltraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.06))
                }
            )
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.75), value: viewModel.isLoading)
        }
        .disabled(viewModel.isLoading || viewModel.todayGenerationCount >= 12)
        .opacity(viewModel.isLoading || viewModel.todayGenerationCount >= 12 ? 0.5 : 1.0)
        .scaleEffect(viewModel.isLoading || viewModel.todayGenerationCount >= 12 ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.todayGenerationCount)
    }
    
    // MARK: - Error Section
    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 4) {
                if message.contains("503") || message.contains("Backend is starting up") {
                    Text("Backend Service Starting")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    Text("The backend service is starting up. Please try again in a few moments.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                } else {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(message.contains("503") || message.contains("Backend is starting up") ? 
                      Color.orange.opacity(0.1) : Color.red.opacity(0.1))
        )
    }
    
    // MARK: - Generated Content Section
    private var generatedContentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Generated Content")
                .font(.system(size: 22, weight: .bold))
            
            ForEach(viewModel.blocks) { block in
                ContentBlockView(block: block)
            }
        }
        .padding(20)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 1))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ContentGenerationView()
}

// MARK: - Content Block Views
struct ContentBlockView: View {
    let block: ContentBlock
    
    // MARK: - iPad Detection
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Display image if available for any block type
            if let imageUrl = block.firebaseImageUrl {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading image...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 300 : 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: isIPad ? 600 : .infinity)
                            .frame(maxHeight: isIPad ? 400 : 300)
                            .cornerRadius(12)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: isIPad ? 300 : 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Display block content based on type
            switch block.type {
            case .heading:
                Text(block.content ?? "")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                
            case .paragraph:
                Text(block.content ?? "")
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .padding(.horizontal, 4)
                
            case .image:
                // Image already displayed above
                if block.content != nil {
                    Text(block.content ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.horizontal, 4)
                }
                
            case .quizHeading:
                Text(block.content ?? "")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                
            case .multipleChoiceQuestion:
                VStack(alignment: .leading, spacing: 16) {
                    Text(block.content ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                    
                    if let options = block.options {
                        VStack(spacing: 8) {
                            ForEach(options) { option in
                                Button(action: {
                                    // Handle option selection
                                }) {
                                    HStack {
                                        Text(option.text)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        if option.id == block.correctAnswerID {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title3)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    if let explanation = block.explanation {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Explanation")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text(explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                
            case .error:
                Text(block.content ?? "An error occurred")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// Add this extension at the bottom of the file if not already present in the project
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
} 
