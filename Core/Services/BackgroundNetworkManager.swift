import Foundation
import UserNotifications
import FirebaseCrashlytics

// Define a result type for background completion
enum BackgroundNetworkResult {
    case success(Data)
    case failure(Error)
}

// The manager that handles all background network tasks
class BackgroundNetworkManager: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    
    static let shared = BackgroundNetworkManager()
    
    private var backgroundSession: URLSession!
    private var backgroundTaskData: [Int: Data] = [:]
    private var completionHandlers: [Int: (BackgroundNetworkResult) -> Void] = [:]
    private var taskInfo: [Int: [String: Any]] = [:] // Store task metadata for crash reporting
    
    // Add this property to hold the system's completion handler
    var sessionCompletionHandler: (() -> Void)?

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.liroo.background.manager")
        config.sessionSendsLaunchEvents = true
        self.backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // Public method to start an upload task
    func startBackgroundUpload(request: URLRequest, fromFile fileURL: URL, completion: @escaping (BackgroundNetworkResult) -> Void) {
        let task = backgroundSession.uploadTask(with: request, fromFile: fileURL)
        let taskId = task.taskIdentifier
        
        // Store task metadata for crash reporting
        taskInfo[taskId] = [
            "url": request.url?.absoluteString ?? "unknown",
            "method": request.httpMethod ?? "unknown",
            "file_size": (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0,
            "file_path": fileURL.path,
            "start_time": Date()
        ]
        
        completionHandlers[taskId] = completion
        task.resume()
        
        // Log task start
        CrashlyticsManager.shared.logUserAction(
            action: "background_upload_started",
            screen: "background_network",
            additionalData: [
                "task_id": taskId,
                "endpoint": request.url?.absoluteString ?? "unknown",
                "method": request.httpMethod ?? "unknown"
            ]
        )
    }
    
    // MARK: - URLSessionDelegate Methods
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let taskId = dataTask.taskIdentifier
        if backgroundTaskData[taskId] != nil {
            backgroundTaskData[taskId]?.append(data)
        } else {
            backgroundTaskData[taskId] = data
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskId = task.taskIdentifier
        
        // Get task metadata for crash reporting
        let taskMetadata = taskInfo[taskId] ?? [:]
        let endpoint = taskMetadata["url"] as? String ?? "unknown"
        let method = taskMetadata["method"] as? String ?? "unknown"
        let fileSize = taskMetadata["file_size"] as? Int ?? 0
        let startTime = taskMetadata["start_time"] as? Date ?? Date()
        let duration = Date().timeIntervalSince(startTime)
        
        // Ensure we have a completion handler for this task
        guard let completion = completionHandlers[taskId] else {
            CrashlyticsManager.shared.logNonFatalError(
                message: "No completion handler for task \(taskId)",
                context: "background_network_manager",
                additionalData: [
                    "task_id": taskId,
                    "endpoint": endpoint,
                    "method": method
                ]
            )
            return
        }
        
        // Clean up the task data and completion handler
        defer {
            backgroundTaskData.removeValue(forKey: taskId)
            completionHandlers.removeValue(forKey: taskId)
            taskInfo.removeValue(forKey: taskId)
            // Also clean up the temp file
            if let fileURL = (task.originalRequest?.url) { // This is incorrect, need to fix
                 // We can't get the file URL from the request here easily. 
                 // The caller should be responsible for cleanup or we need another mechanism.
                 // For now, we will leave the temp file. iOS cleans the temp directory periodically.
            }
        }
        
        // Handle a direct error from URLSession
        if let error = error {
            CrashlyticsManager.shared.logBackgroundNetworkError(
                error: error,
                taskType: "upload",
                fileSize: fileSize
            )
            
            // Log additional context
            CrashlyticsManager.shared.logCustomError(
                error: error,
                context: "background_upload_failed",
                additionalData: [
                    "task_id": taskId,
                    "endpoint": endpoint,
                    "method": method,
                    "duration": duration,
                    "file_size": fileSize
                ]
            )
            
            completion(.failure(error))
            return
        }
        
        // Ensure we have a response and data
        guard let response = task.response as? HTTPURLResponse, let data = backgroundTaskData[taskId] else {
            let noDataError = NSError(domain: "BackgroundNetworkManagerError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data or response received."])
            
            CrashlyticsManager.shared.logBackgroundNetworkError(
                error: noDataError,
                taskType: "upload",
                fileSize: fileSize
            )
            
            completion(.failure(noDataError))
            return
        }
        
        // Handle non-200 status codes
        guard response.statusCode == 200 else {
            let serverError = NSError(domain: "BackgroundNetworkManagerError", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(response.statusCode). Response: \(String(data: data, encoding: .utf8) ?? "")"])
            
            CrashlyticsManager.shared.logNetworkError(
                error: serverError,
                endpoint: endpoint,
                method: method,
                statusCode: response.statusCode,
                requestBody: nil
            )
            
            completion(.failure(serverError))
            return
        }
        
        // Log successful completion
        CrashlyticsManager.shared.logUserAction(
            action: "background_upload_completed",
            screen: "background_network",
            additionalData: [
                "task_id": taskId,
                "endpoint": endpoint,
                "method": method,
                "duration": duration,
                "response_size": data.count,
                "file_size": fileSize
            ]
        )
        
        // Success
        completion(.success(data))
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // This is called when all events for a background session have been delivered.
        // We now call the handler that the AppDelegate provided.
        DispatchQueue.main.async {
            CrashlyticsManager.shared.logAppStateChange(
                state: "background_session_events_completed",
                additionalInfo: ["session_id": session.configuration.identifier ?? "unknown"]
            )
            
            self.sessionCompletionHandler?()
            self.sessionCompletionHandler = nil
        }
    }
    
    // MARK: - Additional URLSession Delegate Methods for Better Error Tracking
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let taskId = task.taskIdentifier
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        
        // Log progress for large uploads
        if totalBytesExpectedToSend > 1024 * 1024 { // Only log for uploads > 1MB
            CrashlyticsManager.shared.logUserAction(
                action: "background_upload_progress",
                screen: "background_network",
                additionalData: [
                    "task_id": taskId,
                    "progress": progress,
                    "bytes_sent": totalBytesSent,
                    "total_bytes": totalBytesExpectedToSend
                ]
            )
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let taskId = task.taskIdentifier
        let originalURL = task.originalRequest?.url?.absoluteString ?? "unknown"
        let newURL = request.url?.absoluteString ?? "unknown"
        
        CrashlyticsManager.shared.logNonFatalError(
            message: "HTTP redirect detected",
            context: "background_network_redirect",
            additionalData: [
                "task_id": taskId,
                "original_url": originalURL,
                "new_url": newURL,
                "status_code": response.statusCode
            ]
        )
        
        completionHandler(request)
    }
}
