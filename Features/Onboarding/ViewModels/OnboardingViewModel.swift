import Foundation
import SwiftUI

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var hasCompletedOnboarding: Bool = false
    @Published var selectedTopics: Set<String> = []
    @Published var isStudent: Bool = false
    @Published var accessibilityPreferences = AccessibilityPreferences()
    
    private let userDefaults = UserDefaults.standard
    private let onboardingKey = "hasCompletedOnboarding"
    
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case features = 1
        case preferences = 2
        case accessibility = 3
        case complete = 4
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to Liroo"
            case .features: return "Discover Features"
            case .preferences: return "Your Preferences"
            case .accessibility: return "Accessibility"
            case .complete: return "You're All Set!"
            }
        }
        
        var description: String {
            switch self {
            case .welcome: return "Your AI-powered reading companion"
            case .features: return "Explore what Liroo can do for you"
            case .preferences: return "Tell us about your interests"
            case .accessibility: return "Customize your reading experience"
            case .complete: return "Ready to start reading!"
            }
        }
    }
    
    struct AccessibilityPreferences: Codable {
        var fontSize: Double = 16.0
        var fontFamily: String = "OpenDyslexic-Regular"
        var lineSpacing: Double = 1.2
        var highContrast: Bool = false
        var reduceMotion: Bool = false
        var screenReader: Bool = false
    }
    
    init() {
        loadOnboardingState()
    }
    
    private func loadOnboardingState() {
        hasCompletedOnboarding = userDefaults.bool(forKey: onboardingKey)
        
        print("OnboardingViewModel: hasCompletedOnboarding = \(hasCompletedOnboarding)")
    }
    
    func nextStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < OnboardingStep.allCases.count else {
            completeOnboarding()
            return
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep.allCases[currentIndex + 1]
        }
    }
    
    func previousStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep.allCases[currentIndex - 1]
        }
    }
    
    func completeOnboarding() {
        userDefaults.set(true, forKey: onboardingKey)
        hasCompletedOnboarding = true
        
        // Save user preferences
        saveUserPreferences()
    }
    
    func skipOnboarding() {
        completeOnboarding()
    }
    
    private func saveUserPreferences() {
        // Save accessibility preferences
        if let encoded = try? JSONEncoder().encode(accessibilityPreferences) {
            userDefaults.set(encoded, forKey: "accessibilityPreferences")
        }
        
        // Save selected topics
        userDefaults.set(Array(selectedTopics), forKey: "selectedTopics")
        userDefaults.set(isStudent, forKey: "isStudent")
    }
    
    func resetOnboarding() {
        userDefaults.removeObject(forKey: onboardingKey)
        hasCompletedOnboarding = false
        currentStep = .welcome
    }
}
