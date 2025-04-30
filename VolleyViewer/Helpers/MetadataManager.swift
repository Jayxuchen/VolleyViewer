// MetadataManager.swift 
import Foundation

struct AnnotatedFile: Codable {
    var displayName: String
    var annotations: [VideoAnnotation]
    var homeScore: Int
    var awayScore: Int
    var lastHomePointIndex: Int?
    var lastAwayPointIndex: Int?
    var lastPlayedTime: Double?
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
        timestampFormatter.dateFormat = "yyyy-MM-dd_HH:mm"
        let creationDate = (try? videoURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        let timestamp = timestampFormatter.string(from: creationDate)
        return directory.appendingPathComponent("meta_\(timestamp).json")
    }

    func loadAnnotatedFile(for videoURL: URL) -> AnnotatedFile? {
        let fileURL = metadataFileURL(for: videoURL)
        guard let data = try? Data(contentsOf: fileURL),
              let container = try? JSONDecoder().decode(AnnotatedFile.self, from: data) else {
            return nil
        }
        return container
    }

    func saveAnnotatedFile(_ file: AnnotatedFile, for videoURL: URL) {
        let fileURL = metadataFileURL(for: videoURL)

        var fileToSave = file
        if fileToSave.displayName.isEmpty {
            // Set display name to match timestamp if missing
            let timestampFormatter = DateFormatter()
            timestampFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let creationDate = (try? videoURL.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            fileToSave.displayName = timestampFormatter.string(from: creationDate)
        }

        do {
            let data = try JSONEncoder().encode(fileToSave)
            try data.write(to: fileURL)
            print("Saved annotated file to \(fileURL.lastPathComponent)")
        } catch {
            print("Failed to save annotated file: \(error.localizedDescription)")
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
