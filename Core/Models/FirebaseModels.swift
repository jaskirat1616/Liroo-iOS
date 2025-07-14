import FirebaseFirestore
import FirebaseFirestore


// MARK: - Firebase Story Models

struct FirebaseStory: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var title: String
    var overview: String?
    var level: String
    var imageStyle: String?
    var chapters: [FirebaseChapter]?
    var mainCharacters: [FirebaseCharacter]? // New: Main characters
    var coverImageUrl: String? // New: Story cover/hero image
    var summaryImageUrl: String? // New: Story conclusion/summary image
    var createdAt: Timestamp? = Timestamp(date: Date())

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseStory, rhs: FirebaseStory) -> Bool {
        lhs.id == rhs.id
    }

    // If you need to initialize with a specific ID for creation:
    init(id: String? = nil, userId: String, title: String, overview: String?, level: String, imageStyle: String?, chapters: [FirebaseChapter]?, mainCharacters: [FirebaseCharacter]? = nil, coverImageUrl: String? = nil, summaryImageUrl: String? = nil, createdAt: Timestamp? = nil) {
        self.id = id
        self.userId = userId
        self.title = title
        self.overview = overview
        self.level = level
        self.imageStyle = imageStyle
        self.chapters = chapters
        self.mainCharacters = mainCharacters
        self.coverImageUrl = coverImageUrl
        self.summaryImageUrl = summaryImageUrl
        self.createdAt = createdAt ?? Timestamp(date: Date())
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var tempId = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        if tempId == "" { tempId = UUID().uuidString }
        let tempUserId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        let tempTitle = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        let tempOverview = try container.decodeIfPresent(String.self, forKey: .overview)
        let tempLevel = try container.decodeIfPresent(String.self, forKey: .level) ?? "unknown"
        let tempImageStyle = try container.decodeIfPresent(String.self, forKey: .imageStyle)
        let tempChapters = try container.decodeIfPresent([FirebaseChapter].self, forKey: .chapters) ?? []
        let tempMainCharacters = try container.decodeIfPresent([FirebaseCharacter].self, forKey: .mainCharacters)
        let tempCoverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        let tempSummaryImageUrl = try container.decodeIfPresent(String.self, forKey: .summaryImageUrl)
        let tempCreatedAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) ?? Timestamp(date: Date())
        // Assign all properties
        id = tempId
        userId = tempUserId
        title = tempTitle
        overview = tempOverview
        level = tempLevel
        imageStyle = tempImageStyle
        chapters = tempChapters
        mainCharacters = tempMainCharacters
        coverImageUrl = tempCoverImageUrl
        summaryImageUrl = tempSummaryImageUrl
        createdAt = tempCreatedAt
        // Now you can use self
        if userId == "" { print("[FirebaseStory.decoder] Warning: userId missing, set to empty string for id: \(id ?? "nil")") }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case title
        case overview
        case level
        case imageStyle
        case chapters
        case mainCharacters
        case coverImageUrl
        case summaryImageUrl
        case createdAt
    }
}

struct FirebaseChapter: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var content: String
    var order: Int
    var imageUrl: String? // Main chapter image
    var keyEvents: [String]? // Key events in this chapter
    var characterInteractions: [String]? // Character interactions in this chapter
    var emotionalMoments: [String]? // Emotional moments in this chapter
    
    // New: Multiple images for different aspects
    var keyEventImages: [FirebaseEventImage]? // Multiple images for key events
    var emotionalMomentImages: [FirebaseEventImage]? // Multiple images for emotional moments
    var characterInteractionImages: [FirebaseEventImage]? // Multiple images for character interactions
    var settingImageUrl: String? // Setting/background image
    var actionImageUrl: String? // Action sequence image

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseChapter, rhs: FirebaseChapter) -> Bool {
        lhs.id == rhs.id
    }

    init(id: String, title: String, content: String, order: Int, imageUrl: String? = nil, keyEvents: [String]? = nil, characterInteractions: [String]? = nil, emotionalMoments: [String]? = nil, keyEventImages: [FirebaseEventImage]? = nil, emotionalMomentImages: [FirebaseEventImage]? = nil, characterInteractionImages: [FirebaseEventImage]? = nil, settingImageUrl: String? = nil, actionImageUrl: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.imageUrl = imageUrl
        self.keyEvents = keyEvents
        self.characterInteractions = characterInteractions
        self.emotionalMoments = emotionalMoments
        self.keyEventImages = keyEventImages
        self.emotionalMomentImages = emotionalMomentImages
        self.characterInteractionImages = characterInteractionImages
        self.settingImageUrl = settingImageUrl
        self.actionImageUrl = actionImageUrl
    }
    
    // Custom decoding to handle both 'id' and 'chapterId' for legacy support
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idValue = try container.decodeIfPresent(String.self, forKey: .id) {
            id = idValue
        } else if let chapterIdValue = try container.decodeIfPresent(String.self, forKey: .chapterId) {
            id = chapterIdValue
        } else {
            id = UUID().uuidString
            print("[FirebaseChapter.decoder] Warning: No id or chapterId found, generated new UUID: \(id)")
        }
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        keyEvents = try container.decodeIfPresent([String].self, forKey: .keyEvents)
        characterInteractions = try container.decodeIfPresent([String].self, forKey: .characterInteractions)
        emotionalMoments = try container.decodeIfPresent([String].self, forKey: .emotionalMoments)
        keyEventImages = try container.decodeIfPresent([FirebaseEventImage].self, forKey: .keyEventImages)
        emotionalMomentImages = try container.decodeIfPresent([FirebaseEventImage].self, forKey: .emotionalMomentImages)
        characterInteractionImages = try container.decodeIfPresent([FirebaseEventImage].self, forKey: .characterInteractionImages)
        settingImageUrl = try container.decodeIfPresent(String.self, forKey: .settingImageUrl)
        actionImageUrl = try container.decodeIfPresent(String.self, forKey: .actionImageUrl)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case chapterId
        case title
        case content
        case order
        case imageUrl
        case keyEvents
        case characterInteractions
        case emotionalMoments
        case keyEventImages
        case emotionalMomentImages
        case characterInteractionImages
        case settingImageUrl
        case actionImageUrl
    }
}

// New: Firebase Event Image structure
struct FirebaseEventImage: Identifiable, Codable, Hashable {
    var id: String
    var description: String // Event description or moment description
    var imageUrl: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseEventImage, rhs: FirebaseEventImage) -> Bool {
        lhs.id == rhs.id
    }
    
    init(id: String, description: String, imageUrl: String) {
        self.id = id
        self.description = description
        self.imageUrl = imageUrl
    }
}

struct FirebaseCharacter: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var description: String
    var personality: String
    var imageUrl: String? // Character portrait image

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseCharacter, rhs: FirebaseCharacter) -> Bool {
        lhs.id == rhs.id
    }

    init(id: String, name: String, description: String, personality: String, imageUrl: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.personality = personality
        self.imageUrl = imageUrl
    }
}

// MARK: - Firebase User Content Models

struct FirebaseUserContent: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String?
    var topic: String?
    var level: String?
    var summarizationTier: String?
    var blocks: [FirebaseContentBlock]?
    var createdAt: Timestamp? = Timestamp(date: Date())

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseUserContent, rhs: FirebaseUserContent) -> Bool {
        lhs.id == rhs.id
    }
    
    // Regular initializer
    init(id: String? = nil, userId: String?, topic: String?, level: String?, summarizationTier: String?, blocks: [FirebaseContentBlock]?, createdAt: Timestamp? = nil) {
        self.id = id
        self.userId = userId
        self.topic = topic
        self.level = level
        self.summarizationTier = summarizationTier
        self.blocks = blocks
        self.createdAt = createdAt ?? Timestamp(date: Date())
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        level = try container.decodeIfPresent(String.self, forKey: .level)
        summarizationTier = try container.decodeIfPresent(String.self, forKey: .summarizationTier)
        blocks = try container.decodeIfPresent([FirebaseContentBlock].self, forKey: .blocks)
        createdAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) ?? Timestamp(date: Date())
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case topic
        case level
        case summarizationTier
        case blocks
        case createdAt
    }
}

struct FirebaseContentBlock: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var type: String?
    var content: String?
    var alt: String?
    var firebaseImageUrl: String?
    var options: [FirebaseQuizOption]?
    var correctAnswerID: String?
    var explanation: String?

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(content)
        hasher.combine(firebaseImageUrl)
    }

    static func == (lhs: FirebaseContentBlock, rhs: FirebaseContentBlock) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.content == rhs.content && lhs.firebaseImageUrl == rhs.firebaseImageUrl
    }
    
    // Regular initializer
    init(type: String?, content: String?, alt: String?, firebaseImageUrl: String?, options: [FirebaseQuizOption]?, correctAnswerID: String?, explanation: String?) {
        self.type = type
        self.content = content
        self.alt = alt
        self.firebaseImageUrl = firebaseImageUrl
        self.options = options
        self.correctAnswerID = correctAnswerID
        self.explanation = explanation
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, but use default if missing
        if let decodedId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = decodedId
        }
        type = try container.decodeIfPresent(String.self, forKey: .type)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
        firebaseImageUrl = try container.decodeIfPresent(String.self, forKey: .firebaseImageUrl)
        options = try container.decodeIfPresent([FirebaseQuizOption].self, forKey: .options)
        correctAnswerID = try container.decodeIfPresent(String.self, forKey: .correctAnswerID)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case content
        case alt
        case firebaseImageUrl
        case options
        case correctAnswerID
        case explanation
    }
}

struct FirebaseQuizOption: Identifiable, Codable, Hashable {
    var id: String? // This should be the unique ID of the option
    var text: String?

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseQuizOption, rhs: FirebaseQuizOption) -> Bool {
        lhs.id == rhs.id
    }
    
    // Regular initializer
    init(id: String?, text: String?) {
        self.id = id
        self.text = text
    }
}

// MARK: - Firebase Lecture Models

struct FirebaseLecture: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var userId: String
    var title: String
    var level: String
    var imageStyle: String?
    var sections: [FirebaseLectureSection]?
    var audioFiles: [FirebaseAudioFile]?
    var createdAt: Timestamp? = Timestamp(date: Date())

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseLecture, rhs: FirebaseLecture) -> Bool {
        lhs.id == rhs.id
    }

    init(id: String? = nil, userId: String, title: String, level: String, imageStyle: String?, sections: [FirebaseLectureSection]?, audioFiles: [FirebaseAudioFile]?) {
        self.userId = userId
        self.title = title
        self.level = level
        self.imageStyle = imageStyle
        self.sections = sections
        self.audioFiles = audioFiles
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var tempId = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        if tempId == "" { tempId = UUID().uuidString }
        let tempUserId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        let tempTitle = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        let tempLevel = try container.decodeIfPresent(String.self, forKey: .level) ?? "unknown"
        let tempImageStyle = try container.decodeIfPresent(String.self, forKey: .imageStyle)
        let tempSections = try container.decodeIfPresent([FirebaseLectureSection].self, forKey: .sections) ?? []
        let tempAudioFiles = try container.decodeIfPresent([FirebaseAudioFile].self, forKey: .audioFiles)
        let tempCreatedAt = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) ?? Timestamp(date: Date())
        // Assign all properties
        id = tempId
        userId = tempUserId
        title = tempTitle
        level = tempLevel
        imageStyle = tempImageStyle
        sections = tempSections
        audioFiles = tempAudioFiles
        createdAt = tempCreatedAt
        // Now you can use self
        if userId == "" { print("[FirebaseLecture.decoder] Warning: userId missing, set to empty string for id: \(id ?? "nil")") }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case title
        case level
        case imageStyle
        case sections
        case audioFiles
        case createdAt
    }
}

struct FirebaseLectureSection: Identifiable, Codable, Hashable {
    var id: String { sectionId }
    var sectionId: String
    var title: String?
    var script: String?
    var imagePrompt: String?
    var imageUrl: String?
    var order: Int?

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(sectionId)
    }

    static func == (lhs: FirebaseLectureSection, rhs: FirebaseLectureSection) -> Bool {
        lhs.sectionId == rhs.sectionId
    }
    
    // Regular initializer
    init(sectionId: String, title: String?, script: String?, imagePrompt: String?, imageUrl: String?, order: Int?) {
        self.sectionId = sectionId
        self.title = title
        self.script = script
        self.imagePrompt = imagePrompt
        self.imageUrl = imageUrl
        self.order = order
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        sectionId = try container.decode(String.self, forKey: .sectionId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        script = try container.decodeIfPresent(String.self, forKey: .script)
        imagePrompt = try container.decodeIfPresent(String.self, forKey: .imagePrompt)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        order = try container.decodeIfPresent(Int.self, forKey: .order)
    }
    
    enum CodingKeys: String, CodingKey {
        case sectionId
        case title
        case script
        case imagePrompt
        case imageUrl
        case order
    }
}

struct FirebaseAudioFile: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var type: String?
    var text: String?
    var url: String?
    var filename: String?
    var section: Int?

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(url)
    }

    static func == (lhs: FirebaseAudioFile, rhs: FirebaseAudioFile) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.url == rhs.url
    }
    
    // Regular initializer
    init(type: String?, text: String?, url: String?, filename: String?, section: Int?) {
        self.type = type
        self.text = text
        self.url = url
        self.filename = filename
        self.section = section
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, but use default if missing
        if let decodedId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = decodedId
        }
        type = try container.decodeIfPresent(String.self, forKey: .type)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        section = try container.decodeIfPresent(Int.self, forKey: .section)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case text
        case url
        case filename
        case section
    }
}
