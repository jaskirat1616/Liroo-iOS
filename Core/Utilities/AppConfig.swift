import Foundation

/// Application configuration for API endpoints and services
/// 
/// To configure for your own deployment:
/// 1. Set BACKEND_URL environment variable, or
/// 2. Update the default value below
struct AppConfig {
    /// Backend API base URL
    /// 
    /// Can be overridden via environment variable: BACKEND_URL
    static var backendURL: String {
        if let envURL = ProcessInfo.processInfo.environment["BACKEND_URL"],
           !envURL.isEmpty {
            return envURL
        }
        // Default to localhost for development
        // Replace with your backend URL for production
        return "http://localhost:5000"
    }
    
    /// Whether to use production or development backend
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}

