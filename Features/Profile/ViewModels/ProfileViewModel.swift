import Foundation
import FirebaseFirestore
import FirebaseAuth

final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    struct UserProfile: Codable {
        let userId: String
        let email: String
        let name: String
        var avatarURL: String?
        var fontPreferences: FontPreferences
        var createdAt: Date
        var updatedAt: Date
        
        struct FontPreferences: Codable {
            var fontSize: Double
            var fontFamily: String
            var isBold: Bool
            var isItalic: Bool
        }
    }
    
    init() {
        loadProfile()
    }
    
    func loadProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let data = snapshot?.data() else { return }
            
            do {
                let profile = try self?.decodeProfile(from: data)
                DispatchQueue.main.async {
                    self?.profile = profile
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateProfile(name: String? = nil, avatarURL: String? = nil, fontPreferences: UserProfile.FontPreferences? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var updateData: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let name = name {
            updateData["name"] = name
        }
        
        if let avatarURL = avatarURL {
            updateData["avatarURL"] = avatarURL
        }
        
        if let fontPreferences = fontPreferences {
            updateData["fontPreferences"] = try JSONEncoder().encode(fontPreferences)
        }
        
        try await db.collection("users").document(userId).updateData(updateData)
    }
    
    private func decodeProfile(from data: [String: Any]) throws -> UserProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        // Convert Firestore Timestamp to Unix timestamp
        var processedData = data
        if let createdAt = data["createdAt"] as? Timestamp {
            processedData["createdAt"] = createdAt.dateValue().timeIntervalSince1970
        }
        if let updatedAt = data["updatedAt"] as? Timestamp {
            processedData["updatedAt"] = updatedAt.dateValue().timeIntervalSince1970
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: processedData)
        return try decoder.decode(UserProfile.self, from: jsonData)
    }
}
