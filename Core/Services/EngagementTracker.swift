import Foundation
import FirebaseAuth

@MainActor
class EngagementTracker: ObservableObject {
    static let shared = EngagementTracker()
    
    private let notificationManager = NotificationManager.shared
    
    private init() {}
    
    // MARK: - User Engagement Tracking
    func trackContentGeneration(contentType: String) {
        print("[EngagementTracker] 📊 Tracking content generation: \(contentType)")
        
        // Update content generation count
        let currentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
        UserDefaults.standard.set(currentCount + 1, forKey: "contentGenerationCount")
        
        // Update daily streak
        Task {
            await updateDailyStreak()
        }
        
        // Check for achievements
        Task {
            await checkAndAwardAchievements()
        }
        
        print("[EngagementTracker] ✅ Content generation tracked. Total: \(currentCount + 1)")
    }
    
    private func updateDailyStreak() async {
        let today = Date()
        let calendar = Calendar.current
        
        if let lastActivity = UserDefaults.standard.object(forKey: "lastActivityDate") as? Date {
            let daysSinceLastActivity = calendar.dateComponents([.day], from: lastActivity, to: today).day ?? 0
            
            if daysSinceLastActivity == 1 {
                // Consecutive day
                let currentStreak = UserDefaults.standard.integer(forKey: "learningStreak")
                let newStreak = currentStreak + 1
                UserDefaults.standard.set(newStreak, forKey: "learningStreak")
                print("[EngagementTracker] 🔥 Streak increased to \(newStreak)")
                
                // Send streak notification for milestones
                await notificationManager.sendStreakNotification(streak: newStreak)
            } else if daysSinceLastActivity > 1 {
                // Streak broken
                UserDefaults.standard.set(1, forKey: "learningStreak")
                print("[EngagementTracker] 💔 Streak reset to 1")
            }
        } else {
            // First time user
            UserDefaults.standard.set(1, forKey: "learningStreak")
            print("[EngagementTracker] 🎉 First activity, streak set to 1")
        }
        
        // Update last activity date
        UserDefaults.standard.set(today, forKey: "lastActivityDate")
    }
    
    private func checkAndAwardAchievements() async {
        let contentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
        let streak = UserDefaults.standard.integer(forKey: "learningStreak")
        
        // Check for first content achievement
        if contentCount == 1 && !UserDefaults.standard.bool(forKey: "achievement_first_content") {
            let achievement = Achievement(
                id: "first_content",
                title: "First Steps",
                description: "You created your first piece of content! Welcome to the learning journey! 🎉",
                icon: "🎯",
                type: .firstContent
            )
            await awardAchievement(achievement)
        }
        
        // Check for content creator achievement
        if contentCount >= 10 && !UserDefaults.standard.bool(forKey: "achievement_content_creator") {
            let achievement = Achievement(
                id: "content_creator",
                title: "Content Creator",
                description: "You've created 10 pieces of content! You're becoming a true content creator! 📚",
                icon: "📝",
                type: .contentCreator
            )
            await awardAchievement(achievement)
        }
        
        // Check for story teller achievement
        if contentCount >= 5 && !UserDefaults.standard.bool(forKey: "achievement_story_teller") {
            let achievement = Achievement(
                id: "story_teller",
                title: "Story Teller",
                description: "You've created 5 pieces of content! Your storytelling skills are growing! 📖",
                icon: "📚",
                type: .storyTeller
            )
            await awardAchievement(achievement)
        }
        
        // Check for streak achievements
        if streak >= 7 && !UserDefaults.standard.bool(forKey: "achievement_streak_master") {
            let achievement = Achievement(
                id: "streak_master",
                title: "Streak Master",
                description: "7 days of consistent learning! You're building amazing habits! 🔥",
                icon: "🔥",
                type: .streakMaster
            )
            await awardAchievement(achievement)
        }
        
        // Check for daily learner achievement
        if streak >= 30 && !UserDefaults.standard.bool(forKey: "achievement_daily_learner") {
            let achievement = Achievement(
                id: "daily_learner",
                title: "Daily Learner",
                description: "30 days of consistent learning! You're unstoppable! 🚀",
                icon: "🚀",
                type: .dailyLearner
            )
            await awardAchievement(achievement)
        }
    }
    
    private func awardAchievement(_ achievement: Achievement) async {
        UserDefaults.standard.set(true, forKey: "achievement_\(achievement.id)")
        
        // Send achievement notification
        await notificationManager.sendAchievementNotification(achievement: achievement)
        
        print("[EngagementTracker] 🏆 Awarded: \(achievement.title)")
    }
    
    // MARK: - Analytics
    func getEngagementAnalytics() -> [String: Any] {
        let streak = UserDefaults.standard.integer(forKey: "learningStreak")
        let contentCount = UserDefaults.standard.integer(forKey: "contentGenerationCount")
        let lastActivity = UserDefaults.standard.object(forKey: "lastActivityDate") as? Date
        
        var achievements: [String] = []
        for achievementType in AchievementType.allCases {
            if UserDefaults.standard.bool(forKey: "achievement_\(achievementType.rawValue)") {
                achievements.append(achievementType.rawValue)
            }
        }
        
        return [
            "currentStreak": streak,
            "totalContentGenerated": contentCount,
            "lastActivityDate": lastActivity?.timeIntervalSince1970 ?? 0,
            "achievements": achievements,
            "totalAchievements": achievements.count
        ]
    }
    
    // MARK: - Reset Functions (for testing)
    func resetEngagementData() {
        UserDefaults.standard.removeObject(forKey: "contentGenerationCount")
        UserDefaults.standard.removeObject(forKey: "learningStreak")
        UserDefaults.standard.removeObject(forKey: "lastActivityDate")
        
        // Reset all achievements
        for achievementType in AchievementType.allCases {
            UserDefaults.standard.removeObject(forKey: "achievement_\(achievementType.rawValue)")
        }
        
        print("[EngagementTracker] 🔄 Engagement data reset")
    }
    
    func getCurrentStreak() -> Int {
        return UserDefaults.standard.integer(forKey: "learningStreak")
    }
    
    func getContentCount() -> Int {
        return UserDefaults.standard.integer(forKey: "contentGenerationCount")
    }
} 
