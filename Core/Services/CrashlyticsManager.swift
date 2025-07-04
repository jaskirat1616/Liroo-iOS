import Foundation
import FirebaseCrashlytics
import FirebaseAuth
import UIKit

/// Centralized Crashlytics manager for comprehensive error tracking
class CrashlyticsManager {
    static let shared = CrashlyticsManager()
    
    private init() {}
    
    // MARK: - User Identification
    func setUser(userId: String, email: String? = nil, name: String? = nil) {
        Crashlytics.crashlytics().setUserID(userId)
        
        if let email = email {
            Crashlytics.crashlytics().setCustomValue(email, forKey: "user_email")
        }
        
        if let name = name {
            Crashlytics.crashlytics().setCustomValue(name, forKey: "user_name")
        }
    }
    
    func clearUser() {
        Crashlytics.crashlytics().setUserID("")
        Crashlytics.crashlytics().setCustomValue("", forKey: "user_email")
        Crashlytics.crashlytics().setCustomValue("", forKey: "user_name")
    }
    
    // MARK: - Content Generation Error Tracking
    func logContentGenerationError(
        error: Error,
        contentType: String,
        inputLength: Int,
        level: String,
        tier: String? = nil,
        genre: String? = nil,
        imageStyle: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(contentType, forKey: "content_type")
        Crashlytics.crashlytics().setCustomValue(inputLength, forKey: "input_length")
        Crashlytics.crashlytics().setCustomValue(level, forKey: "content_level")
        
        if let tier = tier {
            Crashlytics.crashlytics().setCustomValue(tier, forKey: "summarization_tier")
        }
        
        if let genre = genre {
            Crashlytics.crashlytics().setCustomValue(genre, forKey: "story_genre")
        }
        
        if let imageStyle = imageStyle {
            Crashlytics.crashlytics().setCustomValue(imageStyle, forKey: "image_style")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Content generation error logged: \(error.localizedDescription)")
    }
    
    // MARK: - Network Error Tracking
    func logNetworkError(
        error: Error,
        endpoint: String,
        method: String,
        statusCode: Int? = nil,
        requestBody: [String: Any]? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(endpoint, forKey: "network_endpoint")
        Crashlytics.crashlytics().setCustomValue(method, forKey: "network_method")
        
        if let statusCode = statusCode {
            Crashlytics.crashlytics().setCustomValue(statusCode, forKey: "network_status_code")
        }
        
        if let requestBody = requestBody {
            // Log request body size and keys for debugging
            let bodyKeys = Array(requestBody.keys)
            Crashlytics.crashlytics().setCustomValue(bodyKeys, forKey: "request_body_keys")
            
            if let bodyData = try? JSONSerialization.data(withJSONObject: requestBody),
               let bodyString = String(data: bodyData, encoding: .utf8) {
                Crashlytics.crashlytics().setCustomValue(bodyString.count, forKey: "request_body_size")
            }
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Network error logged: \(error.localizedDescription) for \(method) \(endpoint)")
    }
    
    // MARK: - Background Network Error Tracking
    func logBackgroundNetworkError(
        error: Error,
        taskType: String,
        fileSize: Int? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(taskType, forKey: "background_task_type")
        
        if let fileSize = fileSize {
            Crashlytics.crashlytics().setCustomValue(fileSize, forKey: "background_file_size")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Background network error logged: \(error.localizedDescription) for \(taskType)")
    }
    
    // MARK: - Firebase Storage Error Tracking
    func logFirebaseStorageError(
        error: Error,
        operation: String,
        path: String,
        fileSize: Int? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "firebase_operation")
        Crashlytics.crashlytics().setCustomValue(path, forKey: "firebase_path")
        
        if let fileSize = fileSize {
            Crashlytics.crashlytics().setCustomValue(fileSize, forKey: "firebase_file_size")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Firebase storage error logged: \(error.localizedDescription) for \(operation) at \(path)")
    }
    
    // MARK: - Image Generation Error Tracking
    func logImageGenerationError(
        error: Error,
        prompt: String,
        style: String,
        size: String
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(prompt.prefix(100), forKey: "image_prompt")
        Crashlytics.crashlytics().setCustomValue(style, forKey: "image_style")
        Crashlytics.crashlytics().setCustomValue(size, forKey: "image_size")
        Crashlytics.crashlytics().setCustomValue(prompt.count, forKey: "prompt_length")
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Image generation error logged: \(error.localizedDescription)")
    }
    
    // MARK: - Authentication Error Tracking
    func logAuthenticationError(
        error: Error,
        operation: String,
        email: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "auth_operation")
        
        if let email = email {
            Crashlytics.crashlytics().setCustomValue(email, forKey: "auth_email")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Authentication error logged: \(error.localizedDescription) for \(operation)")
    }
    
    // MARK: - Firestore Error Tracking
    func logFirestoreError(
        error: Error,
        operation: String,
        collection: String,
        documentId: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "firestore_operation")
        Crashlytics.crashlytics().setCustomValue(collection, forKey: "firestore_collection")
        
        if let documentId = documentId {
            Crashlytics.crashlytics().setCustomValue(documentId, forKey: "firestore_document_id")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Firestore error logged: \(error.localizedDescription) for \(operation) in \(collection)")
    }
    
    // MARK: - App State Tracking
    func logAppStateChange(state: String, additionalInfo: [String: Any]? = nil) {
        Crashlytics.crashlytics().setCustomValue(state, forKey: "app_state")
        
        if let additionalInfo = additionalInfo {
            for (key, value) in additionalInfo {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
        
        print("[Crashlytics] App state change logged: \(state)")
    }
    
    // MARK: - Performance Tracking
    func logPerformanceIssue(
        operation: String,
        duration: TimeInterval,
        threshold: TimeInterval
    ) {
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "performance_operation")
        Crashlytics.crashlytics().setCustomValue(duration, forKey: "performance_duration")
        Crashlytics.crashlytics().setCustomValue(threshold, forKey: "performance_threshold")
        
        let message = "Performance issue detected: \(operation) took \(duration)s (threshold: \(threshold)s)"
        Crashlytics.crashlytics().log(message)
        
        print("[Crashlytics] Performance issue logged: \(message)")
    }
    
    // MARK: - Memory Warning Tracking
    func logMemoryWarning() {
        Crashlytics.crashlytics().setCustomValue(true, forKey: "memory_warning_received")
        Crashlytics.crashlytics().log("Memory warning received")
        
        print("[Crashlytics] Memory warning logged")
    }
    
    // MARK: - Custom Error Logging
    func logCustomError(
        error: Error,
        context: String,
        additionalData: [String: Any]? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(context, forKey: "error_context")
        
        if let additionalData = additionalData {
            for (key, value) in additionalData {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Custom error logged: \(error.localizedDescription) in context: \(context)")
    }
    
    // MARK: - Non-Fatal Error Logging
    func logNonFatalError(
        message: String,
        context: String,
        additionalData: [String: Any]? = nil
    ) {
        Crashlytics.crashlytics().setCustomValue(context, forKey: "non_fatal_context")
        
        if let additionalData = additionalData {
            for (key, value) in additionalData {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
        
        Crashlytics.crashlytics().log("Non-fatal error: \(message) in context: \(context)")
        
        print("[Crashlytics] Non-fatal error logged: \(message) in context: \(context)")
    }
    
    // MARK: - User Action Tracking
    func logUserAction(action: String, screen: String, additionalData: [String: Any]? = nil) {
        Crashlytics.crashlytics().setCustomValue(action, forKey: "user_action")
        Crashlytics.crashlytics().setCustomValue(screen, forKey: "user_screen")
        
        if let additionalData = additionalData {
            for (key, value) in additionalData {
                Crashlytics.crashlytics().setCustomValue(value, forKey: key)
            }
        }
        
        Crashlytics.crashlytics().log("User action: \(action) on screen: \(screen)")
        
        print("[Crashlytics] User action logged: \(action) on \(screen)")
    }
    
    // MARK: - Device Info Tracking
    func logDeviceInfo() {
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let model = device.model
        let name = device.name
        
        Crashlytics.crashlytics().setCustomValue(systemVersion, forKey: "ios_version")
        Crashlytics.crashlytics().setCustomValue(model, forKey: "device_model")
        Crashlytics.crashlytics().setCustomValue(name, forKey: "device_name")
        
        // App version
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Crashlytics.crashlytics().setCustomValue(appVersion, forKey: "app_version")
        }
        
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            Crashlytics.crashlytics().setCustomValue(buildNumber, forKey: "app_build")
        }
        
        print("[Crashlytics] Device info logged: \(model) running iOS \(systemVersion)")
    }
    
    // MARK: - Basic iOS Error Tracking
    
    // File Operations
    func logFileOperationError(
        error: Error,
        operation: String,
        filePath: String? = nil,
        fileName: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "file_operation")
        
        if let filePath = filePath {
            Crashlytics.crashlytics().setCustomValue(filePath, forKey: "file_path")
        }
        
        if let fileName = fileName {
            Crashlytics.crashlytics().setCustomValue(fileName, forKey: "file_name")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] File operation error logged: \(error.localizedDescription) for \(operation)")
    }
    
    // JSON Parsing
    func logJSONParsingError(
        error: Error,
        context: String,
        dataSize: Int? = nil,
        dataPreview: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(context, forKey: "json_context")
        
        if let dataSize = dataSize {
            Crashlytics.crashlytics().setCustomValue(dataSize, forKey: "json_data_size")
        }
        
        if let dataPreview = dataPreview {
            Crashlytics.crashlytics().setCustomValue(dataPreview.prefix(200), forKey: "json_data_preview")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] JSON parsing error logged: \(error.localizedDescription) in context: \(context)")
    }
    
    // Data Validation
    func logDataValidationError(
        field: String,
        value: String? = nil,
        expectedType: String? = nil,
        context: String
    ) {
        Crashlytics.crashlytics().setCustomValue(field, forKey: "validation_field")
        Crashlytics.crashlytics().setCustomValue(context, forKey: "validation_context")
        
        if let value = value {
            Crashlytics.crashlytics().setCustomValue(value.prefix(100), forKey: "validation_value")
        }
        
        if let expectedType = expectedType {
            Crashlytics.crashlytics().setCustomValue(expectedType, forKey: "validation_expected_type")
        }
        
        let error = NSError(domain: "DataValidationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data validation failed for field: \(field)"])
        Crashlytics.crashlytics().record(error: error)
        
        print("[Crashlytics] Data validation error logged: field '\(field)' in context: \(context)")
    }
    
    // Memory Issues
    func logMemoryIssue(
        operation: String,
        memoryUsage: Int? = nil,
        availableMemory: Int? = nil
    ) {
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "memory_operation")
        
        if let memoryUsage = memoryUsage {
            Crashlytics.crashlytics().setCustomValue(memoryUsage, forKey: "memory_usage_mb")
        }
        
        if let availableMemory = availableMemory {
            Crashlytics.crashlytics().setCustomValue(availableMemory, forKey: "available_memory_mb")
        }
        
        let error = NSError(domain: "MemoryIssue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Memory issue detected during: \(operation)"])
        Crashlytics.crashlytics().record(error: error)
        
        print("[Crashlytics] Memory issue logged: \(operation)")
    }
    
    // System Errors
    func logSystemError(
        error: Error,
        operation: String,
        systemInfo: [String: Any]? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "system_operation")
        
        if let systemInfo = systemInfo {
            for (key, value) in systemInfo {
                Crashlytics.crashlytics().setCustomValue(value, forKey: "system_\(key)")
            }
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] System error logged: \(error.localizedDescription) for \(operation)")
    }
    
    // Permission Issues
    func logPermissionError(
        permission: String,
        status: String,
        context: String
    ) {
        Crashlytics.crashlytics().setCustomValue(permission, forKey: "permission_type")
        Crashlytics.crashlytics().setCustomValue(status, forKey: "permission_status")
        Crashlytics.crashlytics().setCustomValue(context, forKey: "permission_context")
        
        let error = NSError(domain: "PermissionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permission denied: \(permission) in \(context)"])
        Crashlytics.crashlytics().record(error: error)
        
        print("[Crashlytics] Permission error logged: \(permission) - \(status) in \(context)")
    }
    
    // Database Operations
    func logDatabaseError(
        error: Error,
        operation: String,
        table: String? = nil,
        query: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "database_operation")
        
        if let table = table {
            Crashlytics.crashlytics().setCustomValue(table, forKey: "database_table")
        }
        
        if let query = query {
            Crashlytics.crashlytics().setCustomValue(query.prefix(200), forKey: "database_query")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Database error logged: \(error.localizedDescription) for \(operation)")
    }
    
    // UI/View Errors
    func logUIError(
        error: Error,
        viewName: String,
        action: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(viewName, forKey: "ui_view_name")
        
        if let action = action {
            Crashlytics.crashlytics().setCustomValue(action, forKey: "ui_action")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] UI error logged: \(error.localizedDescription) in view: \(viewName)")
    }
    
    // Configuration Errors
    func logConfigurationError(
        setting: String,
        value: String? = nil,
        context: String
    ) {
        Crashlytics.crashlytics().setCustomValue(setting, forKey: "config_setting")
        Crashlytics.crashlytics().setCustomValue(context, forKey: "config_context")
        
        if let value = value {
            Crashlytics.crashlytics().setCustomValue(value, forKey: "config_value")
        }
        
        let error = NSError(domain: "ConfigurationError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Configuration error: \(setting) in \(context)"])
        Crashlytics.crashlytics().record(error: error)
        
        print("[Crashlytics] Configuration error logged: \(setting) in \(context)")
    }
    
    // App State Issues
    func logAppStateIssue(
        issue: String,
        state: String,
        additionalInfo: [String: Any]? = nil
    ) {
        Crashlytics.crashlytics().setCustomValue(issue, forKey: "app_state_issue")
        Crashlytics.crashlytics().setCustomValue(state, forKey: "app_state")
        
        if let additionalInfo = additionalInfo {
            for (key, value) in additionalInfo {
                Crashlytics.crashlytics().setCustomValue(value, forKey: "app_state_\(key)")
            }
        }
        
        let error = NSError(domain: "AppStateError", code: -1, userInfo: [NSLocalizedDescriptionKey: "App state issue: \(issue) in state: \(state)"])
        Crashlytics.crashlytics().record(error: error)
        
        print("[Crashlytics] App state issue logged: \(issue) in state: \(state)")
    }
    
    // Thread/Concurrency Issues
    func logThreadError(
        error: Error,
        thread: String,
        operation: String
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(thread, forKey: "thread_name")
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "thread_operation")
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Thread error logged: \(error.localizedDescription) on \(thread) for \(operation)")
    }
    
    // Resource Loading Issues
    func logResourceError(
        error: Error,
        resourceType: String,
        resourceName: String? = nil,
        url: String? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(resourceType, forKey: "resource_type")
        
        if let resourceName = resourceName {
            Crashlytics.crashlytics().setCustomValue(resourceName, forKey: "resource_name")
        }
        
        if let url = url {
            Crashlytics.crashlytics().setCustomValue(url, forKey: "resource_url")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Resource error logged: \(error.localizedDescription) for \(resourceType)")
    }
    
    // Cache Issues
    func logCacheError(
        error: Error,
        operation: String,
        cacheKey: String? = nil,
        cacheSize: Int? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(operation, forKey: "cache_operation")
        
        if let cacheKey = cacheKey {
            Crashlytics.crashlytics().setCustomValue(cacheKey, forKey: "cache_key")
        }
        
        if let cacheSize = cacheSize {
            Crashlytics.crashlytics().setCustomValue(cacheSize, forKey: "cache_size")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Cache error logged: \(error.localizedDescription) for \(operation)")
    }
    
    // Notification Issues
    func logNotificationError(
        error: Error,
        notificationType: String,
        userInfo: [String: Any]? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(notificationType, forKey: "notification_type")
        
        if let userInfo = userInfo {
            for (key, value) in userInfo {
                Crashlytics.crashlytics().setCustomValue(value, forKey: "notification_\(key)")
            }
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Notification error logged: \(error.localizedDescription) for \(notificationType)")
    }
    
    // Background Task Issues
    func logBackgroundTaskError(
        error: Error,
        taskType: String,
        taskId: String? = nil,
        duration: TimeInterval? = nil
    ) {
        let nsError = error as NSError
        
        Crashlytics.crashlytics().setCustomValue(taskType, forKey: "background_task_type")
        
        if let taskId = taskId {
            Crashlytics.crashlytics().setCustomValue(taskId, forKey: "background_task_id")
        }
        
        if let duration = duration {
            Crashlytics.crashlytics().setCustomValue(duration, forKey: "background_task_duration")
        }
        
        Crashlytics.crashlytics().record(error: nsError)
        
        print("[Crashlytics] Background task error logged: \(error.localizedDescription) for \(taskType)")
    }
}

// MARK: - Error Handling Extensions

extension CrashlyticsManager {
    
    // MARK: - Convenience Methods for Common Errors
    
    /// Logs a generic error with automatic context detection
    func logError(_ error: Error, context: String? = nil, additionalData: [String: Any]? = nil) {
        let nsError = error as NSError
        
        // Auto-detect error type based on domain
        switch nsError.domain {
        case NSURLErrorDomain:
            logNetworkError(
                error: error,
                endpoint: additionalData?["endpoint"] as? String ?? "unknown",
                method: additionalData?["method"] as? String ?? "unknown",
                statusCode: additionalData?["statusCode"] as? Int
            )
        case "NSCocoaErrorDomain":
            logFileOperationError(
                error: error,
                operation: additionalData?["operation"] as? String ?? "file_operation",
                filePath: additionalData?["filePath"] as? String,
                fileName: additionalData?["fileName"] as? String
            )
        case "NSPOSIXErrorDomain":
            logSystemError(
                error: error,
                operation: additionalData?["operation"] as? String ?? "system_operation",
                systemInfo: additionalData
            )
        default:
            logCustomError(
                error: error,
                context: context ?? "unknown_context",
                additionalData: additionalData
            )
        }
    }
    
    /// Wraps a throwing operation with automatic error logging
    func executeWithErrorLogging<T>(
        operation: String,
        context: String? = nil,
        additionalData: [String: Any]? = nil,
        _ block: () throws -> T
    ) -> T? {
        do {
            return try block()
        } catch {
            logError(error, context: context, additionalData: additionalData)
            return nil
        }
    }
    
    /// Wraps an async throwing operation with automatic error logging
    func executeAsyncWithErrorLogging<T>(
        operation: String,
        context: String? = nil,
        additionalData: [String: Any]? = nil,
        _ block: () async throws -> T
    ) async -> T? {
        do {
            return try await block()
        } catch {
            logError(error, context: context, additionalData: additionalData)
            return nil
        }
    }
    
    // MARK: - Common Error Scenarios
    
    /// Logs a file not found error
    func logFileNotFound(filePath: String, operation: String) {
        let error = NSError(domain: "FileNotFoundError", code: -1, userInfo: [NSLocalizedDescriptionKey: "File not found: \(filePath)"])
        logFileOperationError(
            error: error,
            operation: operation,
            filePath: filePath
        )
    }
    
    /// Logs a permission denied error
    func logPermissionDenied(permission: String, context: String) {
        logPermissionError(
            permission: permission,
            status: "denied",
            context: context
        )
    }
    
    /// Logs a timeout error
    func logTimeoutError(operation: String, timeout: TimeInterval) {
        let error = NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out: \(operation)"])
        logCustomError(
            error: error,
            context: "timeout",
            additionalData: [
                "operation": operation,
                "timeout_seconds": timeout
            ]
        )
    }
    
    /// Logs a data corruption error
    func logDataCorruptionError(dataType: String, context: String, dataSize: Int? = nil) {
        let error = NSError(domain: "DataCorruptionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data corruption detected: \(dataType)"])
        logCustomError(
            error: error,
            context: context,
            additionalData: [
                "data_type": dataType,
                "data_size": dataSize ?? 0
            ]
        )
    }
    
    /// Logs a configuration missing error
    func logConfigurationMissing(setting: String, context: String) {
        logConfigurationError(
            setting: setting,
            value: nil,
            context: context
        )
    }
    
    /// Logs a resource loading failure
    func logResourceLoadingFailed(resourceType: String, resourceName: String, url: String? = nil) {
        let error = NSError(domain: "ResourceLoadingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load \(resourceType): \(resourceName)"])
        logResourceError(
            error: error,
            resourceType: resourceType,
            resourceName: resourceName,
            url: url
        )
    }
    
    /// Logs a cache miss
    func logCacheMiss(cacheKey: String, cacheType: String) {
        let error = NSError(domain: "CacheMissError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cache miss for key: \(cacheKey)"])
        logCacheError(
            error: error,
            operation: "cache_miss",
            cacheKey: cacheKey
        )
    }
    
    /// Logs a thread safety violation
    func logThreadSafetyViolation(operation: String, currentThread: String, expectedThread: String) {
        let error = NSError(domain: "ThreadSafetyError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Thread safety violation: \(operation)"])
        logThreadError(
            error: error,
            thread: currentThread,
            operation: operation
        )
    }
    
    /// Logs a UI constraint violation
    func logUIConstraintViolation(viewName: String, constraint: String) {
        let error = NSError(domain: "UIConstraintError", code: -1, userInfo: [NSLocalizedDescriptionKey: "UI constraint violation: \(constraint)"])
        logUIError(
            error: error,
            viewName: viewName,
            action: "constraint_violation"
        )
    }
    
    /// Logs a notification permission issue
    func logNotificationPermissionIssue(status: String) {
        logPermissionError(
            permission: "notifications",
            status: status,
            context: "push_notifications"
        )
    }
    
    /// Logs a background task expiration
    func logBackgroundTaskExpired(taskType: String, taskId: String) {
        let error = NSError(domain: "BackgroundTaskError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Background task expired: \(taskType)"])
        logBackgroundTaskError(
            error: error,
            taskType: taskType,
            taskId: taskId
        )
    }
    
    // MARK: - Performance Monitoring
    
    /// Logs a slow operation
    func logSlowOperation(operation: String, duration: TimeInterval, threshold: TimeInterval = 1.0) {
        if duration > threshold {
            logPerformanceIssue(
                operation: operation,
                duration: duration,
                threshold: threshold
            )
        }
    }
    
    /// Logs a memory pressure event
    func logMemoryPressure(level: String, availableMemory: Int) {
        logMemoryIssue(
            operation: "memory_pressure",
            memoryUsage: nil,
            availableMemory: availableMemory
        )
    }
    
    // MARK: - Validation Helpers
    
    /// Validates and logs data validation errors
    func validateAndLog<T>(
        value: T?,
        field: String,
        context: String,
        validator: (T) -> Bool
    ) -> Bool {
        guard let value = value else {
            logDataValidationError(
                field: field,
                value: nil,
                expectedType: String(describing: T.self),
                context: context
            )
            return false
        }
        
        guard validator(value) else {
            logDataValidationError(
                field: field,
                value: String(describing: value),
                expectedType: "valid_\(String(describing: T.self))",
                context: context
            )
            return false
        }
        
        return true
    }
    
    /// Validates required fields and logs missing ones
    func validateRequiredFields(_ fields: [String: Any?], context: String) -> Bool {
        var isValid = true
        
        for (fieldName, fieldValue) in fields {
            if fieldValue == nil {
                logDataValidationError(
                    field: fieldName,
                    value: nil,
                    expectedType: "required",
                    context: context
                )
                isValid = false
            }
        }
        
        return isValid
    }
} 