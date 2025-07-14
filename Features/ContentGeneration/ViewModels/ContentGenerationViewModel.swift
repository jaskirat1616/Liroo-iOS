import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UserNotifications
import BackgroundTasks
import FirebaseCrashlytics
import FirebaseMessaging

@MainActor
class ContentGenerationViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var selectedLevel: ReadingLevel = .moderate
    @Published var selectedSummarizationTier: SummarizationTier = .detailedExplanation
    @Published var selectedGenre: StoryGenre = .adventure
    @Published var mainCharacter = ""
    @Published var selectedImageStyle: ImageStyle = .ghibli
    
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var currentStory: Story?
    @Published var currentLecture: Lecture?
    @Published var currentLectureAudioFiles: [AudioFile] = []
    @Published var currentComic: Comic?
    @Published var blocks: [ContentBlock] = []
    @Published var isShowingFullScreenStory = false
    @Published var isShowingFullScreenLecture = false
    @Published var isShowingFullScreenContent = false
    @Published var isShowingFullScreenComic = false
    @Published var todayGenerationCount: Int = 0
    @Published var statusMessage: String? = nil
    @Published var savedContentDocumentId: String?
    
    // Progress tracking properties
    @Published var currentRequestId: String?
    private var progressPollingTask: Task<Void, Never>?
    
    private let globalManager = GlobalBackgroundProcessingManager.shared
    private let firestoreService = FirestoreService.shared
    private let backgroundTaskService = BackgroundTaskCompletionService.shared
    private let backendURL = "https://liroo-backend-904791784838.us-central1.run.app"
    
    // Custom URLSession for regular, foreground tasks
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1200  // Increased from 600 to 1200 seconds (20 minutes)
        config.timeoutIntervalForResource = 3600 // Increased from 1800 to 3600 seconds (60 minutes)
        return URLSession(configuration: config)
    }()
    
    // Progress response model
    struct ProgressResponse: Codable {
        let step: String
        let step_number: Int
        let total_steps: Int
        let details: String
        let last_updated: String
        let progress_percentage: Double
    }
    
    // init() is no longer an override
    init() {
        // Notifications are now handled automatically by NotificationManager
        // No manual setup needed
    }
    
    // MARK: - Progress Polling
    
    private func startProgressPolling(requestId: String) {
        // Cancel any existing polling task
        progressPollingTask?.cancel()
        
        progressPollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await pollProgress(requestId: requestId)
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Poll every 1 second
                } catch {
                    print("[Progress] Polling error: \(error)")
                    // If polling fails, add task to background monitoring
                    await MainActor.run {
                        backgroundTaskService.addPendingTask(requestId)
                    }
                    break
                }
            }
        }
    }
    
    private func startProgressPollingFallback() {
        // Fallback for when backend doesn't return request_id (backward compatibility)
        // This will use the existing progress tracking without polling
        print("[Progress] Using fallback progress tracking (no request_id)")
    }
    
    private func stopProgressPolling() {
        progressPollingTask?.cancel()
        progressPollingTask = nil
    }
    
    private func pollProgress(requestId: String) async throws {
        let url = URL(string: "\(backendURL)/progress/\(requestId)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "ProgressPolling", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch progress"])
        }
        
        let progress = try JSONDecoder().decode(ProgressResponse.self, from: data)
        
        await MainActor.run {
            self.globalManager.updateProgress(
                step: progress.step,
                stepNumber: progress.step_number,
                totalSteps: progress.total_steps
            )
            
            // Update status message with details
            if !progress.details.isEmpty {
                self.statusMessage = "\(progress.step): \(progress.details)"
            } else {
                self.statusMessage = progress.step
            }
        }
    }
    
    // The original, async generateContent() method remains for foreground operations
    func generateContent() async {
        let startTime = Date()
        
        // Log user action
        CrashlyticsManager.shared.logUserAction(
            action: "content_generation_started",
            screen: "content_generation",
            additionalData: [
                "content_type": selectedSummarizationTier.displayName,
                "level": selectedLevel.rawValue,
                "input_length": inputText.count,
                "genre": selectedGenre.rawValue,
                "image_style": selectedImageStyle.displayName
            ]
        )
        
        guard !inputText.isEmpty else {
            errorMessage = "Please enter some text to generate content"
            return
        }
        
        guard inputText.count <= 5000 else {
            errorMessage = "Input text must be less than 5000 characters"
            return
        }
        
        if let userId = Auth.auth().currentUser?.uid {
            let todayCount = await fetchTodayGenerationCount(userId: userId)
            if todayCount >= 12 {
                errorMessage = "You have reached your daily generation limit (12 per day)."
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        statusMessage = "Starting generation..."
        
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
        isShowingFullScreenComic = false
        savedContentDocumentId = nil
        currentStory = nil
        currentLecture = nil
        currentLectureAudioFiles = []
        currentComic = nil
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
        
        let maxRetries = 3  // Increased from 2 to 3 retries
        var attempt = 0
        var lastError: Error?
        
        repeat {
            do {
                if selectedSummarizationTier == .story {
                    try await generateStoryWithProgress()
                } else if selectedSummarizationTier == .lecture {
                    try await generateLectureWithProgress()
                } else if selectedSummarizationTier == .comic {
                    try await generateComicWithProgress()
                } else {
                    try await generateRegularContentWithProgress()
                }
                
                // Log successful completion
                let duration = Date().timeIntervalSince(startTime)
                CrashlyticsManager.shared.logUserAction(
                    action: "content_generation_completed",
                    screen: "content_generation",
                    additionalData: [
                        "content_type": selectedSummarizationTier.displayName,
                        "duration": duration,
                        "attempt": attempt + 1
                    ]
                )
                
                // Check for performance issues
                if duration > 60 { // Log if generation takes more than 60 seconds
                    CrashlyticsManager.shared.logPerformanceIssue(
                        operation: "content_generation",
                        duration: duration,
                        threshold: 60
                    )
                }
                
                // Refresh count after successful generation
                await refreshTodayGenerationCount()
                
                // Track engagement and send notifications automatically
                EngagementTracker.shared.trackContentGeneration(contentType: selectedSummarizationTier.displayName)
                
                statusMessage = nil
                isLoading = false
                stopProgressPolling() // Stop progress polling
                currentRequestId = nil
                globalManager.endBackgroundTask()
                return
                
            } catch {
                lastError = error
                attempt += 1
                let nsError = error as NSError
                let isNetworkLost = nsError.domain == NSURLErrorDomain && nsError.code == -1005
                
                // Log error with comprehensive context
                CrashlyticsManager.shared.logContentGenerationError(
                    error: error,
                    contentType: selectedSummarizationTier.displayName,
                    inputLength: inputText.count,
                    level: selectedLevel.rawValue,
                    tier: selectedSummarizationTier.rawValue,
                    genre: selectedGenre.rawValue,
                    imageStyle: selectedImageStyle.displayName
                )
                
                if isNetworkLost && attempt <= maxRetries {
                    await MainActor.run {
                        self.statusMessage = "Network connection lost. Retrying (\(attempt)/\(maxRetries))..."
                        self.globalManager.updateProgress(step: "Retrying...", stepNumber: globalManager.currentStepNumber, totalSteps: globalManager.totalSteps)
                    }
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // Increased from 2 to 3 seconds
                } else {
                    // Send error notification automatically
                    await NotificationManager.shared.sendContentGenerationError(contentType: selectedSummarizationTier.displayName)
                    
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.statusMessage = nil
                    }
                    isLoading = false
                    stopProgressPolling() // Stop progress polling
                    currentRequestId = nil
                    globalManager.endBackgroundTaskWithError(errorMessage: error.localizedDescription)
                    return
                }
            }
        } while attempt <= maxRetries
        
        isLoading = false
        statusMessage = nil
        stopProgressPolling() // Stop progress polling
        currentRequestId = nil
        globalManager.endBackgroundTask()
        if let lastError = lastError {
            errorMessage = lastError.localizedDescription
        }
    }

    // MARK: - Background Generation Methods (Refactored to use Singleton)

    func generateStoryWithProgressInBackground() {
        globalManager.updateProgress(step: "Generating story content... (background)", stepNumber: 1, totalSteps: 6)  // Reduced from 8 to 6
        let trimmedMainCharacter = mainCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        var effectiveInputText = inputText
        if !trimmedMainCharacter.isEmpty {
            effectiveInputText = "The main character of this story is \(trimmedMainCharacter).\n\n\(inputText)"
        }
        let storyPrompt = """
        [Level: \(selectedLevel.rawValue)]
        Please convert the following text into an engaging \(selectedGenre.rawValue.lowercased()) story.
        Image Style to consider for tone and visuals: \(selectedImageStyle.displayName).
        Original Text:
        \(effectiveInputText)
        """
        
        Task {
            let userToken = await getFCMToken()
            let requestBody: [String: Any] = [
                "text": storyPrompt,
                "level": selectedLevel.rawValue,
                "genre": selectedGenre.rawValue.lowercased(),
                "image_style": selectedImageStyle.displayName,
                "user_token": userToken ?? ""
            ]
            startBackgroundTask(with: requestBody, endpoint: "/generate_story", type: "Story")
        }
    }

    func generateLectureWithProgressInBackground() {
        globalManager.updateProgress(step: "Generating lecture content... (background)", stepNumber: 1, totalSteps: 3)
        
        Task {
            let userToken = await getFCMToken()
            let requestBody: [String: Any] = [
                "text": inputText,
                "level": selectedLevel.rawValue,
                "image_style": selectedImageStyle.displayName,
                "user_token": userToken ?? ""
            ]
            startBackgroundTask(with: requestBody, endpoint: "/generate_lecture", type: "Lecture")
        }
    }

    func generateComicWithProgressInBackground() {
        globalManager.updateProgress(step: "Generating comic content... (background)", stepNumber: 1, totalSteps: 3)
        
        Task {
            let userToken = await getFCMToken()
            let requestBody: [String: Any] = [
                "text": inputText,
                "level": selectedLevel.rawValue,
                "image_style": selectedImageStyle.displayName,
                "user_token": userToken ?? ""
            ]
            startBackgroundTask(with: requestBody, endpoint: "/generate_comic", type: "Comic")
        }
    }

    func generateRegularContentWithProgressInBackground() {
        globalManager.updateProgress(step: "Generating content... (background)", stepNumber: 1, totalSteps: 3)
        
        Task {
            let userToken = await getFCMToken()
            let requestBody: [String: Any] = [
                "input_text": inputText,
                "level": selectedLevel.rawValue,
                "summarization_tier": selectedSummarizationTier.rawValue,
                "profile": [
                    "studentLevel": selectedLevel.rawValue,
                    "topicsOfInterest": []
                ],
                "user_token": userToken ?? ""
            ]
            startBackgroundTask(with: requestBody, endpoint: "/process", type: "Content")
        }
    }
    
    // Generic method to start any background task via the manager
    private func startBackgroundTask(with requestBody: [String: Any], endpoint: String, type: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: requestBody) else {
            self.errorMessage = "Failed to encode request."
            return
        }

        let fileName = "\(type.lowercased())_upload_\(UUID().uuidString).json"
        guard let fileURL = try? writeDataToTempFile(data, fileName: fileName) else {
            self.errorMessage = "Failed to write request to temp file."
            return
        }

        let url = URL(string: "\(backendURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        BackgroundNetworkManager.shared.startBackgroundUpload(request: request, fromFile: fileURL) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let responseData):
                    self?.handleSuccessfulBackgroundResponse(data: responseData, type: type)
                case .failure(let error):
                    self?.errorMessage = "Background \(type) generation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // Generic handler for successful background responses
    private func handleSuccessfulBackgroundResponse(data: Data, type: String) {
        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            if let story = decoded.story { self.currentStory = story }
            else if let lecture = decoded.lecture { self.currentLecture = lecture }
            else if let blocks = decoded.blocks { self.blocks = blocks }
            
            self.statusMessage = "Background \(type) generation complete."
            sendBackgroundCompletionNotification(type: type)
        } catch {
            self.errorMessage = "Failed to decode background response: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods
    
    /// Gets the user's FCM token for push notifications
    private func getFCMToken() async -> String? {
        do {
            // Get the FCM token from Firebase Messaging
            let token = try await Messaging.messaging().token()
            print("[Content] FCM token retrieved: \(token.prefix(20))...")
            return token
        } catch {
            print("[Content] Failed to get FCM token: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Attempts to wake up the backend service if it's hibernating
    private func wakeUpBackend() async -> Bool {
        print("[Backend] Checking backend health...")
        
        let url = URL(string: "\(backendURL)/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0 // Increased from 10.0 to 30.0 seconds for health check
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[Backend] Invalid response type")
                return false
            }
            
                print("[Backend] Health check response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                if let healthData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let status = healthData["status"] as? String ?? "unknown"
                    let message = healthData["message"] as? String ?? "No message"
                    print("[Backend] Backend status: \(status) - \(message)")
                    return status == "healthy"
                }
                return true
            } else if httpResponse.statusCode == 503 {
                print("[Backend] Backend is hibernating (503)")
                return false
            } else {
                print("[Backend] Backend health check failed with status: \(httpResponse.statusCode)")
                return false
            }
        } catch {
            print("[Backend] Health check error: \(error.localizedDescription)")
        return false
        }
    }
    
    private func generateStoryWithProgress() async throws {
        globalManager.updateProgress(step: "Generating story content...", stepNumber: 1, totalSteps: 6)  // Reduced from 8 to 6
        
        print("[Story] Starting story generation process")
        
        // Try to wake up the backend first
        await MainActor.run {
            self.statusMessage = "Checking backend status..."
        }
        let backendReady = await wakeUpBackend()
        if !backendReady {
            print("[Story] Backend health check failed, proceeding anyway...")
        } else {
            print("[Story] Backend is ready")
        }
        
        let trimmedMainCharacter = mainCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
        var effectiveInputText = inputText
        if !trimmedMainCharacter.isEmpty {
            effectiveInputText = "The main character of this story is \(trimmedMainCharacter).\n\n\(inputText)"
        }

        let storyPrompt = """
        [Level: \(selectedLevel.rawValue)]
        Please convert the following text into an engaging \(selectedGenre.rawValue.lowercased()) story.
        Image Style to consider for tone and visuals: \(selectedImageStyle.displayName).
        Original Text:
        \(effectiveInputText) 
        """
        
        await MainActor.run {
            self.statusMessage = "Generating story content..."
        }
        
        let userToken = await getFCMToken()
        let requestBody: [String: Any] = [
            "text": storyPrompt,
            "level": selectedLevel.rawValue,
            "image_style": selectedImageStyle.displayName,
            "user_token": userToken ?? ""
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw ContentGenerationError.encodingFailed
        }
        
        let url = URL(string: "\(backendURL)/generate_story")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // Add retry logic for network issues
        let maxRetries = 5  // Increased from 3 to 5 retries
        var attempt = 0
        var lastError: Error?
        
        repeat {
            attempt += 1
            print("[Story] Attempt \(attempt) of \(maxRetries)")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ContentGenerationError.invalidResponse
                }
                
                print("[Story] Received response with status code: \(httpResponse.statusCode)")
                
                // Handle 503 errors (backend hibernation) with retry
                if httpResponse.statusCode == 503 {
                    if attempt < maxRetries {
                        let retryDelay = Double(attempt) * 5.0 // Increased from 3.0 to 5.0 seconds (5s, 10s, 15s, 20s, 25s)
                        print("[Story] Backend is hibernating (503). Retrying in \(retryDelay) seconds... (Attempt \(attempt)/\(maxRetries))")
                        await MainActor.run {
                            self.statusMessage = "Backend is starting up... Please wait (\(attempt)/\(maxRetries))"
                        }
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        print("[Story] Backend hibernation retry limit reached")
                        throw ContentGenerationError.backendError("Backend is starting up. Please try again in a few moments.")
                    }
                }
                
                if httpResponse.statusCode != 200 {
                    print("[Story] HTTP Error: \(httpResponse.statusCode)")
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["error"] as? String {
                        throw ContentGenerationError.backendError(errorMessage)
                    } else {
                        throw ContentGenerationError.httpError(httpResponse.statusCode)
                    }
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let storyData = json["story"] as? [String: Any] else {
                    throw ContentGenerationError.parsingFailed
                }
                
                guard let storyJsonData = try? JSONSerialization.data(withJSONObject: storyData),
                      let story = try? JSONDecoder().decode(Story.self, from: storyJsonData) else {
                    throw ContentGenerationError.parsingFailed
                }
                
                await MainActor.run {
                    self.statusMessage = "Saving story to cloud..."
                }
                
                // Save to Firebase
                if let currentUser = Auth.auth().currentUser {
                    await saveStoryToFirebase(story: story, userId: currentUser.uid)
                }
                
                await MainActor.run {
                    self.currentStory = story
                    self.statusMessage = nil
                }
                
                // Success - break out of retry loop
                return
                
            } catch let error as ContentGenerationError {
                // Don't retry for parsing or encoding errors
                throw error
            } catch {
                lastError = error
                print("[Story] Attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Check if it's a timeout error
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                    if attempt < maxRetries {
                        let retryDelay = Double(attempt) * 3.0 // Increased from 2.0 to 3.0 seconds (3s, 6s, 9s, 12s, 15s)
                        print("[Story] Request timed out. Retrying in \(retryDelay) seconds... (Attempt \(attempt)/\(maxRetries))")
                        await MainActor.run {
                            self.statusMessage = "Request timed out. Retrying... (\(attempt)/\(maxRetries))"
                        }
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        print("[Story] Request timeout retry limit reached")
                        throw ContentGenerationError.networkError(error)
                    }
                } else {
                    // For other network errors, retry once more
                    if attempt < maxRetries {
                        let retryDelay = Double(attempt) * 2.0 // Increased from 1.5 to 2.0 seconds
                        print("[Story] Network error. Retrying in \(retryDelay) seconds... (Attempt \(attempt)/\(maxRetries))")
                        await MainActor.run {
                            self.statusMessage = "Network error. Retrying... (\(attempt)/\(maxRetries))"
                        }
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        throw ContentGenerationError.networkError(error)
                    }
                }
            }
        } while attempt < maxRetries
        
        // If we get here, all retries failed
        throw lastError ?? ContentGenerationError.networkError(NSError(domain: "Unknown", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"]))
    }
    
    private func generateLectureWithProgress() async throws {
        globalManager.updateProgress(step: "Generating lecture content...", stepNumber: 1, totalSteps: 2)
        
        print("[Lecture] Starting lecture generation process")
        
        // Try to wake up the backend first
        await MainActor.run {
            self.statusMessage = "Checking backend status..."
        }
        let backendReady = await wakeUpBackend()
        if !backendReady {
            print("[Lecture] Backend health check failed, proceeding anyway...")
        } else {
            print("[Lecture] Backend is ready")
        }
        
        print("[Lecture] Input text length: \(inputText.count)")
        print("[Lecture] Selected level: \(selectedLevel.rawValue)")
        print("[Lecture] Selected image style: \(selectedImageStyle.displayName)")
        
        // Get user's FCM token for notifications
        let userToken = await getFCMToken()
        
        let requestBody: [String: Any] = [
            "text": inputText,
            "level": selectedLevel.rawValue,
            "image_style": selectedImageStyle.displayName,
            "user_token": userToken ?? ""
        ]
        
        let url = URL(string: "\(backendURL)/generate_lecture")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[Lecture] Sending request to backend (/generate_lecture)")
        
        // Add retry logic for 503 errors (backend hibernation)
        let maxRetries = 5  // Increased from 3 to 5 retries
        var attempt = 0
        
        repeat {
            attempt += 1
            print("[Lecture] Attempt \(attempt) of \(maxRetries)")
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[Lecture] ERROR: Invalid server response")
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                }
                
                print("[Lecture] Received response with status code: \(httpResponse.statusCode)")
                
                // Handle 503 errors (backend hibernation) with retry
                if httpResponse.statusCode == 503 {
                    if attempt < maxRetries {
                        let retryDelay = Double(attempt) * 4.0 // Increased from 2.0 to 4.0 seconds (4s, 8s, 12s, 16s, 20s)
                        print("[Lecture] Backend is hibernating (503). Retrying in \(retryDelay) seconds... (Attempt \(attempt)/\(maxRetries))")
                        await MainActor.run {
                            self.statusMessage = "Backend is starting up... Please wait (\(attempt)/\(maxRetries))"
                        }
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        print("[Lecture] Backend hibernation retry limit reached")
                        let hibernationError = NSError(domain: "BackendHibernation", code: 503, userInfo: [NSLocalizedDescriptionKey: "Backend is starting up. Please try again in a few moments."])
                        throw hibernationError
                    }
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("[Lecture] ERROR: Server returned status code \(httpResponse.statusCode)")
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("[Lecture] Error response from server: \(errorResponse)")
                    }
                    throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
                }
                
                let apiResponse = try JSONDecoder().decode(LectureResponse.self, from: data)
                print("[Lecture] Successfully decoded LectureResponse.self")
                
                // Start progress polling if we received a request_id
                if let requestId = apiResponse.request_id {
                    print("[Lecture] Received request_id: \(requestId), starting progress polling")
                    currentRequestId = requestId
                    startProgressPolling(requestId: requestId)
                } else {
                    startProgressPollingFallback()
                }
                
                if let lecture = apiResponse.lecture {
                    print("[Lecture] Successfully received lecture from backend")
                    
                    // Convert BackendLecture to Lecture with proper ID
                    let lectureId = UUID()
                    let convertedLecture = Lecture(
                        id: lectureId,
                        title: lecture.title,
                        sections: lecture.sections.enumerated().map { index, section in
                            LectureSection(
                                id: UUID(),
                                title: section.title,
                                script: section.script,
                                imagePrompt: section.image_prompt,
                                imageUrl: section.image_url,
                                order: index + 1
                            )
                        },
                        level: selectedLevel,
                        imageStyle: selectedImageStyle.displayName
                    )
                    
                    print("[Lecture] Converted to Lecture - ID: \(convertedLecture.id.uuidString)")
                    print("[Lecture] Lecture Title: \(convertedLecture.title)")
                    print("[Lecture] Number of sections: \(convertedLecture.sections.count)")
                    
                    // Convert audio files from backend response
                    let audioFiles = apiResponse.audio_files ?? []
                    print("[Lecture] Received \(audioFiles.count) audio files from backend")
                    
                    await MainActor.run {
                        self.currentLecture = convertedLecture
                        print("[Lecture] Updated UI with lecture object")
                        globalManager.setLastGeneratedContent(type: .lecture, id: convertedLecture.id.uuidString, title: convertedLecture.title)
                    }
                    
                    globalManager.updateProgress(step: "Saving to cloud...", stepNumber: 2, totalSteps: 2)
                    
                    if let currentUser = Auth.auth().currentUser {
                        print("[Lecture] User authenticated (\(currentUser.uid)), proceeding with Firebase save for lecture ID \(convertedLecture.id.uuidString)")
                        
                        // Save lecture to Firebase with audio files
                        await saveLectureToFirebase(convertedLecture, audioFiles: audioFiles, userId: currentUser.uid)
                        
                        print("[Lecture] Lecture content and audio processing completed.")
                    } else {
                        print("[Lecture] ERROR: No authenticated user found after receiving lecture. Cannot save.")
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                    }
                } else if let error = apiResponse.error {
                    print("[Lecture] ERROR: Backend returned error: \(error)")
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
                }
                
                // If we reach here, the request was successful, so break out of retry loop
                break
                
            } catch let error as NSError {
                // If it's a 503 error and we haven't exhausted retries, continue the loop
                if error.code == 503 && attempt < maxRetries {
                    continue
                }
                
                // For all other errors or if we've exhausted retries, throw the error
                print("[Lecture] Network error occurred")
                print("[Lecture] Error code: \(error.code)")
                print("[Lecture] Error description: \(error.localizedDescription)")
                
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."])
                    case .notConnectedToInternet:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your connection and try again."])
                    default:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
                    }
                } else {
                    throw error
                }
            }
        } while attempt < maxRetries
    }
    
    private func generateRegularContentWithProgress() async throws {
        globalManager.updateProgress(step: "Generating content...", stepNumber: 1, totalSteps: 3)
        
        print("[Content] Starting content generation")
        
        // Try to wake up the backend first
        await MainActor.run {
            self.statusMessage = "Checking backend status..."
        }
        let backendReady = await wakeUpBackend()
        if !backendReady {
            print("[Content] Backend health check failed, proceeding anyway...")
        } else {
            print("[Content] Backend is ready")
        }
        
        print("[Content] Input text length: \(inputText.count)")
        print("[Content] Selected level: \(selectedLevel.rawValue)")
        print("[Content] Selected tier: \(selectedSummarizationTier.rawValue)")
        print("[Content] Selected image style: \(selectedImageStyle.displayName)")
        
        // Get user's FCM token for notifications
        let userToken = await getFCMToken()
        
        let requestBody: [String: Any] = [
            "input_text": inputText,
            "level": selectedLevel.rawValue,
            "summarization_tier": selectedSummarizationTier.rawValue,
            "profile": [
                "studentLevel": selectedLevel.rawValue,
                "topicsOfInterest": []
            ],
            "user_token": userToken ?? ""
        ]
        
        let url = URL(string: "\(backendURL)/process")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[Content] Sending request to backend")
        print("[Content] URL: \(url.absoluteString)")
        print("[Content] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "Unable to print request body")")
        
        // Add retry logic for 503 errors (backend hibernation)
        let maxRetries = 5  // Increased from 3 to 5 retries
        var attempt = 0
        
        repeat {
            attempt += 1
            print("[Content] Attempt \(attempt) of \(maxRetries)")
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[Content] ERROR: Invalid server response")
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                }
                
                print("[Content] Received response with status code: \(httpResponse.statusCode)")
                
                // Handle 503 errors (backend hibernation) with retry
                if httpResponse.statusCode == 503 {
                    if attempt < maxRetries {
                        let retryDelay = Double(attempt) * 4.0 // Increased from 2.0 to 4.0 seconds (4s, 8s, 12s, 16s, 20s)
                        print("[Content] Backend is hibernating (503). Retrying in \(retryDelay) seconds... (Attempt \(attempt)/\(maxRetries))")
                        await MainActor.run {
                            self.statusMessage = "Backend is starting up... Please wait (\(attempt)/\(maxRetries))"
                        }
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        print("[Content] Backend hibernation retry limit reached")
                        let hibernationError = NSError(domain: "BackendHibernation", code: 503, userInfo: [NSLocalizedDescriptionKey: "Backend is starting up. Please try again in a few moments."])
                        throw hibernationError
                    }
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("[Content] ERROR: Server returned status code \(httpResponse.statusCode)")
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("[Content] Error response from server: \(errorResponse)")
                    }
                    throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
                }
                
                let apiResponse = try JSONDecoder().decode(Response.self, from: data)
                
                // Start progress polling if we received a request_id
                if let requestId = apiResponse.request_id {
                    print("[Content] Received request_id: \(requestId), starting progress polling")
                    currentRequestId = requestId
                    startProgressPolling(requestId: requestId)
                } else {
                    startProgressPollingFallback()
                }
                
                if let blocks = apiResponse.blocks {
                    print("[Content] ✅ Successfully received content blocks from backend")
                    print("[Content] Number of blocks received: \(blocks.count)")
                    
                    // Update UI with blocks immediately
                    await MainActor.run {
                        self.blocks = blocks
                        print("[Content] Updated UI with received blocks")
                    }
                    
                    globalManager.updateProgress(step: "Processing images...", stepNumber: 2, totalSteps: 3)
                    
                    // Process images for blocks that have URLs
                    var updatedBlocks = blocks
                    let imageBlocks = blocks.enumerated().filter { $0.element.type == .image }
                    
                    if !imageBlocks.isEmpty {
                        print("[Content] Processing \(imageBlocks.count) image blocks")
                        
                        let baseStepNumber = 2
                        let totalSubSteps = imageBlocks.count * 3 // 3 sub-steps per image: download, convert, upload
                        var processedImageBlocks = 0
                        
                        for (index, block) in imageBlocks {
                            processedImageBlocks += 1
                            
                            if let imageUrlString = block.url,
                               let imageUrl = URL(string: imageUrlString) {
                                
                                print("[Content] Processing image block \(processedImageBlocks): \(imageUrlString)")
                                
                                // Sub-step 1: Download image
                                let subStep1 = baseStepNumber * 100 + (processedImageBlocks - 1) * 3 + 1
                                globalManager.updateProgress(
                                    step: "Downloading image for block \(processedImageBlocks)...",
                                    stepNumber: subStep1,
                                    totalSteps: totalSubSteps
                                )
                                
                                do {
                                    let (imageData, _) = try await session.data(from: imageUrl)
                                    print("[Content] ✅ Successfully downloaded image data. Size: \(imageData.count) bytes")
                                    
                                    if let image = UIImage(data: imageData),
                                       let userId = Auth.auth().currentUser?.uid {
                                        print("[Content] ✅ Converted existing image to UIImage. Size: \(image.size)")
                                        
                                        if let imageData = image.jpegData(compressionQuality: 0.8) {
                                            let fileName = "content_\(block.id.uuidString).jpg"
                                            print("[Content] 📁 Uploading existing image to Firebase Storage path: \(fileName)")
                                            
                                            // Sub-step 3: Upload to Firebase
                                            let subStep3 = baseStepNumber * 100 + (processedImageBlocks - 1) * 3 + 3
                                            globalManager.updateProgress(
                                                step: "Uploading image for block \(processedImageBlocks) to cloud...",
                                                stepNumber: subStep3,
                                                totalSteps: totalSubSteps
                                            )
                                            
                                            let downloadURL = try await uploadImageToFirebase(imageData: imageData, fileName: fileName, userId: userId)
                                            print("[Content] ✅ Successfully uploaded existing image to Firebase Storage.")
                                            print("[Content] 📥 Received Firebase Download URL: \(downloadURL.absoluteString)")
                                            
                                            updatedBlocks[index].firebaseImageUrl = downloadURL.absoluteString
                                            
                                        } else {
                                            print("[Content] ❌ Failed to convert image to JPEG data")
                                        }
                                    } else {
                                        print("[Content] ❌ Failed to convert image data to UIImage or get user ID")
                                    }
                                } catch {
                                    print("[Content] ❌ Error downloading image: \(error.localizedDescription)")
                                }
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
                
                // If we reach here, the request was successful, so break out of retry loop
                break
                
            } catch let error as NSError {
                // If it's a 503 error and we haven't exhausted retries, continue the loop
                if error.code == 503 && attempt < maxRetries {
                    continue
                }
                
                // For all other errors or if we've exhausted retries, throw the error
                print("[Content] Network error occurred")
                print("[Content] Error code: \(error.code)")
                print("[Content] Error description: \(error.localizedDescription)")
                
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."])
                    case .notConnectedToInternet:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your connection and try again."])
                    default:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
                    }
                } else {
                    throw error
                }
            }
        } while attempt < maxRetries
    }
    
    // MARK: - Firebase Storage
    
    private func generateImagesForStoryWithProgress(newStory: Story) async {
        let imageSize = CGSize(width: 800, height: 600) // This size is for the prompt, backend controls actual generation size.
        var updatedChapters = newStory.chapters
        let maxRetries = 3
        let totalChapters = newStory.chapters.count
        
        print("[Story][ImageGen] Starting image generation for story: \(newStory.title)")
        print("[Story][ImageGen] Story ID: \(newStory.id.uuidString)")
        print("[Story][ImageGen] Number of chapters: \(totalChapters)")
        print("[Story][ImageGen] Backend URL: \(backendURL)")
        
        // Enhanced progress tracking with sub-steps
        let baseStepNumber = 2 // We're in step 2 (image generation)
        let totalSubSteps = totalChapters * 3 // Each chapter has 3 sub-steps: check, process, upload
        
        for (index, chapter) in newStory.chapters.enumerated() {
            print("[Story][ImageGen] ========================================")
            print("[Story][ImageGen] Processing chapter \(index + 1)/\(totalChapters): '\(chapter.title)' (ID: \(chapter.id))")
            print("[Story][ImageGen] Chapter content length: \(chapter.content.count) characters")
            
            // Sub-step 1: Check for existing image
            let subStep1 = baseStepNumber * 100 + (index * 3) + 1
            globalManager.updateProgress(
                step: "Checking chapter \(index + 1) for existing image...",
                stepNumber: subStep1,
                totalSteps: totalSubSteps
            )
            
            // ✅ CHECK: Does this chapter already have an image from the backend?
            if let existingImageUrl = chapter.imageUrl {
                print("[Story][ImageGen] ✅ Chapter \(index + 1) already has image from backend: \(existingImageUrl)")
                
                // Sub-step 2: Download existing image
                let subStep2 = baseStepNumber * 100 + (index * 3) + 2
                globalManager.updateProgress(
                    step: "Downloading image for chapter \(index + 1)...",
                    stepNumber: subStep2,
                    totalSteps: totalSubSteps
                )
                
                // Download the existing image and upload to Firebase
                do {
                    print("[Story][ImageGen] 📥 Downloading existing image from backend URL...")
                    if let imageUrl = URL(string: existingImageUrl) {
                        let (imageData, imageResponse) = try await session.data(from: imageUrl)
                        
                        guard let httpImageResponse = imageResponse as? HTTPURLResponse,
                              httpImageResponse.statusCode == 200 else {
                            print("[Story][ImageGen] ❌ ERROR: Failed to download existing image from backend URL")
                            throw NSError(domain: "ImageDownloadError", code: (imageResponse as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download existing image"])
                        }
                        
                        print("[Story][ImageGen] ✅ Successfully downloaded existing image: \(imageData.count) bytes")
                        
                        if let image = UIImage(data: imageData),
                           let userId = Auth.auth().currentUser?.uid {
                            print("[Story][ImageGen] ✅ Converted existing image to UIImage. Size: \(image.size)")
                            
                            if let imageData = image.jpegData(compressionQuality: 0.8) {
                                let imagePath = "stories/\(userId)/\(newStory.id.uuidString)/\(chapter.id).jpg"
                                print("[Story][ImageGen] 📁 Uploading existing image to Firebase Storage path: \(imagePath)")
                                
                                // Sub-step 3: Upload to Firebase
                                let subStep3 = baseStepNumber * 100 + (index * 3) + 3
                                globalManager.updateProgress(
                                    step: "Uploading image for chapter \(index + 1) to cloud...",
                                    stepNumber: subStep3,
                                    totalSteps: totalSubSteps
                                )
                                
                                let metadata = StorageMetadata()
                                metadata.contentType = "image/jpeg"
                                metadata.customMetadata = [
                                    "storyId": newStory.id.uuidString,
                                    "chapterId": chapter.id,
                                    "chapterTitle": chapter.title,
                                    "uploadTimestamp": ISO8601DateFormatter().string(from: Date()),
                                    "source": "backend_generated" // Mark as from backend
                                ]
                                
                                let downloadURL = try await firestoreService.uploadImage(imageData, path: imagePath, metadata: metadata)
                                print("[Story][ImageGen] ✅ Successfully uploaded existing image to Firebase Storage.")
                                print("[Story][ImageGen] 📥 Received Firebase Download URL: \(downloadURL.absoluteString)")
                                
                                // Note: firebaseImageUrl is no longer part of the model, so we skip this update
                                
                                await MainActor.run {
                                    if var currentStory = self.currentStory, currentStory.chapters.indices.contains(index) {
                                        // Note: firebaseImageUrl is no longer part of the model
                                        self.currentStory = currentStory
                                        print("[Story][ImageGen] ✅ UI updated with existing image Firebase URL for chapter \(index + 1).")
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    print("[Story][ImageGen] ❌ ERROR processing existing image for chapter \(index + 1): \(error.localizedDescription)")
                    print("[Story][ImageGen] 🔄 Falling back to generate new image...")
                    // Fall through to generate new image if existing one fails
                }
            } else {
                print("[Story][ImageGen] 📝 Chapter \(index + 1) has no existing image, generating new one...")
                
                // Sub-step 2: Generate new image
                let subStep2 = baseStepNumber * 100 + (index * 3) + 2
                globalManager.updateProgress(
                    step: "Generating new image for chapter \(index + 1)...",
                    stepNumber: subStep2,
                    totalSteps: totalSubSteps
                )
                
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
                                
                                let imagePath = "stories/\(userId)/\(newStory.id.uuidString)/\(chapter.id).jpg"
                                print("[Story][ImageGen] 📁 Preparing to upload image to Firebase Storage path: \(imagePath)")
                                
                                // Sub-step 3: Upload to Firebase
                                let subStep3 = baseStepNumber * 100 + (index * 3) + 3
                                globalManager.updateProgress(
                                    step: "Uploading new image for chapter \(index + 1) to cloud...",
                                    stepNumber: subStep3,
                                    totalSteps: totalSubSteps
                                )
                                
                                let metadata = StorageMetadata()
                                metadata.contentType = "image/jpeg"
                                // Using unique keys for custom metadata to avoid any potential conflicts
                                metadata.customMetadata = [
                                    "storyId": newStory.id.uuidString,
                                    "chapterId": chapter.id,
                                    "chapterTitle": chapter.title,
                                    "uploadTimestamp": ISO8601DateFormatter().string(from: Date()), // Changed key from "uploadDate"
                                    "source": "frontend_generated" // Mark as from frontend
                                ]
                                
                                print("[Story][ImageGen] Firebase Storage Metadata for chapter \(index + 1):")
                                print("[Story][ImageGen] - ContentType: \(metadata.contentType ?? "Not set")")
                                print("[Story][ImageGen] - CustomMetadata: \(metadata.customMetadata ?? [:])")
                                
                                // Assuming firestoreService.uploadImage is the corrected version from previous steps
                                print("[Story][ImageGen] 🔄 Uploading image to Firebase Storage...")
                                let downloadURL = try await firestoreService.uploadImage(imageData, path: imagePath, metadata: metadata)
                                print("[Story][ImageGen] ✅ Successfully uploaded image for chapter \(index + 1) to Firebase Storage.")
                                print("[Story][ImageGen] 📥 Received Firebase Download URL: \(downloadURL.absoluteString)")
                                
                                // Note: firebaseImageUrl is no longer part of the model, so we skip this update
                                success = true
                                
                                await MainActor.run {
                                    if var currentStory = self.currentStory, currentStory.chapters.indices.contains(index) {
                                        // Note: firebaseImageUrl is no longer part of the model
                                        self.currentStory = currentStory // Update the published property
                                        print("[Story][ImageGen] ✅ UI updated with new image for chapter \(index + 1).")
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
                            let errorMessageText = "Failed to process image for chapter '\(chapter.title)' (ID: \(chapter.id)) after \(maxRetries) attempts: \(error.localizedDescription)"
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
                     print("[Story][ImageGen] ⚠️ WARNING: Failed to process image for chapter \(index + 1) ('\(chapter.title)') after all retries. It will not have an image.")
                } else {
                    print("[Story][ImageGen] ✅ SUCCESS: Chapter \(index + 1) image processed successfully!")
                }
            }
            print("[Story][ImageGen] ========================================")
        }
        
        // Ensure the story being saved has the updated chapter image URLs
        var finalStoryToSave = newStory // Start with original story structure
        finalStoryToSave.chapters = updatedChapters // Assign chapters that have been processed
        
        print("[Story][ImageGen] 📊 Final image generation summary:")
        for (index, chapter) in finalStoryToSave.chapters.enumerated() {
            print("[Story][ImageGen] - Chapter \(index + 1): \(chapter.imageUrl != nil ? "✅ Has image" : "❌ No image")")
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
        print("[Story][Save] Number of main characters: \(story.mainCharacters?.count ?? 0)")
        print("[Story][Save] Cover image URL: \(story.coverImageUrl ?? "NIL")")
        print("[Story][Save] Summary image URL: \(story.summaryImageUrl ?? "NIL")")
        
        // Log chapter details before conversion
        print("[Story][Save] 📋 Chapter details before Firebase conversion:")
        for (index, chapter) in story.chapters.enumerated() {
            print("[Story][Save] - Chapter \(index + 1):")
            print("[Story][Save]   - ID: \(chapter.id)")
            print("[Story][Save]   - Title: \(chapter.title)")
            print("[Story][Save]   - Order: \(chapter.order)")
            print("[Story][Save]   - Main image URL: \(chapter.imageUrl ?? "NIL")")
            print("[Story][Save]   - Setting image URL: \(chapter.settingImageUrl ?? "NIL")")
            print("[Story][Save]   - Action image URL: \(chapter.actionImageUrl ?? "NIL")")
            print("[Story][Save]   - Key events: \(chapter.keyEvents?.count ?? 0)")
            print("[Story][Save]   - Key event images: \(chapter.keyEventImages?.count ?? 0)")
            print("[Story][Save]   - Character interactions: \(chapter.characterInteractions?.count ?? 0)")
            print("[Story][Save]   - Character interaction images: \(chapter.characterInteractionImages?.count ?? 0)")
            print("[Story][Save]   - Emotional moments: \(chapter.emotionalMoments?.count ?? 0)")
            print("[Story][Save]   - Emotional moment images: \(chapter.emotionalMomentImages?.count ?? 0)")
        }
        
        // Convert main characters to Firebase format
        let firebaseCharacters = story.mainCharacters?.map { character in
            FirebaseCharacter(
                id: character.id.uuidString,
                name: character.name,
                description: character.description,
                personality: character.personality,
                imageUrl: character.imageUrl
            )
        }
        
        // Convert chapters to Firebase format with new image structure
        let firebaseChapters = story.chapters.map { chapter in
            // Convert event images to Firebase format
            let firebaseKeyEventImages = chapter.keyEventImages?.map { eventImage in
                FirebaseEventImage(
                    id: eventImage.id,
                    description: eventImage.description,
                    imageUrl: eventImage.imageUrl
                )
            }
            
            let firebaseEmotionalMomentImages = chapter.emotionalMomentImages?.map { momentImage in
                FirebaseEventImage(
                    id: momentImage.id,
                    description: momentImage.description,
                    imageUrl: momentImage.imageUrl
                )
            }
            
            let firebaseCharacterInteractionImages = chapter.characterInteractionImages?.map { interactionImage in
                FirebaseEventImage(
                    id: interactionImage.id,
                    description: interactionImage.description,
                    imageUrl: interactionImage.imageUrl
                )
            }
            
            return FirebaseChapter(
                id: chapter.id,
                title: chapter.title,
                content: chapter.content,
                order: chapter.order,
                imageUrl: chapter.imageUrl,
                keyEvents: chapter.keyEvents,
                characterInteractions: chapter.characterInteractions,
                emotionalMoments: chapter.emotionalMoments,
                keyEventImages: firebaseKeyEventImages,
                emotionalMomentImages: firebaseEmotionalMomentImages,
                characterInteractionImages: firebaseCharacterInteractionImages,
                settingImageUrl: chapter.settingImageUrl,
                actionImageUrl: chapter.actionImageUrl
            )
        }
        
        // Convert to Firebase format using the correct models
        let firebaseStory = FirebaseStory(
            id: story.id.uuidString,
            userId: userId,
            title: story.title,
            overview: story.content,
            level: story.level.rawValue,
            imageStyle: story.imageStyle,
            chapters: firebaseChapters,
            mainCharacters: firebaseCharacters,
            coverImageUrl: story.coverImageUrl,
            summaryImageUrl: story.summaryImageUrl
        )
        
        // Log Firebase story details
        print("[Story][Save] 📋 Firebase story details:")
        print("[Story][Save] - ID: \(firebaseStory.id ?? "NIL")")
        print("[Story][Save] - Title: \(firebaseStory.title)")
        print("[Story][Save] - User ID: \(firebaseStory.userId)")
        print("[Story][Save] - Level: \(firebaseStory.level)")
        print("[Story][Save] - Image Style: \(firebaseStory.imageStyle ?? "N/A")")
        print("[Story][Save] - Cover Image URL: \(firebaseStory.coverImageUrl ?? "NIL")")
        print("[Story][Save] - Summary Image URL: \(firebaseStory.summaryImageUrl ?? "NIL")")
        print("[Story][Save] - Number of chapters: \(firebaseStory.chapters?.count ?? 0)")
        print("[Story][Save] - Number of main characters: \(firebaseStory.mainCharacters?.count ?? 0)")
        
        if let chapters = firebaseStory.chapters {
            print("[Story][Save] 📋 Firebase chapter details:")
            for (index, chapter) in chapters.enumerated() {
                print("[Story][Save] - Chapter \(index + 1):")
                print("[Story][Save]   - id: \(chapter.id)")
                print("[Story][Save]   - title: \(chapter.title)")
                print("[Story][Save]   - order: \(chapter.order)")
                print("[Story][Save]   - main image URL: \(chapter.imageUrl ?? "NIL")")
                print("[Story][Save]   - setting image URL: \(chapter.settingImageUrl ?? "NIL")")
                print("[Story][Save]   - action image URL: \(chapter.actionImageUrl ?? "NIL")")
                print("[Story][Save]   - key events: \(chapter.keyEvents?.count ?? 0)")
                print("[Story][Save]   - key event images: \(chapter.keyEventImages?.count ?? 0)")
                print("[Story][Save]   - character interactions: \(chapter.characterInteractions?.count ?? 0)")
                print("[Story][Save]   - character interaction images: \(chapter.characterInteractionImages?.count ?? 0)")
                print("[Story][Save]   - emotional moments: \(chapter.emotionalMoments?.count ?? 0)")
                print("[Story][Save]   - emotional moment images: \(chapter.emotionalMomentImages?.count ?? 0)")
            }
        }
        
        if let characters = firebaseStory.mainCharacters {
            print("[Story][Save] 📋 Firebase character details:")
            for (index, character) in characters.enumerated() {
                print("[Story][Save] - Character \(index + 1):")
                print("[Story][Save]   - id: \(character.id)")
                print("[Story][Save]   - name: \(character.name)")
                print("[Story][Save]   - description: \(character.description)")
                print("[Story][Save]   - personality: \(character.personality)")
                print("[Story][Save]   - imageUrl: \(character.imageUrl ?? "NIL")")
            }
        }
        
        do {
            print("[Story][Save] 🔄 Attempting to create story document in Firestore. Collection: 'stories', DocumentID to be used by service: \(story.id.uuidString)")
            let documentId = try await firestoreService.create(firebaseStory, in: "stories", documentId: story.id.uuidString)
            print("[Story][Save] ✅ Successfully saved story to Firestore with document ID: \(documentId)")
            
            // Track story generation for engagement metrics
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
            
            // Track content generation for engagement metrics
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
                let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response type"])
                
                CrashlyticsManager.shared.logImageGenerationError(
                    error: error,
                    prompt: imagePrompt,
                    style: selectedImageStyle.displayName,
                    size: "800x600"
                )
                
                print("[Image] ERROR: Invalid server response")
                return nil
            }
            
            print("[Image] Received response with status code: \(httpResponse.statusCode)")
            print("[Image] Response headers: \(httpResponse.allHeaderFields)")
            
            guard httpResponse.statusCode == 200 else {
                let serverError = NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
                
                CrashlyticsManager.shared.logImageGenerationError(
                    error: serverError,
                    prompt: imagePrompt,
                    style: selectedImageStyle.displayName,
                    size: "800x600"
                )
                
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
                
                CrashlyticsManager.shared.logCustomError(
                    error: error,
                    context: "image_response_decoding",
                    additionalData: [
                        "endpoint": "/generate_image",
                        "response_size": data.count,
                        "response_preview": String(data: data.prefix(200), encoding: .utf8) ?? "unable_to_decode",
                        "prompt": imagePrompt.prefix(100),
                        "style": selectedImageStyle.displayName
                    ]
                )
                
                return nil
            }
            
            if let imageUrlString = imageResponse.imageUrl, let imageUrl = URL(string: imageUrlString) {
                print("[Image] Successfully generated image URL: \(imageUrlString)")
                
                // Download the image
                print("[Image] Downloading image from: \(imageUrl.absoluteString)")
                let (imageData, imageResponse) = try await session.data(from: imageUrl)
                
                guard let httpImageResponse = imageResponse as? HTTPURLResponse,
                      httpImageResponse.statusCode == 200 else {
                    let downloadError = NSError(domain: "ImageDownloadError", code: (imageResponse as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download image"])
                    
                    CrashlyticsManager.shared.logCustomError(
                        error: downloadError,
                        context: "image_download_failed",
                        additionalData: [
                            "image_url": imageUrlString,
                            "status_code": (imageResponse as? HTTPURLResponse)?.statusCode ?? -1,
                            "prompt": imagePrompt.prefix(100)
                        ]
                    )
                    
                    print("[Image] ERROR: Failed to download image")
                    print("[Image] Image response status: \((imageResponse as? HTTPURLResponse)?.statusCode ?? -1)")
                    return nil
                }
                
                print("[Image] Successfully downloaded image data: \(imageData.count) bytes")
                
                guard let image = UIImage(data: imageData) else {
                    let imageCreationError = NSError(domain: "ImageCreationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create UIImage from data"])
                    
                    CrashlyticsManager.shared.logCustomError(
                        error: imageCreationError,
                        context: "image_creation_failed",
                        additionalData: [
                            "image_data_size": imageData.count,
                            "prompt": imagePrompt.prefix(100)
                        ]
                    )
                    
                    print("[Image] ERROR: Failed to create UIImage from data")
                    return nil
                }
                
                print("[Image] Successfully downloaded and created image. Size: \(image.size)")
                return image
            } else {
                print("[Image] ERROR: No image URL in response")
                if let error = imageResponse.error {
                    print("[Image] Backend error: \(error)")
                    
                    let backendError = NSError(domain: "ImageGenerationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend error: \(error)"])
                    
                    CrashlyticsManager.shared.logImageGenerationError(
                        error: backendError,
                        prompt: imagePrompt,
                        style: selectedImageStyle.displayName,
                        size: "800x600"
                    )
                }
                print("[Image] Full response object: \(imageResponse)")
                return nil
            }
            
        } catch {
            print("[Image] ERROR: Failed to generate image: \(error.localizedDescription)")
            print("[Image] Error type: \(type(of: error))")
            print("[Image] Full error: \(error)")
            
            CrashlyticsManager.shared.logImageGenerationError(
                error: error,
                prompt: imagePrompt,
                style: selectedImageStyle.displayName,
                size: "800x600"
            )
            
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
    
    // MARK: - Missing Helper Methods
    
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

    private func handleContentGenerationError(_ error: Error) {
        print("[Story] Content generation error: \(error.localizedDescription)")
        
        let errorMessage: String
        if let contentError = error as? ContentGenerationError {
            switch contentError {
            case .encodingFailed:
                errorMessage = "Failed to prepare request. Please try again."
            case .invalidResponse:
                errorMessage = "Received invalid response from server. Please try again."
            case .backendError(let message):
                errorMessage = message
            case .httpError(let code):
                if code == 503 {
                    errorMessage = "Backend service is starting up. Please wait a moment and try again."
                } else {
                    errorMessage = "Server error (HTTP \(code)). Please try again later."
                }
            case .parsingFailed:
                errorMessage = "Failed to process server response. Please try again."
            case .networkError(let underlyingError):
                let nsError = underlyingError as NSError
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorTimedOut:
                        errorMessage = "Request timed out. Please check your internet connection and try again."
                    case NSURLErrorNotConnectedToInternet:
                        errorMessage = "No internet connection. Please check your network settings."
                    case NSURLErrorCannotConnectToHost:
                        errorMessage = "Cannot connect to server. Please try again later."
                    default:
                        errorMessage = "Network error. Please check your connection and try again."
                    }
                } else {
                    errorMessage = "Network error: \(underlyingError.localizedDescription)"
                }
            }
        } else {
            errorMessage = "An unexpected error occurred. Please try again."
        }
        
        Task { @MainActor in
            self.statusMessage = errorMessage
            self.isGenerating = false
            
            // Log to Crashlytics if available
            #if DEBUG
            print("[Crashlytics] Content generation error logged: \(errorMessage)")
            #endif
        }
    }

    func generateStory() {
        guard !isGenerating else { return }
        
        Task {
            await MainActor.run {
                self.isGenerating = true
                self.statusMessage = "Preparing story generation..."
            }
            
            do {
                try await generateStoryWithProgress()
            } catch {
                handleContentGenerationError(error)
            }
        }
    }
    
    private func generateComicWithProgress() async throws {
        globalManager.updateProgress(step: "Generating comic content...", stepNumber: 1, totalSteps: 2)
        
        print("[Comic] Starting comic generation process")
        
        // Try to wake up the backend first
        await MainActor.run {
            self.statusMessage = "Checking backend status..."
        }
        let backendReady = await wakeUpBackend()
        if !backendReady {
            print("[Comic] Backend health check failed, proceeding anyway...")
        } else {
            print("[Comic] Backend is ready")
        }
        
        print("[Comic] Input text length: \(inputText.count)")
        print("[Comic] Selected level: \(selectedLevel.rawValue)")
        print("[Comic] Selected image style: \(selectedImageStyle.displayName)")
        
        // Get user's FCM token for notifications
        let userToken = await getFCMToken()
        
        let requestBody: [String: Any] = [
            "text": inputText,
            "level": selectedLevel.rawValue,
            "image_style": selectedImageStyle.displayName,
            "user_token": userToken ?? ""
        ]
        
        let url = URL(string: "\(backendURL)/generate_comic")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("[Comic] Sending request to backend (/generate_comic)")
        
        // Add retry logic for 503 errors (backend hibernation)
        let maxRetries = 5
        var attempt = 0
        
        repeat {
            attempt += 1
            print("[Comic] Attempt \(attempt) of \(maxRetries)")
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("[Comic] ERROR: Invalid server response")
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                }
                
                print("[Comic] Received response with status code: \(httpResponse.statusCode)")
                
                // Handle 503 errors (backend hibernation) with retry
                if httpResponse.statusCode == 503 {
                    if attempt < maxRetries {
                        let retryDelay = Double(attempt) * 4.0
                        print("[Comic] Backend is hibernating (503). Retrying in \(retryDelay) seconds... (Attempt \(attempt)/\(maxRetries))")
                        await MainActor.run {
                            self.statusMessage = "Backend is starting up... Please wait (\(attempt)/\(maxRetries))"
                        }
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        print("[Comic] Backend hibernation retry limit reached")
                        let hibernationError = NSError(domain: "BackendHibernation", code: 503, userInfo: [NSLocalizedDescriptionKey: "Backend is starting up. Please try again in a few moments."])
                        throw hibernationError
                    }
                }
                
                guard httpResponse.statusCode == 200 else {
                    print("[Comic] ERROR: Server returned status code \(httpResponse.statusCode)")
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("[Comic] Error response from server: \(errorResponse)")
                    }
                    throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)"])
                }
                
                let apiResponse = try JSONDecoder().decode(ComicResponse.self, from: data)
                print("[Comic] Successfully decoded ComicResponse")
                
                // Start progress polling if we received a request_id
                if let requestId = apiResponse.request_id {
                    print("[Comic] Received request_id: \(requestId), starting progress polling")
                    currentRequestId = requestId
                    startProgressPolling(requestId: requestId)
                } else {
                    startProgressPollingFallback()
                }
                
                if let comic = apiResponse.comic {
                    print("[Comic] Successfully received comic from backend")
                    print("[Comic] Comic Title: \(comic.comicTitle)")
                    print("[Comic] Number of panels: \(comic.panelLayout.count)")
                    
                    await MainActor.run {
                        self.currentComic = comic
                        print("[Comic] Updated UI with comic object")
                        globalManager.setLastGeneratedContent(type: .comic, id: comic.id.uuidString, title: comic.comicTitle)
                        globalManager.setRecentlyGeneratedContent(comic: comic)
                    }
                    
                    globalManager.updateProgress(step: "Saving to cloud...", stepNumber: 2, totalSteps: 2)
                    
                    if let currentUser = Auth.auth().currentUser {
                        print("[Comic] User authenticated (\(currentUser.uid)), proceeding with Firebase save for comic ID \(comic.id.uuidString)")
                        
                        // Save comic to Firebase
                        await saveComicToFirebase(comic, userId: currentUser.uid)
                        
                        print("[Comic] Comic content processing completed.")
                    } else {
                        print("[Comic] ERROR: No authenticated user found after receiving comic. Cannot save.")
                        throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                    }
                } else if let error = apiResponse.error {
                    print("[Comic] ERROR: Backend returned error: \(error)")
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
                }
                
                // If we reach here, the request was successful, so break out of retry loop
                break
                
            } catch let error as NSError {
                // If it's a 503 error and we haven't exhausted retries, continue the loop
                if error.code == 503 && attempt < maxRetries {
                    continue
                }
                
                // For all other errors or if we've exhausted retries, throw the error
                print("[Comic] Network error occurred")
                print("[Comic] Error code: \(error.code)")
                print("[Comic] Error description: \(error.localizedDescription)")
                
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request timed out. Please try again."])
                    case .notConnectedToInternet:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your connection and try again."])
                    default:
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"])
                    }
                } else {
                    throw error
                }
            }
        } while attempt < maxRetries
    }
    
    private func saveComicToFirebase(_ comic: Comic, userId: String) async {
        print("[Comic][Save] Starting Firebase save process for comic")
        print("[Comic][Save] Comic ID: \(comic.id.uuidString)")
        print("[Comic][Save] Comic Title: \(comic.comicTitle)")
        print("[Comic][Save] User ID: \(userId)")
        
        // Convert to Firebase format
        let firebaseComic = FirebaseComic(
            id: comic.id.uuidString,
            userId: userId,
            comicTitle: comic.comicTitle,
            theme: comic.theme,
            characterStyleGuide: comic.characterStyleGuide,
            panelLayout: comic.panelLayout.map { panel in
                FirebaseComicPanel(
                    panelId: panel.panelId,
                    scene: panel.scene,
                    imagePrompt: panel.imagePrompt,
                    dialogue: panel.dialogue,
                    imageUrl: panel.imageUrl
                )
            },
            createdAt: Timestamp(date: Date())
        )
        
        do {
            print("[Comic][Save] Attempting to create comic document in Firestore. Collection: 'comics', DocumentID: \(comic.id.uuidString)")
            let documentId = try await firestoreService.create(firebaseComic, in: "comics", documentId: comic.id.uuidString)
            print("[Comic][Save] Successfully saved comic to Firestore with document ID: \(documentId)")
            await MainActor.run {
                let currentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
                UserDefaults.standard.set(currentCount + 1, forKey: "contentGenerationCount")
                print("[Engagement] Comic generation tracked. Total: \(currentCount + 1)")
            }
            
            // Send success notification
            await NotificationManager.shared.sendContentGenerationSuccess(contentType: "comic", level: selectedLevel.rawValue)
            
        } catch {
            print("[Comic][Save] ERROR: Failed to save comic to Firestore for comic ID \(comic.id.uuidString).")
            print("[Comic][Save] Error Type: \(type(of: error))")
            print("[Comic][Save] Error Description: \(error.localizedDescription)")
            print("[Comic][Save] Full Error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to save comic to cloud: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Types

enum ReadingLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case moderate = "moderate"
    case intermediate = "intermediate"
}

enum SummarizationTier: String, Codable, CaseIterable {
    case detailedExplanation = "Detailed Explanation"
    case story = "Story"
    case lecture = "Lecture"
    case comic = "Comic"
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
    let request_id: String?
}

// MARK: - Lecture Response Models
struct LectureResponse: Codable {
    let lecture: BackendLecture?
    let audio_files: [BackendAudioFile]?
    let lecture_id: String
    let error: String?
    let request_id: String?
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
    let mainCharacters: [StoryCharacter]? // New: Main characters with descriptions
    let coverImageUrl: String? // New: Story cover/hero image
    let summaryImageUrl: String? // New: Story conclusion/summary image

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case level
        case chapters
        case imageStyle // Ensure this matches the JSON key from the backend if it sends one for the story's overall style
        case mainCharacters
        case coverImageUrl
        case summaryImageUrl
    }

    init(id: UUID = UUID(), title: String, content: String, level: ReadingLevel, chapters: [StoryChapter], imageStyle: String? = nil, mainCharacters: [StoryCharacter]? = nil, coverImageUrl: String? = nil, summaryImageUrl: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.level = level
        self.chapters = chapters
        self.imageStyle = imageStyle
        self.mainCharacters = mainCharacters
        self.coverImageUrl = coverImageUrl
        self.summaryImageUrl = summaryImageUrl
    }
}

struct StoryChapter: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let content: String
    let order: Int
    let imageUrl: String? // Main chapter image
    let keyEvents: [String]? // Key events in this chapter
    let characterInteractions: [String]? // Character interactions in this chapter
    let emotionalMoments: [String]? // Emotional moments in this chapter
    
    // New: Multiple images for different aspects
    let keyEventImages: [StoryEventImage]? // Multiple images for key events
    let emotionalMomentImages: [StoryEventImage]? // Multiple images for emotional moments
    let characterInteractionImages: [StoryEventImage]? // Multiple images for character interactions
    let settingImageUrl: String? // Setting/background image
    let actionImageUrl: String? // Action sequence image

    enum CodingKeys: String, CodingKey {
        case id
        case chapterId
        case title
        case content
        case order
        case imageUrl
        case firebaseImageUrl
        case keyEvents
        case characterInteractions
        case emotionalMoments
        case keyEventImages
        case emotionalMomentImages
        case characterInteractionImages
        case settingImageUrl
        case actionImageUrl
    }

    init(id: String = UUID().uuidString, title: String, content: String, order: Int, imageUrl: String? = nil, keyEvents: [String]? = nil, characterInteractions: [String]? = nil, emotionalMoments: [String]? = nil, keyEventImages: [StoryEventImage]? = nil, emotionalMomentImages: [StoryEventImage]? = nil, characterInteractionImages: [StoryEventImage]? = nil, settingImageUrl: String? = nil, actionImageUrl: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.imageUrl = imageUrl
        self.keyEvents = keyEvents
        self.characterInteractions = characterInteractions
        self.emotionalMoments = emotionalMoments
        self.keyEventImages = keyEventImages
        self.emotionalMomentImages = emotionalMomentImages
        self.characterInteractionImages = characterInteractionImages
        self.settingImageUrl = settingImageUrl
        self.actionImageUrl = actionImageUrl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(order, forKey: .order)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(keyEvents, forKey: .keyEvents)
        try container.encodeIfPresent(characterInteractions, forKey: .characterInteractions)
        try container.encodeIfPresent(emotionalMoments, forKey: .emotionalMoments)
        try container.encodeIfPresent(keyEventImages, forKey: .keyEventImages)
        try container.encodeIfPresent(emotionalMomentImages, forKey: .emotionalMomentImages)
        try container.encodeIfPresent(characterInteractionImages, forKey: .characterInteractionImages)
        try container.encodeIfPresent(settingImageUrl, forKey: .settingImageUrl)
        try container.encodeIfPresent(actionImageUrl, forKey: .actionImageUrl)
    }
}

// New: Structure for event images with descriptions
struct StoryEventImage: Identifiable, Codable, Equatable {
    let id: String
    let description: String // Event description or moment description
    let imageUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case description
        case imageUrl
    }
    
    // For key events
    init(event: String, imageUrl: String) {
        self.id = UUID().uuidString
        self.description = event
        self.imageUrl = imageUrl
    }
    
    // For emotional moments
    init(moment: String, imageUrl: String) {
        self.id = UUID().uuidString
        self.description = moment
        self.imageUrl = imageUrl
    }
    
    // For character interactions
    init(interaction: String, imageUrl: String) {
        self.id = UUID().uuidString
        self.description = interaction
        self.imageUrl = imageUrl
    }
    
    // Custom initializer for decoding
    init(id: String, description: String, imageUrl: String) {
        self.id = id
        self.description = description
        self.imageUrl = imageUrl
    }
}

struct ContentBlock: Identifiable, Codable {
    let id: UUID
    let type: BlockType
    let content: String?
    let alt: String?
    var firebaseImageUrl: String?
    let url: String? // Direct GCS URL that the Python backend adds for image blocks
    let options: [QuizOption]?
    let correctAnswerID: String?
    let explanation: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case content
        case alt
        case url // Key for the GCS URL added by Python backend
        case options
        case correctAnswerID
        case explanation
        // firebaseImageUrl is not decoded from this JSON
    }
    
    // Custom decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let idString = try container.decodeIfPresent(String.self, forKey: .id),
           let parsedUUID = UUID(uuidString: idString) {
            self.id = parsedUUID
        } else {
            print("[ContentBlock.decoder] Warning: Block 'id' missing or invalid in JSON. Generating new client-side UUID.")
            self.id = UUID()
        }
        
        self.type = try container.decode(BlockType.self, forKey: .type)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.alt = try container.decodeIfPresent(String.self, forKey: .alt)
        self.url = try container.decodeIfPresent(String.self, forKey: .url) // Catches the GCS URL
        self.options = try container.decodeIfPresent([QuizOption].self, forKey: .options)
        self.correctAnswerID = try container.decodeIfPresent(String.self, forKey: .correctAnswerID)
        self.explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        
        // firebaseImageUrl is not set during this initial decoding from backend
        self.firebaseImageUrl = nil
    }
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
    private func writeDataToTempFile(_ data: Data, fileName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }

    private func sendBackgroundCompletionNotification(type: String) {
        let content = UNMutableNotificationContent()
        content.title = "Liroo: \(type) Generation Complete"
        content.body = "Your \(type.lowercased()) is ready!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
} 

// Story Character model
struct StoryCharacter: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let personality: String
    let imageUrl: String? // Character portrait image
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case personality
        case imageUrl
    }
    
    init(name: String, description: String, personality: String, imageUrl: String? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.personality = personality
        self.imageUrl = imageUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = UUID() // Generate new UUID for each character
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown Character"
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? "No description available"
        self.personality = try container.decodeIfPresent(String.self, forKey: .personality) ?? "No personality traits described"
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    }
}

// Custom decoders for Story and StoryChapter to handle the new image structure
extension Story {
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
        do {
            self.level = try container.decode(ReadingLevel.self, forKey: .level)
        } catch {
            print("[Story.decoder] Warning: Story 'level' missing or invalid in JSON. Defaulting to .moderate. Error: \(error)")
            self.level = .moderate // Default if level is missing or unparsable
        }

        self.chapters = try container.decodeIfPresent([StoryChapter].self, forKey: .chapters) ?? []
        self.imageStyle = try container.decodeIfPresent(String.self, forKey: .imageStyle)
        self.mainCharacters = try container.decodeIfPresent([StoryCharacter].self, forKey: .mainCharacters)
        self.coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        self.summaryImageUrl = try container.decodeIfPresent(String.self, forKey: .summaryImageUrl)
    }
}

extension StoryChapter {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idString = try container.decodeIfPresent(String.self, forKey: .id) {
            self.id = idString
        } else if let chapterIdString = try container.decodeIfPresent(String.self, forKey: .chapterId) {
            self.id = chapterIdString
        } else {
            print("[StoryChapter.decoder] Warning: Chapter 'id' and 'chapterId' missing or invalid in JSON. Generating new client-side UUID.")
            self.id = UUID().uuidString
        }
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Chapter"
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? "No content for this chapter."
        self.order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        // Robust imageUrl decoding
        if let imageUrlValue = try container.decodeIfPresent(String.self, forKey: .imageUrl) {
            self.imageUrl = imageUrlValue
        } else if let firebaseImageUrlValue = try container.decodeIfPresent(String.self, forKey: .firebaseImageUrl) {
            self.imageUrl = firebaseImageUrlValue
        } else {
            self.imageUrl = nil
        }
        self.keyEvents = try container.decodeIfPresent([String].self, forKey: .keyEvents)
        self.characterInteractions = try container.decodeIfPresent([String].self, forKey: .characterInteractions)
        self.emotionalMoments = try container.decodeIfPresent([String].self, forKey: .emotionalMoments)
        self.keyEventImages = try container.decodeIfPresent([StoryEventImage].self, forKey: .keyEventImages)
        self.emotionalMomentImages = try container.decodeIfPresent([StoryEventImage].self, forKey: .emotionalMomentImages)
        self.characterInteractionImages = try container.decodeIfPresent([StoryEventImage].self, forKey: .characterInteractionImages)
        self.settingImageUrl = try container.decodeIfPresent(String.self, forKey: .settingImageUrl)
        self.actionImageUrl = try container.decodeIfPresent(String.self, forKey: .actionImageUrl)
    }
}

// MARK: - Content Generation Error Types
enum ContentGenerationError: Error, LocalizedError {
    case encodingFailed
    case invalidResponse
    case backendError(String)
    case httpError(Int)
    case parsingFailed
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode request data"
        case .invalidResponse:
            return "Invalid response from server"
        case .backendError(let message):
            return "Backend error: \(message)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .parsingFailed:
            return "Failed to parse response data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
} 
