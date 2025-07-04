import Foundation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private let db = Firestore.firestore()
    
    private init() {
        setupAutomaticNotifications()
    }
    
    // MARK: - Helper Method to Get User Name
    private func getUserName() async -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            return "Bookworm"
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data(), let name = data["name"] as? String {
                return name
            }
        } catch {
            print("[NotificationManager] ❌ Failed to fetch user name: \(error.localizedDescription)")
        }
        
        return "Bookworm"
    }
    
    private func getUserFirstName() async -> String {
        let userName = await getUserName()
        return userName.components(separatedBy: " ").first ?? "Reader"
    }
    
    // MARK: - Public Setup Method
    func ensureNotificationsAreSetup() async {
        print("[NotificationManager] 🔧 Ensuring notifications are properly setup...")
        
        // Check current authorization status
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            print("[NotificationManager] ✅ Notifications authorized, setting up...")
            await setupDailyNotifications()
            setupAchievementNotifications()
            setupStreakNotifications()
            checkNotificationStatus()
        case .denied:
            print("[NotificationManager] ❌ Notifications denied by user")
        case .notDetermined:
            print("[NotificationManager] ⏳ Notification permission not determined, requesting...")
            let granted = await requestPermissions()
            if granted {
                await setupDailyNotifications()
                await setupAchievementNotifications()
                await setupStreakNotifications()
            }
        case .ephemeral:
            print("[NotificationManager] ✅ Provisional notifications enabled")
            await setupDailyNotifications()
            await setupAchievementNotifications()
            await setupStreakNotifications()
        @unknown default:
            print("[NotificationManager] ❓ Unknown authorization status")
        }
    }
    
    // MARK: - Automatic Setup
    private func setupAutomaticNotifications() {
        print("[NotificationManager] 🚀 Setting up automatic notifications...")
        
        // Request permissions automatically
        Task {
            let granted = await requestPermissions()
            if granted {
                print("[NotificationManager] ✅ Permissions granted, setting up notifications")
                await setupDailyNotifications()
                setupAchievementNotifications()
                setupStreakNotifications()
            } else {
                print("[NotificationManager] ❌ Permissions denied")
            }
        }
    }
    
    // MARK: - Permission Request
    private func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .provisional])
            
            if granted {
                print("[NotificationManager] ✅ Notification permissions granted")
            } else {
                print("[NotificationManager] ❌ Notification permissions denied")
            }
            
            return granted
        } catch {
            print("[NotificationManager] ❌ Error requesting permissions: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Daily Notifications
    private func setupDailyNotifications() async {
        print("[NotificationManager] 📅 Setting up daily notifications...")
        
        // Clear existing notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [])
        
        // Schedule daily notifications at optimal times
        let notificationTimes = getOptimalNotificationTimes()
        
        for (index, time) in notificationTimes.enumerated() {
            await scheduleDailyNotification(
                time: time,
                type: getNotificationTypeForTime(time),
                notificationNumber: index + 1
            )
        }
        
        print("[NotificationManager] ✅ Scheduled \(notificationTimes.count) daily notifications")
    }
    
    private func getOptimalNotificationTimes() -> [Date] {
        let calendar = Calendar.current
        let now = Date()
        let timeZone = TimeZone.current
        
        // Log current device time and timezone
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .medium
        timeFormatter.timeZone = timeZone
        
        print("[NotificationManager] 📱 Device Time: \(timeFormatter.string(from: now))")
        print("[NotificationManager] 🌍 Device Timezone: \(timeZone.identifier) (\(timeZone.abbreviation() ?? "Unknown"))")
        
        // Define the notification times we want (hour, minute) - these will be in device local time
        let notificationTimes: [(hour: Int, minute: Int)] = [
            (3, 0),
            (5, 0),
            (7, 0),
            (8, 0),   // Morning motivation
            (12, 30), // Lunch break
           ( 17, 12),
            (17, 30), // After work
            (17, 40),
            (18, 32),
            (19, 0),
            (19, 20),
            (19, 30),
            (19, 35),
            (19, 50),
            (20, 0),
            (23, 40)// Evening learning
        ]
        
        var scheduledTimes: [Date] = []
        
        for (hour, minute) in notificationTimes {
            // Create a date for today at the specified time in device local time
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            components.second = 0
            components.timeZone = timeZone
            
            if let scheduledTime = calendar.date(from: components) {
                scheduledTimes.append(scheduledTime)
                let scheduledTimeString = timeFormatter.string(from: scheduledTime)
                print("[NotificationManager] 📅 Scheduled notification for \(hour):\(String(format: "%02d", minute)) local time - \(scheduledTimeString)")
            }
        }
        
        return scheduledTimes
    }
    
    private func getNotificationTypeForTime(_ time: Date) -> NotificationType {
        let hour = Calendar.current.component(.hour, from: time)
        
        switch hour {
        case 6..<12:
            return .morningMotivation
        case 12..<17:
            return .afternoonBreak
        case 17..<22:
            return .eveningLearning
        default:
            return .generalReminder
        }
    }
    
    private func scheduleDailyNotification(time: Date, type: NotificationType, notificationNumber: Int) async {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // Calculate when the next trigger will occur
        let nextTriggerDate = trigger.nextTriggerDate()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let (title, body) = await generateNotificationContent(type: type, notificationNumber: notificationNumber)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: 1)
        
        content.userInfo = [
            "type": "daily_engagement",
            "notificationType": type.rawValue,
            "notificationNumber": notificationNumber,
            "hour": components.hour ?? 0,
            "minute": components.minute ?? 0,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Add action buttons
        let openAppAction = UNNotificationAction(
            identifier: "OPEN_APP",
            title: "Open Liroo",
            options: [.foreground]
        )
        
        let generateAction = UNNotificationAction(
            identifier: "GENERATE_CONTENT",
            title: "Generate Content",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "DAILY_ENGAGEMENT",
            actions: [openAppAction, generateAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "DAILY_ENGAGEMENT"
        
        // Use unique identifier based on time to prevent duplicates
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let identifier = "daily_\(hour)_\(minute)_\(type.rawValue)"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] ❌ Failed to schedule daily notification: \(error.localizedDescription)")
            } else {
                let nextTrigger = nextTriggerDate.map { timeFormatter.string(from: $0) } ?? "Unknown"
                print("[NotificationManager] ✅ Scheduled daily notification: \(identifier) - Next trigger: \(nextTrigger)")
            }
        }
    }
    
    // MARK: - Content Generation Notifications
    func sendContentGenerationSuccess(contentType: String, level: String) async {
        let (title, body) = await generateSuccessContent(contentType: contentType, level: level)
        sendImmediateNotification(title: title, body: body, type: "content_success")
    }
    
    func sendContentGenerationError(contentType: String) async {
        let (title, body) = await generateErrorContent(contentType: contentType)
        sendImmediateNotification(title: title, body: body, type: "content_error", isSuccess: false)
    }
    
    // MARK: - Achievement Notifications
    private func setupAchievementNotifications() {
        // Achievement notifications are sent immediately when earned
        print("[NotificationManager] 🏆 Achievement notifications ready")
    }
    
    func sendAchievementNotification(achievement: Achievement) async {
        let userFirstName = await getUserFirstName()
        let title = "\(userFirstName), you did something! 🏆"
        let body = "\(userFirstName), you just unlocked: \(achievement.title)! \(achievement.description) Not bad for a human!"
        sendImmediateNotification(title: title, body: body, type: "achievement")
    }
    
    // MARK: - Streak Notifications
    private func setupStreakNotifications() {
        print("[NotificationManager] 🔥 Streak notifications ready")
    }
    
    func sendStreakNotification(streak: Int) async {
        let userFirstName = await getUserFirstName()
        let title = "\(userFirstName), you're on fire! 🔥"
        let body = "\(userFirstName), you've got a \(streak)-day learning streak! Your brain is probably confused but impressed!"
        sendImmediateNotification(title: title, body: body, type: "streak_milestone")
    }
    
    // MARK: - Helper Methods
    private func sendImmediateNotification(title: String, body: String, type: String, isSuccess: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isSuccess ? .default : .defaultCritical
        content.badge = NSNumber(value: 1)
        
        content.userInfo = [
            "type": type,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let identifier = "\(type)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] ❌ Failed to send notification: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] ✅ Notification sent: \(title)")
            }
        }
    }
    
    private func generateNotificationContent(type: NotificationType, notificationNumber: Int) async -> (String, String) {
        let userFirstName = await getUserFirstName()
        
        switch type {
        case .morningMotivation:
            let titles = [
                "\(userFirstName), your brain called... ☀️",
                "Rise and shine, \(userFirstName)! 🌅",
                "\(userFirstName), time to adult! ⏰"
            ]
            let bodies = [
                "Your brain is probably still in bed while your body is at work, \(userFirstName). Let's wake it up!",
                "\(userFirstName), the coffee hasn't kicked in yet, but your learning potential has!",
                "Morning, \(userFirstName)! Your brain cells are having a meeting without you. Crash it!"
            ]
            return (titles.randomElement() ?? titles[0], bodies.randomElement() ?? bodies[0])
            
        case .afternoonBreak:
            let titles = [
                "\(userFirstName), your brain needs a snack! 🍕",
                "Lunch break = brain break, \(userFirstName)! 😌",
                "\(userFirstName), your neurons are hungry! 🧠"
            ]
            let bodies = [
                "\(userFirstName), you've been working so hard your brain is filing for overtime. Give it a learning break!",
                "Lunch break is the perfect time for a 5-minute learning session, \(userFirstName). Your stomach can wait!",
                "\(userFirstName), your brain is probably craving knowledge more than that sandwich you're eating."
            ]
            return (titles.randomElement() ?? titles[0], bodies.randomElement() ?? bodies[0])
            
        case .eveningLearning:
            let titles = [
                "\(userFirstName), let's end the day smart! 🌙",
                "Evening learning time, \(userFirstName)! 📚",
                "\(userFirstName), one more brain workout? 💡"
            ]
            let bodies = [
                "\(userFirstName), before you binge-watch that show about people who don't exist, how about learning about things that do?",
                "Evening is when the best ideas happen, \(userFirstName). Let's capture some before they escape!",
                "\(userFirstName), your future self will thank you for this learning session. Your past self is already jealous!"
            ]
            return (titles.randomElement() ?? titles[0], bodies.randomElement() ?? bodies[0])
            
        case .generalReminder:
            let titles = [
                "\(userFirstName), your content is getting lonely! 👋",
                "Hey \(userFirstName), missing you! 📖",
                "\(userFirstName), your brain cells are gossiping! 🎯"
            ]
            let bodies = [
                "\(userFirstName), your learning streak is getting jealous of your social media time. It's starting to feel neglected!",
                "I've got some fresh content waiting for you, \(userFirstName). It's getting stale from waiting so long!",
                "\(userFirstName), your brain cells are having a party without you. They're probably talking behind your back!"
            ]
            return (titles.randomElement() ?? titles[0], bodies.randomElement() ?? bodies[0])
        }
    }
    
    private func generateSuccessContent(contentType: String, level: String) async -> (String, String) {
        let userFirstName = await getUserFirstName()
        
        let titles = [
            "\(userFirstName), you did the thing! 🎉",
            "Look what \(userFirstName) made! ✨",
            "\(userFirstName), you're not terrible at this! 🎨"
        ]
        
        let bodies = [
            "\(userFirstName), your \(contentType) is ready. It's actually not bad! I'm impressed.",
            "\(userFirstName), you've got a new \(contentType) waiting. Time to see if it's as good as you think!",
            "\(userFirstName), your \(level) \(contentType) is complete. Not gonna lie, it's pretty decent!"
        ]
        
        return (titles.randomElement() ?? titles[0], bodies.randomElement() ?? bodies[0])
    }
    
    private func generateErrorContent(contentType: String) async -> (String, String) {
        let userFirstName = await getUserFirstName()
        
        let titles = [
            "\(userFirstName), we hit a snag! 😅",
            "Oops, \(userFirstName)! 🤔",
            "\(userFirstName), technical difficulties! 🔧"
        ]
        
        let bodies = [
            "\(userFirstName), something went wrong with your \(contentType). Even the best systems have off days!",
            "\(userFirstName), the \(contentType) creation failed. My bad, let's try again!",
            "\(userFirstName), even the smartest AI has moments. This was one of them. Let's retry!"
        ]
        
        return (titles.randomElement() ?? titles[0], bodies.randomElement() ?? bodies[0])
    }
    
    // MARK: - Test Notifications
    func sendTestNotification() async {
        let userFirstName = await getUserFirstName()
        
        let testTitles = [
            "\(userFirstName), this is a test! 🧪",
            "Hey \(userFirstName), testing 1, 2, 3! 🔔",
            "\(userFirstName), notification test! 📱"
        ]
        
        let testBodies = [
            "\(userFirstName), if you're reading this, your notifications work! Congrats, you're not broken!",
            "Test successful, \(userFirstName)! Your phone can receive messages. Revolutionary!",
            "\(userFirstName), notification system is online. Your brain cells are celebrating!"
        ]
        
        let randomTitle = testTitles.randomElement() ?? "Test notification!"
        let randomBody = testBodies.randomElement() ?? "This is a test notification."
        
        let content = UNMutableNotificationContent()
        content.title = randomTitle
        content.body = randomBody
        content.sound = .default
        content.badge = NSNumber(value: 1)
        
        content.userInfo = [
            "type": "test_notification",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let request = UNNotificationRequest(
            identifier: "test_notification_\(UUID().uuidString)",
            content: content,
            trigger: nil // Send immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] ❌ Failed to send test notification: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] ✅ Test notification sent successfully")
            }
        }
    }
    
    // MARK: - Debug and Status Methods
    func checkNotificationStatus() {
        print("[NotificationManager] 🔍 Checking notification status...")
        
        // Check authorization status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("[NotificationManager] 📊 Notification Settings:")
            print("[NotificationManager] - Authorization Status: \(settings.authorizationStatus.rawValue)")
            print("[NotificationManager] - Alert Setting: \(settings.alertSetting.rawValue)")
            print("[NotificationManager] - Badge Setting: \(settings.badgeSetting.rawValue)")
            print("[NotificationManager] - Sound Setting: \(settings.soundSetting.rawValue)")
            print("[NotificationManager] - Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
            print("[NotificationManager] - Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
        }
        
        // List pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("[NotificationManager] 📅 Pending Notifications (\(requests.count)):")
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .short
            timeFormatter.timeStyle = .short
            
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let nextTriggerDate = trigger.nextTriggerDate()
                    let nextTriggerString = nextTriggerDate.map { timeFormatter.string(from: $0) } ?? "Unknown"
                    print("[NotificationManager] - \(request.identifier): \(nextTriggerString)")
                } else {
                    print("[NotificationManager] - \(request.identifier): Immediate")
                }
            }
            
            // Show daily schedule summary
            self.showDailyScheduleSummary(requests: requests)
        }
        
        // List delivered notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            print("[NotificationManager] 📬 Delivered Notifications (\(notifications.count)):")
            for notification in notifications {
                print("[NotificationManager] - \(notification.request.identifier): \(notification.date)")
            }
        }
    }
    
    private func showDailyScheduleSummary(requests: [UNNotificationRequest]) {
        print("[NotificationManager] 📋 Daily Notification Schedule:")
        
        let dailyNotifications = requests.filter { $0.identifier.hasPrefix("daily_") }
        
        if dailyNotifications.isEmpty {
            print("[NotificationManager] ❌ No daily notifications scheduled")
        } else {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            for request in dailyNotifications {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextTriggerDate = trigger.nextTriggerDate() {
                    let timeString = timeFormatter.string(from: nextTriggerDate)
                    let type = request.content.userInfo["notificationType"] as? String ?? "Unknown"
                    print("[NotificationManager] - \(timeString): \(type)")
                }
            }
        }
    }
    
    func rescheduleNotifications() async {
        print("[NotificationManager] 🔄 Rescheduling notifications...")
        
        // Clear existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Wait a moment, then reschedule
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        await setupDailyNotifications()
        checkNotificationStatus()
    }
    
    func getDeviceTimeInfo() -> String {
        let now = Date()
        let timeZone = TimeZone.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .medium
        timeFormatter.timeZone = timeZone
        
        let currentTime = timeFormatter.string(from: now)
        let timeZoneName = timeZone.identifier
        let timeZoneAbbreviation = timeZone.abbreviation() ?? "Unknown"
        let offsetHours = timeZone.secondsFromGMT() / 3600
        
        return """
        📱 Current Device Time: \(currentTime)
        🌍 Timezone: \(timeZoneName) (\(timeZoneAbbreviation))
        ⏰ UTC Offset: \(offsetHours >= 0 ? "+" : "")\(offsetHours) hours
        """
    }
}

// MARK: - Supporting Types
enum NotificationType: String, CaseIterable {
    case morningMotivation = "morning_motivation"
    case afternoonBreak = "afternoon_break"
    case eveningLearning = "evening_learning"
    case generalReminder = "general_reminder"
}

struct Achievement {
    let id: String
    let title: String
    let description: String
    let icon: String
    let type: AchievementType
}

enum AchievementType: String, CaseIterable {
    case firstContent = "first_content"
    case contentCreator = "content_creator"
    case storyTeller = "story_teller"
    case lecturer = "lecturer"
    case streakMaster = "streak_master"
    case dailyLearner = "daily_learner"
} 
