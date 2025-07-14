import Foundation

// MARK: - Comic Response Models
struct ComicResponse: Codable {
    let success: Bool
    let comic: Comic?
    let error: String?
    let request_id: String?
    let timestamp: String?
    
    // Custom decoding to handle both old and new response formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle new standardized response format
        if let success = try? container.decode(Bool.self, forKey: .success) {
            self.success = success
        } else {
            // Fallback for old format - assume success if no error
            self.success = try? container.decode(String.self, forKey: .error) == nil
        }
        
        self.comic = try? container.decode(Comic.self, forKey: .comic)
        self.error = try? container.decode(String.self, forKey: .error)
        self.request_id = try? container.decode(String.self, forKey: .request_id)
        self.timestamp = try? container.decode(String.self, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case comic
        case error
        case request_id
        case timestamp
    }
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
        self.panelLayout = try container.decode([ComicPanel].self, forKey: .panelLayout)

        // Robustly decode the character style guide
        var decodedGuide = [String: String]()
        if let guide = try? container.decode([String: String].self, forKey: .characterStyleGuide) {
            // This is the expected format (String: String)
            decodedGuide = guide
        } else if let complexGuide = try? container.decode([String: [String: String]].self, forKey: .characterStyleGuide) {
            // This handles the unexpected format (String: Dictionary)
            decodedGuide = complexGuide.mapValues { detailsDict -> String in
                return detailsDict.map { "\($0.key.replacingOccurrences(of: "_", with: " ").capitalized): \($0.value)" }.joined(separator: ", ")
            }
        } else if let mixedGuide = try? container.decode([String: Any].self, forKey: .characterStyleGuide) {
            // Handle mixed types in character style guide
            for (key, value) in mixedGuide {
                if let stringValue = value as? String {
                    decodedGuide[key] = stringValue
                } else if let dictValue = value as? [String: Any] {
                    let descriptionParts = dictValue.compactMap { (k, v) -> String? in
                        if let strValue = v as? String {
                            return "\(k.replacingOccurrences(of: "_", with: " ").capitalized): \(strValue)"
                        }
                        return nil
                    }
                    decodedGuide[key] = descriptionParts.joined(separator: ", ")
                } else {
                    decodedGuide[key] = String(describing: value)
                }
            }
        } else {
            // Fallback if the structure is something else entirely or missing
            decodedGuide = [:]
        }
        self.characterStyleGuide = decodedGuide
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
        
        // Robustly decode dialogue
        var decodedDialogue = [String: String]()
        if let dialogue = try? container.decode([String: String].self, forKey: .dialogue) {
            decodedDialogue = dialogue
        } else if let mixedDialogue = try? container.decode([String: Any].self, forKey: .dialogue) {
            // Handle mixed types in dialogue
            for (key, value) in mixedDialogue {
                if let stringValue = value as? String {
                    decodedDialogue[key] = stringValue
                } else {
                    decodedDialogue[key] = String(describing: value)
                }
            }
        }
        self.dialogue = decodedDialogue
        
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
    let userToken: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case level
        case imageStyle = "image_style"
        case userToken = "user_token"
    }
}

// MARK: - Enhanced Progress Response
struct ProgressResponse: Codable {
    let success: Bool
    let step: String
    let step_number: Int
    let total_steps: Int
    let details: String
    let last_updated: String
    let progress_percentage: Double
    let request_id: String?
    let timestamp: String?
    
    // Custom decoding to handle both old and new progress formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle new standardized response format
        if let success = try? container.decode(Bool.self, forKey: .success) {
            self.success = success
        } else {
            // Fallback for old format - assume success
            self.success = true
        }
        
        self.step = try container.decode(String.self, forKey: .step)
        self.step_number = try container.decode(Int.self, forKey: .step_number)
        self.total_steps = try container.decode(Int.self, forKey: .total_steps)
        self.details = try container.decode(String.self, forKey: .details)
        self.last_updated = try container.decode(String.self, forKey: .last_updated)
        self.progress_percentage = try container.decode(Double.self, forKey: .progress_percentage)
        self.request_id = try? container.decode(String.self, forKey: .request_id)
        self.timestamp = try? container.decode(String.self, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case step
        case step_number
        case total_steps
        case details
        case last_updated
        case progress_percentage
        case request_id
        case timestamp
    }
}

// MARK: - Comic Generation Error Types
enum ComicGenerationError: Error, LocalizedError {
    case invalidResponse
    case networkError(String)
    case decodingError(String)
    case backendError(String)
    case timeout
    case noInternetConnection
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to process response: \(message)"
        case .backendError(let message):
            return "Backend error: \(message)"
        case .timeout:
            return "Request timed out. Please try again."
        case .noInternetConnection:
            return "No internet connection. Please check your connection and try again."
        }
    }
} 