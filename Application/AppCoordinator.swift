import SwiftUI

class AppCoordinator: ObservableObject {
    @Published var currentTab: Tab = .dashboard
    
    enum Tab {
        case dashboard
        case reading
        case flashcards
        case history
        case profile
    }
    
    func switchToTab(_ tab: Tab) {
        currentTab = tab
    }
} 