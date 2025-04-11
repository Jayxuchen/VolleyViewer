import SwiftUI
import AVFoundation

class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

struct VideoPlayerContainer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        let playerView = PlayerView()
        playerView.player = player
        playerView.playerLayer.videoGravity = .resizeAspect
        playerView.translatesAutoresizingMaskIntoConstraints = false

        controller.view.addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: controller.view.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
        ])

        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
