import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentGenerationView: View {
    @StateObject private var viewModel = ContentGenerationViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
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

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching other screens
                LinearGradient(
                    gradient: Gradient(
                        colors: colorScheme == .dark ? 
                            [.cyan.opacity(0.1), Color(.systemBackground), Color(.systemBackground)] :
                            [.cyan.opacity(0.2), .white, .white]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Input Section
                        inputSection
                        
                        // Daily Limit Section
                        dailyLimitSection
                        
                        // Configuration Section
                        configurationSection
                        
                        // Generate Button
                        generateButton
                        
                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            errorSection(errorMessage)
                        }
                        
                        // Generated Content
                        if !viewModel.blocks.isEmpty {
                            generatedContentSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Generate Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
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
                        // Clear previous state once at the beginning
                        ocrViewModel.setImageForProcessing(nil)
                        ocrViewModel.errorMessage = nil

                        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                        defer {
                            if shouldStopAccessing {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }

                        do {
                            let resources = try url.resourceValues(forKeys: [.contentTypeKey])
                            guard let contentType = resources.contentType else {
                                ocrViewModel.errorMessage = "Could not determine the file type."
                                return
                            }

                            if contentType.conforms(to: .image) {
                                let imageData = try Data(contentsOf: url)
                                if let uiImage = UIImage(data: imageData) {
                                    ocrViewModel.setImageForProcessing(uiImage)
                                } else {
                                    ocrViewModel.errorMessage = "Failed to convert the selected file to an image. The file might be corrupted or in an unsupported format."
                                }
                            } else if contentType.conforms(to: .pdf) {
                                // Use the OCRViewModel's processFile method for PDF handling
                                ocrViewModel.processFile(at: url, fileType: contentType)
                            } else {
                                let fileExtension = contentType.preferredFilenameExtension ?? "unknown"
                                ocrViewModel.errorMessage = "Unsupported file type selected: \(fileExtension)."
                            }
                        } catch {
                            ocrViewModel.errorMessage = "Could not load data from the file: \(error.localizedDescription)"
                        }
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
            .fullScreenCover(isPresented: $viewModel.isShowingFullScreenStory) {
                if let story = viewModel.currentStory {
                    StoryView(story: story)
                }
            }
        }
        .task {
            await viewModel.refreshTodayGenerationCount()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Generation")
                .font(.system(size: 28, weight: .bold, design: .default))
            
            Text("Transform your text into engaging content with AI-powered generation")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Input Text")
                .font(.system(size: 18, weight: .semibold))
            
            // Text Editor
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: Binding(
                        get: { String(viewModel.inputText.prefix(5000)) },
                        set: { viewModel.inputText = String($0.prefix(5000)) }
                    ))
                    .frame(minHeight: 160)
                    .padding(12)
                    .background(Color.clear)
                    .cornerRadius(12)
                    .overlay(
                        Group {
                            if viewModel.inputText.isEmpty {
                                VStack {
                                    HStack {
                                        Text("Enter your text here or use OCR to scan from images...")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16, weight: .regular))
                                            .padding(.leading, 16)
                                            .padding(.top, 20)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                            }
                        }
                    )
                    
                    // Character count
                    Text("\(viewModel.inputText.count)/5000")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(viewModel.inputText.count > 4500 ? .red : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemBackground))
                        )
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                }
                
                // OCR Buttons
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        OCRButton(
                            title: "Photo Library",
                            icon: "photo.on.rectangle",
                            color: .blue
                        ) {
                            showingPhotosPicker = true
                        }
                        
                        OCRButton(
                            title: "File Import",
                            icon: "doc.text.image",
                            color: .green
                        ) {
                            showingFileImporter = true
                        }
                    }
                    
                    OCRButton(
                        title: "Camera",
                        icon: "camera",
                        color: .orange
                    ) {
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
                    }
                }
                
                // OCR Status
                if ocrViewModel.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(ocrViewModel.totalPages > 1 ? 
                             "Processing page \(ocrViewModel.currentPage) of \(ocrViewModel.totalPages)..." :
                             "Scanning image...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                } else if let ocrError = ocrViewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                        Text("OCR Error: \(ocrError)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Daily Limit Section
    private var dailyLimitSection: some View {
        let used = viewModel.todayGenerationCount
        let limit = 8
        let atLimit = used >= limit
        let progress = Double(used) / Double(limit)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Generation Limit")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("\(used)/\(limit)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(atLimit ? .red : .primary)
            }
            
            // Progress Bar
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: atLimit ? .red : .orange))
                .frame(height: 4)
            
            if atLimit {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                    Text("Daily limit reached. Try again tomorrow!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                }
            } else {
                Text("\(limit - used) generations remaining today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Configuration Section
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Configuration")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 20) {
                // Reading Level Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reading Level")
                        .font(.system(size: 16, weight: .medium))
                    
                    Picker("Reading Level", selection: $viewModel.selectedLevel) {
                        ForEach(ReadingLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Content Type Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Content Type")
                        .font(.system(size: 16, weight: .medium))
                    
                    Picker("Content Type", selection: $viewModel.selectedSummarizationTier) {
                        ForEach(SummarizationTier.allCases, id: \.self) { tier in
                            Text(tier.rawValue).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Story-specific options
                if viewModel.selectedSummarizationTier == .story {
                    VStack(spacing: 20) {
                        Divider()
                            .padding(.vertical, 4)
                        
                        // Genre Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Genre")
                                .font(.system(size: 16, weight: .medium))
                            
                            Picker("Genre", selection: $viewModel.selectedGenre) {
                                ForEach(StoryGenre.allCases, id: \.self) { genre in
                                    Text(genre.rawValue).tag(genre)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Main Character Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Main Character (Optional)")
                                .font(.system(size: 16, weight: .medium))
                            
                            TextField("Enter character name", text: $viewModel.mainCharacter)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 16, weight: .regular))
                        }
                        
                        // Image Style Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Image Style")
                                .font(.system(size: 16, weight: .medium))
                            
                            Picker("Image Style", selection: $viewModel.selectedImageStyle) {
                                ForEach(ImageStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        Button(action: {
            Task {
                await viewModel.generateContent()
            }
        }) {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(viewModel.isLoading ? "Generating..." : "Generate Content")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isLoading || viewModel.todayGenerationCount >= 8)
        .opacity(viewModel.isLoading || viewModel.todayGenerationCount >= 8 ? 0.6 : 1.0)
    }
    
    // MARK: - Error Section
    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
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
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - OCR Button Component
struct OCRButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .cornerRadius(6)
        }
    }
}

// MARK: - Story View
struct StoryView: View {
    let story: Story
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching other screens
                LinearGradient(
                    gradient: Gradient(
                        colors: colorScheme == .dark ? 
                            [.cyan.opacity(0.1), Color(.systemBackground), Color(.systemBackground)] :
                            [.cyan.opacity(0.2), .white, .white]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Story Header
                        storyHeader
                        
                        // Story Overview
                        storyOverview
                        
                        // Chapters
                        chaptersSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
    
    // MARK: - Story Header
    private var storyHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("AI-Generated Story")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Story Overview
    private var storyOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(story.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Chapters Section
    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Chapters")
                .font(.title2)
                .fontWeight(.bold)
            
            ForEach(story.chapters.sorted(by: { $0.order < $1.order })) { chapter in
                ChapterView(chapter: chapter)
            }
        }
    }
}

// MARK: - Chapter View
struct ChapterView: View {
    let chapter: StoryChapter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chapter Header
            HStack {
                Text("Chapter \(chapter.order)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Spacer()
            }
            
            // Chapter Title
            Text(chapter.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Chapter Image
            if let imageUrl = chapter.firebaseImageUrl {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading chapter image...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(12)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Failed to load chapter image")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Chapter Content
            Text(chapter.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Content Block Views
struct ContentBlockView: View {
    let block: ContentBlock
    
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
                            .frame(height: 200)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
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
                        .frame(height: 200)
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

#Preview {
    ContentGenerationView()
} 
