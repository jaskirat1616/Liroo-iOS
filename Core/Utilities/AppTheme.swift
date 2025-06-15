import SwiftUI

enum AppTheme: String, Codable {
    case light
    case dark
    case system
}

struct AppColors {
    static let primary = Color("Primary")
    static let secondary = Color("Secondary")
    static let background = Color("Background")
    static let text = Color("Text")
    static let accent = Color("Accent")
    
    // Semantic colors
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let error = Color("Error")
}

struct AppFonts {
    static let title = Font.custom("OpenDyslexic-Regular", size: 24)
    static let headline = Font.custom("OpenDyslexic-Regular", size: 20)
    static let body = Font.custom("OpenDyslexic-Regular", size: 16)
    static let caption = Font.custom("OpenDyslexic-Regular", size: 14)
}

struct AppStyles {
    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 8
    
    static let shadowRadius: CGFloat = 4
    static let shadowOpacity: Double = 0.1
} 