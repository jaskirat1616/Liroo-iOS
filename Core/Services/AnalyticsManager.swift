import Foundation
import FirebaseAnalytics

/// Analytics Manager for tracking app events, including image generation metrics
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    // MARK: - Image Generation Analytics
    
    func logImageGenerationStart(
        contentType: String,
        style: String,
        aspectRatio: String?,
        quality: String?,
        consistencyMode: Bool = false
    ) {
        var parameters: [String: Any] = [
            AnalyticsParameterContentType: contentType,
            "image_style": style
        ]
        
        if let aspectRatio = aspectRatio {
            parameters["aspect_ratio"] = aspectRatio
        }
        
        if let quality = quality {
            parameters["image_quality"] = quality
        }
        
        parameters["consistency_mode"] = consistencyMode
        
        Analytics.logEvent("image_generation_started", parameters: parameters)
        print("[Analytics] Image generation started: \(contentType), style: \(style)")
    }
    
    func logImageGenerationSuccess(
        contentType: String,
        style: String,
        generationTime: TimeInterval,
        modelUsed: String?,
        aspectRatio: String?,
        cached: Bool = false
    ) {
        var parameters: [String: Any] = [
            AnalyticsParameterContentType: contentType,
            "image_style": style,
            "generation_time": generationTime,
            "cached": cached
        ]
        
        if let modelUsed = modelUsed {
            parameters["model_used"] = modelUsed
        }
        
        if let aspectRatio = aspectRatio {
            parameters["aspect_ratio"] = aspectRatio
        }
        
        Analytics.logEvent("image_generation_success", parameters: parameters)
        print("[Analytics] Image generation succeeded: \(contentType), time: \(generationTime)s")
    }
    
    func logImageGenerationFailure(
        contentType: String,
        style: String,
        error: Error,
        attemptNumber: Int = 1
    ) {
        let parameters: [String: Any] = [
            AnalyticsParameterContentType: contentType,
            "image_style": style,
            "error_domain": (error as NSError).domain,
            "error_code": (error as NSError).code,
            "attempt_number": attemptNumber
        ]
        
        Analytics.logEvent("image_generation_failed", parameters: parameters)
        print("[Analytics] Image generation failed: \(contentType), error: \(error.localizedDescription)")
    }
    
    func logImageConsistencyScore(
        storyId: String,
        consistencyScore: Double,
        chapterCount: Int
    ) {
        let parameters: [String: Any] = [
            "story_id": storyId,
            "consistency_score": consistencyScore,
            "chapter_count": chapterCount
        ]
        
        Analytics.logEvent("image_consistency_score", parameters: parameters)
        print("[Analytics] Consistency score: \(consistencyScore) for story: \(storyId)")
    }
    
    func logImageCacheHit(
        contentType: String,
        style: String
    ) {
        let parameters: [String: Any] = [
            AnalyticsParameterContentType: contentType,
            "image_style": style
        ]
        
        Analytics.logEvent("image_cache_hit", parameters: parameters)
    }
    
    func logImageStyleUsage(style: String) {
        Analytics.logEvent("image_style_selected", parameters: [
            "style": style
        ])
    }
    
    func logAspectRatioUsage(aspectRatio: String) {
        Analytics.logEvent("aspect_ratio_selected", parameters: [
            "aspect_ratio": aspectRatio
        ])
    }
    
    // MARK: - Content Generation Analytics
    
    func logContentGenerationStart(
        contentType: String,
        level: String,
        tier: String?
    ) {
        var parameters: [String: Any] = [
            AnalyticsParameterContentType: contentType,
            "reading_level": level
        ]
        
        if let tier = tier {
            parameters["summarization_tier"] = tier
        }
        
        Analytics.logEvent("content_generation_started", parameters: parameters)
    }
    
    func logContentGenerationSuccess(
        contentType: String,
        generationTime: TimeInterval
    ) {
        Analytics.logEvent("content_generation_success", parameters: [
            AnalyticsParameterContentType: contentType,
            "generation_time": generationTime
        ])
    }
    
    // MARK: - User Engagement Analytics
    
    func logStoryView(storyId: String, chapterCount: Int) {
        Analytics.logEvent("story_viewed", parameters: [
            "story_id": storyId,
            "chapter_count": chapterCount
        ])
    }
    
    func logLectureView(lectureId: String, sectionCount: Int) {
        Analytics.logEvent("lecture_viewed", parameters: [
            "lecture_id": lectureId,
            "section_count": sectionCount
        ])
    }
    
    func logImageRegeneration(
        contentType: String,
        style: String,
        reason: String
    ) {
        Analytics.logEvent("image_regenerated", parameters: [
            AnalyticsParameterContentType: contentType,
            "image_style": style,
            "reason": reason
        ])
    }
    
    // MARK: - Generic Event Logging
    
    func logEvent(name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters ?? [:])
    }
}

