import SwiftUI
import UniformTypeIdentifiers // For UTType

struct FilePickerView: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL? // For direct binding if needed
    var allowedFileTypes: [UTType] // Specify which file types are allowed
    var onFilePicked: (URL) -> Void // Callback with the successfully picked URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // When initialized, the picker is created with the specified document types.
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: allowedFileTypes, asCopy: true)
        // asCopy: true is generally safer. It provides a copy of the file in a temporary location.
        // If you need to access the original file, use asCopy: false and handle security-scoped bookmarks.
        controller.delegate = context.coordinator
        controller.shouldShowFileExtensions = true
        controller.allowsMultipleSelection = false
        controller.directoryURL = nil // Don't restrict to a specific directory
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No dynamic updates needed for the controller in this basic version.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: FilePickerView

        init(_ parent: FilePickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                // This case should ideally not happen if the picker successfully returns.
                // You might want to log an error or handle it.
                print("🔍 FilePickerView: No URL returned from document picker")
                return
            }
            
            print("🔍 FilePickerView: Document picked at URL: \(url.absoluteString)")
            print("🔍 FilePickerView: File exists at path: \(FileManager.default.fileExists(atPath: url.path))")
            
            // Verify the file is accessible
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("🔍 FilePickerView: ERROR - File does not exist at picked URL")
                return
            }
            
            // It's important to handle access to the file URL correctly.
            // If asCopy was true, this URL points to a temporary copy.
            // If asCopy was false, you might need to use startAccessingSecurityScopedResource().
            parent.selectedFileURL = url 
            parent.onFilePicked(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation. You might want to clear any state.
            parent.selectedFileURL = nil
            // Optionally, call a specific cancellation callback if needed.
        }
    }
}

// Example Usage (within another SwiftUI View, perhaps to feed an image to OCRViewModel):
struct ImportAndOCRView: View {
    @StateObject private var ocrViewModel = OCRViewModel()
    @State private var showingFilePicker = false
    @State private var pickedFileURL: URL? // Store the URL from the file picker

    var body: some View {
        VStack {
            // Display OCR related views (image, text, progress)
            if let image = ocrViewModel.imageForProcessing {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
            } else {
                Text("No image selected for OCR.")
                    .padding()
            }

            if ocrViewModel.isProcessing {
                ProgressView("Recognizing Text...")
            } else if let errorMessage = ocrViewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else if !ocrViewModel.recognizedText.isEmpty {
                ScrollView {
                    Text(ocrViewModel.recognizedText)
                        .padding()
                }
            }
            
            Button("Import Image File for OCR") {
                showingFilePicker = true
            }
            .padding()
        }
        .sheet(isPresented: $showingFilePicker) {
            FilePickerView(
                selectedFileURL: $pickedFileURL,
                allowedFileTypes: [.image], // We want to import images (e.g., .png, .jpeg)
                onFilePicked: { url in
                    // Once a file is picked, try to load it as a UIImage
                    // Ensure you handle file access and potential errors robustly.
                    // If UIDocumentPickerViewController was initialized with asCopy: true,
                    // the URL is a temporary copy, and we need to process it before the sheet dismisses
                    // or move it to a persistent location if needed long-term.
                    
                    // Start accessing the security-scoped resource if not copied.
                    // However, with asCopy: true, this might not be strictly necessary
                    // but good practice if you ever change asCopy to false.
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
                            ocrViewModel.setImageForProcessing(nil) // Clear any previous image
                        }
                    } catch {
                        ocrViewModel.errorMessage = "Could not load data from file: \(error.localizedDescription)"
                        ocrViewModel.setImageForProcessing(nil) // Clear any previous image
                    }
                }
            )
        }
        .navigationTitle("Import & OCR")
    }
}

struct FilePickerView_Previews: PreviewProvider {
    static var previews: some View {
        // Basic preview of the picker itself is tricky without a presentation context.
        // Previewing the example usage is more illustrative.
        NavigationStack {
             ImportAndOCRView()
        }
    }
} 