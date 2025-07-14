import Foundation

// MARK: - Comic Response Models
struct ComicResponse: Codable {
    let comic: Comic?
    let error: String?
    let request_id: String?
}

struct Comic: Identifiable, Codable, Equatable {
    let id: UUID
    let comicTitle: String
    let theme: String
    let characterStyleGuide: [String: String]
    let panelLayout: [ComicPanel]
    
    enum CodingKeys: String, CodingKey {
        case id
        case comicTitle = "comic_title"
        case theme
        case characterStyleGuide = "character_style_guide"
        case panelLayout = "panel_layout"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.comicTitle = try container.decode(String.self, forKey: .comicTitle)
        self.theme = try container.decode(String.self, forKey: .theme)
        self.characterStyleGuide = try container.decode([String: String].self, forKey: .characterStyleGuide)
        self.panelLayout = try container.decode([ComicPanel].self, forKey: .panelLayout)
    }
    
    init(id: UUID = UUID(), comicTitle: String, theme: String, characterStyleGuide: [String: String], panelLayout: [ComicPanel]) {
        self.id = id
        self.comicTitle = comicTitle
        self.theme = theme
        self.characterStyleGuide = characterStyleGuide
        self.panelLayout = panelLayout
    }
}

struct ComicPanel: Identifiable, Codable, Equatable {
    let id: UUID
    let panelId: Int
    let scene: String
    let imagePrompt: String
    let dialogue: [String: String]
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case panelId = "panel_id"
        case scene
        case imagePrompt = "image_prompt"
        case dialogue
        case imageUrl = "image_url"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.panelId = try container.decode(Int.self, forKey: .panelId)
        self.scene = try container.decode(String.self, forKey: .scene)
        self.imagePrompt = try container.decode(String.self, forKey: .imagePrompt)
        self.dialogue = try container.decode([String: String].self, forKey: .dialogue)
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
    }
    
    init(id: UUID = UUID(), panelId: Int, scene: String, imagePrompt: String, dialogue: [String: String], imageUrl: String? = nil) {
        self.id = id
        self.panelId = panelId
        self.scene = scene
        self.imagePrompt = imagePrompt
        self.dialogue = dialogue
        self.imageUrl = imageUrl
    }
}

// MARK: - Comic Character Model
struct ComicCharacter: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let description: String
    
    init(id: UUID = UUID(), name: String, description: String) {
        self.id = id
        self.name = name
        self.description = description
    }
}

// MARK: - Comic Generation Parameters
struct ComicGenerationParameters: Codable {
    let text: String
    let level: String
    let imageStyle: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case level
        case imageStyle = "image_style"
    }
} 