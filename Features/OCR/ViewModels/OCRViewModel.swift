import SwiftUI
import Vision // Import the Vision framework
import Combine

class OCRViewModel: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var imageForProcessing: UIImage? {
        didSet {
            print("🔍 OCRViewModel: imageForProcessing was set. Is it nil? \(imageForProcessing == nil)")
            if imageForProcessing != nil {
                print("🔍 OCRViewModel: imageForProcessing is not nil, calling processImage().")
                processImage()
            } else if oldValue != nil {
                print("🔍 OCRViewModel: imageForProcessing was cleared.")
            }
        }
    }
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?

    func processImage() {
        print("🔍 OCRViewModel: processImage() called.")
        guard let cgImage = imageForProcessing?.cgImage else {
            errorMessage = "No image selected or image format is invalid for CGImage conversion."
            recognizedText = ""
            print("🔍 OCRViewModel: processImage() aborted - cgImage is nil. imageForProcessing: \(String(describing: imageForProcessing))")
            return
        }
        
        print("🔍 OCRViewModel: cgImage successfully obtained. Starting VNRecognizeTextRequest.")
        isProcessing = true
        errorMessage = nil
        recognizedText = "" // Clear previous results

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            DispatchQueue.main.async {
                print("🔍 OCRViewModel: VNRecognizeTextRequest completion handler fired.")
                self?.isProcessing = false
                if let error = error {
                    self?.errorMessage = "OCR Error: \(error.localizedDescription)"
                    print("🔍 OCRViewModel: OCR Vision Error: \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    self?.errorMessage = "No text recognized by Vision."
                    print("🔍 OCRViewModel: No text observations returned or observations array is empty.")
                    return
                }
                
                print("🔍 OCRViewModel: Received \(observations.count) text observations.")
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                self?.recognizedText = recognizedStrings.joined(separator: "\n")
                print("🔍 OCRViewModel: Recognized text: \"\(self?.recognizedText ?? "NIL")\"")
                if self?.recognizedText.isEmpty == true && !recognizedStrings.isEmpty {
                    print("🔍 OCRViewModel: Warning - recognizedStrings was not empty but joined recognizedText is empty.")
                } else if self?.recognizedText.isEmpty == true && recognizedStrings.isEmpty {
                    print("🔍 OCRViewModel: recognizedStrings was empty, so recognizedText is also empty.")
                }
            }
        }
        
        request.recognitionLevel = .accurate

        do {
            print("🔍 OCRViewModel: Performing Vision request handler.")
            try requestHandler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.errorMessage = "Failed to perform text recognition request: \(error.localizedDescription)"
                print("🔍 OCRViewModel: Failed to perform Vision request: \(error.localizedDescription)")
            }
        }
    }

    func setImageForProcessing(_ image: UIImage?) {
        print("🔍 OCRViewModel: setImageForProcessing called. Is new image nil? \(image == nil)")
        self.imageForProcessing = image
        if image == nil {
            self.recognizedText = ""
            self.errorMessage = nil
            print("🔍 OCRViewModel: setImageForProcessing cleared text and error because input image is nil.")
        } else {
            self.recognizedText = ""
            self.errorMessage = nil
            print("🔍 OCRViewModel: setImageForProcessing cleared previous text/error for new image.")
        }
    }
} 