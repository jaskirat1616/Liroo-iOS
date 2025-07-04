//
//  LirooApp.swift
//  Liroo
//
//  Created by JASKIRAT SINGH on 2025-06-13.
//

import SwiftUI
import FirebaseCore
import BackgroundTasks
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Register for push notifications
        registerForPushNotifications()
        
        // Ensure local notifications are properly setup
        Task {
            await NotificationManager.shared.ensureNotificationsAreSetup()
        }
        
        // Register background tasks
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.liroo.contentgeneration", using: nil) { task in
            self.handleContentGenerationBackgroundTask(task: task as! BGAppRefreshTask)
        }
        
        return true
    }
    
    // MARK: - Push Notification Registration
    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .provisional]) { granted, error in
            if granted {
                print("[AppDelegate] ✅ Push notification permissions granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("[AppDelegate] ❌ Push notification permissions denied")
                if let error = error {
                    print("[AppDelegate] Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Push Token Handling
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("[AppDelegate] ✅ Device Token: \(token)")
        
        // Store the token for sending to your backend
        UserDefaults.standard.set(token, forKey: "devicePushToken")
        
        // Here you would send this token to your backend server
        // sendTokenToServer(token: token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[AppDelegate] ❌ Failed to register for push notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Push Notification Handling
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("[AppDelegate] 📱 Received push notification: \(userInfo)")
        
        // Handle Live Activity updates
        if let activityId = userInfo["activityId"] as? String,
           let progress = userInfo["progress"] as? Double,
           let currentStep = userInfo["currentStep"] as? String,
           let currentStepNumber = userInfo["currentStepNumber"] as? Int,
           let totalSteps = userInfo["totalSteps"] as? Int {
            
            Task { @MainActor in
                ContentGenerationLiveActivityManager.shared.handlePushUpdate(
                    activityId: activityId,
                    progress: progress,
                    currentStep: currentStep,
                    currentStepNumber: currentStepNumber,
                    totalSteps: totalSteps
                )
            }
        }
        
        // Handle content generation completion
        if let contentType = userInfo["contentType"] as? String,
           let status = userInfo["status"] as? String {
            
            Task {
                if status == "completed" {
                    // Content generation completed
                    await NotificationManager.shared.sendContentGenerationSuccess(contentType: contentType, level: "Standard")
                } else if status == "error" {
                    // Content generation failed
                    await NotificationManager.shared.sendContentGenerationError(contentType: contentType)
                }
            }
        }
        
        completionHandler(.newData)
    }
    
    private func handleContentGenerationBackgroundTask(task: BGAppRefreshTask) {
        // Schedule the next background task
        scheduleBackgroundContentGeneration()
        
        // Create a task to track background execution
        task.expirationHandler = {
            // Handle task expiration
            task.setTaskCompleted(success: false)
        }
        
        // Check if there's a background generation in progress
        let isBackgroundProcessing = UserDefaults.standard.bool(forKey: "isBackgroundProcessing")
        
        if isBackgroundProcessing {
            // Continue background processing
            // This would typically involve checking progress and updating UI
            print("Background content generation in progress")
        }
        
        // Mark the task as completed
        task.setTaskCompleted(success: true)
    }
    
    private func scheduleBackgroundContentGeneration() {
        let request = BGAppRefreshTaskRequest(identifier: "com.liroo.contentgeneration")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background content generation: \(error)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // This function will be called when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("[AppDelegate] Notification received in foreground: \(notification.request.content.title)")
        
        // Show the notification with an alert, sound, and badge
        completionHandler([.banner, .sound, .badge])
    }
    
    // This function will be called when the user taps on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("[AppDelegate] User tapped on notification: \(response.notification.request.content.title)")
        
        // Handle different notification types
        let userInfo = response.notification.request.content.userInfo
        
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "content_success":
                // Navigate to content generation or history
                print("[AppDelegate] User tapped on content success notification")
            case "content_error":
                // Navigate to content generation to retry
                print("[AppDelegate] User tapped on content error notification")
            case "achievement":
                // Navigate to profile or achievements
                print("[AppDelegate] User tapped on achievement notification")
            case "streak_milestone":
                // Navigate to dashboard
                print("[AppDelegate] User tapped on streak notification")
            default:
                break
            }
        }
        
        completionHandler()
    }
}

@main
struct LirooApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var authViewModel = AuthViewModel()

    // Initialize the persistence controller
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(authViewModel)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

