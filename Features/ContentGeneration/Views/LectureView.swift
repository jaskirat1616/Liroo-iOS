import SwiftUI
import AVFoundation

struct LectureView: View {
    let lecture: Lecture
    let audioFiles: [AudioFile]
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentAudioIndex = 0
    @State private var currentWordIndex = 0
    @State private var currentSectionIndex = 0
    @State private var isLoadingAudio = false
    @State private var highlightedWords: [String] = []
    @State private var currentText = ""
    
    // Timer for word-by-word highlighting
    @State private var wordTimer: Timer?
    
    // Timer for monitoring audio playback
    @State private var audioMonitorTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(lecture.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Label(lecture.level.rawValue, systemImage: "person.2.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let imageStyle = lecture.imageStyle {
                            Label(imageStyle, systemImage: "paintbrush.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Audio Controls
                audioControlsView
                    .padding(.horizontal)
                
                // Current Speaking Content
                if isPlaying && !currentText.isEmpty {
                    currentSpeakingView
                        .padding(.horizontal)
                }
                
                // Progress indicator
                if lecture.sections.count > 0 {
                    VStack(spacing: 8) {
                        Text("Section \(currentSectionIndex + 1) of \(lecture.sections.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: Double(currentSectionIndex), total: Double(lecture.sections.count - 1))
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 2)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Lecture")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopLecture()
        }
    }
    
    private var audioControlsView: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    if isPlaying {
                        stopLecture()
                    } else {
                        playFullLecture()
                    }
                }) {
                    HStack {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.title2)
                        Text(isPlaying ? "Stop Lecture" : "Play Full Lecture")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
                }
                
                Spacer()
                
                if isLoadingAudio {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Progress indicator
            if lecture.sections.count > 0 {
                ProgressView(value: Double(currentSectionIndex), total: Double(lecture.sections.count - 1))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var currentSpeakingView: some View {
        let currentSection = lecture.sections[currentSectionIndex]
        
        return VStack(alignment: .leading, spacing: 20) {
            // Section Header
            VStack(alignment: .leading, spacing: 8) {
                Text(currentSection.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Section \(currentSection.order)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Section Image
            if let imageUrl = currentSection.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                        )
                }
            }
            
            // Speaking Text with Word-by-Word Highlighting
            VStack(alignment: .leading, spacing: 12) {
                Text("Speaking Now:")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                HighlightedTextView(
                    fullText: currentSection.script,
                    highlightedWords: highlightedWords,
                    currentText: currentText
                )
                .font(.title3)
                .lineSpacing(6)
                .foregroundColor(.primary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .animation(.easeInOut(duration: 0.3), value: currentSectionIndex)
        .animation(.easeInOut(duration: 0.2), value: highlightedWords.count)
    }
    
    private func playFullLecture() {
        guard !audioFiles.isEmpty else {
            print("[Lecture][Play] ERROR: No audio files available")
            return
        }
        
        // Sort audio files in the correct order: title first, then sections in order
        let sortedAudioFiles = sortAudioFiles(audioFiles)
        
        print("[Lecture][Play] ===== STARTING FULL LECTURE PLAYBACK =====")
        print("[Lecture][Play] Total audio files: \(sortedAudioFiles.count)")
        print("[Lecture][Play] Lecture title: \(lecture.title)")
        print("[Lecture][Play] Lecture sections: \(lecture.sections.count)")
        
        for (index, audio) in sortedAudioFiles.enumerated() {
            print("[Lecture][Play] Audio \(index + 1): type=\(audio.type.rawValue), section=\(audio.section ?? -1), filename=\(audio.filename)")
            print("[Lecture][Play] Audio \(index + 1) text: \(audio.text.prefix(100))...")
        }
        
        stopLecture()
        currentAudioIndex = 0
        currentSectionIndex = 0
        currentWordIndex = 0
        highlightedWords = []
        currentText = ""
        isPlaying = true
        
        print("[Lecture][Play] State initialized - starting playback")
        
        // Use the sorted audio files
        playNextAudio(sortedAudioFiles: sortedAudioFiles)
    }
    
    private func sortAudioFiles(_ audioFiles: [AudioFile]) -> [AudioFile] {
        print("[Lecture][Sort] Sorting \(audioFiles.count) audio files")
        
        let sorted = audioFiles.sorted { first, second in
            // Title comes first
            if first.type == .title && second.type != .title {
                return true
            }
            if first.type != .title && second.type == .title {
                return false
            }
            
            // Then sort by section number
            let firstSection = first.section ?? 0
            let secondSection = second.section ?? 0
            
            if firstSection != secondSection {
                return firstSection < secondSection
            }
            
            // Within the same section, section_title comes before section_script
            if first.type == .sectionTitle && second.type == .sectionScript {
                return true
            }
            if first.type == .sectionScript && second.type == .sectionTitle {
                return false
            }
            
            return false
        }
        
        print("[Lecture][Sort] Sorted order:")
        for (index, audio) in sorted.enumerated() {
            print("[Lecture][Sort] \(index + 1). \(audio.type.rawValue) - Section \(audio.section ?? -1)")
        }
        
        return sorted
    }
    
    private func playNextAudio(sortedAudioFiles: [AudioFile]) {
        print("[Lecture][Next] ===== PLAY NEXT AUDIO =====")
        print("[Lecture][Next] Current audio index: \(currentAudioIndex)")
        print("[Lecture][Next] Total audio files: \(sortedAudioFiles.count)")
        print("[Lecture][Next] Is playing: \(isPlaying)")
        
        guard currentAudioIndex < sortedAudioFiles.count else {
            print("[Lecture][Next] All audio files completed - stopping lecture")
            stopLecture()
            return
        }
        
        // Check if we're still supposed to be playing
        guard isPlaying else {
            print("[Lecture][Next] Playback was stopped, not continuing")
            return
        }
        
        let audioFile = sortedAudioFiles[currentAudioIndex]
        print("[Lecture][Next] Playing audio \(currentAudioIndex + 1)/\(sortedAudioFiles.count): \(audioFile.type.rawValue)")
        print("[Lecture][Next] Audio file: \(audioFile.filename)")
        print("[Lecture][Next] Audio URL: \(audioFile.url)")
        
        playAudioFile(audioFile) {
            print("[Lecture][Next] ===== AUDIO COMPLETED =====")
            print("[Lecture][Next] Audio \(self.currentAudioIndex + 1) completed, moving to next")
            // Move to next audio file
            self.currentAudioIndex += 1
            
            // Add a small delay to ensure smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("[Lecture][Next] Transition delay completed, playing next audio")
                self.playNextAudio(sortedAudioFiles: sortedAudioFiles)
            }
        }
    }
    
    private func playAudioFile(_ audioFile: AudioFile, completion: @escaping () -> Void) {
        print("[Lecture][Audio] ===== PLAYING AUDIO FILE =====")
        print("[Lecture][Audio] File: \(audioFile.filename)")
        print("[Lecture][Audio] Type: \(audioFile.type.rawValue)")
        print("[Lecture][Audio] Section: \(audioFile.section ?? -1)")
        print("[Lecture][Audio] Text: \(audioFile.text.prefix(100))...")
        
        guard let url = URL(string: audioFile.url) else {
            print("[Lecture][Audio] ERROR: Invalid audio URL: \(audioFile.url)")
            completion()
            return
        }
        
        print("[Lecture][Audio] Valid URL: \(audioFile.url)")
        print("[Lecture][Audio] Setting loading state...")
        
        isLoadingAudio = true
        
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            print("[Lecture][Audio] Audio session configured successfully")
        } catch {
            print("[Lecture][Audio] ERROR configuring audio session: \(error)")
        }
        
        // Update current section based on audio file
        if let section = audioFile.section {
            currentSectionIndex = section - 1 // Convert to 0-based index
            print("[Lecture][Audio] Setting current section to: \(currentSectionIndex)")
        } else if audioFile.type == .title {
            currentSectionIndex = 0
            print("[Lecture][Audio] Setting current section to 0 (title)")
        }
        
        // Get the text to highlight
        let textToHighlight = audioFile.text
        currentText = textToHighlight
        print("[Lecture][Audio] Setting current text for highlighting")
        
        // Start word-by-word highlighting
        startWordHighlighting(for: textToHighlight)
        
        print("[Lecture][Audio] Starting download from URL...")
        
        // Download and play audio
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                print("[Lecture][Audio] ===== DOWNLOAD COMPLETED =====")
                self.isLoadingAudio = false
                
                if let error = error {
                    print("[Lecture][Audio] ERROR downloading audio: \(error)")
                    completion()
                    return
                }
                
                guard let data = data else {
                    print("[Lecture][Audio] ERROR: No audio data received")
                    completion()
                    return
                }
                
                print("[Lecture][Audio] Audio data received: \(data.count) bytes")
                
                do {
                    print("[Lecture][Audio] Creating AVAudioPlayer...")
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    
                    let duration = self.audioPlayer?.duration ?? 0
                    print("[Lecture][Audio] Audio duration: \(duration) seconds")
                    
                    // Set up delegate
                    print("[Lecture][Audio] Setting up audio player delegate...")
                    let delegate = AudioPlayerDelegate { 
                        DispatchQueue.main.async {
                            print("[Lecture][Audio] ===== DELEGATE CALLED =====")
                            print("[Lecture][Audio] Audio finished playing: \(audioFile.filename)")
                            self.stopWordHighlighting()
                            self.stopAudioMonitoring()
                            completion()
                        }
                    }
                    self.audioPlayer?.delegate = delegate
                    
                    // Set up fallback timer in case delegate doesn't work
                    let estimatedDuration = self.audioPlayer?.duration ?? 5.0
                    print("[Lecture][Audio] Setting up fallback timer for \(estimatedDuration + 1.0) seconds")
                    
                    var completionCalled = false
                    let fallbackTimer = Timer.scheduledTimer(withTimeInterval: estimatedDuration + 1.0, repeats: false) { _ in
                        DispatchQueue.main.async {
                            if !completionCalled && self.isPlaying {
                                print("[Lecture][Audio] ===== FALLBACK TIMER TRIGGERED =====")
                                print("[Lecture][Audio] Fallback timer triggered - audio should have finished")
                                completionCalled = true
                                self.stopWordHighlighting()
                                self.stopAudioMonitoring()
                                completion()
                            }
                        }
                    }
                    
                    // Start audio monitoring
                    print("[Lecture][Audio] Starting audio monitoring...")
                    self.startAudioMonitoring(estimatedDuration: estimatedDuration) {
                        if !completionCalled {
                            print("[Lecture][Audio] ===== AUDIO MONITORING DETECTED STUCK =====")
                            print("[Lecture][Audio] Audio monitoring detected stuck playback")
                            completionCalled = true
                            fallbackTimer.invalidate()
                            self.stopWordHighlighting()
                            completion()
                        }
                    }
                    
                    // Override the delegate completion to prevent double calls
                    let originalCompletion = delegate.completion
                    delegate.completion = {
                        if !completionCalled {
                            print("[Lecture][Audio] ===== DELEGATE COMPLETION CALLED =====")
                            completionCalled = true
                            fallbackTimer.invalidate()
                            self.stopAudioMonitoring()
                            originalCompletion()
                        } else {
                            print("[Lecture][Audio] WARNING: Delegate completion called but already completed")
                        }
                    }
                    
                    print("[Lecture][Audio] Starting audio playback...")
                    let success = self.audioPlayer?.play() ?? false
                    if success {
                        print("[Lecture][Audio] Audio started playing successfully")
                        print("[Lecture][Audio] Audio player isPlaying: \(self.audioPlayer?.isPlaying == true)")
                        print("[Lecture][Audio] Audio player currentTime: \(self.audioPlayer?.currentTime ?? 0)")
                    } else {
                        print("[Lecture][Audio] ERROR: Failed to start audio playback")
                        fallbackTimer.invalidate()
                        self.stopAudioMonitoring()
                        completion()
                    }
                } catch {
                    print("[Lecture][Audio] ERROR creating audio player: \(error)")
                    completion()
                }
            }
        }.resume()
    }
    
    private func startAudioMonitoring(estimatedDuration: TimeInterval, onStuck: @escaping () -> Void) {
        print("[Lecture][Monitor] ===== STARTING AUDIO MONITORING =====")
        print("[Lecture][Monitor] Estimated duration: \(estimatedDuration) seconds")
        print("[Lecture][Monitor] Max stuck time: \(estimatedDuration + 2.0) seconds")
        
        stopAudioMonitoring()
        
        let checkInterval = 1.0 // Check every second
        let maxStuckTime = estimatedDuration + 2.0 // Allow 2 seconds extra
        
        var lastPlaybackTime: TimeInterval = 0
        var stuckTime: TimeInterval = 0
        var checkCount = 0
        
        audioMonitorTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            checkCount += 1
            guard let player = self.audioPlayer else {
                print("[Lecture][Monitor] Check \(checkCount): No audio player available")
                onStuck()
                return
            }
            
            let currentTime = player.currentTime
            let isPlaying = player.isPlaying
            
            print("[Lecture][Monitor] Check \(checkCount): currentTime=\(currentTime), isPlaying=\(isPlaying), lastTime=\(lastPlaybackTime), stuckTime=\(stuckTime)")
            
            if isPlaying && currentTime > lastPlaybackTime {
                // Audio is progressing normally
                lastPlaybackTime = currentTime
                stuckTime = 0
                print("[Lecture][Monitor] Check \(checkCount): Audio progressing normally")
            } else if isPlaying {
                // Audio is playing but not progressing
                stuckTime += checkInterval
                print("[Lecture][Monitor] Check \(checkCount): Audio stuck for \(stuckTime) seconds")
                if stuckTime >= maxStuckTime {
                    print("[Lecture][Monitor] ===== STUCK DETECTED =====")
                    print("[Lecture][Monitor] Audio appears to be stuck, triggering completion")
                    onStuck()
                }
            } else {
                // Audio is not playing
                print("[Lecture][Monitor] Check \(checkCount): Audio not playing")
                onStuck()
            }
        }
    }
    
    private func stopAudioMonitoring() {
        if audioMonitorTimer != nil {
            print("[Lecture][Monitor] Stopping audio monitoring")
            audioMonitorTimer?.invalidate()
            audioMonitorTimer = nil
        }
    }
    
    private func startWordHighlighting(for text: String) {
        print("[Lecture][Highlight] ===== STARTING WORD HIGHLIGHTING =====")
        print("[Lecture][Highlight] Text: \(text.prefix(100))...")
        
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentWordIndex = 0
        highlightedWords = []
        
        print("[Lecture][Highlight] Total words: \(words.count)")
        
        // Calculate word duration based on audio length (estimate 150 words per minute)
        let estimatedDuration = Double(words.count) / 2.5 // 2.5 words per second
        let wordInterval = estimatedDuration / Double(words.count)
        
        print("[Lecture][Highlight] Estimated duration: \(estimatedDuration) seconds")
        print("[Lecture][Highlight] Word interval: \(wordInterval) seconds")
        
        wordTimer = Timer.scheduledTimer(withTimeInterval: wordInterval, repeats: true) { _ in
            if self.currentWordIndex < words.count {
                let word = words[self.currentWordIndex]
                self.highlightedWords.append(word)
                print("[Lecture][Highlight] Highlighted word \(self.currentWordIndex + 1)/\(words.count): '\(word)'")
                self.currentWordIndex += 1
            } else {
                print("[Lecture][Highlight] All words highlighted")
                self.stopWordHighlighting()
            }
        }
    }
    
    private func stopWordHighlighting() {
        if wordTimer != nil {
            print("[Lecture][Highlight] Stopping word highlighting")
            wordTimer?.invalidate()
            wordTimer = nil
        }
    }
    
    private func stopLecture() {
        print("[Lecture][Stop] ===== STOPPING LECTURE =====")
        print("[Lecture][Stop] Audio player isPlaying: \(audioPlayer?.isPlaying == true)")
        print("[Lecture][Stop] Current audio index: \(currentAudioIndex)")
        print("[Lecture][Stop] Is playing: \(isPlaying)")
        
        audioPlayer?.stop()
        audioPlayer = nil
        stopWordHighlighting()
        stopAudioMonitoring()
        isPlaying = false
        isLoadingAudio = false
        currentAudioIndex = 0
        currentSectionIndex = 0
        currentWordIndex = 0
        highlightedWords = []
        currentText = ""
        
        print("[Lecture][Stop] Lecture stopped successfully")
    }
}

struct HighlightedTextView: View {
    let fullText: String
    let highlightedWords: [String]
    let currentText: String
    
    var body: some View {
        let words = fullText.components(separatedBy: .whitespacesAndNewlines)
        
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let isHighlighted = highlightedWords.contains(word)
                let isCurrent = currentText.contains(word)
                
                Text(word)
                    .foregroundColor(isHighlighted ? .white : (isCurrent ? .primary : .secondary))
                    .fontWeight(isHighlighted ? .bold : .regular)
                    .font(.system(size: isHighlighted ? 18 : 16))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHighlighted ? Color.blue : Color.clear)
                    )
                    .scaleEffect(isHighlighted ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHighlighted)
            }
        }
    }
}

// Audio Player Delegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        print("[Lecture][Delegate] AudioPlayerDelegate initialized")
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("[Lecture][Delegate] ===== DELEGATE METHOD CALLED =====")
        print("[Lecture][Delegate] audioPlayerDidFinishPlaying called")
        print("[Lecture][Delegate] Successfully: \(flag)")
        print("[Lecture][Delegate] Player duration: \(player.duration)")
        print("[Lecture][Delegate] Player current time: \(player.currentTime)")
        completion()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[Lecture][Delegate] ===== DECODE ERROR =====")
        print("[Lecture][Delegate] audioPlayerDecodeErrorDidOccur called")
        if let error = error {
            print("[Lecture][Delegate] Error: \(error)")
        }
    }
}

struct LectureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LectureView(lecture: Lecture(
                title: "Sample Lecture",
                sections: [
                    LectureSection(
                        title: "Introduction",
                        script: "Welcome to this lecture about science...",
                        imagePrompt: "A classroom with students",
                        imageUrl: nil,
                        order: 1
                    )
                ],
                level: .teen,
                imageStyle: "Studio Ghibli"
            ), audioFiles: [])
        }
    }
} 