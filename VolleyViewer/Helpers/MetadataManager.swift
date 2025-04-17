import Foundation

struct AnnotatedFile: Codable {
    var displayName: String
    var annotations: [VideoAnnotation]
}

struct VideoAnnotation: Identifiable, Codable {
    var id = UUID()
    var timestamp: String
    var label: String
}

class MetadataManager {
    static let shared = MetadataManager()
    let fileManager = FileManager.default
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    func metadataFileURL(for videoURL: URL) -> URL {
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let creationDate = (try? videoURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let timestamp = timestampFormatter.string(from: creationDate)
        return directory.appendingPathComponent("meta_\(timestamp).json")
    }

    func loadAnnotations(for videoURL: URL) -> [VideoAnnotation] {
        let fileURL = metadataFileURL(for: videoURL)
        guard let data = try? Data(contentsOf: fileURL),
              let container = try? JSONDecoder().decode(AnnotatedFile.self, from: data) else {
            return []
        }
        return container.annotations
    }

    func saveAnnotations(_ annotations: [VideoAnnotation], for videoURL: URL) {
        let fileURL = metadataFileURL(for: videoURL)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let displayName = baseName
            .replacingOccurrences(of: "meta_", with: "")
            .components(separatedBy: "__").last ?? baseName
        let container = AnnotatedFile(displayName: displayName, annotations: annotations)

        if let data = try? JSONEncoder().encode(container) {
            try? data.write(to: fileURL)
        }
    }

    func listAnnotationFiles() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.lastPathComponent.hasPrefix("meta_") && $0.pathExtension == "json" }
    }

    func loadDisplayName(from url: URL) -> String {
        guard let data = try? Data(contentsOf: url),
              let container = try? JSONDecoder().decode(AnnotatedFile.self, from: data) else {
            return url.deletingPathExtension().lastPathComponent
        }
        return container.displayName
    }
}
