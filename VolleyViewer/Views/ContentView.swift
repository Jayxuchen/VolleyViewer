import SwiftUI

struct ContentView: View {
    @State private var videoURL: URL? = nil
    @State private var showPicker = false
    @State private var showPlayer = false
    @State private var showAnnotationBrowser = false  // ✅ New

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
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
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                Button(action: {
                    showAnnotationBrowser = true
                }) {
                    Text("View Annotations")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showPicker) {
            VideoPicker(url: $videoURL)
        }
        .sheet(isPresented: $showAnnotationBrowser) {
            AnnotationBrowserView()
        }
        .onChange(of: videoURL) { newValue in
            if let url = newValue {
                print("🎞 videoURL set: \(url)")
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
