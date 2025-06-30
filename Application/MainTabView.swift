import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    private let tabBarItems: [AppCoordinator.Tab] = [
        .dashboard, .generation, .history, .profile
    ]
    
    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        if isPad {
            // Default TabView for iPad
            TabView(selection: $coordinator.currentTab) {
                NavigationStack { DashboardView() }
                    .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }
                    .tag(AppCoordinator.Tab.dashboard)
                NavigationStack { ContentGenerationView() }
                    .tabItem { Label("Generate", systemImage: "wand.and.stars") }
                    .tag(AppCoordinator.Tab.generation)
                NavigationStack { HistoryView() }
                    .tabItem { Label("History", systemImage: "list.bullet.rectangle.portrait") }
                    .tag(AppCoordinator.Tab.history)
                NavigationStack { ProfileView() }
                    .tabItem { Label("Profile", systemImage: "person.fill") }
                    .tag(AppCoordinator.Tab.profile)
            }
            .environmentObject(coordinator)
        } else {
            // Custom floating tab bar for iPhone
            ZStack(alignment: .bottom) {
                // Main content
                Group {
                    switch coordinator.currentTab {
                    case .dashboard:
                        NavigationStack { DashboardView() }
                    case .generation:
                        NavigationStack { ContentGenerationView() }
                    case .history:
                        NavigationStack { HistoryView() }
                    case .profile:
                        NavigationStack { ProfileView() }
                    default:
                        NavigationStack { DashboardView() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Custom Tab Bar
                HStack {
                    ForEach(tabBarItems, id: \ .self) { tab in
                        Button(action: {
                            withAnimation(.spring()) {
                                coordinator.switchToTab(tab)
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(coordinator.currentTab == tab ? Color.accentColor : Color.primary.opacity(0.6))
                                Text(tab.title)
                                    .font(.caption2)
                                    .foregroundColor(coordinator.currentTab == tab ? Color.accentColor : Color.primary.opacity(0.6))
                            }
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .background(
                    Group {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                )
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .edgesIgnoringSafeArea(.bottom)
            .environmentObject(coordinator)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
                .environmentObject(AppCoordinator())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .previewDevice("iPhone 15 Pro")
            MainTabView()
                .environmentObject(AppCoordinator())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        }
    }
}
