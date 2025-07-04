import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UserNotifications
import BackgroundTasks

@MainActor
class ContentGenerationViewModel: NSObject, ObservableObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    @Published var inputText = ""
    @Published var selectedLevel: ReadingLevel = .standard
    @Published var selectedSummarizationTier: SummarizationTier = .quickSummary
    @Published var selectedGenre: StoryGenre = .adventure
    @Published var mainCharacter = ""
    @Published var selectedImageStyle: ImageStyle = .ghibli
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentStory: Story?
    @Published var currentLecture: Lecture?
    @Published var currentLectureAudioFiles: [AudioFile] = []
    @Published var blocks: [ContentBlock] = []
    @Published var isShowingFullScreenStory = false
    @Published var isShowingFullScreenLecture = false
    @Published var isShowingFullScreenContent = false
    @Published var todayGenerationCount: Int = 0
    @Published var statusMessage: String? = nil
    @Published var savedContentDocumentId: String?
    
    // Use global background processing manager
    private let globalManager = GlobalBackgroundProcessingManager.shared
    
    private let firestoreService = FirestoreService.shared
    private let backendURL = "https://backend-orasync-test.onrender.com"
    
    // Add custom URLSession configuration
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600  // 10 minutes timeout for request
        config.timeoutIntervalForResource = 1800  // 30 minutes timeout for resource
        return URLSession(configuration: config)
    }()
    
    // Add background session property
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.liroo.contentgeneration.bg")
        config.timeoutIntervalForRequest = 600  // 10 minutes
        config.timeoutIntervalForResource = 1800  // 30 minutes
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // Add a property to accumulate data for background tasks
    private var backgroundTaskData: [Int: Data] = [:]
    
    // MARK: - Notification Setup
    override init() {
        // Notifications are now handled automatically by NotificationManager
        // No manual setup needed
    }
    
    // MARK: - Content Generation
    
    func generateContent() async {
        guard !inputText.isEmpty else {
            errorMessage = "Please enter some text to generate content"
            return
        }
        
        guard inputText.count <= 5000 else {
            errorMessage = "Input text must be less than 5000 characters"
            return
        }
        
        // Daily generation limit check
        if let userId = Auth.auth().currentUser?.uid {
            let todayCount = await fetchTodayGenerationCount(userId: userId)
            await MainActor.run { self.todayGenerationCount = todayCount }
            if todayCount >= 12 {
                errorMessage = "You have reached your daily generation limit (12 per day). Please try again tomorrow."
                return
            }
        }
        
        // Start background processing
        let generationType = selectedSummarizationTier.displayName.lowercased()
        let taskId = globalManager.startBackgroundTask(type: generationType)
        isLoading = true
        errorMessage = nil
        statusMessage = "Starting generation... You can continue using the app."
        
        // Clear any existing full screen states AND previous content
        isShowingFullScreenStory = false
        isShowingFullScreenLecture = false
        isShowingFullScreenContent = false
        savedContentDocumentId = nil
        currentStory = nil
        currentLecture = nil
        blocks = []
        
        // Store generation parameters for background processing
        let generationParams = GenerationParameters(
            inputText: inputText,
            selectedLevel: selectedLevel,
            selectedSummarizationTier: selectedSummarizationTier,
            selectedGenre: selectedGenre,
            mainCharacter: mainCharacter,
            selectedImageStyle: selectedImageStyle
        )
        
        // Store parameters for background processing
        if let encoded = try? JSONEncoder().encode(generationParams) {
            UserDefaults.standard.set(encoded, forKey: "backgroundGenerationParams")
        }
        
        let maxRetries = 2
        var attempt = 0
        var lastError: Error?
        
        repeat {
            do {
                if selectedSummarizationTier == .story {
                    try await generateStoryWithProgress()
                } else if selectedSummarizationTier == .lecture {
                    try await generateLectureWithProgress()
                } else {
                    try await generateRegularContentWithProgress()
                }
                
                // Refresh count after successful generation
                await refreshTodayGenerationCount()
                
                // Track engagement and send notifications automatically
                EngagementTracker.shared.trackContentGeneration(contentType: selectedSummarizationTier.displayName)
                
                statusMessage = nil
                isLoading = false
                globalManager.endBackgroundTask()
                return
                
            } catch {
                lastError = error
                attempt += 1
                let nsError = error as NSError
                let isNetworkLost = nsError.domain == NSURLErrorDomain && nsError.code == -1005
                
                if isNetworkLost && attempt <= maxRetries {
                    await MainActor.run {
                        self.statusMessage = "Network connection lost. Retrying (\(attempt)/\(maxRetries))..."
                        self.globalManager.updateProgress(step: "Retrying...", stepNumber: globalManager.currentStepNumber, totalSteps: globalManager.totalSteps)
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                } else {
                    // Send error notification automatically
                    await NotificationManager.shared.sendContentGenerationError(contentType: selectedSummarizationTier.displayName)
                    
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.statusMessage = nil
                    }
                    isLoading = false
                    globalManager.endBackgroundTaskWithError(errorMessage: error.localizedDescription)
                    return
                }
            }
        } while attempt <= maxRetries
        
        isLoading = false
        statusMessage = nil
        globalManager.endBackgroundTask()
        if let lastError = lastError {
            errorMessage = lastError.localizedDescription
        }
    }
    
    // MARK: - Progress-Aware Generation Methods
    
    private func generateStoryWithProgress() async throws {
        globalManager.updateProgress(step: "Generating story content...", stepNumber: 1, totalSteps: 4)
        
        print("[Story] Starting story generation process")
        let trimmedMainCharacter = mainCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Story] Trimmed main character for prompt: '\(trimmedMainCharacter)'")

        // MODIFICATION 1: Integrate main character directly into the input text for the story LLM
        var effectiveInputText = inputText
        if !trimmedMainCharacter.isEmpty {
            effectiveInputText = "The main character of this story is \(trimmedMainCharacter).\n\n\(inputText)"
            print("[Story] Effective input text for story model will include main character: \(effectiveInputText.prefix(100))...")
        }

        // The "Main Character: \(trimmedMainCharacter)" line in storyPrompt is still useful
        // for the backend to parse for chapter image generation prompts.
        let storyPrompt = """
        [Level: \(selectedLevel.rawValue)]
        Please convert the following text into an engaging \(selectedGenre.rawValue.lowercased()) story, maintaining the key information but presenting it in a narrative format.
        Image Style to consider for tone and visuals: \(selectedImageStyle.displayName).
        \(trimmedMainCharacter.isEmpty ? "" : "Main Character: \(trimmedMainCharacter)") 
        Original Text:
        \(effectiveInputText) 
        """
        
        print("[Story] Generated story prompt for backend")
        // print("[Story] Full prompt: \(storyPrompt)") // For debugging the exact prompt
        print("[Story] Selected level: \(selectedLevel.rawValue)")
        print("[Story] Selected genre: \(selectedGenre.rawValue)")
        print("[Story] Selected image style for prompt (displayName): \(selectedImageStyle.displayName)")
        
        let requestBody: [String: Any] = [
            "text": storyPrompt,
            "level": selectedLevel.rawValue,
            "genre": selectedGenre.rawValue.lowercased(),
            // MODIFICATION 2: Use displayName for image_style to match backend's expected keys
            "image_style": selectedImageStyle.displayName 
        ]
        
        let url = URL(string: "\(backendURL)/generate_story")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[Story] Sending request to backend (/generate_story)")
        // print("[Story] URL: \(url.absoluteString)")
        // print("[Story] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to print request body")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Story] ERROR: Invalid server response (not HTTPURLResponse)")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response type"])
            }
            
            print("[Story] Received response with status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Story] ERROR: Server returned status code \(httpResponse.statusCode)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Story] Error response from server: \(errorResponse)")
                    // Try to decode a simple error message if backend sends one
                    struct BackendError: Codable { let error: String? }
                    if let decodedError = try? JSONDecoder().decode(BackendError.self, from: data), let message = decodedError.error {
                         throw NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(message) (Status \(httpResponse.statusCode))"])
                    }
                }
                throw NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
            }
            
            print("[Story] Attempting to decode response into Response.self")
            do {
                let apiResponse = try JSONDecoder().decode(Response.self, from: data)
                print("[Story] Successfully decoded Response.self")
            
                if let story = apiResponse.story {
                    print("[Story] Successfully received story object from backend.")
                    print("[Story] Story ID: \(story.id.uuidString)")
                    print("[Story] Story Title: \(story.title)")
                    print("[Story] Story Level: \(story.level.rawValue)")
                    print("[Story] Story ImageStyle: \(story.imageStyle ?? "N/A")")
                    print("[Story] Number of chapters received: \(story.chapters.count)")
                    for (idx, chap) in story.chapters.enumerated() {
                        print("[Story] - Chapter \(idx+1): ID=\(chap.id.uuidString), Title='\(chap.title)', Order=\(chap.order), ImageStyle=\(chap.imageStyle ?? "N/A")")
                    }
                    
                    await MainActor.run {
                        self.currentStory = story
                        print("[Story] Updated UI with story object")
                    }
                    
                    globalManager.updateProgress(step: "Generating images for chapters...", stepNumber: 2, totalSteps: 4)
                    
                    if let currentUser = Auth.auth().currentUser {
                        print("[Story] User authenticated (\(currentUser.uid)), proceeding with image generation and Firebase save for story ID \(story.id.uuidString)")
                        await generateImagesForStoryWithProgress(newStory: story) // This will call fetchImageForChapter, which calls /generate_image
                        // saveStoryToFirebase is called at the end of generateImagesForStory
                        
                        globalManager.updateProgress(step: "Saving to cloud...", stepNumber: 3, totalSteps: 4)
                        
                        // Show full screen view AFTER everything is saved
                        // await MainActor.run {
                        //     self.isShowingFullScreenStory = true
                        //     print("[Story] Story fully saved to Firebase, now showing full screen")
                        // }
                        
                        globalManager.updateProgress(step: "Complete!", stepNumber: 4, totalSteps: 4)
                        print("[Story] Story content and image processing completed.")
                    } else {
                        print("[Story] ERROR: No authenticated user found after receiving story. Cannot save or generate images.")
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                    }
                } else if let errorMsg = apiResponse.error { // Check our Response.error field
                    print("[Story] ERROR: Backend returned error in JSON response: \(errorMsg)")
                    throw NSError(domain: "BackendLogicError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                } else {
                    print("[Story] ERROR: Backend response did not contain a story or an error message")
                    throw NSError(domain: "BackendLogicError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend response did not contain a story or an error message"])
                }
            } catch let decodingError {
                print("[Story] ERROR: Failed to decode response into Response.self")
                print("[Story] Decoding error: \(decodingError)")
                print("[Story] Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to print response data")")
                throw decodingError
            }
        } catch { // Catch any other errors, including re-thrown decoding errors or errors from above
            print("[Story] ERROR: Unexpected error during story generation process: \(error.localizedDescription)")
            print("[Story] Error type: \(type(of: error))")
            // Ensure the errorMessage is updated on the main thread for UI
            let finalErrorMessage = error.localizedDescription
            await MainActor.run { self.errorMessage = finalErrorMessage }
            // Do not re-throw here if you want generateContent to handle isLoading = false
            // throw error // Or handle completion of isLoading within this catch
        }
    }
    
    private func generateLectureWithProgress() async throws {
        globalManager.updateProgress(step: "Generating lecture content...", stepNumber: 1, totalSteps: 3)
        
        print("[Lecture] Starting lecture generation process")
        print("[Lecture] Input text length: \(inputText.count)")
        print("[Lecture] Selected level: \(selectedLevel.rawValue)")
        print("[Lecture] Selected image style: \(selectedImageStyle.displayName)")
        
        let requestBody: [String: Any] = [
            "text": inputText,
            "level": selectedLevel.rawValue,
            "image_style": selectedImageStyle.displayName
        ]
        
        let url = URL(string: "\(backendURL)/generate_lecture")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[Lecture] Sending request to backend (/generate_lecture)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Lecture] ERROR: Invalid server response")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }
            
            print("[Lecture] Received response with status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Lecture] ERROR: Server returned status code \(httpResponse.statusCode)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Lecture] Error response from server: \(errorResponse)")
                }
                throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
            }
            
            let apiResponse = try JSONDecoder().decode(Response.self, from: data)
            
            if let lecture = apiResponse.lecture {
                print("[Lecture] Successfully received lecture from backend")
                print("[Lecture] Lecture ID: \(lecture.id.uuidString)")
                print("[Lecture] Lecture Title: \(lecture.title)")
                print("[Lecture] Number of sections: \(lecture.sections.count)")
                
                await MainActor.run {
                    self.currentLecture = lecture
                    print("[Lecture] Updated UI with lecture object")
                    globalManager.setLastGeneratedContent(type: .lecture, id: lecture.id.uuidString, title: lecture.title)
                }
                
                globalManager.updateProgress(step: "Generating audio narration...", stepNumber: 2, totalSteps: 3)
                
                if let currentUser = Auth.auth().currentUser {
                    print("[Lecture] User authenticated (\(currentUser.uid)), proceeding with audio generation and Firebase save for lecture ID \(lecture.id.uuidString)")
                    await generateAudioForLectureWithProgress(lecture: lecture)
                    
                    globalManager.updateProgress(step: "Saving to cloud...", stepNumber: 3, totalSteps: 3)
                    
                    // Show full screen view AFTER everything is saved
                    // await MainActor.run {
                    //     self.isShowingFullScreenLecture = true
                    //     print("[Lecture] Lecture fully saved to Firebase, now showing full screen")
                    // }
                    print("[Lecture] Lecture content and audio processing completed.")
                } else {
                    print("[Lecture] ERROR: No authenticated user found after receiving lecture. Cannot save or generate audio.")
                    throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }
            } else if let error = apiResponse.error {
                print("[Lecture] ERROR: Backend returned error: \(error)")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }
        } catch let error as URLError {
            print("[Lecture] Network error occurred")
            print("[Lecture] Error code: \(error.code.rawValue)")
            print("[Lecture] Error description: \(error.localizedDescription)")
            
            switch error.code {
            case .timedOut:
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."])
            case .notConnectedToInternet:
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your connection and try again."])
            default:
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
            }
        }
    }
    
    private func generateRegularContentWithProgress() async throws {
        globalManager.updateProgress(step: "Generating content...", stepNumber: 1, totalSteps: 3)
        
        print("[Content] Starting content generation")
        print("[Content] Input text length: \(inputText.count)")
        print("[Content] Selected level: \(selectedLevel.rawValue)")
        print("[Content] Selected tier: \(selectedSummarizationTier.rawValue)")
        print("[Content] Selected image style: \(selectedImageStyle.displayName)")
        
        let requestBody: [String: Any] = [
            "input_text": inputText,
            "level": selectedLevel.rawValue,
            "summarization_tier": selectedSummarizationTier.rawValue,
            "profile": [
                "studentLevel": selectedLevel.rawValue,
                "topicsOfInterest": []
            ]
        ]
        
        let url = URL(string: "\(backendURL)/process")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[Content] Sending request to backend")
        print("[Content] URL: \(url.absoluteString)")
        print("[Content] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to print request body")")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Content] ERROR: Invalid server response")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }
            
            print("[Content] Received response with status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Content] ERROR: Server returned status code \(httpResponse.statusCode)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Content] Error response from server: \(errorResponse)")
                }
                throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
            }
            
            let apiResponse = try JSONDecoder().decode(Response.self, from: data)
            
            if let blocksFromResponse = apiResponse.blocks {
                print("[Content] Received \(blocksFromResponse.count) blocks from backend")
                print("[Content] Processing blocks for image generation...")
                
                globalManager.updateProgress(step: "Generating images...", stepNumber: 2, totalSteps: 3)
                
                // Process images for blocks before saving
                var updatedBlocks = blocksFromResponse
                for (index, block) in blocksFromResponse.enumerated() {
                    if block.type == .image {
                        print("[Content] Processing image block \(index + 1)/\(blocksFromResponse.count)")
                        print("[Content] Block ID: \(block.id.uuidString)")
                        print("[Content] Block type: \(block.type.rawValue)")
                        print("[Content] Block content: \(block.content ?? "No content")")
                        print("[Content] Block alt: \(block.alt ?? "No alt text")")
                        
                        // Use alt text if content is empty
                        let imagePrompt = block.content ?? block.alt
                        
                        // Skip if both content and alt are empty
                        guard let prompt = imagePrompt, !prompt.isEmpty else {
                            print("[Content] WARNING: Both block content and alt text are empty, skipping image generation")
                            continue
                        }
                        
                        print("[Content] Generating image for block using prompt: \(prompt)")
                        if let image = await fetchImageForBlock(block: block) {
                            print("[Content] Successfully generated image for block ID: \(block.id.uuidString)")
                            print("[Content] Image size: \(image.size)")
                            
                            if let imageData = image.jpegData(compressionQuality: 0.8),
                               let userId = Auth.auth().currentUser?.uid {
                                print("[Content] Image data size: \(imageData.count) bytes")
                                
                                if imageData.count == 0 {
                                    print("[Content] ERROR: Image data is empty for block ID: \(block.id.uuidString)")
                                    continue
                                }
                                
                                do {
                                    let fileName = "content_\(block.id.uuidString).jpg"
                                    let downloadURL = try await uploadImageToFirebase(imageData: imageData, fileName: fileName, userId: userId)
                                    print("[Content] Successfully uploaded image for block ID \(block.id.uuidString) to Firebase Storage")
                                    print("[Content] Download URL: \(downloadURL.absoluteString)")
                                    
                                    updatedBlocks[index].firebaseImageUrl = downloadURL.absoluteString
                                    
                                    await MainActor.run {
                                        self.blocks = updatedBlocks
                                        print("[Content] Updated UI with new block image URL")
                                    }
                                } catch {
                                    print("[Content] ERROR uploading image for block ID \(block.id.uuidString)")
                                    print("[Content] Error type: \(type(of: error))")
                                    print("[Content] Error description: \(error.localizedDescription)")
                                    print("[Content] Full error details: \(error)")
                                }
                            } else {
                                print("[Content] ERROR: Failed to convert image to JPEG data or get user ID")
                                print("[Content] User ID available: \(Auth.auth().currentUser?.uid != nil)")
                            }
                        } else {
                            print("[Content] WARNING: Failed to generate image for block ID: \(block.id.uuidString)")
                        }
                    }
                }
                
                // Update UI with all blocks
                await MainActor.run {
                    self.blocks = updatedBlocks
                    print("[Content] Updated UI with all processed blocks")
                    if let firstBlock = updatedBlocks.first {
                        let title = extractTopicTitle(from: inputText)
                        globalManager.setLastGeneratedContent(type: .userContent, id: firstBlock.id.uuidString, title: title)
                    }
                }
                
                globalManager.updateProgress(step: "Saving to cloud...", stepNumber: 3, totalSteps: 3)
                
                // Save to Firebase if user is authenticated BEFORE showing full screen
                if let currentUser = Auth.auth().currentUser {
                    print("[Content] Saving content to Firebase for user: \(currentUser.uid)")
                    let documentId = await saveContentBlocksToFirebase(
                        topic: extractTopicTitle(from: inputText),
                        blocks: updatedBlocks,
                        level: selectedLevel,
                        summarizationTier: selectedSummarizationTier,
                        userId: currentUser.uid
                    )
                    
                    // Store the saved document ID
                    await MainActor.run {
                        self.savedContentDocumentId = documentId
                        print("[Content] Content saved to Firebase with ID: \(documentId)")
                    }
                } else {
                    print("[Content] WARNING: No authenticated user found, skipping Firebase save")
                    // Still show the content without saving
                    await MainActor.run {
                        self.isShowingFullScreenContent = false // Ensure we don't navigate
                    }
                }
            } else if let error = apiResponse.error {
                print("[Content] ERROR: Backend returned error: \(error)")
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
            }
        } catch let error as URLError {
            print("[Content] Network error occurred")
            print("[Content] Error code: \(error.code.rawValue)")
            print("[Content] Error description: \(error.localizedDescription)")
            
            switch error.code {
            case .timedOut:
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."])
            case .notConnectedToInternet:
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your connection and try again."])
            default:
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
            }
        }
    }
    
    // MARK: - Firebase Storage
    
    private func generateImagesForStoryWithProgress(newStory: Story) async {
        let imageSize = CGSize(width: 800, height: 600) // This size is for the prompt, backend controls actual generation size.
        var updatedChapters = newStory.chapters
        let maxRetries = 3
        
        print("[Story][ImageGen] Starting image generation for story: \(newStory.title)")
        print("[Story][ImageGen] Story ID: \(newStory.id.uuidString)")
        print("[Story][ImageGen] Number of chapters: \(newStory.chapters.count)")
        print("[Story][ImageGen] Backend URL: \(backendURL)")
        // print("[Story][ImageGen] Desired image prompt size guide: \(imageSize)") // Informational

        for (index, chapter) in newStory.chapters.enumerated() {
            print("[Story][ImageGen] ========================================")
            print("[Story][ImageGen] Processing chapter \(index + 1)/\(newStory.chapters.count): '\(chapter.title ?? "Untitled")' (ID: \(chapter.id.uuidString))")
            print("[Story][ImageGen] Chapter content length: \(chapter.content.count) characters")
            var retryCount = 0
            var success = false
            
            while retryCount < maxRetries && !success {
                print("[Story][ImageGen] Attempt \(retryCount + 1) of \(maxRetries) for chapter \(index + 1)")
                do {
                    // fetchImageForChapter now correctly gets image data from GCS URL
                    print("[Story][ImageGen] Calling fetchImageForChapter for chapter \(index + 1)...")
                    if let image = await fetchImageForChapter(chapter: chapter, maxSize: imageSize) {
                        print("[Story][ImageGen] ✅ Successfully fetched UIImage for chapter \(index + 1). Image size: \(image.size)")
                        
                        if let imageData = image.jpegData(compressionQuality: 0.8),
                           let userId = Auth.auth().currentUser?.uid {
                            print("[Story][ImageGen] ✅ Converted UIImage to JPEG data. Size: \(imageData.count) bytes for chapter \(index + 1). User ID: \(userId)")
                            
                            if imageData.count == 0 {
                                print("[Story][ImageGen] ❌ ERROR: Generated image data is empty for chapter \(index + 1).")
                                throw NSError(domain: "ImageProcessingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Generated image data is empty"])
                            }
                            
                            let imagePath = "stories/\(userId)/\(newStory.id.uuidString)/\(chapter.id.uuidString).jpg"
                            print("[Story][ImageGen] 📁 Preparing to upload image to Firebase Storage path: \(imagePath)")
                            
                            let metadata = StorageMetadata()
                            metadata.contentType = "image/jpeg"
                            // Using unique keys for custom metadata to avoid any potential conflicts
                            metadata.customMetadata = [
                                "storyId": newStory.id.uuidString,
                                "chapterId": chapter.id.uuidString,
                                "chapterTitle": chapter.title ?? "Untitled",
                                "uploadTimestamp": ISO8601DateFormatter().string(from: Date()) // Changed key from "uploadDate"
                            ]
                            
                            print("[Story][ImageGen] Firebase Storage Metadata for chapter \(index + 1):")
                            print("[Story][ImageGen] - ContentType: \(metadata.contentType ?? "Not set")")
                            print("[Story][ImageGen] - CustomMetadata: \(metadata.customMetadata ?? [:])")
                            
                            // Assuming firestoreService.uploadImage is the corrected version from previous steps
                            print("[Story][ImageGen] 🔄 Uploading image to Firebase Storage...")
                            let downloadURL = try await firestoreService.uploadImage(imageData, path: imagePath, metadata: metadata)
                            print("[Story][ImageGen] ✅ Successfully uploaded image for chapter \(index + 1) to Firebase Storage.")
                            print("[Story][ImageGen] 📥 Received Firebase Download URL: \(downloadURL.absoluteString)")
                            
                            updatedChapters[index].firebaseImageUrl = downloadURL.absoluteString
                            success = true
                            
                            await MainActor.run {
                                if var currentStory = self.currentStory, currentStory.chapters.indices.contains(index) {
                                    currentStory.chapters[index].firebaseImageUrl = downloadURL.absoluteString
                                    self.currentStory = currentStory // Update the published property
                                    print("[Story][ImageGen] ✅ UI updated with new firebaseImageUrl for chapter \(index + 1).")
                                } else {
                                    print("[Story][ImageGen] ⚠️ Warning: Could not update currentStory in UI for chapter \(index + 1) image URL (story or chapter index mismatch).")
                                }
                            }
                        } else {
                            let reason = Auth.auth().currentUser?.uid == nil ? "User ID is nil." : "Failed to convert UIImage to JPEG data."
                            print("[Story][ImageGen] ❌ ERROR: \(reason) for chapter \(index + 1).")
                            throw NSError(domain: "ImageProcessingError", code: 2, userInfo: [NSLocalizedDescriptionKey: reason])
                        }
                    } else {
                        print("[Story][ImageGen] ❌ ERROR: fetchImageForChapter returned nil (failed to generate/download image) for chapter \(index + 1).")
                        throw NSError(domain: "ImageFetchingError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to generate or download image for chapter."])
                    }
                } catch {
                    retryCount += 1
                    print("[Story][ImageGen] ❌ ERROR during attempt \(retryCount) for chapter \(index + 1): \(error.localizedDescription)")
                    print("[Story][ImageGen] Error Type: \(type(of: error))")
                    print("[Story][ImageGen] Full Error: \(error)")
                    
                    if retryCount >= maxRetries {
                        let errorMessageText = "Failed to process image for chapter '\(chapter.title ?? "Untitled")' (ID: \(chapter.id.uuidString)) after \(maxRetries) attempts: \(error.localizedDescription)"
                        print("[Story][ImageGen] 🚨 FINAL ERROR: \(errorMessageText)")
                        // Optionally update UI with this specific error
                        // await MainActor.run { self.errorMessage = errorMessageText }
                    } else {
                        print("[Story][ImageGen] 🔄 Retrying in \(retryCount * 2) seconds...") // Increased retry delay
                        try? await Task.sleep(nanoseconds: UInt64(2_000_000_000 * retryCount))
                    }
                }
            }
            if !success {
                 print("[Story][ImageGen] ⚠️ WARNING: Failed to process image for chapter \(index + 1) ('\(chapter.title ?? "Untitled")') after all retries. It will not have an image.")
            } else {
                print("[Story][ImageGen] ✅ SUCCESS: Chapter \(index + 1) image processed successfully!")
            }
            print("[Story][ImageGen] ========================================")
        }
        
        // Ensure the story being saved has the updated chapter image URLs
        var finalStoryToSave = newStory // Start with original story structure
        finalStoryToSave.chapters = updatedChapters // Assign chapters that have firebaseImageUrls (or nil if failed)
        
        print("[Story][ImageGen] 📊 Final image generation summary:")
        for (index, chapter) in finalStoryToSave.chapters.enumerated() {
            print("[Story][ImageGen] - Chapter \(index + 1): \(chapter.firebaseImageUrl != nil ? "✅ Has image" : "❌ No image")")
        }
        
        await MainActor.run {
            self.currentStory = finalStoryToSave // Update UI with the story containing all attempted image URLs
            print("[Story][ImageGen] ✅ Image generation process for all chapters completed. UI updated with final story.")
            globalManager.setLastGeneratedContent(type: .story, id: finalStoryToSave.id.uuidString, title: finalStoryToSave.title)
        }
        
        if let userId = Auth.auth().currentUser?.uid {
            print("[Story][Save] 🔄 Proceeding to save story with updated chapter image URLs to Firebase for user \(userId).")
            await saveStoryToFirebase(story: finalStoryToSave, userId: userId)
        } else {
            print("[Story][Save] ❌ ERROR: No authenticated user found. Cannot save story to Firebase.")
            // Update UI with an appropriate error message
            await MainActor.run {
                self.errorMessage = "User not authenticated. Story could not be saved."
            }
        }
    }
    
    private func saveStoryToFirebase(story: Story, userId: String) async {
        print("[Story][Save] Starting Firebase save process for story")
        print("[Story][Save] Story ID: \(story.id.uuidString)")
        print("[Story][Save] User ID: \(userId)")
        print("[Story][Save] Number of chapters: \(story.chapters.count)")
        
        // Log chapter details before conversion
        print("[Story][Save] 📋 Chapter details before Firebase conversion:")
        for (index, chapter) in story.chapters.enumerated() {
            print("[Story][Save] - Chapter \(index + 1):")
            print("[Story][Save]   - ID: \(chapter.id.uuidString)")
            print("[Story][Save]   - Title: \(chapter.title ?? "N/A")")
            print("[Story][Save]   - Order: \(chapter.order)")
            print("[Story][Save]   - firebaseImageUrl: \(chapter.firebaseImageUrl ?? "NIL")")
            print("[Story][Save]   - imageStyle: \(chapter.imageStyle ?? "N/A")")
        }
        
        // Convert to Firebase format using the correct models
        let firebaseStory = FirebaseStory(
            id: story.id.uuidString,
            userId: userId,
            title: story.title,
            overview: story.content,
            level: story.level.rawValue,
            imageStyle: story.imageStyle,
            chapters: story.chapters.map { chapter in
                FirebaseChapter(
                    chapterId: chapter.id.uuidString,
                    title: chapter.title,
                    content: chapter.content,
                    order: chapter.order,
                    firebaseImageUrl: chapter.firebaseImageUrl,
                    imageStyle: chapter.imageStyle
                )
            }
        )
        
        // Log Firebase story details
        print("[Story][Save] 📋 Firebase story details:")
        print("[Story][Save] - ID: \(firebaseStory.id ?? "NIL")")
        print("[Story][Save] - Title: \(firebaseStory.title)")
        print("[Story][Save] - User ID: \(firebaseStory.userId)")
        print("[Story][Save] - Level: \(firebaseStory.level)")
        print("[Story][Save] - Image Style: \(firebaseStory.imageStyle ?? "N/A")")
        print("[Story][Save] - Number of chapters: \(firebaseStory.chapters?.count ?? 0)")
        
        if let chapters = firebaseStory.chapters {
            print("[Story][Save] 📋 Firebase chapter details:")
            for (index, chapter) in chapters.enumerated() {
                print("[Story][Save] - Chapter \(index + 1):")
                print("[Story][Save]   - chapterId: \(chapter.chapterId)")
                print("[Story][Save]   - title: \(chapter.title ?? "N/A")")
                print("[Story][Save]   - order: \(chapter.order ?? -1)")
                print("[Story][Save]   - firebaseImageUrl: \(chapter.firebaseImageUrl ?? "NIL")")
                print("[Story][Save]   - imageStyle: \(chapter.imageStyle ?? "N/A")")
            }
        }
        
        do {
            print("[Story][Save] 🔄 Attempting to create story document in Firestore. Collection: 'stories', DocumentID to be used by service: \(story.id.uuidString)")
            let documentId = try await firestoreService.create(firebaseStory, in: "stories", documentId: story.id.uuidString)
            print("[Story][Save] ✅ Successfully saved story to Firestore with document ID: \(documentId)")
            
            // Track story generation for dashboard engagement metrics
            await MainActor.run {
                let currentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
                UserDefaults.standard.set(currentCount + 1, forKey: "contentGenerationCount")
                print("[Engagement] Story generation tracked. Total: \(currentCount + 1)")
            }
            
            // Send success notification
            await NotificationManager.shared.sendContentGenerationSuccess(contentType: "story", level: story.level.rawValue)
            
        } catch {
            print("[Story][Save] ❌ ERROR: Failed to save story to Firestore for story ID \(story.id.uuidString).")
            print("[Story][Save] Error Type: \(type(of: error))")
            print("[Story][Save] Error Description: \(error.localizedDescription)")
            print("[Story][Save] Full Error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to save story to cloud: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveLectureToFirebase(_ lecture: Lecture, audioFiles: [BackendAudioFile], userId: String) async {
        print("[Lecture][Save] Starting Firebase save process for lecture")
        print("[Lecture][Save] Lecture ID: \(lecture.id.uuidString)")
        print("[Lecture][Save] User ID: \(userId)")
        
        // Convert to Firebase format using the correct models
        let firebaseLecture = FirebaseLecture(
            id: lecture.id.uuidString,
            userId: userId,
            title: lecture.title,
            level: lecture.level.rawValue,
            imageStyle: lecture.imageStyle ?? "default",
            sections: lecture.sections.map { section in
                FirebaseLectureSection(
                    sectionId: section.id.uuidString,
                    title: section.title,
                    script: section.script,
                    imagePrompt: section.imagePrompt,
                    imageUrl: section.imageUrl,
                    order: section.order
                )
            },
            audioFiles: audioFiles.map { audio in
                FirebaseAudioFile(
                    type: audio.type,
                    text: audio.text,
                    url: audio.url,
                    filename: audio.filename,
                    section: audio.section
                )
            }
        )
        
        do {
            print("[Lecture][Save] Attempting to create lecture document in Firestore. Collection: 'lectures', DocumentID to be used by service: \(lecture.id.uuidString)")
            let documentId = try await firestoreService.create(firebaseLecture, in: "lectures", documentId: lecture.id.uuidString)
            print("[Lecture][Save] Successfully saved lecture to Firestore with document ID: \(documentId)")
            await MainActor.run {
                let currentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
                UserDefaults.standard.set(currentCount + 1, forKey: "contentGenerationCount")
                print("[Engagement] Lecture generation tracked. Total: \(currentCount + 1)")
            }
            
            // Send success notification
            await NotificationManager.shared.sendContentGenerationSuccess(contentType: "lecture", level: lecture.level.rawValue)
            
        } catch {
            print("[Lecture][Save] ERROR: Failed to save lecture to Firestore for lecture ID \(lecture.id.uuidString).")
            print("[Lecture][Save] Error Type: \(type(of: error))")
            print("[Lecture][Save] Error Description: \(error.localizedDescription)")
            print("[Lecture][Save] Full Error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to save lecture to cloud: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveContentBlocksToFirebase(topic: String, blocks: [ContentBlock], level: ReadingLevel, summarizationTier: SummarizationTier, userId: String) async -> String {
        print("[Content][Save] Starting Firebase save process for content")
        print("[Content][Save] Topic: \(topic)")
        print("[Content][Save] Number of blocks: \(blocks.count)")
        print("[Content][Save] User ID: \(userId)")
        print("[Content][Save] Level: \(level.rawValue), Tier: \(summarizationTier.rawValue)")

        let firebaseContent = FirebaseUserContent(
            id: nil, // Let Firestore generate the ID
            userId: userId,
            topic: topic,
            level: level.rawValue,
            summarizationTier: summarizationTier.rawValue,
            blocks: blocks.map { block -> FirebaseContentBlock in
                print("[Content][Save] Mapping block ID \(block.id.uuidString) for Firestore. Type: \(block.type.rawValue)")
                print("[Content][Save] - FirebaseImageUrl: \(block.firebaseImageUrl ?? "N/A")")
                return FirebaseContentBlock(
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
            }
        )
        
        do {
            print("[Content][Save] Attempting to create content document in Firestore. Collection: 'userGeneratedContent'")
            let documentId = try await firestoreService.create(firebaseContent, in: "userGeneratedContent")
            print("[Content][Save] Successfully saved content to Firestore with document ID: \(documentId)")
            
            // Track content generation for dashboard engagement metrics
            await MainActor.run {
                let currentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
                UserDefaults.standard.set(currentCount + 1, forKey: "contentGenerationCount")
                print("[Engagement] Content generation tracked. Total: \(currentCount + 1)")
            }
            
            // Send success notification
            await NotificationManager.shared.sendContentGenerationSuccess(contentType: summarizationTier.rawValue, level: level.rawValue)
            
            return documentId
        } catch {
            print("[Content][Save] ERROR: Failed to save content to Firestore")
            print("[Content][Save] Error Type: \(type(of: error))")
            print("[Content][Save] Error Description: \(error.localizedDescription)")
            print("[Content][Save] Full Error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to save content to cloud: \(error.localizedDescription)"
            }
            return ""
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchImageForChapter(chapter: StoryChapter, maxSize: CGSize) async -> UIImage? {
        print("[Image] Generating image for chapter: \(chapter.title)")
        print("[Image] Chapter content: \(chapter.content.prefix(100))...")
        
        // Create image prompt from chapter content
        let imagePrompt = chapter.content
        print("[Image] Using image prompt: \(imagePrompt.prefix(100))...")
        
        // Call the backend image generation API
        let requestBody: [String: Any] = [
            "prompt": imagePrompt,
            "style": selectedImageStyle.displayName,
            "size": "800x600"
        ]
        
        print("[Image] Request body for image generation:")
        print("[Image] - prompt: \(imagePrompt.prefix(50))...")
        print("[Image] - style: \(selectedImageStyle.displayName)")
        print("[Image] - size: 800x600")
        
        let url = URL(string: "\(backendURL)/generate_image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("[Image] Sending image generation request to backend")
            print("[Image] URL: \(url.absoluteString)")
            print("[Image] Request body JSON: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to print request body")")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Image] ERROR: Invalid server response")
                return nil
            }
            
            print("[Image] Received response with status code: \(httpResponse.statusCode)")
            print("[Image] Response headers: \(httpResponse.allHeaderFields)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Image] ERROR: Server returned status code \(httpResponse.statusCode)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Image] Error response from server: \(errorResponse)")
                }
                return nil
            }
            
            print("[Image] Response data received: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[Image] Response content: \(responseString)")
            } else {
                print("[Image] WARNING: Could not decode response as UTF-8 string")
                print("[Image] Raw data (first 100 bytes): \(data.prefix(100).map { String(format: "%02x", $0) }.joined())")
            }
            
            // Parse the response to get the image URL
            let imageResponse: ImageGenerationResponse
            do {
                imageResponse = try JSONDecoder().decode(ImageGenerationResponse.self, from: data)
                print("[Image] Successfully decoded ImageGenerationResponse")
                print("[Image] - url: \(imageResponse.url ?? "nil")")
                print("[Image] - image_url: \(imageResponse.image_url ?? "nil")")
                print("[Image] - imageUrl (computed): \(imageResponse.imageUrl ?? "nil")")
                print("[Image] - error: \(imageResponse.error ?? "nil")")
            } catch {
                print("[Image] ERROR: Failed to decode ImageGenerationResponse")
                print("[Image] Decoding error: \(error)")
                print("[Image] Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to print response data")")
                return nil
            }
            
            if let imageUrlString = imageResponse.imageUrl, let imageUrl = URL(string: imageUrlString) {
                print("[Image] Successfully generated image URL: \(imageUrlString)")
                
                // Download the image
                print("[Image] Downloading image from: \(imageUrl.absoluteString)")
                let (imageData, imageResponse) = try await session.data(from: imageUrl)
                
                guard let httpImageResponse = imageResponse as? HTTPURLResponse,
                      httpImageResponse.statusCode == 200 else {
                    print("[Image] ERROR: Failed to download image")
                    print("[Image] Image response status: \((imageResponse as? HTTPURLResponse)?.statusCode ?? -1)")
                    return nil
                }
                
                print("[Image] Successfully downloaded image data: \(imageData.count) bytes")
                
                guard let image = UIImage(data: imageData) else {
                    print("[Image] ERROR: Failed to create UIImage from data")
                    return nil
                }
                
                print("[Image] Successfully downloaded and created image. Size: \(image.size)")
                return image
            } else {
                print("[Image] ERROR: No image URL in response")
                if let error = imageResponse.error {
                    print("[Image] Backend error: \(error)")
                }
                print("[Image] Full response object: \(imageResponse)")
                return nil
            }
            
        } catch {
            print("[Image] ERROR: Failed to generate image: \(error.localizedDescription)")
            print("[Image] Error type: \(type(of: error))")
            print("[Image] Full error: \(error)")
            return nil
        }
    }
    
    private func fetchImageForBlock(block: ContentBlock) async -> UIImage? {
        print("[Image] Generating image for block ID: \(block.id.uuidString)")
        
        // Use alt text if content is empty
        let imagePrompt = block.content ?? block.alt ?? "A beautiful illustration"
        print("[Image] Using image prompt: \(imagePrompt)")
        
        // Call the backend image generation API
        let requestBody: [String: Any] = [
            "prompt": imagePrompt,
            "style": selectedImageStyle.displayName,
            "size": "800x600"
        ]
        
        let url = URL(string: "\(backendURL)/generate_image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("[Image] Sending image generation request to backend")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Image] ERROR: Invalid server response")
                return nil
            }
            
            print("[Image] Received response with status code: \(httpResponse.statusCode)")
            print("[Image] Response headers: \(httpResponse.allHeaderFields)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Image] ERROR: Server returned status code \(httpResponse.statusCode)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Image] Error response from server: \(errorResponse)")
                }
                return nil
            }
            
            print("[Image] Response data received: \(data.count) bytes")
            if let responseString = String(data: data, encoding: .utf8) {
                print("[Image] Response content: \(responseString)")
            } else {
                print("[Image] WARNING: Could not decode response as UTF-8 string")
                print("[Image] Raw data (first 100 bytes): \(data.prefix(100).map { String(format: "%02x", $0) }.joined())")
            }
            
            // Parse the response to get the image URL
            let imageResponse: ImageGenerationResponse
            do {
                imageResponse = try JSONDecoder().decode(ImageGenerationResponse.self, from: data)
                print("[Image] Successfully decoded ImageGenerationResponse")
                print("[Image] - url: \(imageResponse.url ?? "nil")")
                print("[Image] - image_url: \(imageResponse.image_url ?? "nil")")
                print("[Image] - imageUrl (computed): \(imageResponse.imageUrl ?? "nil")")
                print("[Image] - error: \(imageResponse.error ?? "nil")")
            } catch {
                print("[Image] ERROR: Failed to decode ImageGenerationResponse")
                print("[Image] Decoding error: \(error)")
                print("[Image] Raw response data: \(String(data: data, encoding: .utf8) ?? "Unable to print response data")")
                return nil
            }
            
            if let imageUrlString = imageResponse.imageUrl, let imageUrl = URL(string: imageUrlString) {
                print("[Image] Successfully generated image URL: \(imageUrlString)")
                
                // Download the image
                let (imageData, imageResponse) = try await session.data(from: imageUrl)
                
                guard let httpImageResponse = imageResponse as? HTTPURLResponse,
                      httpImageResponse.statusCode == 200 else {
                    print("[Image] ERROR: Failed to download image")
                    return nil
                }
                
                guard let image = UIImage(data: imageData) else {
                    print("[Image] ERROR: Failed to create UIImage from data")
                    return nil
                }
                
                print("[Image] Successfully downloaded and created image. Size: \(image.size)")
                return image
            } else {
                print("[Image] ERROR: No image URL in response")
                return nil
            }
            
        } catch {
            print("[Image] ERROR: Failed to generate image: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractTopicTitle(from text: String) -> String {
        let firstLine = text.split(separator: "\n").first ?? ""
        return String(firstLine.prefix(50))
    }
    
    /// Fetches the number of content generations (stories + userGeneratedContent + lectures) for the user today.
    private func fetchTodayGenerationCount(userId: String) async -> Int {
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
        let startTimestamp = Timestamp(date: startOfDay)
        let endTimestamp = Timestamp(date: endOfDay)
        var total = 0
        
        // Count stories
        do {
            let storiesQuery = db.collection("stories")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: startTimestamp)
                .whereField("createdAt", isLessThanOrEqualTo: endTimestamp)
            let storiesSnapshot = try await storiesQuery.getDocuments()
            total += storiesSnapshot.documents.count
        } catch {
            print("[DailyLimit] Error fetching stories count: \(error)")
        }
        
        // Count user generated content
        do {
            let contentQuery = db.collection("userGeneratedContent")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: startTimestamp)
                .whereField("createdAt", isLessThanOrEqualTo: endTimestamp)
            let contentSnapshot = try await contentQuery.getDocuments()
            total += contentSnapshot.documents.count
        } catch {
            print("[DailyLimit] Error fetching content count: \(error)")
        }
        
        // Count lectures
        do {
            let lecturesQuery = db.collection("lectures")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: startTimestamp)
                .whereField("createdAt", isLessThanOrEqualTo: endTimestamp)
            let lecturesSnapshot = try await lecturesQuery.getDocuments()
            total += lecturesSnapshot.documents.count
        } catch {
            print("[DailyLimit] Error fetching lectures count: \(error)")
        }
        
        return total
    }

    /// Public method to refresh the daily generation count (call onAppear in the view)
    @MainActor
    func refreshTodayGenerationCount() async {
        if let userId = Auth.auth().currentUser?.uid {
            let count = await fetchTodayGenerationCount(userId: userId)
            self.todayGenerationCount = count
        }
    }
    
    // MARK: - Simulator Notification Test
    func testSimulatorNotifications() async {
        print("[Notifications] 📱 Testing simulator notifications...")
        await NotificationManager.shared.sendTestNotification()
    }
    
    // MARK: - Notification Settings Management
    // All notification functionality is now handled automatically by NotificationManager
    // No manual notification methods needed
    
    // MARK: - URLSessionDelegate Methods
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskId = dataTask.taskIdentifier
        if backgroundTaskData[taskId] != nil {
            backgroundTaskData[taskId]?.append(data)
        } else {
            backgroundTaskData[taskId] = data
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskId = task.taskIdentifier
        defer { backgroundTaskData.removeValue(forKey: taskId) }
        if let error = error {
            DispatchQueue.main.async {
                self.errorMessage = "Background content generation failed: \(error.localizedDescription)"
                self.isLoading = false
            }
            return
        }
        guard let data = backgroundTaskData[taskId], let response = (task as? URLSessionDataTask)?.response as? HTTPURLResponse else {
            DispatchQueue.main.async {
                self.errorMessage = "Background content generation failed: No data or response."
                self.isLoading = false
            }
            return
        }
        guard response.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown server error"
            DispatchQueue.main.async {
                self.errorMessage = "Server error (background): \(response.statusCode) - \(errorMsg)"
                self.isLoading = false
            }
            return
        }
        // Try to decode as Response (story, lecture, or blocks)
        if let decoded = try? JSONDecoder().decode(Response.self, from: data) {
            DispatchQueue.main.async {
                if let story = decoded.story {
                    self.currentStory = story
                    self.statusMessage = "Background story generation completed."
                    self.sendBackgroundCompletionNotification(type: "Story")
                } else if let lecture = decoded.lecture {
                    self.currentLecture = lecture
                    self.statusMessage = "Background lecture generation completed."
                    self.sendBackgroundCompletionNotification(type: "Lecture")
                } else if let blocks = decoded.blocks {
                    self.blocks = blocks
                    self.statusMessage = "Background content generation completed."
                    self.sendBackgroundCompletionNotification(type: "Content")
                } else if let error = decoded.error {
                    self.errorMessage = "Background generation error: \(error)"
                } else {
                    self.statusMessage = "Background generation completed (no content)."
                }
                self.isLoading = false
            }
        } else {
            let raw = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
            DispatchQueue.main.async {
                self.errorMessage = "Failed to decode background response: \(raw)"
                self.isLoading = false
            }
        }
    }
    
    // Local notification for background completion
    private func sendBackgroundCompletionNotification(type: String) {
        let content = UNMutableNotificationContent()
        content.title = "Liroo: \(type) Generation Complete"
        content.body = "Your \(type.lowercased()) is ready!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // MARK: - Background lecture generation method using uploadTask
    func generateLectureWithProgressInBackground() {
        globalManager.updateProgress(step: "Generating lecture content... (background)", stepNumber: 1, totalSteps: 3)
        let requestBody: [String: Any] = [
            "text": inputText,
            "level": selectedLevel.rawValue,
            "image_style": selectedImageStyle.displayName
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: requestBody) else {
            DispatchQueue.main.async { self.errorMessage = "Failed to encode request body." }
            return
        }
        let fileName = "lecture_upload_\(UUID().uuidString).json"
        guard let fileURL = try? writeDataToTempFile(data, fileName: fileName) else {
            DispatchQueue.main.async { self.errorMessage = "Failed to write request body to file." }
            return
        }
        let url = URL(string: "\(backendURL)/generate_lecture")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        task.resume()
    }

    // MARK: - Background regular content generation method using uploadTask
    func generateRegularContentWithProgressInBackground() {
        globalManager.updateProgress(step: "Generating content... (background)", stepNumber: 1, totalSteps: 3)
        let requestBody: [String: Any] = [
            "input_text": inputText,
            "level": selectedLevel.rawValue,
            "summarization_tier": selectedSummarizationTier.rawValue,
            "profile": [
                "studentLevel": selectedLevel.rawValue,
                "topicsOfInterest": []
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: requestBody) else {
            DispatchQueue.main.async { self.errorMessage = "Failed to encode request body." }
            return
        }
        let fileName = "content_upload_\(UUID().uuidString).json"
        guard let fileURL = try? writeDataToTempFile(data, fileName: fileName) else {
            DispatchQueue.main.async { self.errorMessage = "Failed to write request body to file." }
            return
        }
        let url = URL(string: "\(backendURL)/process")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        task.resume()
    }

    // Helper to write Data to a temp file and return the URL
    private func writeDataToTempFile(_ data: Data, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - Supporting Types

enum ReadingLevel: String, Codable, CaseIterable {
    case kid = "Kid"
    case preTeen = "PreTeen"
    case teen = "Teen"
    case university = "University"
    case standard = "Standard"
}

enum SummarizationTier: String, Codable, CaseIterable {
    case keyTakeaways = "Key Takeaways"
    case quickSummary = "Quick Summary"
    case detailedExplanation = "Detailed Explanation"
    case story = "Story"
    case lecture = "Lecture"
}

enum StoryGenre: String, Codable, CaseIterable {
    case adventure = "Adventure"
    case fantasy = "Fantasy"
    case mystery = "Mystery"
    case scienceFiction = "Science Fiction"
    case historical = "Historical"
    case educational = "Educational"
}

enum ImageStyle: String, Codable, CaseIterable {
    case ghibli = "ghibli"
    case disney = "disney"
    case comicBook = "comic_book"
    case watercolor = "watercolor"
    case pixelArt = "pixel_art"
    case threeDRender = "3d_render"
    
    var displayName: String {
        switch self {
        case .ghibli: return "Studio Ghibli"
        case .disney: return "Disney"
        case .comicBook: return "Comic Book"
        case .watercolor: return "Watercolor"
        case .pixelArt: return "Pixel Art"
        case .threeDRender: return "3D Render"
        }
    }
    
    var backendRawValue: String {
        rawValue
    }
}

struct Response: Codable {
    let story: Story?
    let lecture: Lecture?
    let blocks: [ContentBlock]?
    let error: String?
}

// MARK: - Lecture Response Models
struct LectureResponse: Codable {
    let lecture: BackendLecture?
    let audio_files: [BackendAudioFile]?
    let lecture_id: String
    let error: String?
}

struct BackendLecture: Codable {
    let title: String
    let sections: [BackendLectureSection]
}

struct BackendLectureSection: Codable {
    let title: String
    let script: String
    let image_prompt: String
    let image_url: String?
}

struct BackendAudioFile: Codable {
    let type: String
    let text: String
    let url: String
    let filename: String
    let section: Int?
}

struct Story: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let content: String // This is the overview/summary of the story
    let level: ReadingLevel
    var chapters: [StoryChapter]
    let imageStyle: String? // Overall story image style, hint from backend

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case level
        case chapters
        case imageStyle // Ensure this matches the JSON key from the backend if it sends one for the story's overall style
    }

    // Standard initializer if needed elsewhere
    init(id: UUID, title: String, content: String, level: ReadingLevel, chapters: [StoryChapter], imageStyle: String?) {
        self.id = id
        self.title = title
        self.content = content
        self.level = level
        self.chapters = chapters
        self.imageStyle = imageStyle
    }

    // Custom decoder to handle potentially missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Attempt to decode 'id' as String, then convert to UUID; generate if missing/invalid
        if let idString = try container.decodeIfPresent(String.self, forKey: .id),
           let parsedUUID = UUID(uuidString: idString) {
            self.id = parsedUUID
        } else {
            print("[Story.decoder] Warning: Story 'id' missing or invalid in JSON. Generating new client-side UUID.")
            self.id = UUID() // Generate a new UUID if not present or invalid
        }
        
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Story"
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? "No overview provided."
        
        // For 'level', if it can be missing or invalid, it's more complex.
        // Assuming the backend IS sending 'level' as a valid string for ReadingLevel.rawValue.
        // If 'level' itself is the "missing data", this line will fail.
        // To make it more robust if 'level' can be missing:
        // self.level = (try? container.decodeIfPresent(ReadingLevel.self, forKey: .level)) ?? .standard
        // For now, keeping it as a direct decode, assuming backend provides it.
        // The error "data couldn't be read because it is missing" might point to this if 'level' key is absent.
        do {
            self.level = try container.decode(ReadingLevel.self, forKey: .level)
        } catch {
            print("[Story.decoder] Warning: Story 'level' missing or invalid in JSON. Defaulting to .standard. Error: \(error)")
            self.level = .standard // Default if level is missing or unparsable
        }

        self.chapters = try container.decodeIfPresent([StoryChapter].self, forKey: .chapters) ?? []
        self.imageStyle = try container.decodeIfPresent(String.self, forKey: .imageStyle)
    }
}

struct StoryChapter: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    var firebaseImageUrl: String? // This will be populated client-side after Firebase upload
    let imageStyle: String?      // Image style hint for this chapter from backend (if provided)
    let imageUrl: String?        // Direct GCS URL that the Python backend adds

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case order
        case imageStyle // Expected key from AI if it provides a style per chapter
        case imageUrl   // Key for the GCS URL added by Python backend
        // `firebaseImageUrl` is not decoded from this JSON
    }

    // Standard initializer if needed
    init(id: UUID, title: String, content: String, order: Int, firebaseImageUrl: String? = nil, imageStyle: String?, imageUrl: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.firebaseImageUrl = firebaseImageUrl
        self.imageStyle = imageStyle
        self.imageUrl = imageUrl
    }

    // Custom decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let idString = try container.decodeIfPresent(String.self, forKey: .id),
           let parsedUUID = UUID(uuidString: idString) {
            self.id = parsedUUID
        } else {
            print("[StoryChapter.decoder] Warning: Chapter 'id' missing or invalid in JSON. Generating new client-side UUID.")
            self.id = UUID() // Generate a new UUID if not present or invalid
        }
        
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Chapter"
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? "No content for this chapter."
        self.order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0 // Default order if missing
        
        self.imageStyle = try container.decodeIfPresent(String.self, forKey: .imageStyle)
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) // Catches the GCS URL
        
        // firebaseImageUrl is not set during this initial decoding from backend
        self.firebaseImageUrl = nil
    }
}

struct ContentBlock: Identifiable, Codable {
    let id: UUID
    let type: BlockType
    let content: String?
    let alt: String?
    var firebaseImageUrl: String?
    let options: [QuizOption]?
    let correctAnswerID: String?
    let explanation: String?
}

enum BlockType: String, Codable {
    case heading
    case paragraph
    case image
    case quizHeading
    case multipleChoiceQuestion
    case error
}

struct QuizOption: Identifiable, Codable {
    let id: String
    let text: String
}

// MARK: - Generation Parameters Struct
struct GenerationParameters: Codable {
    let inputText: String
    let selectedLevel: ReadingLevel
    let selectedSummarizationTier: SummarizationTier
    let selectedGenre: StoryGenre
    let mainCharacter: String
    let selectedImageStyle: ImageStyle
}

// MARK: - Image Generation Response
struct ImageGenerationResponse: Codable {
    let url: String?
    let image_url: String?
    let error: String?
    
    // Computed property to handle both field names
    var imageUrl: String? {
        return url ?? image_url
    }
}

// MARK: - Missing Helper Methods
extension ContentGenerationViewModel {
    
    private func generateAudioForLectureWithProgress(lecture: Lecture) async {
        // This would contain the audio generation logic
        // For now, we'll just simulate the process
        print("[Lecture][Audio] Starting audio generation for lecture: \(lecture.title)")
        
        // Simulate audio generation time
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Save lecture to Firebase
        await saveLectureToFirebase(lecture, audioFiles: [], userId: Auth.auth().currentUser?.uid ?? "")
    }
    
    private func uploadImageToFirebase(imageData: Data, fileName: String, userId: String) async throws -> URL {
        let imagePath = "content/\(userId)/\(fileName)"
        print("[Firebase] Uploading image to path: \(imagePath)")
        
        // Add metadata for better organization
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "uploadDate": ISO8601DateFormatter().string(from: Date())
        ]
        
        print("[Firebase] Image metadata:")
        print("[Firebase] - Content type: \(metadata.contentType ?? "Not specified")")
        print("[Firebase] - Custom metadata: \(metadata.customMetadata ?? [:])")
        
        let downloadURL = try await firestoreService.uploadImage(imageData, path: imagePath, metadata: metadata)
        print("[Firebase] Successfully uploaded image")
        return downloadURL
    }
} 
