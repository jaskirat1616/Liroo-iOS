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
    @State private var currentWordIndex = 0
    @State private var currentSectionIndex = 0
    @State private var isLoadingAudio = false
    @State private var highlightedWords: [String] = []
    @State private var currentText = ""
    @State private var wordTimer: Timer?
    @State private var audioMonitorTimer: Timer?
    @State private var audioError: String? = nil
    @State private var showHaptics = false

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
                        // Progress
                        progressSection
                        // Current Speaking Content
                        if isPlaying && !currentText.isEmpty {
                            currentSpeakingView
                        } else {
                            sectionPreview
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
                // Close button for modal
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            stopLecture()
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding(8)
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle(lecture.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                stopLecture()
            }
        }
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

    // MARK: - Section Preview (when not playing)
    private var sectionPreview: some View {
        let section = lecture.sections[currentSectionIndex]
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader(section)
            sectionImage(section)
            Text(section.script)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground).opacity(0.9)))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Current Speaking Content
    private var currentSpeakingView: some View {
        let section = lecture.sections[currentSectionIndex]
        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader(section)
            sectionImage(section)
            VStack(alignment: .leading, spacing: 12) {
                Text("Speaking Now:")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                HighlightedTextView(
                    fullText: section.script,
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground).opacity(0.95)))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Section Header & Image
    private func sectionHeader(_ section: LectureSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.title)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .lineLimit(2)
            Text("Section \(section.order)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit).frame(maxHeight: 180).cornerRadius(12)
                    case .failure:
                        ZStack {
                            Rectangle().fill(Color(.systemGray5)).frame(height: 180).cornerRadius(12)
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }

    // MARK: - Audio Controls
    private var audioControlsView: some View {
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

    // MARK: - Audio Logic (same as before, but with better error handling and cleanup)
    private func playFullLecture() {
        guard !audioFiles.isEmpty else {
            audioError = "No audio files available."
            return
        }
        stopLecture()
        currentAudioIndex = 0
        currentSectionIndex = 0
        currentWordIndex = 0
        highlightedWords = []
        currentText = ""
        isPlaying = true
        audioError = nil
        playNextAudio(sortedAudioFiles: sortAudioFiles(audioFiles))
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
    private func playNextAudio(sortedAudioFiles: [AudioFile]) {
        guard currentAudioIndex < sortedAudioFiles.count else {
            stopLecture()
            return
        }
        guard isPlaying else { return }
        let audioFile = sortedAudioFiles[currentAudioIndex]
        playAudioFile(audioFile) {
            self.currentAudioIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.playNextAudio(sortedAudioFiles: sortedAudioFiles)
            }
        }
    }
    private func playAudioFile(_ audioFile: AudioFile, completion: @escaping () -> Void) {
        guard let url = URL(string: audioFile.url) else {
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
            audioError = "Audio session error: \(error.localizedDescription)"
        }
        if let section = audioFile.section {
            currentSectionIndex = section - 1
        } else if audioFile.type == .title {
            currentSectionIndex = 0
        }
        let textToHighlight = audioFile.text
        currentText = textToHighlight
        startWordHighlighting(for: textToHighlight)
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingAudio = false
                if let error = error {
                    self.audioError = "Audio download error: \(error.localizedDescription)"
                    completion()
                    return
                }
                guard let data = data else {
                    self.audioError = "No audio data received."
                    completion()
                    return
                }
                do {
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    let delegate = AudioPlayerDelegate {
                        DispatchQueue.main.async {
                            self.stopWordHighlighting()
                            self.stopAudioMonitoring()
                            completion()
                        }
                    }
                    self.audioPlayer?.delegate = delegate
                    let estimatedDuration = self.audioPlayer?.duration ?? 5.0
                    var completionCalled = false
                    let fallbackTimer = Timer.scheduledTimer(withTimeInterval: estimatedDuration + 1.0, repeats: false) { _ in
                        DispatchQueue.main.async {
                            if !completionCalled && self.isPlaying {
                                completionCalled = true
                                self.stopWordHighlighting()
                                self.stopAudioMonitoring()
                                completion()
                            }
                        }
                    }
                    self.startAudioMonitoring(estimatedDuration: estimatedDuration) {
                        if !completionCalled {
                            completionCalled = true
                            fallbackTimer.invalidate()
                            self.stopWordHighlighting()
                            completion()
                        }
                    }
                    let originalCompletion = delegate.completion
                    delegate.completion = {
                        if !completionCalled {
                            completionCalled = true
                            fallbackTimer.invalidate()
                            self.stopAudioMonitoring()
                            originalCompletion()
                        }
                    }
                    let success = self.audioPlayer?.play() ?? false
                    if !success {
                        self.audioError = "Failed to start audio playback."
                        fallbackTimer.invalidate()
                        self.stopAudioMonitoring()
                        completion()
                    }
                } catch {
                    self.audioError = "Audio player error: \(error.localizedDescription)"
                    completion()
                }
            }
        }.resume()
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
    private func startWordHighlighting(for text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        currentWordIndex = 0
        highlightedWords = []
        let estimatedDuration = Double(words.count) / 2.5
        let wordInterval = estimatedDuration / Double(words.count)
        wordTimer = Timer.scheduledTimer(withTimeInterval: wordInterval, repeats: true) { _ in
            if self.currentWordIndex < words.count {
                let word = words[self.currentWordIndex]
                self.highlightedWords.append(word)
                self.currentWordIndex += 1
            } else {
                self.stopWordHighlighting()
            }
        }
    }
    private func stopWordHighlighting() {
        wordTimer?.invalidate()
        wordTimer = nil
    }
    private func stopLecture() {
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
        audioError = nil
    }
}

// MARK: - HighlightedTextView (unchanged, but ensure accessibility)
struct HighlightedTextView: View {
    let fullText: String
    let highlightedWords: [String]
    let currentText: String
    var body: some View {
        let words = fullText.components(separatedBy: .whitespacesAndNewlines)
        LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                let isHighlighted = highlightedWords.contains(word)
                Text(word)
                    .foregroundColor(isHighlighted ? .white : .primary)
                    .fontWeight(isHighlighted ? .bold : .regular)
                    .font(.system(size: isHighlighted ? 18 : 16))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHighlighted ? Color.purple : Color.clear)
                    )
                    .scaleEffect(isHighlighted ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isHighlighted)
                    .accessibilityLabel(isHighlighted ? "Speaking: \(word)" : word)
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