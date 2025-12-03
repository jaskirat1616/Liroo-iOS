import SwiftUI

struct AppView: View {
    @StateObject private var coordinator = AppCoordinator()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        MainTabView()
            .environmentObject(coordinator)
            .onAppear {
                // Ensure proper display scaling
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.windows.forEach { window in
                        window.contentScaleFactor = UIScreen.main.scale
                    }
                }
            }
    }
}