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
    
    @StateObject private var authViewModel = AuthViewModel() // Assuming you have an AuthViewModel that manages auth state

    // Initialize the persistence controller
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView() // Your main tab view
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

// It's good practice to encapsulate the main TabView structure
struct MainAppView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                     Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
            ContentGenerationView()
                .tabItem {
                    Label("Generate", systemImage: "wand.and.stars")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet.rectangle.portrait")
                }
            
            
            ProfileView()
                 .tabItem {
                     Label("Profile", systemImage: "person.crop.circle")
                 }

                 SettingsView() // Add SettingsView as a tab
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
