import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Tracks reading progress, engagement, and provides insights
@MainActor
class ReadingProgressTracker: ObservableObject {
    static let shared = ReadingProgressTracker()
    
    @Published var readingSessions: [ReadingSession] = []
    @Published var totalReadingTime: TimeInterval = 0
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    
    private let db = Firestore.firestore()
    private var currentSession: ReadingSession?
    private var sessionTimer: Timer?
    
    private init() {
        loadProgressData()
    }
    
    // MARK: - Models
    
    struct ReadingSession: Identifiable, Codable {
        let id: String
        let contentId: String
        let contentType: ContentType
        let startTime: Date
        var endTime: Date?
        var duration: TimeInterval
        var pagesRead: Int
        var completionPercentage: Double
        var engagementScore: Double
        
        enum ContentType: String, Codable {
            case story
            case lecture
            case userContent
            case comic
        }
    }
    
    struct ReadingStats: Codable {
        var totalReadingTime: TimeInterval
        var totalSessions: Int
        var averageSessionDuration: TimeInterval
        var currentStreak: Int
        var longestStreak: Int
        var favoriteGenres: [String: Int]
        var readingSpeed: Double // words per minute
    }
    
    // MARK: - Session Management
    
    /// Start a new reading session
    func startSession(contentId: String, contentType: ReadingSession.ContentType) {
        let session = ReadingSession(
            id: UUID().uuidString,
            contentId: contentId,
            contentType: contentType,
            startTime: Date(),
            endTime: nil,
            duration: 0,
            pagesRead: 0,
            completionPercentage: 0,
            engagementScore: 0
        )
        
        currentSession = session
        
        // Start timer for session tracking
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateSessionProgress()
            }
        }
        
        AnalyticsManager.shared.logEvent(name: "reading_session_started", parameters: [
            "content_id": contentId,
            "content_type": contentType.rawValue
        ])
    }
    
    /// End current reading session
    func endSession(completionPercentage: Double = 0, pagesRead: Int = 0) {
        guard var session = currentSession else { return }
        
        session.endTime = Date()
        session.duration = session.endTime!.timeIntervalSince(session.startTime)
        session.completionPercentage = completionPercentage
        session.pagesRead = pagesRead
        session.engagementScore = calculateEngagementScore(session: session)
        
        readingSessions.append(session)
        totalReadingTime += session.duration
        
        // Update streak
        updateStreak()
        
        // Save to Firebase
        Task {
            await saveSession(session)
            await saveProgressStats()
        }
        
        currentSession = nil
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        AnalyticsManager.shared.logEvent(name: "reading_session_ended", parameters: [
            "content_id": session.contentId,
            "duration": session.duration,
            "completion": completionPercentage,
            "engagement_score": session.engagementScore
        ])
    }
    
    /// Update session progress
    func updateSessionProgress() async {
        guard var session = currentSession else { return }
        
        session.duration = Date().timeIntervalSince(session.startTime)
        
        // Calculate engagement score based on duration and activity
        session.engagementScore = calculateEngagementScore(session: session)
        
        currentSession = session
    }
    
    // MARK: - Progress Calculation
    
    private func calculateEngagementScore(session: ReadingSession) -> Double {
        var score: Double = 0.0
        
        // Base score from duration (max 50 points)
        let durationScore = min(session.duration / 60.0 * 10.0, 50.0) // 10 points per minute, max 50
        score += durationScore
        
        // Completion bonus (max 30 points)
        score += session.completionPercentage * 0.3
        
        // Pages read bonus (max 20 points)
        score += min(Double(session.pagesRead) * 2.0, 20.0)
        
        return min(score, 100.0) // Cap at 100
    }
    
    private func updateStreak() {
        guard let lastSession = readingSessions.last else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastSessionDay = calendar.startOfDay(for: lastSession.startTime)
        
        if calendar.isDate(lastSessionDay, inSameDayAs: today) {
            // Same day - check if we need to increment
            if let yesterdaySession = readingSessions.dropLast().last {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
                let yesterdaySessionDay = calendar.startOfDay(for: yesterdaySession.startTime)
                
                if calendar.isDate(yesterdaySessionDay, inSameDayAs: yesterday) {
                    currentStreak += 1
                } else {
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
        } else {
            // Different day - check if consecutive
            let daysDifference = calendar.dateComponents([.day], from: lastSessionDay, to: today).day ?? 0
            
            if daysDifference == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        }
        
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
    }
    
    // MARK: - Statistics
    
    func getReadingStats() -> ReadingStats {
        let totalSessions = readingSessions.count
        let averageDuration = totalSessions > 0 ? totalReadingTime / Double(totalSessions) : 0
        
        // Calculate favorite genres
        var genreCounts: [String: Int] = [:]
        for session in readingSessions {
            let genre = session.contentType.rawValue
            genreCounts[genre, default: 0] += 1
        }
        
        // Calculate reading speed (words per minute)
        // This would need word count data from content
        let readingSpeed = calculateReadingSpeed()
        
        return ReadingStats(
            totalReadingTime: totalReadingTime,
            totalSessions: totalSessions,
            averageSessionDuration: averageDuration,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            favoriteGenres: genreCounts,
            readingSpeed: readingSpeed
        )
    }
    
    private func calculateReadingSpeed() -> Double {
        // Placeholder - would need actual word count data
        // Average reading speed: 200-250 words per minute
        return 225.0
    }
    
    // MARK: - Persistence
    
    private func saveSession(_ session: ReadingSession) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users").document(userId)
                .collection("readingSessions")
                .document(session.id)
                .setData(from: session)
        } catch {
            print("[ReadingProgressTracker] Error saving session: \(error)")
            CrashlyticsManager.shared.logFirestoreError(
                error: error,
                operation: "save_reading_session",
                collection: "readingSessions"
            )
        }
    }
    
    private func saveProgressStats() async {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        
        let stats = getReadingStats()
        
        do {
            try await db.collection("users").document(userId)
                .collection("stats")
                .document("readingProgress")
                .setData(from: stats)
        } catch {
            print("[ReadingProgressTracker] Error saving stats: \(error)")
        }
    }
    
    private func loadProgressData() {
        Task {
            await loadSessions()
            await loadStats()
        }
    }
    
    private func loadSessions() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("readingSessions")
                .order(by: "startTime", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            readingSessions = try snapshot.documents.compactMap { doc in
                try doc.data(as: ReadingSession.self)
            }
        } catch {
            print("[ReadingProgressTracker] Error loading sessions: \(error)")
        }
    }
    
    private func loadStats() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let doc = try await db.collection("users").document(userId)
                .collection("stats")
                .document("readingProgress")
                .getDocument()
            
            if let stats = try? doc.data(as: ReadingStats.self) {
                totalReadingTime = stats.totalReadingTime
                currentStreak = stats.currentStreak
                longestStreak = stats.longestStreak
            }
        } catch {
            print("[ReadingProgressTracker] Error loading stats: \(error)")
        }
    }
}

// MARK: - ReadingSession Codable Extension

extension ReadingProgressTracker.ReadingSession {
    enum CodingKeys: String, CodingKey {
        case id, contentId, contentType, startTime, endTime, duration
        case pagesRead, completionPercentage, engagementScore
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        contentId = try container.decode(String.self, forKey: .contentId)
        contentType = try container.decode(ContentType.self, forKey: .contentType)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        pagesRead = try container.decode(Int.self, forKey: .pagesRead)
        completionPercentage = try container.decode(Double.self, forKey: .completionPercentage)
        engagementScore = try container.decode(Double.self, forKey: .engagementScore)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(contentId, forKey: .contentId)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(pagesRead, forKey: .pagesRead)
        try container.encode(completionPercentage, forKey: .completionPercentage)
        try container.encode(engagementScore, forKey: .engagementScore)
    }
}

