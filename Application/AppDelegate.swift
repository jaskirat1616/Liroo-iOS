import UIKit
import UserNotifications
import BackgroundTasks
import FirebaseCrashlytics
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // This dictionary will hold the completion handlers for each session identifier.
    var backgroundSessionCompletionHandlers: [String: () -> Void] = [:]

    func application(_ application: UIApplication, 
                     handleEventsForBackgroundURLSession identifier: String, 
                     completionHandler: @escaping () -> Void) {
        // Store the completion handler.
        backgroundSessionCompletionHandlers[identifier] = completionHandler
        
        // Pass the completion handler to the BackgroundNetworkManager
        if identifier == "com.liroo.background.manager" {
            BackgroundNetworkManager.shared.sessionCompletionHandler = completionHandler
        }
    }

    // This method handles notification presentation in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner, play sound, and update badge for foreground notifications.
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - App Lifecycle Methods
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Crashlytics
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        
        // Test Crashlytics integration (remove this after testing)
        Crashlytics.crashlytics().log("App launched successfully - Crashlytics test")
        Crashlytics.crashlytics().setCustomValue("test_value", forKey: "test_key")
        
        // Test crash function (uncomment to test - REMOVE AFTER TESTING)
        // testCrashlyticsIntegration()
        
        // Set up uncaught exception handler
        setupUncaughtExceptionHandler()
        
        // Set up system monitoring
        setupSystemMonitoring()
        
        // Log device info
        CrashlyticsManager.shared.logDeviceInfo()
        
        // Set up auth state listener for user tracking
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                CrashlyticsManager.shared.setUser(
                    userId: user.uid,
                    email: user.email,
                    name: user.displayName
                )
            } else {
                CrashlyticsManager.shared.clearUser()
            }
        }
        
        // Log app launch
        CrashlyticsManager.shared.logAppStateChange(state: "app_launched")
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        CrashlyticsManager.shared.logAppStateChange(state: "app_will_resign_active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        CrashlyticsManager.shared.logAppStateChange(state: "app_did_enter_background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        CrashlyticsManager.shared.logAppStateChange(state: "app_will_enter_foreground")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        CrashlyticsManager.shared.logAppStateChange(state: "app_did_become_active")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        CrashlyticsManager.shared.logAppStateChange(state: "app_will_terminate")
    }
    
    // MARK: - Memory Warning Handling
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        CrashlyticsManager.shared.logMemoryWarning()
        
        // Log additional memory information
        let memoryUsage = getMemoryUsage()
        CrashlyticsManager.shared.logMemoryIssue(
            operation: "system_memory_warning",
            memoryUsage: memoryUsage.used,
            availableMemory: memoryUsage.available
        )
    }
    
    // MARK: - System Monitoring Setup
    
    private func setupUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            // Convert NSException to a proper Error
            let exceptionError = NSError(
                domain: "UncaughtException",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: exception.reason ?? "Unknown exception",
                    "exception_name": exception.name.rawValue,
                    "exception_reason": exception.reason ?? "unknown",
                    "call_stack": exception.callStackSymbols.joined(separator: "\n")
                ]
            )
            
            CrashlyticsManager.shared.logSystemError(
                error: exceptionError,
                operation: "uncaught_exception",
                systemInfo: [
                    "exception_name": exception.name.rawValue,
                    "exception_reason": exception.reason ?? "unknown",
                    "call_stack": exception.callStackSymbols.joined(separator: "\n")
                ]
            )
        }
    }
    
    private func setupSystemMonitoring() {
        // Monitor for low memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            CrashlyticsManager.shared.logMemoryIssue(
                operation: "notification_memory_warning"
            )
        }
        
        // Monitor for significant time changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            CrashlyticsManager.shared.logAppStateIssue(
                issue: "significant_time_change",
                state: "system_notification"
            )
        }
        
        // Monitor for protected data becoming available
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { _ in
            CrashlyticsManager.shared.logAppStateIssue(
                issue: "protected_data_unavailable",
                state: "system_notification"
            )
        }
        
        // Monitor for protected data becoming available
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { _ in
            CrashlyticsManager.shared.logAppStateIssue(
                issue: "protected_data_available",
                state: "system_notification"
            )
        }
    }
    
    // MARK: - Memory Usage Helper
    
    private func getMemoryUsage() -> (used: Int, available: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Int(info.resident_size) / 1024 / 1024 // Convert to MB
            let totalMemory = Int(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 // Convert to MB
            let availableMemory = totalMemory - usedMemory
            
            return (used: usedMemory, available: availableMemory)
        } else {
            return (used: 0, available: 0)
        }
    }
    
    // MARK: - Test Functions (REMOVE AFTER TESTING)
    
    private func testCrashlyticsIntegration() {
        // This function is for testing Crashlytics integration
        // Uncomment the line below to test a crash
        // fatalError("Test crash for Crashlytics integration")
        
        // Test non-fatal error logging
        let testError = NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Test error for Crashlytics"])
        CrashlyticsManager.shared.logCustomError(
            error: testError,
            context: "test_integration",
            additionalData: ["test_timestamp": Date().timeIntervalSince1970]
        )
        
        print("Crashlytics test completed - check Firebase Console")
    }
}
