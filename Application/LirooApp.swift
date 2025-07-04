//
//  LirooApp.swift
//  Liroo
//
//  Created by JASKIRAT SINGH on 2025-06-13.
//

import SwiftUI
import Firebase
import UserNotifications

@main
struct LirooApp: App {
    // Connect the one true AppDelegate from AppDelegate.swift
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var authViewModel = AuthViewModel()
    // The unnecessary view models have been removed.

    init() {
        FirebaseApp.configure()
        // Correctly assign the appDelegate as the notification center's delegate
        UNUserNotificationCenter.current().delegate = appDelegate
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .environmentObject(appCoordinator)
                .environmentObject(authViewModel)
        }
    }
}

// The duplicate GlobalBackgroundProcessingManager has been removed from this file.
// It should live in its own dedicated file, likely in Core/Managers.

// Enum to identify content types for navigation
enum ContentType {
    case story
    case lecture
    case userContent
}


