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