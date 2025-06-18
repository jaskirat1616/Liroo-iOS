import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    struct UserProfile: Codable {
        let userId: String
        let email: String
        let name: String
        var avatarURL: String?
        var fontPreferences: FontPreferences?
        var createdAt: Date?
        var updatedAt: Date?
        var interestedTopics: [String]?
        var isStudent: Bool?
        var additionalInfo: String?
        var lastLoginAt: Date?
        
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
        guard let userId = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                self.errorMessage = "User not authenticated."
                print("ProfileViewModel: User not authenticated.")
            }
            return
        }
        
        db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching profile: \(error.localizedDescription)"
                    print("ProfileViewModel: Firestore error - \(error)")
                }
                return
            }
            
            guard let data = snapshot?.data(), !data.isEmpty else {
                DispatchQueue.main.async {
                    self.errorMessage = "User profile document not found or is empty."
                    print("ProfileViewModel: User profile document not found or is empty for user ID: \(userId)")
                    // Consider creating a default profile here if appropriate for your app's logic
                }
                return
            }
            
            do {
                let profile = try self.decodeProfile(from: data)
                DispatchQueue.main.async {
                    self.profile = profile
                    self.errorMessage = nil // Clear any previous error on successful load
                }
            } catch {
                DispatchQueue.main.async {
                    // More descriptive error message for the UI
                    var detailedErrorMessage = "Failed to decode profile data. "
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            detailedErrorMessage += "Missing field: '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))."
                        case .valueNotFound(let type, let context):
                            detailedErrorMessage += "Expected value for type '\(type)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))."
                        case .typeMismatch(let type, let context):
                            detailedErrorMessage += "Type mismatch for field '\(context.codingPath.last?.stringValue ?? "Unknown field")'. Expected '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))."
                        case .dataCorrupted(let context):
                            detailedErrorMessage += "Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))."
                        @unknown default:
                            detailedErrorMessage += error.localizedDescription
                        }
                    } else {
                        detailedErrorMessage += error.localizedDescription
                    }
                    self.errorMessage = detailedErrorMessage
                    print("ProfileViewModel: Decoding error - \(error)") // Full error for console
                    if let decodingError = error as? DecodingError { // Detailed breakdown for console
                        switch decodingError {
                        case .typeMismatch(let type, let context):
                            print("  Type mismatch: Expected \(type) at path '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))'. Debug: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("  Value not found: No value for expected type \(type) at path '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))'. Debug: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("  Key not found: '\(key.stringValue)' at path '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))'. Debug: \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            print("  Data corrupted: At path '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))'. Debug: \(context.debugDescription)")
                        @unknown default:
                            print("  Unknown decoding error: \(error)")
                        }
                    }
                }
            }
        }
    }
    
    func updateProfile(name: String? = nil, avatarURL: String? = nil, fontPreferences: UserProfile.FontPreferences? = nil, interestedTopics: [String]? = nil, isStudent: Bool? = nil, additionalInfo: String? = nil) async throws {
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
        
        if let interestedTopics = interestedTopics {
            updateData["interestedTopics"] = interestedTopics
        }
        
        if let isStudent = isStudent {
            updateData["isStudent"] = isStudent
        }
        
        if let additionalInfo = additionalInfo {
            updateData["additionalInfo"] = additionalInfo
        }
        
        try await db.collection("users").document(userId).updateData(updateData)
    }
    
    // Updated function to handle image upload to Firebase Storage and profile update
    func updateProfileImage(imageData: Data) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                self.errorMessage = "User not authenticated."
                print("ProfileViewModel: User not authenticated for image upload.")
            }
            return
        }

        // Create a unique path for the image in Firebase Storage
        let storageRef = Storage.storage().reference().child("profile_images/\(userId).jpg")
        
        // Prepare metadata for the image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg" // Assuming JPEG, adjust if you allow other types

        do {
            DispatchQueue.main.async {
                // Optionally, set a loading state here if you have one
                self.errorMessage = nil // Clear previous errors
                // self.isLoading = true // Example
            }
            print("ProfileViewModel: Starting image upload to Firebase Storage...")
            
            // Upload the image data
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            print("ProfileViewModel: Image uploaded successfully to path: \(storageRef.fullPath)")
            
            // Get the download URL for the uploaded image
            let downloadURL = try await storageRef.downloadURL()
            print("ProfileViewModel: Got download URL: \(downloadURL.absoluteString)")

            // Update the avatarURL in Firestore with the new download URL
            try await self.updateProfile(avatarURL: downloadURL.absoluteString)
            print("ProfileViewModel: Profile avatarURL updated in Firestore.")
            
            DispatchQueue.main.async {
                // self.isLoading = false // Example
                // Potentially clear any temporary image data state if managed in VM
            }

        } catch {
            DispatchQueue.main.async {
                // self.isLoading = false // Example
                self.errorMessage = "Failed to update profile image: \(error.localizedDescription)"
                print("ProfileViewModel: Error updating profile image: \(error)")
                // More detailed error logging if needed
                if let storageError = error as? StorageError {
                    print("ProfileViewModel: Firebase Storage specific error code: \(storageError.errorCode)")
                }
            }
        }
    }
    
    private func decodeProfile(from data: [String: Any]) throws -> UserProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        var processedData = data

        // Convert Firestore Timestamp to Unix timestamp (Double) or handle nil for dates
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            processedData["createdAt"] = createdAtTimestamp.dateValue().timeIntervalSince1970
        } else if data["createdAt"] == nil || data["createdAt"] is NSNull {
            processedData["createdAt"] = nil
        } else if data["createdAt"] != nil && !(data["createdAt"] is Double) {
            print("Warning: 'createdAt' field was of an unexpected type: \(String(describing: type(of: data["createdAt"]!))). Treating as nil.")
            processedData["createdAt"] = nil
        }

        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            processedData["updatedAt"] = updatedAtTimestamp.dateValue().timeIntervalSince1970
        } else if data["updatedAt"] == nil || data["updatedAt"] is NSNull {
            processedData["updatedAt"] = nil
        } else if data["updatedAt"] != nil && !(data["updatedAt"] is Double) {
            print("Warning: 'updatedAt' field was of an unexpected type: \(String(describing: type(of: data["updatedAt"]!))). Treating as nil.")
            processedData["updatedAt"] = nil
        }

        // START NEW CODE TO HANDLE lastLoginAt
        if let lastLoginAtTimestamp = data["lastLoginAt"] as? Timestamp {
            processedData["lastLoginAt"] = lastLoginAtTimestamp.dateValue().timeIntervalSince1970
        } else if data["lastLoginAt"] == nil || data["lastLoginAt"] is NSNull {
            // If UserProfile expects an optional Date for lastLoginAt, setting to nil is correct.
            processedData["lastLoginAt"] = nil
        } else if data["lastLoginAt"] != nil && !(data["lastLoginAt"] is Double) {
            // If lastLoginAt exists but is not a Timestamp or already a Double, it's unexpected.
            print("Warning: 'lastLoginAt' field was of an unexpected type: \(String(describing: type(of: data["lastLoginAt"]!))). Treating as nil.")
            processedData["lastLoginAt"] = nil // Or you could remove it: processedData.removeValue(forKey: "lastLoginAt")
                                             // depending on whether UserProfile model has this field.
        }
        // END NEW CODE TO HANDLE lastLoginAt

        // Handle FontPreferences: Firestore might return it as Data
        if let fontPrefsData = data["fontPreferences"] as? Data {
            do {
                // Decode the Data into FontPreferences struct first
                let fontPreferencesStruct = try JSONDecoder().decode(UserProfile.FontPreferences.self, from: fontPrefsData)
                // Then, to make it compatible with JSONSerialization, convert this struct to a dictionary
                let fontPreferencesDict = try JSONEncoder().encode(fontPreferencesStruct)
                let dictRepresentation = try JSONSerialization.jsonObject(with: fontPreferencesDict, options: []) as? [String: Any]
                processedData["fontPreferences"] = dictRepresentation
            } catch {
                print("Error decoding fontPreferences Data into dictionary: \(error). Setting to nil.")
                processedData["fontPreferences"] = nil
            }
        } else if data["fontPreferences"] != nil && !(data["fontPreferences"] is [String: Any]) {
            // If it's not Data and not already a dictionary, it's an unexpected type.
            print("Warning: 'fontPreferences' field was of an unexpected type: \(String(describing: type(of: data["fontPreferences"]!))). Treating as nil.")
            processedData["fontPreferences"] = nil
        }

        let jsonData = try JSONSerialization.data(withJSONObject: processedData, options: [])
        return try decoder.decode(UserProfile.self, from: jsonData)
    }
}
