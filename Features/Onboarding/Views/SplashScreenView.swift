import SwiftUI
import AVKit
import AVFoundation // For AVAudioSession

// 1. Remove the old VideoPlayerView struct (or comment it out)
// struct VideoPlayerView: UIViewRepresentable { ... }

// 2. Add the new AVPlayerViewControllerRepresentable
struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Hide controls
        controller.videoGravity = .resizeAspectFill // Fill the screen
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player // Ensure player is up to date
    }
}

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var player: AVPlayer?
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    private let splashDuration: Double = 5.0
    private let fadeOutDuration: Double = 0.75
    
    @State private var videoOpacity: Double = 1.0
    @State private var loopObserver: (any NSObjectProtocol)? = nil

    var body: some View {
        ZStack {
            if let player = player {
                AVPlayerViewControllerRepresentable(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .opacity(videoOpacity)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                    .opacity(videoOpacity)
            }
            
            VStack {
                Spacer()
                Text("Liroo")
                    .font(.custom("OpenDyslexic-Regular", size: 48))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                    .padding(.bottom, 50)
            }
            .opacity(videoOpacity)
        }
        .onAppear {
            DispatchQueue.main.async {
                 setupVideo()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                withAnimation(.easeInOut(duration: fadeOutDuration)) {
                    videoOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                    isActive = true
                }
            }
        }
        .onDisappear {
            player?.pause()
            clearVideoLoopObserver()
        }
        .fullScreenCover(isPresented: $isActive) {
            if authViewModel.isAuthenticated {
                AppView()
            } else {
                WelcomeAuthEntryView()
            }
        }
    }
    
    private func setupVideo() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SplashScreenView: Failed to set audio session category: \(error.localizedDescription)")
        }

        // Try this path if 'Resources' is a blue folder reference in Xcode
        guard let videoURL = Bundle.main.url(forResource: "SplashVideo", withExtension: "mp4") else {
            // If the above fails, it means "Resources/Media" was not found.
            // Let's also try the original path in case "Resources" is a yellow group.
            if let alternativeVideoURL = Bundle.main.url(forResource: "SplashVideo", withExtension: "mp4") {
                // Found it with "Media" subdirectory, proceed with this one
                let newPlayer = AVPlayer(url: alternativeVideoURL)
                if newPlayer.currentItem?.status == .failed {
                    print("SplashScreenView: AVPlayerItem failed to load (path: Media/SplashVideo.mp4). Check video file integrity/format.")
                    return
                }
                self.player = newPlayer
                self.player?.play()
                setupVideoLoopObserver(for: newPlayer)
                return // Successfully setup with "Media" path
            }
            
            // If both paths fail, print a comprehensive error.
            print("SplashScreenView: Video file 'SplashVideo.mp4' NOT FOUND. Tried looking in 'Resources/Media/' AND 'Media/' subdirectories. Please check: \n1. File Name and Extension. \n2. Target Membership for 'SplashVideo.mp4'. \n3. How 'Resources' and 'Media' folders are added to your Xcode project (blue folder reference vs. yellow group).")
            return
        }
        
        // If the first guard let succeeded (found in "Resources/Media/")
        let newPlayer = AVPlayer(url: videoURL)
        if newPlayer.currentItem?.status == .failed {
            print("SplashScreenView: AVPlayerItem failed to load (path: Resources/Media/SplashVideo.mp4). Check video file integrity/format.")
            return
        }
        self.player = newPlayer
        self.player?.play()
        setupVideoLoopObserver(for: newPlayer)
    }
    
    private func setupVideoLoopObserver(for playerToLoop: AVPlayer) {
        clearVideoLoopObserver()
        
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerToLoop.currentItem,
            queue: .main
        ) { [weak playerToLoop] _ in
            playerToLoop?.seek(to: .zero)
            playerToLoop?.play()
        }
    }
    
    private func clearVideoLoopObserver() {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(AuthViewModel())
}
