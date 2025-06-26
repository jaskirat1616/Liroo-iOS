import SwiftUI
import AVFoundation
import UIKit

struct LectureView: View {
    let lecture: Lecture
    let audioFiles: [AudioFile]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var currentAudioIndex = 0
    @State private var currentSectionIndex = 0
    @State private var isLoadingAudio = false
    @State private var audioError: String? = nil
    @State private var typewriterText = ""
    @State private var fullText = ""
    @State private var typewriterTimer: Timer?
    @State private var currentCharIndex = 0
    @State private var isTypewriterActive = false
    @State private var showChapterSelector = false
    @State private var isExploringMode = false
    @State private var lastPlayedSection = 0
    @State private var lastPlayedAudioIndex = 0
    @State private var audioMonitorTimer: Timer?
    @State private var sortedAudioFiles: [AudioFile] = []
    @State private var isTransitioningAudio = false
    @State private var showFullTextWhenPaused = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [.purple.opacity(0.1), .black] : [.purple.opacity(0.08), .white]),
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerSection
                        
                        // Chapter Navigation
                        chapterNavigationSection
                        
                        // Progress
                        progressSection
                        
                        // Current Content
                        if isPlaying || (isTypewriterActive && !typewriterText.isEmpty && !showFullTextWhenPaused) {
                            typewriterView
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                        } else {
                            exploreView
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                        }
                        
                        // Audio Controls
                        audioControlsView
                        
                        // Error
                        if let audioError = audioError {
                            errorSection(audioError)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }

            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                stopLecture()
            }
            .onAppear {
                // Sort audio files once when view appears
                print("[LectureView] View appeared - Audio files count: \(audioFiles.count)")
                sortedAudioFiles = sortAudioFiles(audioFiles)
                print("[LectureView] Sorted audio files count: \(sortedAudioFiles.count)")
                for (index, audio) in sortedAudioFiles.enumerated() {
                    print("[LectureView] Audio \(index): Type=\(audio.type), Section=\(audio.section ?? -1), URL=\(audio.url)")
                }
            }
            .sheet(isPresented: $showChapterSelector) {
                ChapterSelectorView(
                    lecture: lecture,
                    currentSection: currentSectionIndex,
                    onChapterSelected: { sectionIndex in
                        currentSectionIndex = sectionIndex
                        showChapterSelector = false
                        if isPlaying {
                            stopLecture()
                        }
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentSectionIndex)
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .animation(.easeInOut(duration: 0.3), value: isTypewriterActive)
        .animation(.easeInOut(duration: 0.3), value: isExploringMode)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lecture.title)
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                Label(lecture.level.rawValue, systemImage: "person.2.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let imageStyle = lecture.imageStyle {
                    Label(imageStyle, systemImage: "paintbrush.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Chapter Navigation
    private var chapterNavigationSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                if currentSectionIndex > 0 {
                    currentSectionIndex -= 1
                    if isPlaying {
                        stopLecture()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(currentSectionIndex > 0 ? .purple : .gray)
            }
            .disabled(currentSectionIndex == 0)
            
            Spacer()
            
            Button(action: { showChapterSelector = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("Chapters")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.purple)
            }
            
            Spacer()
            
            Button(action: {
                if currentSectionIndex < lecture.sections.count - 1 {
                    currentSectionIndex += 1
                    if isPlaying {
                        stopLecture()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(currentSectionIndex < lecture.sections.count - 1 ? .purple : .gray)
            }
            .disabled(currentSectionIndex == lecture.sections.count - 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground).opacity(0.9)))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Progress
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Section \(currentSectionIndex + 1) of \(lecture.sections.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            ProgressView(value: Double(currentSectionIndex), total: Double(max(lecture.sections.count - 1, 1)))
                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                .scaleEffect(y: 2)
        }
    }

    // MARK: - Typewriter View (when playing)
    private var typewriterView: some View {
        let section = lecture.sections[currentSectionIndex]
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader(section)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            
            sectionImage(section)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Speaking Now:")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    Spacer()
                    if isTypewriterActive && !fullText.isEmpty {
                        Text("\(Int((Double(currentCharIndex) / Double(fullText.count)) * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if isTransitioningAudio {
                        Text("Transitioning...")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                    if !isPlaying && isTypewriterActive && !typewriterText.isEmpty {
                        Text("Tap 'Full Text' to see complete content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                
                Text(typewriterText)
                    .font(.title3)
                    .lineSpacing(6)
                    .foregroundColor(.primary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .animation(.easeInOut(duration: 0.1), value: typewriterText)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground).opacity(0.95)))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: currentSectionIndex)
        .animation(.easeInOut(duration: 0.3), value: typewriterText)
    }

    // MARK: - Explore View (when not playing)
    private var exploreView: some View {
        let section = lecture.sections[currentSectionIndex]
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader(section)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            
            sectionImage(section)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Section Content:")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    if isExploringMode {
                        Text("Explore Mode")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
                
                Text(section.script)
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundColor(.primary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground).opacity(0.9)))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.3), value: currentSectionIndex)
    }

    // MARK: - Section Header & Image
    private func sectionHeader(_ section: LectureSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.title)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .lineLimit(2)
                .animation(.easeInOut(duration: 0.2), value: section.title)
            Text("Section \(section.order)")
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.2), value: section.order)
        }
        .animation(.easeInOut(duration: 0.3), value: section.id)
    }
    
    private func sectionImage(_ section: LectureSection) -> some View {
        Group {
            if let imageUrl = section.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle().fill(Color(.systemGray5)).frame(height: 180).cornerRadius(12)
                            ProgressView().scaleEffect(1.2)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 180).cornerRadius(12)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    case .failure:
                        ZStack {
                            Rectangle().fill(Color(.systemGray5)).frame(height: 180).cornerRadius(12)
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    @unknown default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: imageUrl)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: section.imageUrl)
    }

    // MARK: - Audio Controls
    private var audioControlsView: some View {
        VStack(spacing: 16) {
            // Main Play/Stop Button
            HStack(spacing: 16) {
                Button(action: {
                    if isPlaying {
                        stopLecture()
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } else {
                        playFullLecture()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.title2)
                        Text(isPlaying ? "Stop" : "Play Lecture")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(isPlaying ? Color.red : Color.purple)
                    .cornerRadius(25)
                    .shadow(color: (isPlaying ? Color.red : Color.purple).opacity(0.18), radius: 8, x: 0, y: 2)
                }
                .accessibilityLabel(isPlaying ? "Stop Lecture" : "Play Lecture")
                .accessibilityAddTraits(.isButton)
                
                if isLoadingAudio {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            // Secondary Controls
            HStack(spacing: 12) {
                Button(action: {
                    isExploringMode.toggle()
                    if isPlaying {
                        stopLecture()
                        // Don't clear typewriter text when switching to explore mode
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExploringMode ? "speaker.slash" : "eye")
                        Text(isExploringMode ? "Audio Mode" : "Explore Mode")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isExploringMode ? .purple : .blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((isExploringMode ? Color.purple : Color.blue).opacity(0.1))
                    )
                }
                
                // Toggle between typewriter and full text when paused
                if !isPlaying && isTypewriterActive && !typewriterText.isEmpty {
                    Button(action: {
                        showFullTextWhenPaused.toggle()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showFullTextWhenPaused ? "textformat.abc" : "textformat.123")
                            Text(showFullTextWhenPaused ? "Typewriter" : "Full Text")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }
                }
                
                Spacer()
                
                Button(action: {
                    resumeLecture()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Resume")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(lastPlayedSection >= 0 && lastPlayedAudioIndex > 0 ? .orange : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
                .disabled(lastPlayedSection < 0 || lastPlayedAudioIndex == 0)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Error Section
    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Audio Logic
    private func playFullLecture() {
        guard !sortedAudioFiles.isEmpty else {
            print("[LectureView] No audio files available for playback")
            audioError = "No audio files available."
            return
        }
        
        print("[LectureView] Starting lecture playback - Audio files: \(sortedAudioFiles.count)")
        print("[LectureView] Current section: \(currentSectionIndex), Audio index: \(currentAudioIndex)")
        
        stopLecture()
        
        // Clear typewriter text when starting a new lecture
        clearTypewriterText()
        
        // If resuming, use the saved positions; otherwise start from beginning
        if lastPlayedSection >= 0 && lastPlayedAudioIndex > 0 {
            currentSectionIndex = lastPlayedSection
            currentAudioIndex = lastPlayedAudioIndex
            print("[LectureView] Resuming from section \(currentSectionIndex), audio \(currentAudioIndex)")
        } else {
            currentAudioIndex = 0
            currentSectionIndex = 0
            print("[LectureView] Starting from beginning")
        }
        
        isPlaying = true
        isTypewriterActive = false
        audioError = nil
        playNextAudio()
    }
    
    private func clearTypewriterText() {
        stopTypewriter()
        typewriterText = ""
        currentCharIndex = 0
        isTypewriterActive = false
        showFullTextWhenPaused = false
    }
    
    private func sortAudioFiles(_ audioFiles: [AudioFile]) -> [AudioFile] {
        audioFiles.sorted { first, second in
            if first.type == .title && second.type != .title { return true }
            if first.type != .title && second.type == .title { return false }
            let firstSection = first.section ?? 0
            let secondSection = second.section ?? 0
            if firstSection != secondSection { return firstSection < secondSection }
            if first.type == .sectionTitle && second.type == .sectionScript { return true }
            if first.type == .sectionScript && second.type == .sectionTitle { return false }
            return false
        }
    }
    
    private func playNextAudio() {
        guard currentAudioIndex < sortedAudioFiles.count else {
            print("[LectureView] Finished all audio files")
            stopLecture()
            return
        }
        guard isPlaying else { 
            print("[LectureView] Playback stopped, not continuing to next audio")
            return 
        }
        
        let audioFile = sortedAudioFiles[currentAudioIndex]
        print("[LectureView] Playing next audio file \(currentAudioIndex + 1)/\(sortedAudioFiles.count)")
        
        // Set transition state
        isTransitioningAudio = true
        
        playAudioFile(audioFile) {
            self.currentAudioIndex += 1
            self.lastPlayedAudioIndex = self.currentAudioIndex
            
            // Clear transition state after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isTransitioningAudio = false
            }
            
            // Keep the typewriter text visible during the transition
            // Don't reset it immediately, let it fade naturally
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if self.isPlaying {
                    self.playNextAudio()
                }
            }
        }
    }
    
    private func playAudioFile(_ audioFile: AudioFile, completion: @escaping () -> Void) {
        print("[LectureView] Playing audio file - Type: \(audioFile.type), URL: \(audioFile.url)")
        
        guard let url = URL(string: audioFile.url) else {
            print("[LectureView] Invalid audio URL: \(audioFile.url)")
            audioError = "Invalid audio URL."
            completion()
            return
        }
        isLoadingAudio = true
        audioError = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[LectureView] Audio session error: \(error.localizedDescription)")
            audioError = "Audio session error: \(error.localizedDescription)"
        }
        if let section = audioFile.section {
            currentSectionIndex = section - 1
            lastPlayedSection = currentSectionIndex
        } else if audioFile.type == .title {
            currentSectionIndex = 0
            lastPlayedSection = 0
        }
        
        // Start typewriter for new text, but don't immediately clear the old text
        let newText = audioFile.text
        fullText = newText
        
        // Only start new typewriter if we're not already in the middle of one
        if !isTypewriterActive {
            startTypewriter(for: newText)
        } else {
            // If we're already typing, smoothly transition to new text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startTypewriter(for: newText)
            }
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingAudio = false
                if let error = error {
                    print("[LectureView] Audio download error: \(error.localizedDescription)")
                    self.audioError = "Audio download error: \(error.localizedDescription)"
                    completion()
                    return
                }
                guard let data = data else {
                    print("[LectureView] No audio data received")
                    self.audioError = "No audio data received."
                    completion()
                    return
                }
                
                print("[LectureView] Audio data received - Size: \(data.count) bytes")
                
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    let delegate = AudioPlayerDelegate {
                        DispatchQueue.main.async {
                            print("[LectureView] Audio playback completed")
                            // Complete the typewriter text when audio finishes
                            self.completeTypewriterText()
                            // Don't immediately stop typewriter, let it complete naturally
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.stopTypewriter()
                                self.stopAudioMonitoring()
                                completion()
                            }
                        }
                    }
                    self.audioPlayer?.delegate = delegate
                    let estimatedDuration = self.audioPlayer?.duration ?? 5.0
                    print("[LectureView] Audio duration: \(estimatedDuration) seconds")
                    
                    var completionCalled = false
                    let fallbackTimer = Timer.scheduledTimer(withTimeInterval: estimatedDuration + 1.0, repeats: false) { _ in
                        DispatchQueue.main.async {
                            if !completionCalled && self.isPlaying {
                                print("[LectureView] Fallback timer triggered")
                                completionCalled = true
                                self.completeTypewriterText()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    self.stopTypewriter()
                                    self.stopAudioMonitoring()
                                    completion()
                                }
                            }
                        }
                    }
                    self.startAudioMonitoring(estimatedDuration: estimatedDuration) {
                        if !completionCalled {
                            print("[LectureView] Audio monitoring detected completion")
                            completionCalled = true
                            fallbackTimer.invalidate()
                            self.completeTypewriterText()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.stopTypewriter()
                                completion()
                            }
                        }
                    }
                    let originalCompletion = delegate.completion
                    delegate.completion = {
                        if !completionCalled {
                            print("[LectureView] Audio player delegate completion")
                            completionCalled = true
                            fallbackTimer.invalidate()
                            self.stopAudioMonitoring()
                            originalCompletion()
                        }
                    }
                    let success = self.audioPlayer?.play() ?? false
                    if !success {
                        print("[LectureView] Failed to start audio playback")
                        self.audioError = "Failed to start audio playback."
                        fallbackTimer.invalidate()
                        self.stopAudioMonitoring()
                        completion()
                    } else {
                        print("[LectureView] Audio playback started successfully")
                    }
                } catch {
                    print("[LectureView] Audio player error: \(error.localizedDescription)")
                    self.audioError = "Audio player error: \(error.localizedDescription)"
                    completion()
                }
            }
        }.resume()
    }
    
    private func startTypewriter(for text: String) {
        stopTypewriter()
        
        // Smooth transition: fade out current text, then fade in new text
        withAnimation(.easeInOut(duration: 0.15)) {
            typewriterText = ""
            currentCharIndex = 0
            isTypewriterActive = true
        }
        
        // Start the new typewriter after a brief delay for smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Calculate timing based on audio duration, not text length
            // We'll sync with the audio player's current time
            self.startAudioSyncTypewriter(for: text)
        }
    }
    
    private func startAudioSyncTypewriter(for text: String) {
        // Start with empty text
        typewriterText = ""
        currentCharIndex = 0
        
        // Use a timer that syncs with audio playback
        let syncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard let player = self.audioPlayer, player.isPlaying else {
                timer.invalidate()
                return
            }
            
            // Calculate how much of the audio has played
            let audioProgress = player.currentTime / player.duration
            let targetCharIndex = Int(audioProgress * Double(text.count))
            
            // Handle seeking (if user skipped forward/backward)
            if targetCharIndex < self.currentCharIndex {
                // User went backward, reset typewriter
                self.typewriterText = ""
                self.currentCharIndex = 0
            }
            
            // Add characters to match audio progress
            while self.currentCharIndex < targetCharIndex && self.currentCharIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: self.currentCharIndex)
                withAnimation(.easeInOut(duration: 0.05)) {
                    self.typewriterText += String(text[index])
                }
                self.currentCharIndex += 1
            }
            
            // Stop timer if we've reached the end
            if self.currentCharIndex >= text.count {
                timer.invalidate()
            }
        }
        
        // Store the timer for cleanup
        self.typewriterTimer = syncTimer
    }
    
    private func stopTypewriter() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        isTypewriterActive = false
    }
    
    private func startAudioMonitoring(estimatedDuration: TimeInterval, onStuck: @escaping () -> Void) {
        stopAudioMonitoring()
        let checkInterval = 1.0
        let maxStuckTime = estimatedDuration + 2.0
        var lastPlaybackTime: TimeInterval = 0
        var stuckTime: TimeInterval = 0
        audioMonitorTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { _ in
            guard let player = self.audioPlayer else {
                onStuck()
                return
            }
            let currentTime = player.currentTime
            let isPlaying = player.isPlaying
            if isPlaying && currentTime > lastPlaybackTime {
                lastPlaybackTime = currentTime
                stuckTime = 0
            } else if isPlaying {
                stuckTime += checkInterval
                if stuckTime >= maxStuckTime {
                    onStuck()
                }
            } else {
                onStuck()
            }
        }
    }
    
    private func stopAudioMonitoring() {
        audioMonitorTimer?.invalidate()
        audioMonitorTimer = nil
    }
    
    private func stopLecture() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopAudioMonitoring()
        isPlaying = false
        isLoadingAudio = false
        isTransitioningAudio = false
        showFullTextWhenPaused = false
        audioError = nil
        
        // Don't immediately clear typewriter text - let it persist during pauses
        // Only clear it when explicitly stopping or starting a new lecture
    }
    
    private func resumeLecture() {
        guard lastPlayedSection >= 0 && lastPlayedAudioIndex > 0 else { return }
        currentSectionIndex = lastPlayedSection
        currentAudioIndex = lastPlayedAudioIndex
        
        // Don't clear typewriter text when resuming - keep the current state
        isPlaying = true
        audioError = nil
        playNextAudio()
    }
    
    private func completeTypewriterText() {
        // Complete the typewriter text by showing all remaining characters
        while currentCharIndex < fullText.count {
            let index = fullText.index(fullText.startIndex, offsetBy: currentCharIndex)
            typewriterText += String(fullText[index])
            currentCharIndex += 1
        }
    }
}

// MARK: - Chapter Selector View
struct ChapterSelectorView: View {
    let lecture: Lecture
    let currentSection: Int
    let onChapterSelected: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(lecture.sections.enumerated()), id: \.offset) { index, section in
                    Button(action: {
                        onChapterSelected(index)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Section \(section.order)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if index == currentSection {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - AudioPlayerDelegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var completion: () -> Void
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion()
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        completion()
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
