import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, name: String, interestedTopics: [String]? = nil, isStudent: Bool? = nil, additionalInfo: String? = nil) async throws {
        do {
            // Create user in Firebase Auth
            let authResult = try await auth.createUser(withEmail: email, password: password)
            
            // Create user profile in Firestore
            var userData: [String: Any] = [
                "userId": authResult.user.uid,
                "email": email,
                "name": name,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            // Add new optional fields if they have values
            if let interestedTopics = interestedTopics, !interestedTopics.isEmpty {
                userData["interestedTopics"] = interestedTopics
            }
            if let isStudent = isStudent {
                userData["isStudent"] = isStudent
            }
            if let additionalInfo = additionalInfo, !additionalInfo.isEmpty {
                userData["additionalInfo"] = additionalInfo
            }
            // avatarURL can be set later via profile edit. Font preferences can also be default or set later.

            try await db.collection("users").document(authResult.user.uid).setData(userData)
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        do {
            try await auth.signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        do {
            try auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(name: String) async throws {
        guard let userId = user?.uid else { return }
        
        do {
            let userData: [String: Any] = [
                "name": name,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(userId).updateData(userData)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}
