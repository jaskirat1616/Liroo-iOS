import Foundation
import FirebaseAnalytics

/// Analytics manager for tracking user events and app usage
@MainActor
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    /// Log an analytics event
    /// - Parameters:
    ///   - name: Event name (e.g., "content_shared", "content_liked")
    ///   - parameters: Optional dictionary of event parameters
    func logEvent(name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    /// Set a user property
    /// - Parameters:
    ///   - value: Property value
    ///   - property: Property name
    func setUserProperty(value: String?, forName property: String) {
        Analytics.setUserProperty(value, forName: property)
    }
    
    /// Set user ID for analytics
    /// - Parameter userId: User identifier
    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }
}
