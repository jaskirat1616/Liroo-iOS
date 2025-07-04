import Foundation
import FirebaseAuth
import FirebaseFirestore
import LocalAuthentication
import FirebaseCrashlytics

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var sessionExpired = false
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    // Rate limiting for security
    private var lastSignInAttempt: Date?
    private var signInAttempts = 0
    private let maxSignInAttempts = 5
    private let signInCooldown: TimeInterval = 300 // 5 minutes
    
    // Session management
    private var sessionTimer: Timer?
    private let sessionTimeout: TimeInterval = 3600 // 1 hour
    
    init() {
        // Listen for auth state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil
                if user == nil {
                    self?.resetRateLimiting()
                    self?.stopSessionTimer()
                    
                    // Log user sign out
                    CrashlyticsManager.shared.logUserAction(
                        action: "user_signed_out",
                        screen: "authentication"
                    )
                } else {
                    self?.startSessionTimer()
                    
                    // Log user sign in
                    CrashlyticsManager.shared.logUserAction(
                        action: "user_signed_in",
                        screen: "authentication",
                        additionalData: [
                            "user_id": user?.uid ?? "unknown",
                            "email": user?.email ?? "unknown"
                        ]
                    )
                }
            }
        }
    }
    
    deinit {
        // Timer will be automatically invalidated when the object is deallocated
        // No need to call cleanup() as the timer property will be released
    }
    
    // MARK: - Input Validation
    private func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func validatePassword(_ password: String) -> (isValid: Bool, message: String?) {
        if password.count < 8 {
            return (false, "Password must be at least 8 characters long")
        }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        
        if !hasUppercase || !hasLowercase || !hasDigit {
            return (false, "Password must contain uppercase, lowercase, and numeric characters")
        }
        
        return (true, nil)
    }
    
    // MARK: - Rate Limiting
    private func checkRateLimit() -> Bool {
        guard let lastAttempt = lastSignInAttempt else { return true }
        
        if Date().timeIntervalSince(lastAttempt) < signInCooldown {
            if signInAttempts >= maxSignInAttempts {
                CrashlyticsManager.shared.logNonFatalError(
                    message: "Rate limit exceeded for sign-in attempts",
                    context: "authentication_rate_limit",
                    additionalData: [
                        "attempts": signInAttempts,
                        "time_since_last_attempt": Date().timeIntervalSince(lastAttempt)
                    ]
                )
                return false
            }
        } else {
            resetRateLimiting()
        }
        
        return true
    }
    
    private func updateRateLimit() {
        lastSignInAttempt = Date()
        signInAttempts += 1
        
        CrashlyticsManager.shared.logUserAction(
            action: "sign_in_attempt",
            screen: "authentication",
            additionalData: [
                "attempt_number": signInAttempts
            ]
        )
    }
    
    private func resetRateLimiting() {
        lastSignInAttempt = nil
        signInAttempts = 0
    }
    
    // MARK: - Session Management
    private func startSessionTimer() {
        stopSessionTimer()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.sessionExpired = true
                self?.isAuthenticated = false
                
                CrashlyticsManager.shared.logNonFatalError(
                    message: "Session expired due to inactivity",
                    context: "session_management",
                    additionalData: [
                        "session_timeout": self?.sessionTimeout ?? 3600
                    ]
                )
                
                try? self?.auth.signOut()
            }
        }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    func refreshSession() {
        sessionExpired = false
        startSessionTimer()
        
        CrashlyticsManager.shared.logUserAction(
            action: "session_refreshed",
            screen: "authentication"
        )
    }
    
    // MARK: - Biometric Authentication
    func authenticateWithBiometrics() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let authError = AuthError.biometricNotAvailable
            
            CrashlyticsManager.shared.logAuthenticationError(
                error: error ?? NSError(domain: "BiometricError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Biometric authentication not available"]),
                operation: "biometric_check"
            )
            
            throw authError
        }
        
        let reason = "Authenticate to access your account"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            
            if success {
                CrashlyticsManager.shared.logUserAction(
                    action: "biometric_authentication_successful",
                    screen: "authentication"
                )
            } else {
                CrashlyticsManager.shared.logAuthenticationError(
                    error: NSError(domain: "BiometricError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Biometric authentication failed"]),
                    operation: "biometric_authentication"
                )
            }
            
            return success
        } catch {
            CrashlyticsManager.shared.logAuthenticationError(
                error: error,
                operation: "biometric_authentication"
            )
            
            throw AuthError.biometricAuthenticationFailed
        }
    }
    
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, name: String, interestedTopics: [String]? = nil, isStudent: Bool? = nil, additionalInfo: String? = nil) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Validate inputs
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Name cannot be empty"
            let error = AuthError.invalidInput("Name cannot be empty")
            
            CrashlyticsManager.shared.logAuthenticationError(
                error: error,
                operation: "sign_up_validation"
            )
            
            throw error
        }
        
        guard validateEmail(email) else {
            errorMessage = "Please enter a valid email address"
            let error = AuthError.invalidInput("Invalid email format")
            
            CrashlyticsManager.shared.logAuthenticationError(
                error: error,
                operation: "sign_up_validation"
            )
            
            throw error
        }
        
        let passwordValidation = validatePassword(password)
        guard passwordValidation.isValid else {
            errorMessage = passwordValidation.message
            let error = AuthError.invalidInput(passwordValidation.message ?? "Invalid password")
            
            CrashlyticsManager.shared.logAuthenticationError(
                error: error,
                operation: "sign_up_validation"
            )
            
            throw error
        }
        
        do {
            // Create user in Firebase Auth
            let authResult = try await auth.createUser(withEmail: email, password: password)
            
            // Create user profile in Firestore
            var userData: [String: Any] = [
                "userId": authResult.user.uid,
                "email": email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "lastLoginAt": FieldValue.serverTimestamp()
            ]
            
            // Add optional fields if they have values
            if let interestedTopics = interestedTopics, !interestedTopics.isEmpty {
                userData["interestedTopics"] = interestedTopics.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            if let isStudent = isStudent {
                userData["isStudent"] = isStudent
            }
            if let additionalInfo = additionalInfo, !additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                userData["additionalInfo"] = additionalInfo.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            try await db.collection("users").document(authResult.user.uid).setData(userData)
            
            // Log successful sign up
            CrashlyticsManager.shared.logUserAction(
                action: "user_signed_up",
                screen: "authentication",
                additionalData: [
                    "user_id": authResult.user.uid,
                    "email": email,
                    "has_interested_topics": interestedTopics?.isEmpty == false,
                    "is_student": isStudent ?? false
                ]
            )
            
        } catch {
            errorMessage = error.localizedDescription
            
            CrashlyticsManager.shared.logAuthenticationError(
                error: error,
                operation: "sign_up",
                email: email
            )
            
            throw error
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Check rate limiting
        guard checkRateLimit() else {
            errorMessage = "Too many sign-in attempts. Please try again in 5 minutes."
            throw AuthError.rateLimitExceeded
        }
        
        // Validate email format
        guard validateEmail(email) else {
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidInput("Invalid email format")
        }
        
        do {
            try await auth.signIn(withEmail: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            
            // Update last login time
            if let userId = user?.uid {
                try await db.collection("users").document(userId).updateData([
                    "lastLoginAt": FieldValue.serverTimestamp()
                ])
            }
            
            // Reset rate limiting on successful sign in
            resetRateLimiting()
            
        } catch {
            updateRateLimit()
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        do {
            try auth.signOut()
            resetRateLimiting()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard validateEmail(email) else {
            errorMessage = "Please enter a valid email address"
            throw AuthError.invalidInput("Invalid email format")
        }
        
        do {
            try await auth.sendPasswordReset(withEmail: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Update Profile
    func updateProfile(name: String) async throws {
        guard let userId = user?.uid else { 
            throw AuthError.userNotFound
        }
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Name cannot be empty"
            throw AuthError.invalidInput("Name cannot be empty")
        }
        
        do {
            let userData: [String: Any] = [
                "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            try await db.collection("users").document(userId).updateData(userData)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let userId = user?.uid else {
            throw AuthError.userNotFound
        }
        
        do {
            // Delete user data from Firestore
            try await db.collection("users").document(userId).delete()
            
            // Delete user from Firebase Auth
            try await user?.delete()
            
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
}

// MARK: - Custom Auth Errors
enum AuthError: LocalizedError {
    case invalidInput(String)
    case rateLimitExceeded
    case userNotFound
    case networkError
    case biometricNotAvailable
    case biometricAuthenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .rateLimitExceeded:
            return "Too many attempts. Please try again later."
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error. Please check your connection."
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed"
        }
    }
}
