import Foundation
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import FirebaseCrashlytics

@MainActor
class BackgroundTaskCompletionService: ObservableObject {
    static let shared = BackgroundTaskCompletionService()
    
    private let db = Firestore.firestore()
    private let globalManager = GlobalBackgroundProcessingManager.shared
    private let notificationManager = NotificationManager.shared
    
    @Published var pendingTasks: [String: BackgroundTask] = [:]
    @Published var isCheckingTasks = false
    
    private var taskCheckTimer: Timer?
    
    private init() {
        setupTaskChecking()
    }
    
    // MARK: - Background Task Model
    struct BackgroundTask: Codable, Identifiable {
        let id: String
        let status: String
        let createdAt: Date
        let completedAt: Date?
        let resultData: [String: Any]?
        let errorMessage: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case status
            case createdAt = "created_at"
            case completedAt = "completed_at"
            case resultData = "result_data"
            case errorMessage = "error_message"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            status = try container.decode(String.self, forKey: .status)
            
            let createdAtString = try container.decode(String.self, forKey: .createdAt)
            createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
            
            if let completedAtString = try container.decodeIfPresent(String.self, forKey: .completedAt) {
                completedAt = ISO8601DateFormatter().date(from: completedAtString)
            } else {
                completedAt = nil
            }
            
            resultData = try container.decodeIfPresent([String: Any].self, forKey: .resultData)
            errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        }
    }
    
    // MARK: - Setup and Configuration
    private func setupTaskChecking() {
        // Check for pending tasks every 30 seconds when app is active
        taskCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkPendingTasks()
            }
        }
        
        // Initial check when service starts
        Task {
            await checkPendingTasks()
        }
    }
    
    // MARK: - Task Management
    func addPendingTask(_ requestId: String) {
        pendingTasks[requestId] = BackgroundTask(
            id: requestId,
            status: "started",
            createdAt: Date(),
            completedAt: nil,
            resultData: nil,
            errorMessage: nil
        )
        
        print("[BackgroundTaskService] Added pending task: \(requestId)")
    }
    
    func removePendingTask(_ requestId: String) {
        pendingTasks.removeValue(forKey: requestId)
        print("[BackgroundTaskService] Removed pending task: \(requestId)")
    }
    
    // MARK: - Firebase Status Checking
    func checkPendingTasks() async {
        guard !pendingTasks.isEmpty else { return }
        
        isCheckingTasks = true
        print("[BackgroundTaskService] Checking \(pendingTasks.count) pending tasks...")
        
        for (requestId, _) in pendingTasks {
            await checkTaskStatus(requestId: requestId)
        }
        
        isCheckingTasks = false
    }
    
    private func checkTaskStatus(requestId: String) async {
        do {
            let document = try await db.collection("background_tasks").document(requestId).getDocument()
            
            guard document.exists,
                  let data = document.data() else {
                print("[BackgroundTaskService] Task \(requestId) not found in Firebase")
                return
            }
            
            let status = data["status"] as? String ?? "unknown"
            print("[BackgroundTaskService] Task \(requestId) status: \(status)")
            
            switch status {
            case "completed":
                await handleTaskCompletion(requestId: requestId, data: data)
            case "failed":
                await handleTaskFailure(requestId: requestId, data: data)
            case "processing":
                // Task is still running, update progress if available
                await updateProgressFromFirebase(requestId: requestId, data: data)
            default:
                print("[BackgroundTaskService] Unknown task status: \(status)")
            }
            
        } catch {
            print("[BackgroundTaskService] Error checking task status: \(error.localizedDescription)")
            CrashlyticsManager.shared.logCustomError(
                error: error,
                context: "background_task_status_check",
                additionalData: ["request_id": requestId]
            )
        }
    }
    
    private func handleTaskCompletion(requestId: String, data: [String: Any]) async {
        print("[BackgroundTaskService] Task \(requestId) completed successfully")
        
        // Get result data
        let resultData = data["result_data"] as? [String: Any]
        let completedAt = data["completed_at"] as? String
        
        // Update global manager
        globalManager.endBackgroundTask()
        
        // Send completion notification
        await sendCompletionNotification(requestId: requestId, resultData: resultData)
        
        // Process result data based on type
        if let resultData = resultData {
            await processCompletedTaskData(requestId: requestId, resultData: resultData)
        }
        
        // Remove from pending tasks
        removePendingTask(requestId)
        
        // Log completion
        CrashlyticsManager.shared.logUserAction(
            action: "background_task_completed",
            screen: "background_task_service",
            additionalData: [
                "request_id": requestId,
                "completed_at": completedAt ?? "unknown"
            ]
        )
    }
    
    private func handleTaskFailure(requestId: String, data: [String: Any]) async {
        print("[BackgroundTaskService] Task \(requestId) failed")
        
        let errorMessage = data["error_message"] as? String ?? "Unknown error"
        
        // Update global manager with error
        globalManager.endBackgroundTaskWithError(errorMessage: errorMessage)
        
        // Send error notification
        await sendErrorNotification(requestId: requestId, errorMessage: errorMessage)
        
        // Remove from pending tasks
        removePendingTask(requestId)
        
        // Log failure
        CrashlyticsManager.shared.logCustomError(
            error: NSError(domain: "BackgroundTaskError", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]),
            context: "background_task_failed",
            additionalData: ["request_id": requestId]
        )
    }
    
    private func updateProgressFromFirebase(requestId: String, data: [String: Any]) async {
        // Check if there's progress data in the request_progress collection
        do {
            let progressDoc = try await db.collection("request_progress").document(requestId).getDocument()
            
            if progressDoc.exists,
               let progressData = progressDoc.data() {
                
                let step = progressData["step"] as? String ?? ""
                let stepNumber = progressData["step_number"] as? Int ?? 0
                let totalSteps = progressData["total_steps"] as? Int ?? 1
                let progressPercentage = progressData["progress_percentage"] as? Double ?? 0.0
                
                // Update global manager progress
                globalManager.updateProgress(
                    step: step,
                    stepNumber: stepNumber,
                    totalSteps: totalSteps
                )
                
                print("[BackgroundTaskService] Updated progress for \(requestId): \(Int(progressPercentage))% - \(step)")
            }
        } catch {
            print("[BackgroundTaskService] Error updating progress: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Result Processing
    private func processCompletedTaskData(requestId: String, resultData: [String: Any]) async {
        // Determine content type and process accordingly
        if resultData["blocks"] != nil {
            await processContentBlocks(requestId: requestId, resultData: resultData)
        } else if resultData["story"] != nil {
            await processStory(requestId: requestId, resultData: resultData)
        } else if resultData["lecture"] != nil {
            await processLecture(requestId: requestId, resultData: resultData)
        } else if resultData["flashcards"] != nil {
            await processFlashcards(requestId: requestId, resultData: resultData)
        } else if resultData["slides"] != nil {
            await processSlideshow(requestId: requestId, resultData: resultData)
        } else if resultData["dialogue_response"] != nil {
            await processDialogue(requestId: requestId, resultData: resultData)
        } else if resultData["re_explained_paragraph"] != nil {
            await processExplainAgain(requestId: requestId, resultData: resultData)
        }
    }
    
    private func processContentBlocks(requestId: String, resultData: [String: Any]) async {
        // This would typically update the ContentGenerationViewModel
        // For now, we'll just log the completion
        if let blocks = resultData["blocks"] as? [[String: Any]] {
            print("[BackgroundTaskService] Content generation completed with \(blocks.count) blocks")
            
            // Update global manager with content
            globalManager.setRecentlyGeneratedContent(userContent: []) // You'd need to convert blocks to ContentBlock objects
        }
    }
    
    private func processStory(requestId: String, resultData: [String: Any]) async {
        if let storyData = resultData["story"] as? [String: Any] {
            print("[BackgroundTaskService] Story generation completed")
            
            // Update global manager with story
            // globalManager.setRecentlyGeneratedContent(story: story) // You'd need to convert storyData to Story object
        }
    }
    
    private func processLecture(requestId: String, resultData: [String: Any]) async {
        if let lectureData = resultData["lecture"] as? [String: Any] {
            print("[BackgroundTaskService] Lecture generation completed")
            
            // Update global manager with lecture
            // globalManager.setRecentlyGeneratedContent(lecture: lecture) // You'd need to convert lectureData to Lecture object
        }
    }
    
    private func processFlashcards(requestId: String, resultData: [String: Any]) async {
        if let flashcards = resultData["flashcards"] as? [[String: Any]] {
            print("[BackgroundTaskService] Flashcard generation completed with \(flashcards.count) cards")
        }
    }
    
    private func processSlideshow(requestId: String, resultData: [String: Any]) async {
        if let slides = resultData["slides"] as? [[String: Any]] {
            print("[BackgroundTaskService] Slideshow generation completed with \(slides.count) slides")
        }
    }
    
    private func processDialogue(requestId: String, resultData: [String: Any]) async {
        if let response = resultData["dialogue_response"] as? String {
            print("[BackgroundTaskService] Dialogue response completed")
        }
    }
    
    private func processExplainAgain(requestId: String, resultData: [String: Any]) async {
        if let response = resultData["re_explained_paragraph"] as? String {
            print("[BackgroundTaskService] Explain again completed")
        }
    }
    
    // MARK: - Notifications
    private func sendCompletionNotification(requestId: String, resultData: [String: Any]?) async {
        let contentType = determineContentType(from: resultData)
        
        await notificationManager.sendContentGenerationSuccess(
            contentType: contentType,
            level: "moderate" // You might want to store the level in the task data
        )
    }
    
    private func sendErrorNotification(requestId: String, errorMessage: String) async {
        let contentType = "content generation" // Default fallback
        
        await notificationManager.sendContentGenerationError(contentType: contentType)
    }
    
    private func determineContentType(from resultData: [String: Any]?) -> String {
        guard let resultData = resultData else { return "content" }
        
        if resultData["blocks"] != nil { return "Detailed Explanation" }
        if resultData["story"] != nil { return "Story" }
        if resultData["lecture"] != nil { return "Lecture" }
        if resultData["flashcards"] != nil { return "Flashcards" }
        if resultData["slides"] != nil { return "Slideshow" }
        if resultData["dialogue_response"] != nil { return "Dialogue" }
        if resultData["re_explained_paragraph"] != nil { return "Explanation" }
        
        return "content"
    }
    
    // MARK: - Public Methods
    func startMonitoring() {
        print("[BackgroundTaskService] Starting background task monitoring")
        setupTaskChecking()
    }
    
    func stopMonitoring() {
        print("[BackgroundTaskService] Stopping background task monitoring")
        taskCheckTimer?.invalidate()
        taskCheckTimer = nil
    }
    
    func cleanup() {
        stopMonitoring()
        pendingTasks.removeAll()
    }
} 