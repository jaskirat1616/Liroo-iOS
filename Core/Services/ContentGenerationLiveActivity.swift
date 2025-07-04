import ActivityKit
import SwiftUI

// MARK: - Live Activity Manager
@MainActor
class ContentGenerationLiveActivityManager: ObservableObject {
    static let shared = ContentGenerationLiveActivityManager()
    
    private var currentActivity: Activity<ContentGenerationAttributes>?
    
    private init() {}
    
    func startLiveActivity(generationType: String) {
        print("[LiveActivity] 🔍 Checking Live Activity permissions...")
        
        // Check if Live Activities are supported on this device
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] ❌ Live Activities not enabled on this device")
            print("[LiveActivity] 💡 User needs to enable Live Activities in Settings > Face ID & Passcode > Live Activities")
            print("[LiveActivity] 📝 Note: Live Activities require iOS 16.1+ and supported devices")
            return
        }
        
        print("[LiveActivity] ✅ Live Activity permissions granted")
        
        let attributes = ContentGenerationAttributes(
            generationType: generationType,
            startTime: Date()
        )
        
        let initialState = ContentGenerationAttributes.ContentState(
            progress: 0.0,
            currentStep: "Starting...",
            generationType: generationType,
            totalSteps: 4,
            currentStepNumber: 1
        )
        
        do {
            print("[LiveActivity] 🚀 Starting Live Activity for \(generationType)...")
            
            // Try to start without push support first (works with Team Provisioning Profile)
            let activity = try Activity.request(
                attributes: attributes,
                contentState: initialState
            )
            currentActivity = activity
            
            print("[LiveActivity] ✅ Successfully started Live Activity for \(generationType)")
            print("[LiveActivity] 📱 Activity ID: \(activity.id)")
            print("[LiveActivity] ℹ️ Note: Push updates not available with Team Provisioning Profile")
            
        } catch {
            print("[LiveActivity] ❌ Failed to start Live Activity: \(error)")
            print("[LiveActivity] 🔍 Error details: \(error.localizedDescription)")
            print("[LiveActivity] 💡 Live Activities may not be available with current provisioning profile")
            
            // Check for specific error types
            if error.localizedDescription.contains("entitlement") {
                print("[LiveActivity] 💡 This requires a paid Apple Developer account")
                print("[LiveActivity] 💡 For development, Live Activities are disabled")
            } else if error.localizedDescription.contains("unsupported") {
                print("[LiveActivity] 💡 Live Activities require iOS 16.1+ and supported devices")
            }
        }
    }
    
    // MARK: - Push Token Management
    private func storePushTokenForActivity(activityId: String, token: String) async {
        // Store the push token in UserDefaults for now
        // In a real implementation, you'd send this to your backend
        UserDefaults.standard.set(token, forKey: "liveActivityPushToken_\(activityId)")
        print("[LiveActivity] Stored push token for activity: \(activityId)")
    }
    
    // MARK: - Handle Push-Based Updates (called when app receives push notification)
    func handlePushUpdate(activityId: String, progress: Double, currentStep: String, currentStepNumber: Int, totalSteps: Int) {
        guard let activity = currentActivity, activity.id == activityId else {
            print("[LiveActivity] Activity not found for push update")
            return
        }
        
        let newState = ContentGenerationAttributes.ContentState(
            progress: progress,
            currentStep: currentStep,
            generationType: activity.attributes.generationType,
            totalSteps: totalSteps,
            currentStepNumber: currentStepNumber
        )
        
        Task {
            await activity.update(using: newState)
            print("[LiveActivity] Updated via push: \(Int(progress * 100))% - \(currentStep)")
        }
    }
    
    func updateLiveActivity(progress: Double, currentStep: String, currentStepNumber: Int, totalSteps: Int) {
        guard let activity = currentActivity else { return }
        
        let newState = ContentGenerationAttributes.ContentState(
            progress: progress,
            currentStep: currentStep,
            generationType: activity.attributes.generationType,
            totalSteps: totalSteps,
            currentStepNumber: currentStepNumber
        )
        
        Task {
            await activity.update(using: newState)
            print("[LiveActivity] Updated progress: \(Int(progress * 100))% - \(currentStep)")
        }
    }
    
    func endLiveActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            print("[LiveActivity] Ended Live Activity")
        }
    }
    
    func endLiveActivityWithSuccess() {
        guard let activity = currentActivity else { return }
        
        let finalState = ContentGenerationAttributes.ContentState(
            progress: 1.0,
            currentStep: "Complete! 🎉",
            generationType: activity.attributes.generationType,
            totalSteps: 4,
            currentStepNumber: 4
        )
        
        Task {
            await activity.update(using: finalState)
            // Keep the activity visible for a moment to show completion
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            print("[LiveActivity] Ended Live Activity with success")
        }
    }
    
    func endLiveActivityWithError(errorMessage: String) {
        guard let activity = currentActivity else { return }
        
        let errorState = ContentGenerationAttributes.ContentState(
            progress: 0.0,
            currentStep: "Error: \(errorMessage)",
            generationType: activity.attributes.generationType,
            totalSteps: 4,
            currentStepNumber: 0
        )
        
        Task {
            await activity.update(using: errorState)
            // Keep the activity visible briefly to show the error
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            print("[LiveActivity] Ended Live Activity with error: \(errorMessage)")
        }
    }
    
    // MARK: - Status and Troubleshooting
    func checkLiveActivityStatus() -> String {
        let authorizationInfo = ActivityAuthorizationInfo()
        
        var status = "📊 Live Activity Status:\n"
        status += "• Activities Enabled: \(authorizationInfo.areActivitiesEnabled ? "✅" : "❌")\n"
        status += "• Current Activity: \(currentActivity != nil ? "✅ Active" : "❌ None")\n"
        
        // Check for Team Provisioning Profile limitation
        status += "\n🔧 Development Status:\n"
        status += "• Using Team Provisioning Profile: Limited Live Activity support\n"
        status += "• Push updates: ❌ Not available\n"
        status += "• Basic Live Activities: ✅ Available (if device supports)\n"
        
        if !authorizationInfo.areActivitiesEnabled {
            status += "\n💡 To enable Live Activities:\n"
            status += "1. Go to Settings > Face ID & Passcode\n"
            status += "2. Scroll down to 'Live Activities'\n"
            status += "3. Toggle it ON\n"
        }
        
        status += "\n📝 For Full Live Activity Support:\n"
        status += "• Requires paid Apple Developer account ($99/year)\n"
        status += "• Create App ID with Live Activity capability\n"
        status += "• Generate proper provisioning profile\n"
        status += "• Enable push notifications for background updates\n"
        
        return status
    }
    
    func isLiveActivitySupported() -> Bool {
        let authorizationInfo = ActivityAuthorizationInfo()
        return authorizationInfo.areActivitiesEnabled
    }
    
    func isLiveActivityFullySupported() -> Bool {
        // This would return true only with proper provisioning profile
        // For now, return false to indicate limited functionality
        return false
    }
} 


