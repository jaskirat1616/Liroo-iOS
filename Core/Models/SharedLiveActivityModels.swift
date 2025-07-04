import ActivityKit
import Foundation

// MARK: - Shared Live Activity Attributes
public struct ContentGenerationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var currentStep: String
        public var generationType: String
        public var totalSteps: Int
        public var currentStepNumber: Int
        
        public init(progress: Double, currentStep: String, generationType: String, totalSteps: Int, currentStepNumber: Int) {
            self.progress = progress
            self.currentStep = currentStep
            self.generationType = generationType
            self.totalSteps = totalSteps
            self.currentStepNumber = currentStepNumber
        }
    }
    
    public var generationType: String
    public var startTime: Date
    
    public init(generationType: String, startTime: Date) {
        self.generationType = generationType
        self.startTime = startTime
    }
} 