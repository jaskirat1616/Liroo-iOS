import Foundation
import SwiftUI

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
    
    private init() {
        restoreFromUserDefaults()
    }
    
    public func startBackgroundTask(type: String) -> String {
        let taskId = UUID().uuidString
        backgroundTaskId = taskId
        isBackgroundProcessing = true
        progress = 0.0
        currentStepNumber = 0
        generationType = type
        
        // Store task info for background processing
        UserDefaults.standard.set(taskId, forKey: "currentBackgroundTaskId")
        UserDefaults.standard.set(true, forKey: "isBackgroundProcessing")
        UserDefaults.standard.set(type, forKey: "backgroundGenerationType")
        
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
        
        // Clear stored task info
        UserDefaults.standard.removeObject(forKey: "currentBackgroundTaskId")
        UserDefaults.standard.set(false, forKey: "isBackgroundProcessing")
        UserDefaults.standard.removeObject(forKey: "backgroundGenerationType")
    }
    
    public func updateProgress(step: String, stepNumber: Int, totalSteps: Int) {
        currentStep = step
        currentStepNumber = stepNumber
        self.totalSteps = totalSteps
        progress = Double(stepNumber) / Double(totalSteps)
        
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
        }
    }
} 