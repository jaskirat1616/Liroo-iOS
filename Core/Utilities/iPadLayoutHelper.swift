import SwiftUI

// MARK: - iPad Layout Helper
struct iPadLayoutHelper {
    
    // MARK: - Device Detection
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPadLandscape: Bool {
        isIPad && UIDevice.current.orientation.isLandscape
    }
    
    static var isIPadPortrait: Bool {
        isIPad && UIDevice.current.orientation.isPortrait
    }
    
    // MARK: - Responsive Spacing
    static func adaptiveSpacing(_ baseSpacing: CGFloat) -> CGFloat {
        isIPad ? baseSpacing * 1.5 : baseSpacing
    }
    
    static func adaptivePadding(_ basePadding: CGFloat) -> CGFloat {
        isIPad ? basePadding * 1.3 : basePadding
    }
    
    // MARK: - Responsive Font Sizes
    static func adaptiveFontSize(_ baseSize: CGFloat) -> CGFloat {
        isIPad ? baseSize * 1.2 : baseSize
    }
    
    static func adaptiveTitleFontSize(_ baseSize: CGFloat) -> CGFloat {
        isIPad ? baseSize * 1.3 : baseSize
    }
    
    // MARK: - Grid Layout
    static func adaptiveGridColumns() -> [GridItem] {
        if isIPad {
            if isIPadLandscape {
                return Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
            } else {
                return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            }
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        }
    }
    
    static func adaptiveCompactGridColumns() -> [GridItem] {
        if isIPad {
            if isIPadLandscape {
                return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            } else {
                return Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
            }
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        }
    }
    
    // MARK: - Content Width
    static func maxContentWidth() -> CGFloat {
        if isIPad {
            return 800
        } else {
            return UIScreen.main.bounds.width
        }
    }
    
    // MARK: - Card Dimensions
    static func adaptiveCardHeight() -> CGFloat {
        isIPad ? 120 : 100
    }
    
    static func adaptiveCardWidth() -> CGFloat {
        if isIPad {
            return isIPadLandscape ? 200 : 180
        } else {
            return 160
        }
    }
    
    // MARK: - Image Sizes
    static func adaptiveImageSize() -> CGFloat {
        isIPad ? 60 : 44
    }
    
    static func adaptiveAvatarSize() -> CGFloat {
        isIPad ? 60 : 44
    }
    
    // MARK: - Button Sizes
    static func adaptiveButtonHeight() -> CGFloat {
        isIPad ? 56 : 44
    }
    
    static func adaptiveButtonPadding() -> CGFloat {
        isIPad ? 20 : 16
    }
    
    // MARK: - Navigation Helpers
    static func adaptiveNavigationTitleDisplayMode() -> NavigationBarItem.TitleDisplayMode {
        isIPad ? .large : .inline
    }
    
    static func adaptiveSidebarWidth() -> CGFloat {
        isIPad ? 320 : 280
    }
    
    static func adaptiveDetailViewPadding() -> CGFloat {
        isIPad ? 24 : 16
    }
}

// MARK: - View Extensions for iPad Optimization
extension View {
    
    // MARK: - Adaptive Padding
    func adaptivePadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let paddingValue = length ?? 16
        return self.padding(edges, paddingValue)
    }
    
    // MARK: - Adaptive Spacing
    func adaptiveSpacing(_ spacing: CGFloat) -> some View {
        self.environment(\.spacing, spacing)
    }
    
    // MARK: - iPad Centered Content
    func iPadCenteredContent() -> some View {
        self.frame(maxWidth: iPadLayoutHelper.isIPad ? iPadLayoutHelper.maxContentWidth() : .infinity)
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Adaptive Navigation Title
    func adaptiveNavigationTitle(_ title: String, displayMode: NavigationBarItem.TitleDisplayMode? = nil) -> some View {
        let titleDisplayMode = displayMode ?? iPadLayoutHelper.adaptiveNavigationTitleDisplayMode()
        return self.navigationTitle(title)
            .navigationBarTitleDisplayMode(titleDisplayMode)
    }
    
    // MARK: - Responsive Background
    func responsiveBackground(_ colorScheme: ColorScheme) -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(
                    colors: colorScheme == .dark ? 
                        [.cyan.opacity(0.1), Color(.systemBackground), Color(.systemBackground)] :
                        [.cyan.opacity(0.2), .white, .white]
                ),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    // MARK: - iPad Navigation Optimization
    func iPadNavigationOptimized() -> some View {
        self
            .navigationBarTitleDisplayMode(iPadLayoutHelper.adaptiveNavigationTitleDisplayMode())
            .toolbarBackground(.visible, for: .navigationBar)
    }
    
    // MARK: - Adaptive List Style
    func adaptiveListStyle() -> some View {
        Group {
            if iPadLayoutHelper.isIPad {
                self.listStyle(.insetGrouped)
            } else {
                self.listStyle(.plain)
            }
        }
    }
    
    // MARK: - Adaptive Form Style
    func adaptiveFormStyle() -> some View {
        Group {
            if iPadLayoutHelper.isIPad {
                self.formStyle(.grouped)
            } else {
                self.formStyle(.automatic)
            }
        }
    }
}

// MARK: - Environment Key for Adaptive Spacing
private struct SpacingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 8
}

extension EnvironmentValues {
    var spacing: CGFloat {
        get { self[SpacingKey.self] }
        set { self[SpacingKey.self] = newValue }
    }
} 