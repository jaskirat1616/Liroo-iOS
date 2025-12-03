import Foundation

/// Manages Gemini model configuration and selection
class GeminiConfigurationManager {
    static let shared = GeminiConfigurationManager()
    
    private init() {}
    
    // MARK: - Model Configuration
    
    /// Primary image generation model (Gemini 3.0 Pro)
    var primaryImageModel: String {
        return "gemini-3.0-pro-exp"
    }
    
    /// Fallback image generation model (Gemini 2.5 Flash Image)
    var fallbackImageModel: String {
        return "gemini-2.5-flash-image"
    }
    
    /// Primary text generation model
    var primaryTextModel: String {
        return "gemini-2.5-flash-preview-04-17"
    }
    
    // MARK: - Configuration Parameters
    
    struct ImageGenerationConfig {
        let temperature: Double
        let topP: Double
        let topK: Int
        let maxOutputTokens: Int?
        
        static let `default` = ImageGenerationConfig(
            temperature: 0.7,
            topP: 0.6,
            topK: 40,
            maxOutputTokens: nil
        )
        
        static let highQuality = ImageGenerationConfig(
            temperature: 0.8,
            topP: 0.7,
            topK: 50,
            maxOutputTokens: nil
        )
        
        static let fastGeneration = ImageGenerationConfig(
            temperature: 0.6,
            topP: 0.5,
            topK: 30,
            maxOutputTokens: nil
        )
    }
    
    /// Get configuration based on quality preference
    func getImageConfig(for quality: ImageQuality) -> ImageGenerationConfig {
        switch quality {
        case .high:
            return .highQuality
        case .medium:
            return .default
        case .low:
            return .fastGeneration
        }
    }
    
    // MARK: - Aspect Ratio Mapping
    
    /// Map aspect ratio to API format
    func mapAspectRatio(_ aspectRatio: ImageAspectRatio) -> String {
        switch aspectRatio {
        case .square:
            return "1:1"
        case .landscape:
            return "16:9"
        case .portrait:
            return "9:16"
        }
    }
    
    // MARK: - Model Selection Logic
    
    /// Determine which model to use based on quality and availability
    func selectImageModel(for quality: ImageQuality, preferFast: Bool = false) -> String {
        if preferFast || quality == .low {
            return fallbackImageModel
        }
        return primaryImageModel
    }
    
    // MARK: - Feature Flags
    
    /// Whether to use caching for image generation
    var useImageCache: Bool {
        return true
    }
    
    /// Whether to enable consistency tracking
    var enableConsistencyTracking: Bool {
        return true
    }
    
    /// Maximum number of retry attempts
    var maxRetryAttempts: Int {
        return 2
    }
    
    /// Retry delay in seconds
    var retryDelay: TimeInterval {
        return 1.0
    }
}

