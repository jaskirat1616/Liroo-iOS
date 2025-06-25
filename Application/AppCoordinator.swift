import SwiftUI

class AppCoordinator: ObservableObject {
    @Published var currentTab: Tab = .dashboard
    @Published var selectedSidebarItem: Tab? = .dashboard
    @Published var isIPadLayout: Bool = false
    
    enum Tab: Hashable, CaseIterable, Identifiable {
        case dashboard
        case reading
        case flashcards
        case history
        case profile
        case generation
        case settings
        
        var id: String { self.rawValue }
        
        var rawValue: String {
            switch self {
            case .dashboard: return "dashboard"
            case .reading: return "reading"
            case .flashcards: return "flashcards"
            case .history: return "history"
            case .profile: return "profile"
            case .generation: return "generation"
            case .settings: return "settings"
            }
        }
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .reading: return "Reading"
            case .flashcards: return "Flashcards"
            case .history: return "History"
            case .profile: return "Profile"
            case .generation: return "Generate"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"
            case .reading: return "book.fill"
            case .flashcards: return "rectangle.on.rectangle.fill"
            case .history: return "list.bullet.rectangle.portrait"
            case .profile: return "person.fill"
            case .generation: return "wand.and.stars"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    init() {
        // Detect if we're on iPad
        isIPadLayout = UIDevice.current.userInterfaceIdiom == .pad
    }
    
    func switchToTab(_ tab: Tab) {
        currentTab = tab
        selectedSidebarItem = tab
    }
    
    func handleSidebarSelection(_ tab: Tab?) {
        if let tab = tab {
            switchToTab(tab)
        }
    }
    
    // MARK: - iPad Navigation Helpers
    func getSidebarItems() -> [Tab] {
        return [.dashboard, .generation, .history, .profile, .settings]
    }
    
    func isCurrentTab(_ tab: Tab) -> Bool {
        return currentTab == tab
    }
} 