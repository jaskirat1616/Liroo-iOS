import SwiftUI

struct AppView: View {
    @StateObject private var coordinator = AppCoordinator()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        MainTabView()
            .environmentObject(coordinator)
    }
}