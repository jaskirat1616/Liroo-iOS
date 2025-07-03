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
        
        // Register background tasks
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.liroo.contentgeneration", using: nil) { task in
            self.handleContentGenerationBackgroundTask(task: task as! BGAppRefreshTask)
        }
        
        return true
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
        
        // Here you can handle the user's interaction with the notification
        // For example, navigate to a specific screen
        
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

