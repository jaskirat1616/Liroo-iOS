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
                // Fallback to static splash screen if video fails to load
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
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            isActive = true
                        }
                    }) {
                        Text("Get Started")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(22)
                            .padding(.horizontal, 40)
                    }
                    Text("By clicking Get Started you agree to our Terms of Service and Privacy Policy.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            print("SplashScreenView: onAppear called")
            DispatchQueue.main.async {
                 setupVideo()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                print("SplashScreenView: Starting fade out animation")
                withAnimation(.easeInOut(duration: fadeOutDuration)) {
                    videoOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                    print("SplashScreenView: Transitioning to main app")
                    isActive = true
                }
            }
        }
        .onDisappear {
            // Stop the video player
            player?.pause()
            player = nil
            
            // Clear any loop observers
            clearVideoLoopObserver()
            
            // Deactivate audio session to stop music player from appearing
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("SplashScreenView: Failed to deactivate audio session: \(error.localizedDescription)")
            }
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

        // Try to find the video file in the main bundle (not in subdirectory)
        guard let videoURL = Bundle.main.url(forResource: "SplashVideo", withExtension: "mp4") else {
            print("SplashScreenView: Video file 'SplashVideo.mp4' NOT FOUND in main bundle.")
            print("SplashScreenView: Available bundle resources:")
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("SplashScreenView: Bundle contents: \(contents)")
                } catch {
                    print("SplashScreenView: Could not list bundle contents: \(error)")
                }
            }
            return
        }
        
        print("SplashScreenView: Found video at: \(videoURL)")
        
        let newPlayer = AVPlayer(url: videoURL)
        
        // Check if player item is ready to play
        if newPlayer.currentItem?.status == .failed {
            print("SplashScreenView: AVPlayerItem failed to load. Error: \(newPlayer.currentItem?.error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        self.player = newPlayer
        self.player?.play()
        
        // Don't loop the video - let it play once
        self.player?.actionAtItemEnd = .pause
        
        print("SplashScreenView: Video player setup complete")
    }
    
    private func setupVideoLoopObserver(for playerToLoop: AVPlayer) {
        // Remove this function - we don't want the video to loop
        clearVideoLoopObserver()
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
