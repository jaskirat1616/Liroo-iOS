import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        TabView(selection: $coordinator.currentTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2.fill")
            }
            .tag(AppCoordinator.Tab.dashboard)

            NavigationStack {
                ContentGenerationView()
            }
            .tabItem {
                Label("Generate", systemImage: "wand.and.stars")
            }
            .tag(AppCoordinator.Tab.generation)
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "list.bullet.rectangle.portrait")
            }
            .tag(AppCoordinator.Tab.history)
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(AppCoordinator.Tab.profile)
        }
        .environmentObject(coordinator)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppCoordinator())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
