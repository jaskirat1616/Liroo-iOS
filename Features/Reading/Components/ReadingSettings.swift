import SwiftUI

enum ReadingTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case sepia = "Sepia"
    case dark = "Dark"

    var id: String { self.rawValue }

    var backgroundColor: Color {
        switch self {
        case .light:
            return Color(UIColor.systemBackground) // Standard system background
        case .sepia:
            return Color(red: 245/255, green: 235/255, blue: 215/255) // A common sepia tone
        case .dark:
            // For a darker dark mode, closer to typical "dark themes"
            return Color(red: 28/255, green: 28/255, blue: 30/255) // Example: A very dark gray
            // return Color(UIColor.systemGray6) // This was the previous one, can be a bit light for "dark"
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .light, .sepia:
            return Color(UIColor.label) // Standard text color for light backgrounds
        case .dark:
            return Color(UIColor.systemGray) // Good for very dark backgrounds
            // return Color.white // Or pure white if the dark background is very dark
        }
    }
    
    var secondaryTextColor: Color {
        switch self {
        case .light, .sepia:
            return Color(UIColor.secondaryLabel)
        case .dark:
            return Color(UIColor.systemGray2) // Good for very dark backgrounds
            // return Color.gray // Or a lighter gray
        }
    }
}

enum ReadingFontStyle: String, CaseIterable, Identifiable {
    case systemDefault = "System Default"
    case systemSerif = "System Serif" // e.g., New York
    // case systemMonospaced = "System Monospaced" // Another option
    // case customSansSerif = "Open Sans" // Example if you bundle a custom font

    var id: String { self.rawValue }

    func getFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .systemDefault:
            return .system(size: size, weight: weight, design: .default)
        case .systemSerif:
            return .system(size: size, weight: weight, design: .serif)
        // case .systemMonospaced:
        //     return .system(size: size, weight: weight, design: .monospaced)
        // case .customSansSerif:
        //     return .custom("OpenSans-Regular", size: size) // Ensure "OpenSans-Regular.ttf" is bundled and in Info.plist
        }
    }
}
