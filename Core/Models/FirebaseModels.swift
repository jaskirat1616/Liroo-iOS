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
    var createdAt: Timestamp? = Timestamp(date: Date())

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FirebaseStory, rhs: FirebaseStory) -> Bool {
        lhs.id == rhs.id
    }

    // If you need to initialize with a specific ID for creation:
    init(id: String? = nil, userId: String, title: String, overview: String?, level: String, imageStyle: String?, chapters: [FirebaseChapter]?) {
        self.userId = userId
        self.title = title
        self.overview = overview
        self.level = level
        self.imageStyle = imageStyle
        self.chapters = chapters
    }
}

struct FirebaseChapter: Identifiable, Codable, Hashable {
    var id: String { chapterId }
    var chapterId: String
    var title: String?
    var content: String?
    var order: Int?
    var firebaseImageUrl: String?
    var imageStyle: String?

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(chapterId)
    }

    static func == (lhs: FirebaseChapter, rhs: FirebaseChapter) -> Bool {
        lhs.chapterId == rhs.chapterId
    }
    
    enum CodingKeys: String, CodingKey {
        case chapterId
        case title
        case content
        case order
        case firebaseImageUrl
        case imageStyle
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
    
    enum CodingKeys: String, CodingKey {
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
    
    enum CodingKeys: String, CodingKey {
        case type
        case text
        case url
        case filename
        case section
    }
}
