import Foundation
import SwiftUI
import ActivityKit

// MARK: - Global Background Processing Manager
public class GlobalBackgroundProcessingManager: ObservableObject {
    public static let shared = GlobalBackgroundProcessingManager()
    
    @Published public var isBackgroundProcessing = false
    @Published public var backgroundTaskId: String?
    @Published public var progress: Double = 0.0
    @Published public var currentStep: String = ""
    @Published public var totalSteps: Int = 0
    @Published public var currentStepNumber: Int = 0
    @Published public var generationType: String = ""
    @Published public var isIndicatorVisible: Bool = true
    @Published var recentlyGeneratedStory: Story? = nil
    @Published var recentlyGeneratedLecture: Lecture? = nil
    @Published var recentlyGeneratedUserContent: [ContentBlock]? = nil
    @Published var showSuccessBox: Bool = false
    @Published var lastGeneratedContent: LastGeneratedContent? = nil {
        didSet {
            if let content = lastGeneratedContent, let data = try? JSONEncoder().encode(content) {
                UserDefaults.standard.set(data, forKey: "lastGeneratedContent")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastGeneratedContent")
            }
        }
    }
    
    private let liveActivityManager = ContentGenerationLiveActivityManager.shared
    
    private init() {
        restoreFromUserDefaults()
        // Restore lastGeneratedContent
        if let data = UserDefaults.standard.data(forKey: "lastGeneratedContent"),
           let content = try? JSONDecoder().decode(LastGeneratedContent.self, from: data) {
            self.lastGeneratedContent = content
        }
    }
    
    public func startBackgroundTask(type: String) -> String {
        let taskId = UUID().uuidString
        backgroundTaskId = taskId
        isBackgroundProcessing = true
        progress = 0.0
        currentStepNumber = 0
        generationType = type
        isIndicatorVisible = true
        
        // Start Live Activity for Dynamic Island
        Task { @MainActor in
            liveActivityManager.startLiveActivity(generationType: type)
        }
        
        // Store task info for background processing
        UserDefaults.standard.set(taskId, forKey: "currentBackgroundTaskId")
        UserDefaults.standard.set(true, forKey: "isBackgroundProcessing")
        UserDefaults.standard.set(type, forKey: "backgroundGenerationType")
        UserDefaults.standard.set(isIndicatorVisible, forKey: "isIndicatorVisible")
        
        return taskId
    }
    
    public func endBackgroundTask() {
        isBackgroundProcessing = false
        backgroundTaskId = nil
        progress = 0.0
        currentStep = ""
        currentStepNumber = 0
        totalSteps = 0
        generationType = ""
        
        // End Live Activity with success
        Task { @MainActor in
            liveActivityManager.endLiveActivityWithSuccess()
        }
        
        // When the task ends, we can hide the indicator, but let's leave it visible
        // until the user dismisses it, so they see the "Complete!" message.
        // isIndicatorVisible = false

        // Clear stored task info
        UserDefaults.standard.removeObject(forKey: "currentBackgroundTaskId")
        UserDefaults.standard.set(false, forKey: "isBackgroundProcessing")
        UserDefaults.standard.removeObject(forKey: "backgroundGenerationType")
        UserDefaults.standard.removeObject(forKey: "isIndicatorVisible")
    }
    
    public func endBackgroundTaskWithError(errorMessage: String) {
        isBackgroundProcessing = false
        backgroundTaskId = nil
        progress = 0.0
        currentStep = ""
        currentStepNumber = 0
        totalSteps = 0
        generationType = ""
        
        // End Live Activity with error
        Task { @MainActor in
            liveActivityManager.endLiveActivityWithError(errorMessage: errorMessage)
        }
        
        // Clear stored task info
        UserDefaults.standard.removeObject(forKey: "currentBackgroundTaskId")
        UserDefaults.standard.set(false, forKey: "isBackgroundProcessing")
        UserDefaults.standard.removeObject(forKey: "backgroundGenerationType")
        UserDefaults.standard.removeObject(forKey: "isIndicatorVisible")
    }
    
    public func dismissIndicator() {
        isIndicatorVisible = false
        UserDefaults.standard.set(false, forKey: "isIndicatorVisible")
    }
    
    public func updateProgress(step: String, stepNumber: Int, totalSteps: Int) {
        currentStep = step
        currentStepNumber = stepNumber
        self.totalSteps = totalSteps
        progress = Double(stepNumber) / Double(totalSteps)
        
        // Update Live Activity
        Task { @MainActor in
            liveActivityManager.updateLiveActivity(
                progress: progress,
                currentStep: step,
                currentStepNumber: stepNumber,
                totalSteps: totalSteps
            )
        }
        
        // Store progress for background updates
        UserDefaults.standard.set(progress, forKey: "backgroundProgress")
        UserDefaults.standard.set(step, forKey: "backgroundCurrentStep")
        UserDefaults.standard.set(stepNumber, forKey: "backgroundStepNumber")
        UserDefaults.standard.set(totalSteps, forKey: "backgroundTotalSteps")
    }
    
    public func restoreFromUserDefaults() {
        if UserDefaults.standard.bool(forKey: "isBackgroundProcessing") {
            isBackgroundProcessing = true
            backgroundTaskId = UserDefaults.standard.string(forKey: "currentBackgroundTaskId")
            progress = UserDefaults.standard.double(forKey: "backgroundProgress")
            currentStep = UserDefaults.standard.string(forKey: "backgroundCurrentStep") ?? ""
            currentStepNumber = UserDefaults.standard.integer(forKey: "backgroundStepNumber")
            totalSteps = UserDefaults.standard.integer(forKey: "backgroundTotalSteps")
            generationType = UserDefaults.standard.string(forKey: "backgroundGenerationType") ?? ""
            isIndicatorVisible = UserDefaults.standard.object(forKey: "isIndicatorVisible") as? Bool ?? true
        }
    }
    
    func setRecentlyGeneratedContent(story: Story? = nil, lecture: Lecture? = nil, userContent: [ContentBlock]? = nil) {
        self.recentlyGeneratedStory = story
        self.recentlyGeneratedLecture = lecture
        self.recentlyGeneratedUserContent = userContent
        self.showSuccessBox = true
    }

    func clearRecentlyGeneratedContent() {
        self.recentlyGeneratedStory = nil
        self.recentlyGeneratedLecture = nil
        self.recentlyGeneratedUserContent = nil
        self.showSuccessBox = false
    }

    func setLastGeneratedContent(type: LastGeneratedContent.ContentType, id: String, title: String, date: Date = Date()) {
        self.lastGeneratedContent = LastGeneratedContent(type: type, id: id, title: title, date: date)
    }

    func clearLastGeneratedContent() {
        self.lastGeneratedContent = nil
    }
}

struct LastGeneratedContent: Codable {
    enum ContentType: String, Codable { case story, lecture, userContent }
    let type: ContentType
    let id: String
    let title: String
    let date: Date
} 