import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var globalManager = GlobalBackgroundProcessingManager.shared
    
    private let tabBarItems: [AppCoordinator.Tab] = [
        .generation, .history, .profile
    ]
    
    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isPad {
                // iPad Layout
                ZStack {
                    // Main content area
                    TabView(selection: $coordinator.currentTab) {
                        NavigationStack {
                            ContentGenerationView()
                                .navigationTitle("Generate")
                                .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("Generate", systemImage: "wand.and.stars")
                        }
                        .tag(AppCoordinator.Tab.generation)
                        
                        NavigationStack {
                            HistoryView()
                                .navigationTitle("History")
                                .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("History", systemImage: "list.bullet.rectangle.portrait")
                        }
                        .tag(AppCoordinator.Tab.history)
                        
                        NavigationStack {
                            ProfileView()
                                .navigationTitle("Profile")
                                .navigationBarTitleDisplayMode(.large)
                        }
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                        .tag(AppCoordinator.Tab.profile)
                    }
                    .environmentObject(coordinator)
                    .onAppear {
                        // Configure tab bar appearance for iPad to be translucent
                        let appearance = UITabBarAppearance()
                        appearance.configureWithDefaultBackground()
                        
                        UITabBar.appearance().standardAppearance = appearance
                        UITabBar.appearance().scrollEdgeAppearance = appearance
                    }
                    
                    // Global Background Processing Indicator for iPad
                    VStack {
                        Spacer()
                        if globalManager.isBackgroundProcessing && globalManager.isIndicatorVisible {
                            globalBackgroundProcessingIndicator
                                .padding(.horizontal, 40)
                                .padding(.bottom, 85) // Position above the tab bar
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.3), value: globalManager.isBackgroundProcessing)
                        }
                    }
                }
            } else {
                // iPhone Layout
                ZStack {
                    // Main content area - NO bottom padding so it can scroll behind tab bar
                    Group {
                        switch coordinator.currentTab {
                        case .generation:
                            NavigationStack { ContentGenerationView() }
                        case .history:
                            NavigationStack { HistoryView() }
                        case .profile:
                            NavigationStack { ProfileView() }
                        default:
                            NavigationStack { ContentGenerationView() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Floating Tab Bar and Indicator
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Global Background Processing Indicator
                        if globalManager.isBackgroundProcessing && globalManager.isIndicatorVisible {
                            globalBackgroundProcessingIndicator
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.3), value: globalManager.isBackgroundProcessing)
                        }
                        
                        // Custom Tab Bar
                        HStack {
                            ForEach(tabBarItems, id: \.self) { tab in
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
                        .padding(.bottom, 34) // Adjust for safe area
                    }
                }
                .edgesIgnoringSafeArea(.bottom)
                .environmentObject(coordinator)
            }
        }
        .onAppear {
            globalManager.restoreFromUserDefaults()
        }
    }
    
    // MARK: - Global Background Processing Indicator
    private var globalBackgroundProcessingIndicator: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generating \(globalManager.generationType)...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Show detailed step information
                        if globalManager.currentStepNumber > 100 {
                            // This is a granular sub-step
                            let baseStep = globalManager.currentStepNumber / 100
                            let subStep = globalManager.currentStepNumber % 100
                            Text("Step \(baseStep).\(subStep)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            // This is a regular main step
                            Text("Step \(globalManager.currentStepNumber)/\(globalManager.totalSteps)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(globalManager.progress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Show time estimate based on progress
                    if globalManager.progress > 0.1 {
                        let estimatedTimeRemaining = estimateTimeRemaining(progress: globalManager.progress)
                        Text(estimatedTimeRemaining)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Button(action: {
                    globalManager.dismissIndicator()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.leading, 8)
                }
                .accessibilityLabel("Dismiss background processing indicator")
            }
            
            // Enhanced Progress Bar with animation
            ProgressView(value: globalManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                .frame(height: 3)
                .animation(.easeInOut(duration: 0.3), value: globalManager.progress)
            
            if !globalManager.currentStep.isEmpty {
                Text(globalManager.currentStep)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .animation(.easeInOut(duration: 0.2), value: globalManager.currentStep)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
    
    // Helper function to estimate time remaining
    private func estimateTimeRemaining(progress: Double) -> String {
        guard progress > 0 else { return "" }
        
        // Base time estimates for different content types
        let baseTime: TimeInterval
        switch globalManager.generationType.lowercased() {
        case "story":
            baseTime = 45 // 45 seconds for story generation
        case "lecture":
            baseTime = 30 // 30 seconds for lecture generation
        case "content":
            baseTime = 25 // 25 seconds for content generation
        case "comic":
            baseTime = 60 // 60 seconds for comic generation (more complex with multiple panels)
        default:
            baseTime = 30
        }
        
        let elapsedTime = baseTime * progress
        let remainingTime = baseTime - elapsedTime
        
        if remainingTime < 60 {
            return "~\(Int(remainingTime))s"
        } else {
            let minutes = Int(remainingTime / 60)
            let seconds = Int(remainingTime.truncatingRemainder(dividingBy: 60))
            return "~\(minutes)m \(seconds)s"
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
                .environmentObject(AppCoordinator())
                .environmentObject(AuthViewModel())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .previewDevice("iPhone 15 Pro")
            MainTabView()
                .environmentObject(AppCoordinator())
                .environmentObject(AuthViewModel())
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        }
    }
}
