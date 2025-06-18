import SwiftUI
import Vision // Import the Vision framework
import Combine
import UniformTypeIdentifiers
import CoreGraphics

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
    @Published var currentPage: Int = 0
    @Published var totalPages: Int = 0

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
        print("🔍 OCRViewModel: Current imageForProcessing is nil? \(imageForProcessing == nil)")
        print("🔍 OCRViewModel: Stack trace: \(Thread.callStackSymbols.prefix(3).joined(separator: "\n"))")
        
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

    func processFile(at fileURL: URL, fileType: UTType) {
        self.errorMessage = nil
        self.recognizedText = ""
        self.imageForProcessing = nil

        print("🔍 OCRViewModel: processFile called with URL: \(fileURL.absoluteString), Type: \(fileType.identifier)")

        // Ensure we can access the file
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.errorMessage = "The selected file does not exist or cannot be accessed."
            print("🔍 OCRViewModel: File does not exist at path: \(fileURL.path)")
            return
        }

        if fileType.conforms(to: UTType.image) {
            print("🔍 OCRViewModel: Image file detected. Loading image data.")
            let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let imageData = try Data(contentsOf: fileURL)
                if let uiImage = UIImage(data: imageData) {
                    print("🔍 OCRViewModel: Successfully loaded image from file.")
                    setImageForProcessing(uiImage)
                } else {
                    self.errorMessage = "Failed to convert the selected file to an image. The file might be corrupted or in an unsupported format."
                    print("🔍 OCRViewModel: Failed to create UIImage from file data.")
                }
            } catch {
                self.errorMessage = "Could not load data from the file: \(error.localizedDescription)"
                print("🔍 OCRViewModel: Error loading image file: \(error.localizedDescription)")
            }
        } else if fileType.conforms(to: UTType.pdf) {
            print("🔍 OCRViewModel: PDF file detected. Processing all pages.")
            var pdfURL = fileURL
            let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: tmpURL.path) {
                    try FileManager.default.removeItem(at: tmpURL)
                }
                try FileManager.default.copyItem(at: fileURL, to: tmpURL)
                print("🔍 OCRViewModel: PDF file copied to tmp: \(tmpURL.path)")
                pdfURL = tmpURL
            } catch {
                print("🔍 OCRViewModel: Failed to copy PDF to tmp: \(error.localizedDescription)")
                // Fallback: try to use the original fileURL
            }
            
            // Process all pages of the PDF
            processAllPDFPages(url: pdfURL)
        } else {
            let fileExtension = fileType.preferredFilenameExtension ?? "unknown"
            self.errorMessage = "Unsupported file type: \(fileExtension). Please select an image or PDF file."
            print("🔍 OCRViewModel: Unsupported file type: \(fileType.identifier)")
        }
    }

    private func convertPDFPageToImage(url: URL, pageNumber: Int) -> UIImage? {
        print("🔍 OCRViewModel: Attempting to create CGPDFDocument from URL: \(url)")
        guard let document = CGPDFDocument(url as CFURL) else {
            print("🔍 OCRViewModel: convertPDFPageToImage - Could not create CGPDFDocument. File may be corrupted, password-protected, or not a valid PDF.")
            return nil
        }
        print("🔍 OCRViewModel: CGPDFDocument created. Number of pages: \(document.numberOfPages)")
        guard let page = document.page(at: pageNumber) else {
            print("🔍 OCRViewModel: convertPDFPageToImage - Could not get page \(pageNumber) from PDF. PDF may be empty.")
            return nil
        }
        let pageRect = page.getBoxRect(.mediaBox)
        print("🔍 OCRViewModel: PDF page rect: \(pageRect)")
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let img = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.drawPDFPage(page)
        }
        print("🔍 OCRViewModel: convertPDFPageToImage - Successfully rendered PDF page to UIImage.")
        return img
    }

    private func processAllPDFPages(url: URL) {
        print("🔍 OCRViewModel: processAllPDFPages called with URL: \(url)")
        
        guard let document = CGPDFDocument(url as CFURL) else {
            self.errorMessage = "Failed to open PDF. The file might be corrupted, password-protected, or not a valid PDF."
            print("🔍 OCRViewModel: processAllPDFPages - Could not create CGPDFDocument.")
            return
        }
        
        let totalPages = document.numberOfPages
        print("🔍 OCRViewModel: PDF has \(totalPages) pages. Starting sequential processing.")
        
        self.isProcessing = true
        self.errorMessage = nil
        self.recognizedText = ""
        self.currentPage = 1
        self.totalPages = totalPages
        
        // Start processing from page 1
        processPDFPage(document: document, pageNumber: 1, totalPages: totalPages, accumulatedText: "")
    }
    
    private func processPDFPage(document: CGPDFDocument, pageNumber: Int, totalPages: Int, accumulatedText: String) {
        print("🔍 OCRViewModel: Processing page \(pageNumber) of \(totalPages)")
        
        // Update current page for UI progress
        DispatchQueue.main.async {
            self.currentPage = pageNumber
        }
        
        guard let page = document.page(at: pageNumber) else {
            print("🔍 OCRViewModel: Could not get page \(pageNumber) from PDF.")
            // Continue with next page if this one fails
            if pageNumber < totalPages {
                processPDFPage(document: document, pageNumber: pageNumber + 1, totalPages: totalPages, accumulatedText: accumulatedText)
            } else {
                // Finished processing all pages
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.recognizedText = accumulatedText
                    self.currentPage = 0
                    self.totalPages = 0
                    print("🔍 OCRViewModel: Finished processing all \(totalPages) pages. Total text length: \(accumulatedText.count)")
                }
            }
            return
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let img = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.drawPDFPage(page)
        }
        
        guard let cgImage = img.cgImage else {
            print("🔍 OCRViewModel: Failed to create CGImage from page \(pageNumber)")
            // Continue with next page
            if pageNumber < totalPages {
                processPDFPage(document: document, pageNumber: pageNumber + 1, totalPages: totalPages, accumulatedText: accumulatedText)
            } else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.recognizedText = accumulatedText
                }
            }
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { [weak self] (request, error) in
            DispatchQueue.main.async {
                var newAccumulatedText = accumulatedText
                
                if let error = error {
                    print("🔍 OCRViewModel: OCR Error on page \(pageNumber): \(error.localizedDescription)")
                    // Continue processing even if this page fails
                } else if let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty {
                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    let pageText = recognizedStrings.joined(separator: "\n")
                    print("🔍 OCRViewModel: Page \(pageNumber) - Received \(observations.count) text observations")
                    
                    // Add page separator if not the first page
                    if !accumulatedText.isEmpty {
                        newAccumulatedText += "\n\n--- Page \(pageNumber) ---\n\n"
                    } else {
                        newAccumulatedText += "--- Page \(pageNumber) ---\n\n"
                    }
                    newAccumulatedText += pageText
                } else {
                    print("🔍 OCRViewModel: No text found on page \(pageNumber)")
                    if !accumulatedText.isEmpty {
                        newAccumulatedText += "\n\n--- Page \(pageNumber) (No text found) ---\n\n"
                    }
                }
                
                // Process next page or finish
                if pageNumber < totalPages {
                    self?.processPDFPage(document: document, pageNumber: pageNumber + 1, totalPages: totalPages, accumulatedText: newAccumulatedText)
                } else {
                    // Finished processing all pages
                    self?.isProcessing = false
                    self?.recognizedText = newAccumulatedText
                    self?.currentPage = 0
                    self?.totalPages = 0
                    print("🔍 OCRViewModel: Finished processing all \(totalPages) pages. Total text length: \(newAccumulatedText.count)")
                }
            }
        }
        
        request.recognitionLevel = .accurate
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("🔍 OCRViewModel: Failed to perform OCR on page \(pageNumber): \(error.localizedDescription)")
            // Continue with next page
            if pageNumber < totalPages {
                processPDFPage(document: document, pageNumber: pageNumber + 1, totalPages: totalPages, accumulatedText: accumulatedText)
            } else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.recognizedText = accumulatedText
                }
            }
        }
    }
} 