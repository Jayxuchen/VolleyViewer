// CustomVideoPlayerView.swift 
import SwiftUI
import AVFoundation


struct CustomVideoPlayerView: View {
    let videoURL: URL
    @Binding var isPresentingPlayer: Bool

    @State private var player: AVPlayer
    @State private var showControls = true
    @State private var isPlaying = true
    @State private var autoHideWorkItem: DispatchWorkItem?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isScrubbing = false
    @State private var annotatedFile: AnnotatedFile
    @State private var lastTapDate: Date = Date.distantPast
    @State private var showFlashOverlay = false
    @State private var flashText = ""
    @State private var singleTapWorkItem: DispatchWorkItem?




    init(videoURL: URL, isPresentingPlayer: Binding<Bool>) {
        self.videoURL = videoURL
        self._isPresentingPlayer = isPresentingPlayer
        _player = State(initialValue: AVPlayer())

        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd hh:mm a"
        
        let creationDate = (try? videoURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let timestamp = timestampFormatter.string(from: creationDate)

        _annotatedFile = State(initialValue: AnnotatedFile(
            displayName: timestamp,
            annotations: [],
            homeScore: 0,
            awayScore: 0,
            lastHomePointIndex: nil,
            lastAwayPointIndex: nil
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                VideoPlayerContainer(player: player)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let now = Date()
                                let timeSinceLastTap = now.timeIntervalSince(lastTapDate)

                                let tapX = value.location.x
                                let width = geometry.size.width

                                if timeSinceLastTap < 0.3 {
                                    // Double tap detected
                                    singleTapWorkItem?.cancel()
                                    singleTapWorkItem = nil

                                    if tapX < width / 2 {
                                        seek(by: -5)
                                        flashText = "«5"
                                        print("👈 Double tap left: -5 seconds")
                                    } else {
                                        seek(by: 5)
                                        flashText = "5»"
                                        print("👉 Double tap right: +5 seconds")
                                    }

                                    // Flash overlay
                                    showFlashOverlay = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation {
                                            showFlashOverlay = false
                                        }
                                    }
                                } else {
                                    // Single tap detected - delayed toggleControls
                                    let workItem = DispatchWorkItem {
                                        toggleControls()
                                    }
                                    singleTapWorkItem = workItem
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                                }

                                lastTapDate = now
                            }
                    )
            }
            
            if showControls {
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                }
                .transition(.opacity)
                .animation(.easeInOut, value: showControls)
            }

            VStack {
                Spacer()

                // Annotation buttons
                HStack(spacing: 20) {
                    // Home Score Box
                    ScoreBoxView(
                        teamName: "Home",
                        score: annotatedFile.homeScore,
                        backgroundColor: .blue,
                        onTopTap: {
                            addPoint(for: "Point Home")
                        },
                        onBottomTap: {
                            removeLastPoint(for: "Point Home")
                        }
                    )
                    // Away Score Box
                    ScoreBoxView(
                        teamName: "Away",
                        score: annotatedFile.awayScore,
                        backgroundColor: .red,
                        onTopTap: {
                            addPoint(for: "Point Away")
                        },
                        onBottomTap: {
                            removeLastPoint(for: "Point Away")
                        }
                    )
                }
                .padding(.bottom, showControls ? 120 : 30)

                .padding(.bottom, showControls ? 120 : 30) // 👈 Key: dynamic padding based on showControls
            }
            .ignoresSafeArea()
            
            if showFlashOverlay {
                Text(flashText)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .transition(.scale)
                    .animation(.easeInOut, value: showFlashOverlay)
            }


            if showControls {
                VStack {
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
        
            if let loaded = MetadataManager.shared.loadAnnotatedFile(for: videoURL) {
                annotatedFile = loaded
            }
            configureAudioSession()
            loadAsset()
        }
        .onDisappear {
            annotatedFile.lastPlayedTime = currentTime
            MetadataManager.shared.saveAnnotatedFile(annotatedFile, for: videoURL)
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
        print("Loading asset for URL: \(videoURL.absoluteString)")
        let asset = AVURLAsset(url: videoURL)
        let keys = ["playable"]

        asset.loadValuesAsynchronously(forKeys: keys) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "playable", error: &error)

            switch status {
            case .loaded:
                let item = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: item)
                if let lastTime = annotatedFile.lastPlayedTime, lastTime > 0 {
                    let cmTime = CMTime(seconds: lastTime, preferredTimescale: 600)
                    player.seek(to: cmTime)
                    print("Resumed playback at \(formatTime(lastTime))")
                }
                player.play()
                isPlaying = true
                scheduleAutoHide()
                addPeriodicTimeObserver()
            case .failed:
                print("Video failed to load: \(error?.localizedDescription ?? "Unknown error")")
            case .cancelled:
                print("Video load was cancelled")
            default:
                print("Unexpected status: \(status.rawValue)")
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
        // periodically save the last time
        annotatedFile.lastPlayedTime = currentTime
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
    
    func addPoint(for label: String) {
        let timestamp = formatTime(currentTime)
        let annotation = VideoAnnotation(timestamp: timestamp, label: label)
        annotatedFile.annotations.append(annotation)

        if label == "Point Home" {
            annotatedFile.homeScore += 1
            annotatedFile.lastHomePointIndex = annotatedFile.annotations.count - 1
        } else if label == "Point Away" {
            annotatedFile.awayScore += 1
            annotatedFile.lastAwayPointIndex = annotatedFile.annotations.count - 1
        }

        MetadataManager.shared.saveAnnotatedFile(annotatedFile, for: videoURL)
        print("📍 Added annotation: \(timestamp) - \(label)")
        scheduleAutoHide()
    }

    func removeLastPoint(for label: String) {
        if label == "Point Home", let index = annotatedFile.lastHomePointIndex, index < annotatedFile.annotations.count {
            annotatedFile.annotations.remove(at: index)
            annotatedFile.homeScore = max(annotatedFile.homeScore - 1, 0)
            annotatedFile.lastHomePointIndex = annotatedFile.annotations.lastIndex(where: { $0.label == "Point Home" })
        } else if label == "Point Away", let index = annotatedFile.lastAwayPointIndex, index < annotatedFile.annotations.count {
            annotatedFile.annotations.remove(at: index)
            annotatedFile.awayScore = max(annotatedFile.awayScore - 1, 0)
            annotatedFile.lastAwayPointIndex = annotatedFile.annotations.lastIndex(where: { $0.label == "Point Away" })
        }

        MetadataManager.shared.saveAnnotatedFile(annotatedFile, for: videoURL)
        print("🗑️ Removed last \(label) annotation")
        scheduleAutoHide()
    }

}

struct ScoreBoxView: View {
    var teamName: String
    var score: Int
    var backgroundColor: Color
    var onTopTap: () -> Void
    var onBottomTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text(teamName)
                    .font(.caption)
                    .foregroundColor(.white)
                Text("\(score)")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
            }
            .frame(width: 80, height: 50)
            .background(backgroundColor)
            .onTapGesture {
                onTopTap()
            }

            Rectangle()
                .fill(backgroundColor.opacity(0.8))
                .frame(width: 80, height: 40)
                .onTapGesture {
                    onBottomTap()
                }
        }
        .cornerRadius(8)
    }
}
