import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard

    // You might access the context here if MainTabView itself needs to perform Core Data operations
    // @Environment(\.managedObjectContext) private var viewContext 
    // However, for now, DashboardScreen gets its data via DashboardViewModel which will use a service.

    enum Tab: Hashable { // Added Hashable for potential future use with .tag
        case dashboard
        case reading
        case profile
        case generation
        case settings

    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView() // Assuming DashboardView is the correct name of your dashboard screen
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(Tab.dashboard)


            ContentGenerationView()
                .tabItem {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .tag(Tab.generation)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet.rectangle.portrait")
                }
                  .tag(Tab.reading)
            
            ProfileView() // Your actual or new placeholder ProfileView
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)

             SettingsView() // Add SettingsView as a tab
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                 .tag(Tab.settings)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            // For previews that might involve Core Data dependent views within MainTabView
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
