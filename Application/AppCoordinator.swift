import SwiftUI

class AppCoordinator: ObservableObject {
    @Published var currentTab: Tab = .generation
    
    enum Tab: Hashable, CaseIterable, Identifiable {
        case reading
        case history
        case profile
        case generation
        case settings
        case help
        
        var id: String { self.rawValue }
        
        var rawValue: String {
            switch self {
            case .reading: return "reading"
            case .history: return "history"
            case .profile: return "profile"
            case .generation: return "generation"
            case .settings: return "settings"
            case .help: return "help"
            }
        }
        
        var title: String {
            switch self {
            case .reading: return "Reading"
            case .history: return "History"
            case .profile: return "Profile"
            case .generation: return "Generate"
            case .settings: return "Settings"
            case .help: return "Help"
            }
        }
        
        var icon: String {
            switch self {
            case .reading: return "book.fill"
            case .history: return "list.bullet.rectangle.portrait"
            case .profile: return "person.fill"
            case .generation: return "wand.and.stars"
            case .settings: return "gearshape.fill"
            case .help: return "questionmark.circle.fill"
            }
        }
    }
    
    func switchToTab(_ tab: Tab) {
        currentTab = tab
    }
} 