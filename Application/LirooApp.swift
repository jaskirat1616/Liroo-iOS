//
//  LirooApp.swift
//  Liroo
//
//  Created by JASKIRAT SINGH on 2025-06-13.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
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
            Group {
                if authViewModel.isAuthenticated {
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    SplashScreenView()
                }
            }
            .environmentObject(authViewModel)
        }
    }
}

