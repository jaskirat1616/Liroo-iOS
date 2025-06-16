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

    var body: some Scene {
        WindowGroup {
            // If user is authenticated, show main app content (TabView)
            // Otherwise, show a login/authentication view
            // This is a common pattern. Adjust if your auth flow is different.
            
            // For now, let's assume we always show the TabView.
            // You might want to wrap this in an if/else based on authViewModel.isAuthenticated
            
            MainAppView() // New View that will host the TabView
                .environmentObject(authViewModel) // Pass AuthViewModel if needed by subviews
        }
    }
}

// It's good practice to encapsulate the main TabView structure
struct MainAppView: View {
    var body: some View {
        TabView {
            ContentGenerationView()
                .tabItem {
                    Label("Generate", systemImage: "wand.and.stars")
                }
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet.rectangle.portrait")
                }
            
            // Add other main views as tabs here if needed
            // For example, a ProfileView:
            // ProfileView()
            //     .tabItem {
            //         Label("Profile", systemImage: "person.crop.circle")
            //     }
        }
    }
}
