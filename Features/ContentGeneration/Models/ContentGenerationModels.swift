import Foundation

// MARK: - Chapter Model
struct Chapter: Identifiable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    var firebaseImageUrl: String?
    
    init(id: UUID = UUID(), title: String, content: String, order: Int, firebaseImageUrl: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.firebaseImageUrl = firebaseImageUrl
    }
}

// MARK: - Lecture Models
struct Lecture: Identifiable, Codable {
    let id: UUID
    let title: String
    var sections: [LectureSection]
    let level: ReadingLevel
    let imageStyle: String?
    let createdAt: Date
    
    init(id: UUID = UUID(), title: String, sections: [LectureSection], level: ReadingLevel, imageStyle: String? = nil) {
        self.id = id
        self.title = title
        self.sections = sections
        self.level = level
        self.imageStyle = imageStyle
        self.createdAt = Date()
    }
}

struct LectureSection: Identifiable, Codable {
    let id: UUID
    let title: String
    let script: String
    let imagePrompt: String
    let imageUrl: String?
    let order: Int
    var firebaseImageUrl: String?
    
    init(id: UUID = UUID(), title: String, script: String, imagePrompt: String, imageUrl: String? = nil, order: Int, firebaseImageUrl: String? = nil) {
        self.id = id
        self.title = title
        self.script = script
        self.imagePrompt = imagePrompt
        self.imageUrl = imageUrl
        self.order = order
        self.firebaseImageUrl = firebaseImageUrl
    }
}

struct AudioFile: Identifiable, Codable {
    let id: UUID
    let type: AudioFileType
    let text: String
    let url: String
    let filename: String
    let section: Int?
    
    init(id: UUID = UUID(), type: AudioFileType, text: String, url: String, filename: String, section: Int? = nil) {
        self.id = id
        self.type = type
        self.text = text
        self.url = url
        self.filename = filename
        self.section = section
    }
}

enum AudioFileType: String, Codable {
    case title = "title"
    case sectionTitle = "section_title"
    case sectionScript = "section_script"
}

// MARK: - Image Generation Models

enum ImageStyle: String, Codable, CaseIterable {
    case ghibli = "ghibli"
    case disney = "disney"
    case comicBook = "comic_book"
    case watercolor = "watercolor"
    case pixelArt = "pixel_art"
    case threeDRender = "3d_render"
    
    var displayName: String {
        switch self {
        case .ghibli: return "Studio Ghibli"
        case .disney: return "Disney Classic"
        case .comicBook: return "Comic Book"
        case .watercolor: return "Watercolor"
        case .pixelArt: return "Pixel Art"
        case .threeDRender: return "3D Render"
        }
    }
    
    var backendRawValue: String {
        switch self {
        case .ghibli: return "Studio Ghibli"
        case .disney: return "Disney Classic"
        case .comicBook: return "Comic Book"
        case .watercolor: return "Watercolor"
        case .pixelArt: return "Pixel Art"
        case .threeDRender: return "3D Render"
        }
    }
}

enum ImageAspectRatio: String, Codable, CaseIterable {
    case square = "square"
    case landscape = "landscape"
    case portrait = "portrait"
    
    var displayName: String {
        switch self {
        case .square: return "Square (1:1)"
        case .landscape: return "Landscape (16:9)"
        case .portrait: return "Portrait (9:16)"
        }
    }
    
    var iconName: String {
        switch self {
        case .square: return "square.fill"
        case .landscape: return "rectangle.fill"
        case .portrait: return "rectangle.portrait.fill"
        }
    }
}

enum ImageSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "Small (512px)"
        case .medium: return "Medium (768px)"
        case .large: return "Large (1024px)"
        }
    }
    
    var dimension: Int {
        switch self {
        case .small: return 512
        case .medium: return 768
        case .large: return 1024
        }
    }
}

enum ImageQuality: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low (Fast)"
        case .medium: return "Medium (Balanced)"
        case .high: return "High (Best Quality)"
        }
    }
    
    var description: String {
        switch self {
        case .high: return "Best quality, slower generation"
        case .medium: return "Balanced quality and speed"
        case .low: return "Faster generation, reduced quality"
        }
    }
}

struct ImageEditOptions {
    let crop: Bool
    let rotate: Bool
    let filter: Bool
    
    static let none = ImageEditOptions(crop: false, rotate: false, filter: false)
    static let all = ImageEditOptions(crop: true, rotate: true, filter: true)
} 