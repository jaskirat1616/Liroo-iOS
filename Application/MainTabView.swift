import SwiftUI

struct MainTabView: View {
    @StateObject private var coordinator = AppCoordinator()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        TabView(selection: $coordinator.currentTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(AppCoordinator.Tab.dashboard)

            ContentGenerationView()
                .tabItem {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .tag(AppCoordinator.Tab.generation)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet.rectangle.portrait")
                }
                .tag(AppCoordinator.Tab.history)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(AppCoordinator.Tab.profile)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppCoordinator.Tab.settings)
        }
        .environmentObject(coordinator)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
