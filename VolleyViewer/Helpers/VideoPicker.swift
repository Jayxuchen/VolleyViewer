import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var url: URL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .videos
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let firstResult = results.first else {
                print("⚠️ No result from picker")
                return
            }

            guard let assetId = firstResult.assetIdentifier else {
                print("❌ Could not get asset identifier from result")
                return
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            guard let asset = fetchResult.firstObject else {
                print("❌ Could not fetch PHAsset from identifier")
                return
            }

            // Find the actual video resource
            let resources = PHAssetResource.assetResources(for: asset)
            guard let videoResource = resources.first(where: { $0.type == .video }) else {
                print("❌ No video resource found in PHAsset")
                return
            }

            // Target path
            let filename = UUID().uuidString + ".mov"
            let targetURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            print("📦 Starting video request from Photos (iCloud download if needed)...")

            PHAssetResourceManager.default().writeData(for: videoResource, toFile: targetURL, options: nil) { error in
                if let error = error {
                    print("❌ Failed to write video data: \(error.localizedDescription)")
                    return
                }

                print("✅ Video successfully written to: \(targetURL)")
                DispatchQueue.main.async {
                    self.parent.url = targetURL
                }
            }
        }
    }
}
