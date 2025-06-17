import SwiftUI
import Vision // Import the Vision framework
import Combine

class OCRViewModel: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var imageForProcessing: UIImage? {
        didSet {
            if imageForProcessing != nil {
                processImage()
            }
        }
    }
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    func processImage() {
        guard let cgImage = imageForProcessing?.cgImage else {
            errorMessage = "No image selected or image format is invalid."
            recognizedText = ""
            return
        }
        
        isProcessing = true
        errorMessage = nil
        recognizedText = "" // Clear previous results

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            DispatchQueue.main.async {
                self?.isProcessing = false
                if let error = error {
                    self?.errorMessage = "OCR Error: \(error.localizedDescription)"
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    self?.errorMessage = "No text recognized."
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    // Return the string with the highest confidence.
                    observation.topCandidates(1).first?.string
                }
                self?.recognizedText = recognizedStrings.joined(separator: "\n")
            }
        }
        
        // You can set recognition languages if needed, e.g., request.recognitionLanguages = ["en-US", "fr-FR"]
        // By default, it uses the device's current language settings.
        request.recognitionLevel = .accurate // Or .fast for quicker, less accurate results

        do {
            try requestHandler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.errorMessage = "Failed to perform text recognition: \(error.localizedDescription)"
            }
        }
    }

    // Call this method to set the image. Processing will start automatically.
    func setImageForProcessing(_ image: UIImage?) {
        self.imageForProcessing = image
        // Clear previous results if a new image is set (or nil)
        if image == nil {
            self.recognizedText = ""
            self.errorMessage = nil
        }
    }
} 