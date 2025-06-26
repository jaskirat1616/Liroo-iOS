import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
class ContentGenerationViewModel: ObservableObject {
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
    @Published var todayGenerationCount: Int = 0
    
    private let firestoreService = FirestoreService.shared
    private let backendURL = "https://backend-orasync-test.onrender.com"
    
    // Add custom URLSession configuration
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120  // 2 minutes timeout for request
        config.timeoutIntervalForResource = 600  // 10 minutes timeout for resource
        return URLSession(configuration: config)
    }()
    
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
            if todayCount >= 8 {
                errorMessage = "You have reached your daily generation limit (8 per day). Please try again tomorrow."
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if selectedSummarizationTier == .story {
                try await generateStory()
            } else if selectedSummarizationTier == .lecture {
                try await generateLecture()
            } else {
                try await generateRegularContent()
            }
            // Refresh count after successful generation
            await refreshTodayGenerationCount()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func generateStory() async throws {
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

                    // Create a new story with a unique ID (the one from backend IS the unique ID)
                    // The 'id' in the Swift Story struct should be decoded directly from the backend JSON.
                    let newStory = Story(
                        id: story.id, // Use the ID from the decoded story
                        title: story.title,
                        content: story.content,
                        level: story.level,
                        chapters: story.chapters,
                        imageStyle: story.imageStyle
                    )
                    
                    await MainActor.run {
                        self.currentStory = newStory
                        self.blocks = [] // Clear regular content blocks
                        self.isShowingFullScreenStory = true
                        print("[Story] UI updated: currentStory set, isShowingFullScreenStory = true")
                    }
                    
                    if let currentUser = Auth.auth().currentUser {
                        print("[Story] User authenticated (\(currentUser.uid)), proceeding with image generation and Firebase save for story ID \(newStory.id.uuidString)")
                        await generateImagesForStory(newStory) // This will call fetchImageForChapter, which calls /generate_image
                        // saveStoryToFirebase is called at the end of generateImagesForStory
                        print("[Story] Story content and image processing initiated.")
                    } else {
                        print("[Story] ERROR: No authenticated user found after receiving story. Cannot save or generate images.")
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                    }
                } else if let errorMsg = apiResponse.error { // Check our Response.error field
                    print("[Story] ERROR: Backend returned error in JSON response: \(errorMsg)")
                    throw NSError(domain: "BackendLogicError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                } else {
                    print("[Story] ERROR: No story or error field in decoded JSON response.")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("[Story] Raw JSON that led to this (first 500 chars): \(jsonString.prefix(500))")
                    }
                    throw NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response structure from server (no story or error)."])
                }

            } catch let decodingError as DecodingError {
                print("[Story] DECODING ERROR: Failed to decode story response from backend.")
                print("[Story] DecodingError: \(decodingError.localizedDescription)")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("[Story] TypeMismatch: Expected type '\(type)' but found different type. Context: \(context.debugDescription)")
                    print("[Story] CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let value, let context):
                    print("[Story] ValueNotFound: Expected value of type '\(value)' not found. Context: \(context.debugDescription)")
                    print("[Story] CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .keyNotFound(let key, let context):
                    print("[Story] KeyNotFound: Key '\(key.stringValue)' not found. Context: \(context.debugDescription)")
                    print("[Story] CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("[Story] DataCorrupted: Data is corrupted. Context: \(context.debugDescription)")
                    print("[Story] CodingPath: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("[Story] Unknown DecodingError occurred.")
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[Story] Raw JSON response string that failed to decode (first 1000 chars): \(jsonString.prefix(1000))")
                }
                throw decodingError // Re-throw to be caught by the outer catch
            }
            // Other non-decoding errors specific to this block would be caught here
            
        } catch let urlError as URLError {
            print("[Story] Network URLError occurred: \(urlError.localizedDescription)")
            print("[Story] Error code: \(urlError.code.rawValue)")
            let specificMessage: String
            switch urlError.code {
            case .timedOut: specificMessage = "Request timed out. Please try again."
            case .notConnectedToInternet: specificMessage = "No internet connection. Please check your connection and try again."
            case .cannotConnectToHost, .networkConnectionLost: specificMessage = "Could not connect to the server. Please try again later."
            default: specificMessage = "Network error: \(urlError.localizedDescription)"
            }
            throw NSError(domain: "NetworkError.URL", code: urlError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: specificMessage])
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
    
    private func generateLecture() async throws {
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
                print("[Lecture] ERROR: Invalid server response (not HTTPURLResponse)")
                throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response type"])
            }
            
            print("[Lecture] Received response with status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Lecture] ERROR: Server returned status code \(httpResponse.statusCode)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Lecture] Error response from server: \(errorResponse)")
                }
                throw NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
            }
            
            print("[Lecture] Attempting to decode response")
            do {
                let apiResponse = try JSONDecoder().decode(LectureResponse.self, from: data)
                print("[Lecture] Successfully decoded LectureResponse")
            
                if let lectureData = apiResponse.lecture, let audioFiles = apiResponse.audio_files {
                    print("[Lecture] Successfully received lecture data from backend.")
                    print("[Lecture] Lecture title: \(lectureData.title)")
                    print("[Lecture] Number of sections: \(lectureData.sections.count)")
                    print("[Lecture] Number of audio files: \(audioFiles.count)")
                    
                    // Convert backend lecture data to our Lecture model
                    let sections = lectureData.sections.enumerated().map { index, section in
                        LectureSection(
                            id: UUID(),
                            title: section.title,
                            script: section.script,
                            imagePrompt: section.image_prompt,
                            imageUrl: section.image_url,
                            order: index + 1
                        )
                    }
                    
                    // Convert backend audio files to our AudioFile model
                    let convertedAudioFiles = audioFiles.map { backendAudio in
                        AudioFile(
                            id: UUID(),
                            type: AudioFileType(rawValue: backendAudio.type) ?? .sectionScript,
                            text: backendAudio.text,
                            url: backendAudio.url,
                            filename: backendAudio.filename,
                            section: backendAudio.section
                        )
                    }
                    
                    let newLecture = Lecture(
                        id: UUID(uuidString: apiResponse.lecture_id) ?? UUID(),
                        title: lectureData.title,
                        sections: sections,
                        level: selectedLevel,
                        imageStyle: selectedImageStyle.displayName
                    )
                    
                    await MainActor.run {
                        self.currentLecture = newLecture
                        self.currentLectureAudioFiles = convertedAudioFiles
                        self.blocks = [] // Clear regular content blocks
                        self.isShowingFullScreenLecture = true
                        print("[Lecture] UI updated: currentLecture set, isShowingFullScreenLecture = true")
                    }
                    
                    if let currentUser = Auth.auth().currentUser {
                        print("[Lecture] User authenticated (\(currentUser.uid)), proceeding with Firebase save for lecture ID \(newLecture.id.uuidString)")
                        await saveLectureToFirebase(newLecture, audioFiles: audioFiles, userId: currentUser.uid)
                        print("[Lecture] Lecture content and audio processing completed.")
                    } else {
                        print("[Lecture] ERROR: No authenticated user found after receiving lecture. Cannot save.")
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                    }
                } else if let errorMsg = apiResponse.error {
                    print("[Lecture] ERROR: Backend returned error in JSON response: \(errorMsg)")
                    throw NSError(domain: "BackendLogicError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                } else {
                    print("[Lecture] ERROR: No lecture or error field in decoded JSON response.")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("[Lecture] Raw JSON that led to this (first 500 chars): \(jsonString.prefix(500))")
                    }
                    throw NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response structure from server (no lecture or error)."])
                }

            } catch let decodingError as DecodingError {
                print("[Lecture] DECODING ERROR: Failed to decode lecture response from backend.")
                print("[Lecture] DecodingError: \(decodingError.localizedDescription)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[Lecture] Raw JSON response string that failed to decode (first 1000 chars): \(jsonString.prefix(1000))")
                }
                throw decodingError
            }
            
        } catch let urlError as URLError {
            print("[Lecture] Network URLError occurred: \(urlError.localizedDescription)")
            print("[Lecture] Error code: \(urlError.code.rawValue)")
            let specificMessage: String
            switch urlError.code {
            case .timedOut: specificMessage = "Request timed out. Please try again."
            case .notConnectedToInternet: specificMessage = "No internet connection. Please check your connection and try again."
            case .cannotConnectToHost, .networkConnectionLost: specificMessage = "Could not connect to the server. Please try again later."
            default: specificMessage = "Network error: \(urlError.localizedDescription)"
            }
            throw NSError(domain: "NetworkError.URL", code: urlError.code.rawValue, userInfo: [NSLocalizedDescriptionKey: specificMessage])
        } catch {
            print("[Lecture] ERROR: Unexpected error during lecture generation process: \(error.localizedDescription)")
            print("[Lecture] Error type: \(type(of: error))")
            let finalErrorMessage = error.localizedDescription
            await MainActor.run { self.errorMessage = finalErrorMessage }
        }
    }
    
    private func generateRegularContent() async throws {
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
                                    let imagePath = "content/\(userId)/\(block.id.uuidString).jpg"
                                    print("[Content] Uploading image to path: \(imagePath)")
                                    
                                    // Add metadata for better organization
                                    let metadata = StorageMetadata()
                                    metadata.contentType = "image/jpeg"
                                    metadata.customMetadata = [
                                        "blockId": block.id.uuidString,
                                        "blockTypeString": block.type.rawValue,
                                        "uploadDate": ISO8601DateFormatter().string(from: Date())
                                    ]
                                    
                                    print("[Content] Image metadata:")
                                    print("[Content] - Content type: \(metadata.contentType ?? "Not specified")")
                                    print("[Content] - Custom metadata: \(metadata.customMetadata ?? [:])")
                                    
                                    let downloadURL = try await firestoreService.uploadImage(imageData, path: imagePath, metadata: metadata)
                                    print("[Content] Successfully uploaded image for block ID \(block.id.uuidString)")
                                    print("[Content] Download URL: \(downloadURL.absoluteString)")
                                    
                                    // Update the block with the Firebase image URL
                                    updatedBlocks[index].firebaseImageUrl = downloadURL.absoluteString
                                    
                                    // Update UI with the latest block
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
                }
                
                // Save to Firebase if user is authenticated
                if let currentUser = Auth.auth().currentUser {
                    print("[Content] Saving content to Firebase for user: \(currentUser.uid)")
                    await saveContentBlocksToFirebase(
                        topic: extractTopicTitle(from: inputText),
                        blocks: updatedBlocks,
                        level: selectedLevel,
                        summarizationTier: selectedSummarizationTier,
                        userId: currentUser.uid
                    )
                } else {
                    print("[Content] WARNING: No authenticated user found, skipping Firebase save")
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
    
    private func generateImagesForStory(_ story: Story) async {
        let imageSize = CGSize(width: 800, height: 600) // This size is for the prompt, backend controls actual generation size.
        var updatedChapters = story.chapters
        let maxRetries = 3
        
        print("[Story][ImageGen] Starting image generation for story: \(story.title)")
        print("[Story][ImageGen] Story ID: \(story.id.uuidString)")
        print("[Story][ImageGen] Number of chapters: \(story.chapters.count)")
        // print("[Story][ImageGen] Desired image prompt size guide: \(imageSize)") // Informational

        for (index, chapter) in story.chapters.enumerated() {
            print("[Story][ImageGen] Processing chapter \(index + 1)/\(story.chapters.count): '\(chapter.title ?? "Untitled")' (ID: \(chapter.id.uuidString))")
            var retryCount = 0
            var success = false
            
            while retryCount < maxRetries && !success {
                print("[Story][ImageGen] Attempt \(retryCount + 1) of \(maxRetries) for chapter \(index + 1)")
                do {
                    // fetchImageForChapter now correctly gets image data from GCS URL
                    if let image = await fetchImageForChapter(chapter: chapter, maxSize: imageSize) {
                        print("[Story][ImageGen] Successfully fetched UIImage for chapter \(index + 1). Image size: \(image.size)")
                        
                        if let imageData = image.jpegData(compressionQuality: 0.8),
                           let userId = Auth.auth().currentUser?.uid {
                            print("[Story][ImageGen] Converted UIImage to JPEG data. Size: \(imageData.count) bytes for chapter \(index + 1). User ID: \(userId)")
                            
                            if imageData.count == 0 {
                                print("[Story][ImageGen] ERROR: Generated image data is empty for chapter \(index + 1).")
                                throw NSError(domain: "ImageProcessingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Generated image data is empty"])
                            }
                            
                            let imagePath = "stories/\(userId)/\(story.id.uuidString)/\(chapter.id.uuidString).jpg"
                            print("[Story][ImageGen] Preparing to upload image to Firebase Storage path: \(imagePath)")
                            
                            let metadata = StorageMetadata()
                            metadata.contentType = "image/jpeg"
                            // Using unique keys for custom metadata to avoid any potential conflicts
                            metadata.customMetadata = [
                                "storyId": story.id.uuidString,
                                "chapterId": chapter.id.uuidString,
                                "chapterTitle": chapter.title ?? "Untitled",
                                "uploadTimestamp": ISO8601DateFormatter().string(from: Date()) // Changed key from "uploadDate"
                            ]
                            
                            print("[Story][ImageGen] Firebase Storage Metadata for chapter \(index + 1):")
                            print("[Story][ImageGen] - ContentType: \(metadata.contentType ?? "Not set")")
                            print("[Story][ImageGen] - CustomMetadata: \(metadata.customMetadata ?? [:])")
                            
                            // Assuming firestoreService.uploadImage is the corrected version from previous steps
                            let downloadURL = try await firestoreService.uploadImage(imageData, path: imagePath, metadata: metadata)
                            print("[Story][ImageGen] Successfully uploaded image for chapter \(index + 1) to Firebase Storage.")
                            print("[Story][ImageGen] Received Firebase Download URL: \(downloadURL.absoluteString)")
                            
                            updatedChapters[index].firebaseImageUrl = downloadURL.absoluteString
                            success = true
                            
                            await MainActor.run {
                                if var currentStory = self.currentStory, currentStory.chapters.indices.contains(index) {
                                    currentStory.chapters[index].firebaseImageUrl = downloadURL.absoluteString
                                    self.currentStory = currentStory // Update the published property
                                    print("[Story][ImageGen] UI updated with new firebaseImageUrl for chapter \(index + 1).")
                                } else {
                                    print("[Story][ImageGen] Warning: Could not update currentStory in UI for chapter \(index + 1) image URL (story or chapter index mismatch).")
                                }
                            }
                        } else {
                            let reason = Auth.auth().currentUser?.uid == nil ? "User ID is nil." : "Failed to convert UIImage to JPEG data."
                            print("[Story][ImageGen] ERROR: \(reason) for chapter \(index + 1).")
                            throw NSError(domain: "ImageProcessingError", code: 2, userInfo: [NSLocalizedDescriptionKey: reason])
                        }
                    } else {
                        print("[Story][ImageGen] ERROR: fetchImageForChapter returned nil (failed to generate/download image) for chapter \(index + 1).")
                        throw NSError(domain: "ImageFetchingError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to generate or download image for chapter."])
                    }
                } catch {
                    retryCount += 1
                    print("[Story][ImageGen] ERROR during attempt \(retryCount) for chapter \(index + 1): \(error.localizedDescription)")
                    print("[Story][ImageGen] Error Type: \(type(of: error))")
                    print("[Story][ImageGen] Full Error: \(error)")
                    
                    if retryCount >= maxRetries {
                        let errorMessageText = "Failed to process image for chapter '\(chapter.title ?? "Untitled")' (ID: \(chapter.id.uuidString)) after \(maxRetries) attempts: \(error.localizedDescription)"
                        print("[Story][ImageGen] FINAL ERROR: \(errorMessageText)")
                        // Optionally update UI with this specific error
                        // await MainActor.run { self.errorMessage = errorMessageText }
                    } else {
                        print("[Story][ImageGen] Retrying in \(retryCount * 2) seconds...") // Increased retry delay
                        try? await Task.sleep(nanoseconds: UInt64(2_000_000_000 * retryCount))
                    }
                }
            }
            if !success {
                 print("[Story][ImageGen] WARNING: Failed to process image for chapter \(index + 1) ('\(chapter.title ?? "Untitled")') after all retries. It will not have an image.")
            }
        }
        
        // Ensure the story being saved has the updated chapter image URLs
        var finalStoryToSave = story // Start with original story structure
        finalStoryToSave.chapters = updatedChapters // Assign chapters that have firebaseImageUrls (or nil if failed)
        
        await MainActor.run {
            self.currentStory = finalStoryToSave // Update UI with the story containing all attempted image URLs
            print("[Story][ImageGen] Image generation process for all chapters completed. UI updated with final story.")
        }
        
        if let userId = Auth.auth().currentUser?.uid {
            print("[Story][Save] Proceeding to save story with updated chapter image URLs to Firebase for user \(userId).")
            await saveStoryToFirebase(story: finalStoryToSave, userId: userId)
        } else {
            print("[Story][Save] ERROR: No authenticated user found. Cannot save story to Firebase.")
            // Update UI with an appropriate error message
            await MainActor.run {
                self.errorMessage = "User not authenticated. Story could not be saved."
            }
        }
    }
    
    private func saveStoryToFirebase(story: Story, userId: String) async {
        print("[Story][Save] Starting Firebase save process for story: '\(story.title)' (ID: \(story.id.uuidString))")
        print("[Story][Save] User ID: \(userId)")
        print("[Story][Save] Total chapters to save: \(story.chapters.count)")
        
        let firebaseChapters = story.chapters.map { chapter -> FirebaseChapter in
            print("[Story][Save] Mapping chapter '\(chapter.title ?? "Untitled")' (ID: \(chapter.id.uuidString)) for Firestore.")
            print("[Story][Save] - FirebaseImageUrl for chapter: \(chapter.firebaseImageUrl ?? "N/A - No image URL")")
            print("[Story][Save] - ImageStyle for chapter: \(chapter.imageStyle ?? "N/A")")
            
            return FirebaseChapter(
                chapterId: chapter.id.uuidString,
                title: chapter.title,
                content: chapter.content,
                order: chapter.order,
                firebaseImageUrl: chapter.firebaseImageUrl, // This is critical
                imageStyle: chapter.imageStyle
            )
        }

        let firebaseStory = FirebaseStory(
            userId: userId,
            title: story.title,
            overview: story.content,
            level: story.level.rawValue,
            imageStyle: story.imageStyle,
            chapters: firebaseChapters
        )
        
        do {
            print("[Story][Save] Attempting to create story document in Firestore. Collection: 'stories', DocumentID to be used by service: \(story.id.uuidString)")
            let documentId = try await firestoreService.create(firebaseStory, in: "stories", documentId: story.id.uuidString)
            print("[Story][Save] Successfully saved story to Firestore with document ID: \(documentId)")
            
            // Track story generation for dashboard engagement metrics
            await MainActor.run {
                let currentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
                UserDefaults.standard.set(currentCount + 1, forKey: "contentGenerationCount")
                print("[Engagement] Story generation tracked. Total: \(currentCount + 1)")
            }
            
            // Optional: Verification step
            // print("[Story][Save] Verifying saved story data...")
            // if let savedStoryData = try? await firestoreService.fetch(FirebaseStory.self, from: "stories", documentId: documentId) {
            //     print("[Story][Save] Verification successful. Saved story title: \(savedStoryData.title)")
            //     savedStoryData.chapters?.forEach { ch in
            //         print("[Story][Save] - Verified Chapter '\(ch.title ?? "")' Image URL: \(ch.firebaseImageUrl ?? "N/A")")
            //     }
            // } else {
            //     print("[Story][Save] WARNING: Could not verify story save by fetching back the document.")
            // }
            
        } catch {
            print("[Story][Save] ERROR: Failed to save story to Firestore for story ID \(story.id.uuidString).")
            print("[Story][Save] Error Type: \(type(of: error))")
            print("[Story][Save] Error Description: \(error.localizedDescription)")
            print("[Story][Save] Full Error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to save story to cloud: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveLectureToFirebase(_ lecture: Lecture, audioFiles: [BackendAudioFile], userId: String) async {
        print("[Lecture][Save] Starting Firebase save process for lecture: '\(lecture.title)' (ID: \(lecture.id.uuidString))")
        print("[Lecture][Save] User ID: \(userId)")
        print("[Lecture][Save] Total sections to save: \(lecture.sections.count)")
        print("[Lecture][Save] Total audio files: \(audioFiles.count)")
        
        let firebaseSections = lecture.sections.map { section -> FirebaseLectureSection in
            print("[Lecture][Save] Mapping section '\(section.title)' (ID: \(section.id.uuidString)) for Firestore.")
            print("[Lecture][Save] - ImageUrl for section: \(section.imageUrl ?? "N/A - No image URL")")
            
            return FirebaseLectureSection(
                sectionId: section.id.uuidString,
                title: section.title,
                script: section.script,
                imagePrompt: section.imagePrompt,
                imageUrl: section.imageUrl,
                order: section.order
            )
        }
        
        let firebaseAudioFiles = audioFiles.map { audioFile -> FirebaseAudioFile in
            return FirebaseAudioFile(
                type: audioFile.type,
                text: audioFile.text,
                url: audioFile.url,
                filename: audioFile.filename,
                section: audioFile.section
            )
        }

        let firebaseLecture = FirebaseLecture(
            userId: userId,
            title: lecture.title,
            level: lecture.level.rawValue,
            imageStyle: lecture.imageStyle,
            sections: firebaseSections,
            audioFiles: firebaseAudioFiles
        )
        
        do {
            print("[Lecture][Save] Attempting to create lecture document in Firestore. Collection: 'lectures', DocumentID to be used by service: \(lecture.id.uuidString)")
            let documentId = try await firestoreService.create(firebaseLecture, in: "lectures", documentId: lecture.id.uuidString)
            print("[Lecture][Save] Successfully saved lecture to Firestore with document ID: \(documentId)")
            
            // Track lecture generation for dashboard engagement metrics
            await MainActor.run {
                let currentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
                UserDefaults.standard.set(currentCount + 1, forKey: "contentGenerationCount")
                print("[Engagement] Lecture generation tracked. Total: \(currentCount + 1)")
            }
            
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
    
    private func saveContentBlocksToFirebase(topic: String, blocks: [ContentBlock], level: ReadingLevel, summarizationTier: SummarizationTier, userId: String) async {
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
            
            // Optional: Verification step
            // print("[Content][Save] Verifying saved content data...")
            // if let savedContentData = try? await firestoreService.fetch(FirebaseUserContent.self, from: "userGeneratedContent", documentId: documentId) {
            //     print("[Content][Save] Verification successful. Saved content topic: \(savedContentData.topic ?? "N/A")")
            //     print("[Content][Save] - Verified blocks count: \(savedContentData.blocks?.count ?? 0)")
            // } else {
            //     print("[Content][Save] WARNING: Could not verify content save by fetching back the document.")
            // }

        } catch {
            print("[Content][Save] ERROR: Failed to save content to Firestore.")
            print("[Content][Save] Error Type: \(type(of: error))")
            print("[Content][Save] Error Description: \(error.localizedDescription)")
            print("[Content][Save] Full Error: \(error)")
            // Optionally update UI with error
            // await MainActor.run {
            //     self.errorMessage = "Failed to save content: \(error.localizedDescription)"
            // }
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchImageForChapter(chapter: StoryChapter, maxSize: CGSize) async -> UIImage? {
        print("[Image] Generating image for chapter: \(chapter.title ?? "Untitled") (New Method)")
        
        let chapterIdentifier = chapter.title ?? "ID: \(chapter.id.uuidString)"
        // Using a combined prompt from title and content. Adjust length as needed.
        let promptText = "Vivid illustration for story chapter titled '\(chapterIdentifier)': \(chapter.content.prefix(250))"

        // MODIFICATION 3: Use displayName for image_style fallback
        let effectiveImageStyle = chapter.imageStyle ?? selectedImageStyle.displayName
        print("[Image] Effective image style for chapter '\(chapterIdentifier)': \(effectiveImageStyle)")

        let requestBody: [String: Any] = [
            "prompt": promptText,
            "level": currentStory?.level.rawValue ?? selectedLevel.rawValue,
            "image_style": effectiveImageStyle,
            // max_width and max_height are not directly handled by the /generate_image endpoint's parameters in the provided backend code.
            // The backend's generate_and_save_image function uses them for prompt engineering if they were passed deeper.
            // For now, relying on backend's internal logic for sizing.
        ]

        guard let url = URL(string: "\(backendURL)/generate_image") else {
            print("[Image] ERROR: Invalid URL for image generation")
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            print("[Image] Sending image generation request to backend (/generate_image) for chapter: \(chapterIdentifier)")
            // print("[Image] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to print request body")") // Optional: for detailed debugging

            let (data, response) = try await self.session.data(for: request) // Use self.session

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Image] ERROR: Invalid server response for chapter \(chapterIdentifier)")
                return nil
            }

            print("[Image] Received response for chapter \(chapterIdentifier) with status code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("[Image] ERROR: Server returned status code \(httpResponse.statusCode) for chapter \(chapterIdentifier)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Image] Error response from server: \(errorResponse)")
                }
                return nil
            }

            struct BackendImageResponse: Codable {
                let url: String
            }
            
            let backendImageResponse = try JSONDecoder().decode(BackendImageResponse.self, from: data)
            guard let gcsImageUrl = URL(string: backendImageResponse.url) else {
                print("[Image] ERROR: Backend did not return a valid GCS URL string for chapter image: \(backendImageResponse.url)")
                return nil
            }

            print("[Image] Received GCS URL: \(gcsImageUrl.absoluteString) for chapter \(chapterIdentifier). Downloading image data...")
            
            let (imageData, imageResponse) = try await self.session.data(from: gcsImageUrl) // Use self.session

            guard let httpImageResponse = imageResponse as? HTTPURLResponse, httpImageResponse.statusCode == 200 else {
                print("[Image] ERROR: Failed to download image data from GCS URL for chapter \(chapterIdentifier). Status: \((imageResponse as? HTTPURLResponse)?.statusCode ?? -1)")
                if let gcsErrorData = String(data: imageData, encoding: .utf8), gcsErrorData.count < 1000 { // Avoid printing huge data
                    print("[Image] GCS download error data: \(gcsErrorData)")
                }
                return nil
            }
            
            guard let image = UIImage(data: imageData) else {
                print("[Image] ERROR: Failed to create UIImage from downloaded GCS data for chapter \(chapterIdentifier)")
                if let responseString = String(data: imageData, encoding: .utf8), responseString.count < 500 {
                     print("[Image] GCS Response data (if not image): \(responseString)")
                }
                return nil
            }
            
            print("[Image] Successfully generated and downloaded image for chapter \(chapterIdentifier)")
            print("[Image] Image size: \(image.size)")
            return image
            
        } catch let decodingError as DecodingError {
            print("[Image] ERROR decoding JSON for chapter \(chapterIdentifier): \(decodingError)")
            // To aid debugging, print the request body and raw response if decoding fails.
            if let requestBodyData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
               let requestBodyString = String(data: requestBodyData, encoding: .utf8) {
                print("[Image] Request body sent was: \(requestBodyString)")
            }
            // This part is tricky as 'data' might be from the GCS download if that's where decoding failed.
            // The initial 'data' from '/generate_image' call is more relevant for BackendImageResponse decoding issues.
            // Consider logging 'data' before 'JSONDecoder().decode' if this error occurs frequently.
            return nil
        } catch {
            print("[Image] ERROR: Failed to generate/fetch image for chapter \(chapterIdentifier): \(error.localizedDescription)")
            print("[Image] Full error details: \(error)")
            return nil
        }
    }
    
    private func fetchImageForBlock(block: ContentBlock) async -> UIImage? {
        print("[Image] Starting image generation for block ID: \(block.id.uuidString) (New Method)")
        // print("[Image] Block content: \(block.content ?? "No content")") // Optional debug
        // print("[Image] Block alt: \(block.alt ?? "No alt text")") // Optional debug
        // print("[Image] Selected image style: \(selectedImageStyle.displayName)") // Optional debug
        
        let imagePromptText = block.content ?? block.alt
        
        guard let prompt = imagePromptText, !prompt.isEmpty else {
            print("[Image] ERROR: Both block content and alt text are empty for block ID \(block.id.uuidString), cannot generate image")
            return nil
        }
        
        let requestBody: [String: Any] = [
            "prompt": prompt,
            "image_style": selectedImageStyle.backendRawValue,
            "level": selectedLevel.rawValue // Added level, ensure it's appropriate
            // "max_width": 800, // Backend /generate_image doesn't take these directly.
            // "max_height": 600 // Sizing is handled by backend's internal logic or prompt engineering.
        ]
        
        do {
            let url = URL(string: "\(backendURL)/generate_image")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            print("[Image] Sending request to backend (/generate_image) for block ID: \(block.id.uuidString)")
            // print("[Image] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to print request body")") // Optional: for detailed debugging

            let (data, response) = try await self.session.data(for: request) // Use self.session
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Image] ERROR: Invalid server response for block ID \(block.id.uuidString)")
                return nil
            }
            
            print("[Image] Received response for block ID \(block.id.uuidString) with status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("[Image] ERROR: Server returned status code \(httpResponse.statusCode) for block ID \(block.id.uuidString)")
                if let errorResponse = String(data: data, encoding: .utf8) {
                    print("[Image] Error response from server: \(errorResponse)")
                }
                return nil
            }

            struct BackendImageResponse: Codable {
                let url: String
            }

            let backendImageResponse = try JSONDecoder().decode(BackendImageResponse.self, from: data)
            guard let gcsImageUrl = URL(string: backendImageResponse.url) else {
                print("[Image] ERROR: Backend did not return a valid GCS URL string for block image: \(backendImageResponse.url)")
                return nil
            }

            print("[Image] Received GCS URL: \(gcsImageUrl.absoluteString) for block ID \(block.id.uuidString). Downloading image data...")

            let (imageData, imageResponse) = try await self.session.data(from: gcsImageUrl) // Use self.session

            guard let httpImageResponse = imageResponse as? HTTPURLResponse, httpImageResponse.statusCode == 200 else {
                print("[Image] ERROR: Failed to download image data from GCS URL for block ID \(block.id.uuidString). Status: \((imageResponse as? HTTPURLResponse)?.statusCode ?? -1)")
                if let gcsErrorData = String(data: imageData, encoding: .utf8), gcsErrorData.count < 1000 {
                     print("[Image] GCS download error data: \(gcsErrorData)")
                }
                return nil
            }
            
            guard let image = UIImage(data: imageData) else {
                print("[Image] ERROR: Failed to create UIImage from downloaded GCS data for block ID \(block.id.uuidString)")
                if let responseString = String(data: imageData, encoding: .utf8), responseString.count < 500 {
                    print("[Image] GCS Response data (if not image): \(responseString)")
                }
                return nil
            }
            
            print("[Image] Successfully generated image for block ID \(block.id.uuidString)")
            print("[Image] Image size: \(image.size)")
            return image

        } catch let decodingError as DecodingError {
            print("[Image] ERROR decoding JSON for block ID \(block.id.uuidString): \(decodingError)")
            if let requestBodyData = try? JSONSerialization.data(withJSONObject: requestBody, options: .prettyPrinted),
               let requestBodyString = String(data: requestBodyData, encoding: .utf8) {
                print("[Image] Request body sent was: \(requestBodyString)")
            }
            return nil
        } catch {
            print("[Image] ERROR: Failed to generate image for block ID \(block.id.uuidString)")
            print("[Image] Error type: \(type(of: error))")
            print("[Image] Error description: \(error.localizedDescription)")
            print("[Image] Full error details: \(error)")
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
        do {
            // Query userGeneratedContent
            let userContentSnapshot = try await db.collection("userGeneratedContent")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: startTimestamp)
                .whereField("createdAt", isLessThanOrEqualTo: endTimestamp)
                .getDocuments()
            total += userContentSnapshot.documents.count
            
            // Query stories
            let storiesSnapshot = try await db.collection("stories")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: startTimestamp)
                .whereField("createdAt", isLessThanOrEqualTo: endTimestamp)
                .getDocuments()
            total += storiesSnapshot.documents.count
            
            // Query lectures
            let lecturesSnapshot = try await db.collection("lectures")
                .whereField("userId", isEqualTo: userId)
                .whereField("createdAt", isGreaterThanOrEqualTo: startTimestamp)
                .whereField("createdAt", isLessThanOrEqualTo: endTimestamp)
                .getDocuments()
            total += lecturesSnapshot.documents.count
        } catch {
            print("[DailyLimit] Error fetching today's generation count: \(error)")
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

struct Story: Identifiable, Codable {
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

struct StoryChapter: Identifiable, Codable {
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