import SwiftUI

struct ContentView: View {
    @State private var videoURL: URL? = nil
    @State private var showPicker = false
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Text("VolleyViewer")
                    .font(.largeTitle)
                    .bold()
                    .padding()

                Button(action: {
                    showPicker = true
                }) {
                    Text("Select a Video")
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showPicker) {
            VideoPicker(url: $videoURL)
        }
        .onChange(of: videoURL) { newValue in
            if let url = newValue {
                print("🎞 videoURL set: \(url)")

                // ⚠️ Delay slightly to avoid presenting fullscreen while sheet is active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showPlayer = true
                    print("🎬 showPlayer = true")
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer, onDismiss: {
            print("👋 Player dismissed")
            videoURL = nil
        }) {
            if let url = videoURL {
                CustomVideoPlayerView(videoURL: url, isPresentingPlayer: $showPlayer)
            }
        }
    }
}
