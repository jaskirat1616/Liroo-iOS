import SwiftUI
import PhotosUI // For PhotosPicker

struct OCRView: View {
    @StateObject private var viewModel = OCRViewModel()
    @State private var selectedPhoto: PhotosPickerItem? = nil

    var body: some View {
        NavigationView { // Or NavigationStack for iOS 16+
            VStack(spacing: 20) {
                Text("OCR - Text Recognition")
                    .font(.headline)

                // Image Picker
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images, // We are only interested in images
                    photoLibrary: .shared()
                ) {
                    Text("Select Image")
                }
                .onChange(of: selectedPhoto) { newItem in
                    Task {
                        // Retrieve the image data from the selected photo
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                viewModel.setImageForProcessing(uiImage)
                                return
                            }
                        }
                        // If loading fails or no item is selected
                        viewModel.setImageForProcessing(nil)
                        if newItem != nil { // only show error if an item was selected but failed to load
                             viewModel.errorMessage = "Could not load image."
                        }
                    }
                }

                // Display selected image (optional, but good for UX)
                if let image = viewModel.imageForProcessing {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .padding(.vertical)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundColor(.gray)
                        .padding(.vertical)
                    Text("No image selected")
                        .foregroundColor(.gray)
                }
                
                // OCR Processing Indicator and Results
                if viewModel.isProcessing {
                    ProgressView("Processing...")
                } else {
                    if let errorMsg = viewModel.errorMessage {
                        Text("Error: \(errorMsg)")
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    ScrollView {
                        Text(viewModel.recognizedText.isEmpty && viewModel.errorMessage == nil && viewModel.imageForProcessing != nil ? "No text found or processing not initiated." : viewModel.recognizedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled) // Allow text selection
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Image OCR") // For NavigationView
            // .navigationBarTitleDisplayMode(.inline) // Optional: For NavigationView
        }
    }
}

struct OCRView_Previews: PreviewProvider {
    static var previews: some View {
        OCRView()
    }
} 