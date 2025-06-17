import SwiftUI
import PhotosUI

struct ContentGenerationView: View {
    @StateObject private var viewModel = ContentGenerationViewModel()
    @Environment(\.dismiss) private var dismiss
    
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
            ScrollView {
                VStack(spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your text or use OCR")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.inputText)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        // Buttons for OCR
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    showingPhotosPicker = true
                                } label: {
                                    Label("From Library", systemImage: "photo.on.rectangle")
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                                
                                Button {
                                    showingFileImporter = true
                                } label: {
                                    Label("From File", systemImage: "doc.text.image")
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                            }
                            
                            Button {
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
                            } label: {
                                Label("From Camera", systemImage: "camera")
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 5)

                        // Display OCR Status/Error
                        if ocrViewModel.isProcessing {
                            ProgressView("Scanning image...")
                                .padding(.top, 5)
                        } else if let ocrError = ocrViewModel.errorMessage {
                            Text("OCR Error: \(ocrError)")
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 5)
                        }
                        
                    }
                    .padding(.horizontal)
                    
                    // Reading Level Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reading Level")
                            .font(.headline)
                        
                        Picker("Reading Level", selection: $viewModel.selectedLevel) {
                            ForEach(ReadingLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Content Type Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Type")
                            .font(.headline)
                        
                        Picker("Content Type", selection: $viewModel.selectedSummarizationTier) {
                            ForEach(SummarizationTier.allCases, id: \.self) { tier in
                                Text(tier.rawValue).tag(tier)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Story-specific options
                    if viewModel.selectedSummarizationTier == .story {
                        VStack(alignment: .leading, spacing: 16) {
                            // Genre Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Genre")
                                    .font(.headline)
                                
                                Picker("Genre", selection: $viewModel.selectedGenre) {
                                    ForEach(StoryGenre.allCases, id: \.self) { genre in
                                        Text(genre.rawValue).tag(genre)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            // Main Character Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Main Character (Optional)")
                                    .font(.headline)
                                
                                TextField("Main Character (Optional)", text: $viewModel.mainCharacter)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    
                            }
                            
                            // Image Style Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Image Style")
                                    .font(.headline)
                                
                                Picker("Image Style", selection: $viewModel.selectedImageStyle) {
                                    ForEach(ImageStyle.allCases, id: \.self) { style in
                                        Text(style.displayName).tag(style)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Generate Button
                    Button(action: {
                        Task {
                            await viewModel.generateContent()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Generate Content")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(viewModel.isLoading)
                    
                    // Error Message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Display Generated Content Blocks
                    if !viewModel.blocks.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Generated Content")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.blocks) { block in
                                ContentBlockView(block: block)
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Generate Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
                    ocrViewModel.setImageForProcessing(nil)
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            ocrViewModel.setImageForProcessing(uiImage)
                            return
                        }
                    }
                    if newItem != nil {
                        ocrViewModel.errorMessage = "Could not load image from library."
                    }
                }
            }
            .sheet(isPresented: $showingFileImporter) {
                FilePickerView(
                    selectedFileURL: .constant(nil),
                    allowedFileTypes: [.image],
                    onFilePicked: { url in
                        ocrViewModel.setImageForProcessing(nil)
                        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
                        defer {
                            if shouldStopAccessing {
                                url.stopAccessingSecurityScopedResource()
                            }
                        }
                        do {
                            let imageData = try Data(contentsOf: url)
                            if let uiImage = UIImage(data: imageData) {
                                ocrViewModel.setImageForProcessing(uiImage)
                            } else {
                                ocrViewModel.errorMessage = "Failed to convert imported file to an image."
                            }
                        } catch {
                            ocrViewModel.errorMessage = "Could not load data from file: \(error.localizedDescription)"
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
    }
}

// MARK: - Story View
struct StoryView: View {
    let story: Story
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Story Title
                    Text(story.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    // Story Overview
                    Text(story.content)
                        .font(.body)
                        .padding(.horizontal)
                    
                    // Chapters
                    ForEach(story.chapters.sorted(by: { $0.order < $1.order })) { chapter in
                        VStack(alignment: .leading, spacing: 12) {
                            // Chapter Title
                            Text(chapter.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            // Chapter Image
                            if let imageUrl = chapter.firebaseImageUrl {
                                AsyncImage(url: URL(string: imageUrl)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(maxHeight: 300)
                            }
                            
                            // Chapter Content
                            Text(chapter.content)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Content Block Views
struct ContentBlockView: View {
    let block: ContentBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Display image if available for any block type
            if let imageUrl = block.firebaseImageUrl {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(10)
                    case .failure:
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
            // Display block content based on type
            switch block.type {
            case .heading:
                Text(block.content ?? "")
                    .font(.title2)
                    .fontWeight(.bold)
                
            case .paragraph:
                Text(block.content ?? "")
                    .font(.body)
                
            case .image:
                // Image already displayed above
                if block.content != nil {
                    Text(block.content ?? "")
                        .font(.body)
                }
                
            case .quizHeading:
                Text(block.content ?? "")
                    .font(.title3)
                    .fontWeight(.semibold)
                
            case .multipleChoiceQuestion:
                VStack(alignment: .leading, spacing: 16) {
                    Text(block.content ?? "")
                        .font(.headline)
                    
                    if let options = block.options {
                        ForEach(options) { option in
                            Button(action: {
                                // Handle option selection
                            }) {
                                HStack {
                                    Text(option.text)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if option.id == block.correctAnswerID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    if let explanation = block.explanation {
                        Text(explanation)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                
            case .error:
                Text(block.content ?? "An error occurred")
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ContentGenerationView()
} 
