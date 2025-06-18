import Foundation
import FirebaseFirestore
import FirebaseAuth

final class AuthProfileViewModel: ObservableObject {
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
        
        var processedData = data
        
        // Handle createdAt timestamp
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            processedData["createdAt"] = createdAtTimestamp.dateValue().timeIntervalSince1970
        } else if data["createdAt"] == nil || data["createdAt"] is NSNull {
            processedData["createdAt"] = nil
        } else if data["createdAt"] != nil && !(data["createdAt"] is Double) {
            print("Warning: 'createdAt' field was of an unexpected type: \(String(describing: type(of: data["createdAt"]!))). Treating as nil.")
            processedData["createdAt"] = nil
        }
        
        // Handle updatedAt timestamp
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            processedData["updatedAt"] = updatedAtTimestamp.dateValue().timeIntervalSince1970
        } else if data["updatedAt"] == nil || data["updatedAt"] is NSNull {
            processedData["updatedAt"] = nil
        } else if data["updatedAt"] != nil && !(data["updatedAt"] is Double) {
            print("Warning: 'updatedAt' field was of an unexpected type: \(String(describing: type(of: data["updatedAt"]!))). Treating as nil.")
            processedData["updatedAt"] = nil
        }
        
        // Handle lastLoginAt timestamp
        if let lastLoginAtTimestamp = data["lastLoginAt"] as? Timestamp {
            processedData["lastLoginAt"] = lastLoginAtTimestamp.dateValue().timeIntervalSince1970
        } else if data["lastLoginAt"] == nil || data["lastLoginAt"] is NSNull {
            processedData["lastLoginAt"] = nil
        } else if data["lastLoginAt"] != nil && !(data["lastLoginAt"] is Double) {
            print("Warning: 'lastLoginAt' field was of an unexpected type: \(String(describing: type(of: data["lastLoginAt"]!))). Treating as nil.")
            processedData["lastLoginAt"] = nil
        }
        
        // Handle fontPreferences if it's stored as Data
        if let fontPrefsData = data["fontPreferences"] as? Data {
            do {
                let fontPreferencesStruct = try JSONDecoder().decode(UserProfile.FontPreferences.self, from: fontPrefsData)
                let fontPreferencesDict = try JSONEncoder().encode(fontPreferencesStruct)
                let dictRepresentation = try JSONSerialization.jsonObject(with: fontPreferencesDict, options: []) as? [String: Any]
                processedData["fontPreferences"] = dictRepresentation
            } catch {
                print("Error decoding fontPreferences Data into dictionary: \(error). Setting to nil.")
                processedData["fontPreferences"] = nil
            }
        } else if data["fontPreferences"] != nil && !(data["fontPreferences"] is [String: Any]) {
            print("Warning: 'fontPreferences' field was of an unexpected type: \(String(describing: type(of: data["fontPreferences"]!))). Treating as nil.")
            processedData["fontPreferences"] = nil
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: processedData)
        return try decoder.decode(UserProfile.self, from: jsonData)
    }
} 