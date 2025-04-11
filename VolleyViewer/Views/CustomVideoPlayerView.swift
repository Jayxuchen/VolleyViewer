import SwiftUI
import AVFoundation

struct CustomVideoPlayerView: View {
    let videoURL: URL
    @Binding var isPresentingPlayer: Bool

    @State private var player: AVPlayer
    @State private var showControls = true
    @State private var isPlaying = true
    @State private var autoHideWorkItem: DispatchWorkItem?

    // Timestamp tracking
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isScrubbing = false

    init(videoURL: URL, isPresentingPlayer: Binding<Bool>) {
        self.videoURL = videoURL
        self._isPresentingPlayer = isPresentingPlayer
        _player = State(initialValue: AVPlayer())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VideoPlayerContainer(player: player)
                .onTapGesture {
                    toggleControls()
                }

            if showControls {
                VStack {
                    // X button
                    HStack {
                        Button(action: {
                            player.pause()
                            player.replaceCurrentItem(with: nil)
                            isPresentingPlayer = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }

                    Spacer()

                    // Playback buttons
                    HStack(spacing: 40) {
                        Button(action: { seek(by: -5) }) {
                            Image(systemName: "gobackward.5")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }

                        Button(action: togglePlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }

                        Button(action: { seek(by: 5) }) {
                            Image(systemName: "goforward.5")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                    }

                    // Slider + time labels
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(get: {
                                currentTime
                            }, set: { newValue in
                                isScrubbing = true
                                currentTime = newValue
                            }),
                            in: 0...((duration > 0) ? duration : 1),
                            onEditingChanged: { editing in
                                if !editing {
                                    let time = CMTime(seconds: currentTime, preferredTimescale: 600)
                                    player.seek(to: time) { _ in
                                        isScrubbing = false
                                    }
                                    scheduleAutoHide()
                                }
                            }
                        )
                        .accentColor(.white)
                        .padding(.horizontal)

                        HStack {
                            Text(formatTime(currentTime))
                            Spacer()
                            Text(formatTime(duration))
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: showControls)
            }
        }
        .onAppear {
            print("🎬 Attempting to play video: \(videoURL.absoluteString)")
            configureAudioSession()
            loadAsset()
        }
    }

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            print("🔊 Audio session activated")
        } catch {
            print("❌ Failed to activate audio session: \(error.localizedDescription)")
        }
    }

    func loadAsset() {
        print("🔄 Loading asset for URL: \(videoURL.absoluteString)")
        let asset = AVURLAsset(url: videoURL)
        let keys = ["playable"]

        asset.loadValuesAsynchronously(forKeys: keys) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "playable", error: &error)

            switch status {
            case .loaded:
                print("✅ Video is playable")
                let item = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: item)
                player.play()
                isPlaying = true
                scheduleAutoHide()
                addPeriodicTimeObserver()
            case .failed:
                print("❌ Video failed to load: \(error?.localizedDescription ?? "Unknown error")")
            case .cancelled:
                print("⚠️ Video load was cancelled")
            default:
                print("⚠️ Unexpected status: \(status.rawValue)")
            }
        }
    }

    func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
        _ = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if !isScrubbing {
                currentTime = CMTimeGetSeconds(time)
            }

            if let item = player.currentItem {
                duration = CMTimeGetSeconds(item.duration)
            }
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            print("⏸️ Paused video")
        } else {
            player.play()
            print("▶️ Playing video")
        }
        isPlaying.toggle()
        scheduleAutoHide()
    }

    func seek(by seconds: Double) {
        let newTime = max(currentTime + seconds, 0)
        let time = CMTime(seconds: newTime, preferredTimescale: 600)
        player.seek(to: time)
        currentTime = newTime
        scheduleAutoHide()
    }

    func toggleControls() {
        showControls.toggle()
        if showControls {
            scheduleAutoHide()
        }
    }

    func scheduleAutoHide() {
        autoHideWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation {
                showControls = false
            }
        }
        autoHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else {
            return "00:00"
        }

        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
