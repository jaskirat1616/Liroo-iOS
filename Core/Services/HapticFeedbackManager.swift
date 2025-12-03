import UIKit

/// Centralized haptic feedback manager for consistent user experience
class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    
    /// Light impact feedback (for subtle interactions)
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium impact feedback (for standard interactions)
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Heavy impact feedback (for significant interactions)
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Rigid impact feedback (iOS 13+)
    @available(iOS 13.0, *)
    func rigidImpact() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
    
    /// Soft impact feedback (iOS 13+)
    @available(iOS 13.0, *)
    func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
    
    // MARK: - Notification Feedback
    
    /// Success notification feedback
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Warning notification feedback
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Error notification feedback
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    /// Selection feedback (for picker/stepper changes)
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Content-Specific Feedback
    
    /// Feedback for content generation start
    func contentGenerationStart() {
        mediumImpact()
    }
    
    /// Feedback for content generation success
    func contentGenerationSuccess() {
        success()
    }
    
    /// Feedback for content generation error
    func contentGenerationError() {
        error()
    }
    
    /// Feedback for button tap
    func buttonTap() {
        lightImpact()
    }
    
    /// Feedback for important action
    func importantAction() {
        mediumImpact()
    }
    
    /// Feedback for destructive action
    func destructiveAction() {
        heavyImpact()
    }
    
    /// Feedback for toggle/switch
    func toggle() {
        selection()
    }
    
    /// Feedback for swipe gesture
    func swipe() {
        lightImpact()
    }
    
    /// Feedback for pull-to-refresh
    func refresh() {
        mediumImpact()
    }
}

