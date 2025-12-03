import Foundation
import FirebaseMessaging
import OSLog

@MainActor
class ComicNetworkingService: ObservableObject {
    static let shared = ComicNetworkingService()
    
    private let logger = Logger(subsystem: "com.liroo.app", category: "ComicNetworking")
    private var backendURL: String { AppConfig.backendURL }
    
    // Custom URLSession for comic generation with extended timeouts
    private lazy var comicSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 7200  // 120 minutes for comic generation
        config.timeoutIntervalForResource = 14400 // 240 minutes (4 hours) for comic generation
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Comic Generation
    
    func generateComic(
        text: String,
        level: String,
        imageStyle: String,
        userToken: String? = nil
    ) async throws -> (Comic, String?) {
        
        logger.info("Starting comic generation - Text length: \(text.count), Level: \(level), Style: \(imageStyle)")
        
        // Validate input
        guard !text.isEmpty else {
            throw ComicGenerationError.backendError("No text provided for comic generation")
        }
        
        guard text.count <= 5000 else {
            throw ComicGenerationError.backendError("Input text must be less than 5000 characters")
        }
        
        // Get FCM token if not provided
        let fcmToken: String?
        if let userToken = userToken {
            fcmToken = userToken
        } else {
            fcmToken = await getFCMToken()
        }
        
        // Prepare request
        let requestBody: [String: Any] = [
            "text": text,
            "level": level,
            "image_style": imageStyle,
            "user_token": fcmToken ?? ""
        ]
        
        let url = URL(string: "\(backendURL)/generate_comic")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        logger.info("Sending comic generation request to backend")
        
        // Add retry logic for 503 errors (backend hibernation)
        let maxRetries = 5
        var attempt = 0
        var lastError: Error?
        
        repeat {
            attempt += 1
            logger.info("Comic generation attempt \(attempt) of \(maxRetries)")
            
            do {
                let (data, response) = try await comicSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ComicGenerationError.invalidResponse
                }
                
                logger.info("Received response with status code: \(httpResponse.statusCode)")
                
                // Log raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.debug("Raw response: \(responseString.prefix(500))...")
                }
                
                // Handle 503 errors (backend hibernation) with retry
                if httpResponse.statusCode == 503 {
                    if attempt < maxRetries {
                        let retryDelay = Double(attempt) * 4.0
                        logger.info("Backend is hibernating (503). Retrying in \(retryDelay) seconds...")
                        try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        continue
                    } else {
                        throw ComicGenerationError.backendError("Backend is starting up. Please try again in a few moments.")
                    }
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    logger.error("Server returned status code \(httpResponse.statusCode): \(errorMessage)")
                    throw ComicGenerationError.backendError("Server returned status code \(httpResponse.statusCode): \(errorMessage)")
                }
                
                // Decode response
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(ComicResponse.self, from: data)
                
                logger.info("Successfully decoded ComicResponse - Success: \(apiResponse.success)")
                
                // Check for backend error
                if let error = apiResponse.error {
                    logger.error("Backend returned error: \(error)")
                    throw ComicGenerationError.backendError(error)
                }
                
                // Validate success flag
                if !apiResponse.success {
                    throw ComicGenerationError.backendError("Backend indicated failure")
                }
                
                // Extract comic data
                guard let comic = apiResponse.comic else {
                    throw ComicGenerationError.decodingError("No comic data in response")
                }
                
                logger.info("Successfully received comic - Title: \(comic.comicTitle), Panels: \(comic.panelLayout.count)")
                
                return (comic, apiResponse.request_id)
                
            } catch let error as ComicGenerationError {
                // Re-throw our custom errors
                throw error
            } catch let error as URLError {
                switch error.code {
                case .timedOut:
                    throw ComicGenerationError.timeout
                case .notConnectedToInternet:
                    throw ComicGenerationError.noInternetConnection
                default:
                    throw ComicGenerationError.networkError(error.localizedDescription)
                }
            } catch {
                lastError = error
                logger.error("Comic generation attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt == maxRetries {
                    if let decodingError = error as? DecodingError {
                        throw ComicGenerationError.decodingError("Failed to decode response: \(decodingError)")
                    } else {
                        throw ComicGenerationError.networkError(error.localizedDescription)
                    }
                }
                
                // Wait before retry
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        } while attempt < maxRetries
        
        // If we get here, all retries failed
        throw lastError ?? ComicGenerationError.networkError("All retry attempts failed")
    }
    
    // MARK: - Progress Polling
    
    func pollProgress(requestId: String) async throws -> ProgressResponse {
        let url = URL(string: "\(backendURL)/progress/\(requestId)")!
        
        logger.debug("Polling progress for request: \(requestId)")
        
        let (data, response) = try await comicSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ComicGenerationError.networkError("Failed to fetch progress")
        }
        
        let decoder = JSONDecoder()
        let progress = try decoder.decode(ProgressResponse.self, from: data)
        
        logger.debug("Progress update - Step: \(progress.step_number)/\(progress.total_steps) - \(progress.step)")
        
        return progress
    }
    
    // MARK: - Health Check
    
    func checkBackendHealth() async throws -> Bool {
        let url = URL(string: "\(backendURL)/health")!
        
        logger.info("Checking backend health")
        
        do {
            let (data, response) = try await comicSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logger.warning("Backend health check failed - Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return false
            }
            
            // Try to decode health response
            if let healthResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = healthResponse["status"] as? String {
                let isHealthy = status == "healthy"
                logger.info("Backend health check result: \(isHealthy)")
                return isHealthy
            }
            
            // If we can't decode, assume it's healthy if we got a 200
            logger.info("Backend health check passed (200 status)")
            return true
            
        } catch {
            logger.error("Backend health check error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFCMToken() async -> String? {
        do {
            let token = try await Messaging.messaging().token()
            logger.debug("Retrieved FCM token: \(token.prefix(10))...")
            return token
        } catch {
            logger.warning("Failed to get FCM token: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Comic Generation Result

struct ComicGenerationResult {
    let comic: Comic
    let requestId: String?
    let generationTime: TimeInterval
    let success: Bool
    let error: ComicGenerationError?
    
    init(comic: Comic, requestId: String?, generationTime: TimeInterval, success: Bool = true, error: ComicGenerationError? = nil) {
        self.comic = comic
        self.requestId = requestId
        self.generationTime = generationTime
        self.success = success
        self.error = error
    }
} 