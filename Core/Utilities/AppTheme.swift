import SwiftUI

enum AppTheme: String, Codable {
    case light
    case dark
    case system
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
