import Foundation
import AVFoundation
import Combine

/// Service for handling text-to-speech narration using Gemini 2.5 Flash Preview TTS
@MainActor
class NarratorTTSService: ObservableObject {
    static let shared = NarratorTTSService()
    
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentText: String?
    
    private var audioPlayer: AVAudioPlayer?
    private var currentAudioURL: URL?
    private var playbackTask: Task<Void, Never>?
    private var backendURL: String { AppConfig.backendURL }
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[NarratorTTS] Failed to setup audio session: \(error)")
        }
    }
    
    /// Generate and play TTS audio for the given text
    func narrate(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "No text to narrate"
            return
        }
        
        // Stop any current playback
        stop()
        
        currentText = text
        isLoading = true
        errorMessage = nil
        
        do {
            // Generate TTS audio from backend
            let audioURL = try await generateTTS(text: text)
            
            // Play the audio
            try await playAudio(from: audioURL)
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("[NarratorTTS] Error: \(error)")
        }
    }
    
    /// Generate TTS audio using backend
    private func generateTTS(text: String) async throws -> URL {
        guard let url = URL(string: "\(backendURL)/generate_tts") else {
            throw NarratorTTSError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "text": text,
            "voice": "narrator",
            "model": "gemini-2.5-flash-preview-tts"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NarratorTTSError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NarratorTTSError.backendError("Backend returned status \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let decoder = JSONDecoder()
        let ttsResponse = try decoder.decode(TTSResponse.self, from: data)
        
        guard let audioURL = URL(string: ttsResponse.audio_url) else {
            throw NarratorTTSError.invalidAudioURL
        }
        
        return audioURL
    }
    
    /// Download and play audio from URL
    private func playAudio(from url: URL) async throws {
        // Download audio data
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Create audio player
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = NarratorAudioPlayerDelegate { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
                self?.isLoading = false
            }
        }
        
        // Play audio
        let success = audioPlayer?.play() ?? false
        if !success {
            throw NarratorTTSError.playbackFailed
        }
        
        isPlaying = true
        isLoading = false
    }
    
    /// Stop current playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        isLoading = false
        currentText = nil
    }
    
    /// Pause current playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    /// Resume paused playback
    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }
}

// MARK: - Models
struct TTSResponse: Codable {
    let audio_url: String
    let voice: String
    let model: String
}

enum NarratorTTSError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidAudioURL
    case backendError(String)
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidAudioURL:
            return "Invalid audio URL"
        case .backendError(let message):
            return message
        case .playbackFailed:
            return "Failed to start audio playback"
        }
    }
}

// MARK: - Audio Player Delegate
class NarratorAudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[NarratorTTS] Audio decode error: \(error?.localizedDescription ?? "Unknown")")
        onFinish()
    }
}

