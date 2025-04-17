// AnnotationBrowserView.swift (with CSV export, multi-selection, sort, delete, rename)
import SwiftUI

struct AnnotationBrowserView: View {
    @State private var files: [URL] = []
    @State private var selectedFile: URL? = nil
    @State private var selectedAnnotations: [VideoAnnotation] = []
    @State private var showDetail = false
    @State private var isSelecting = false
    @State private var selectedFiles: Set<URL> = []
    @State private var showShareSheet = false
    @State private var csvToExport: ExportableFile? = nil
    @State private var showRenamePrompt: URL? = nil
    @State private var newFilename: String = ""

    var body: some View {
        NavigationView {
            let _ = (selectedFile, selectedAnnotations)
            VStack {
                List(selection: $selectedFiles) {
                    ForEach(files, id: \.self) { file in
                        HStack {
                            if isSelecting {
                                Image(systemName: selectedFiles.contains(file) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedFiles.contains(file) ? .blue : .gray)
                                    .onTapGesture {
                                        toggleSelection(for: file)
                                    }
                            }

                            Button(action: {
                                if isSelecting {
                                    toggleSelection(for: file)
                                } else {
                                    loadAnnotations(from: file)
                                }
                            }) {
                                Text(MetadataManager.shared.loadDisplayName(from: file))
                                    .foregroundColor(.primary)
                            }
                            .contextMenu {
                                Button("Export to CSV") {
                                    exportAnnotationsToCSV(for: file)
                                }
                                Button("Rename") {
                                    showRenamePrompt = file
                                    newFilename = MetadataManager.shared.loadDisplayName(from: file)
                                }
                                Button("Delete", role: .destructive) {
                                    deleteFile(file)
                                }
                            }
                        }
                    }
                }

                if isSelecting {
                    HStack(spacing: 20) {
                        Button("Select All") {
                            selectedFiles = Set(files)
                        }
                        Button("Deselect All") {
                            selectedFiles.removeAll()
                        }
                        Button("Delete Selected", role: .destructive) {
                            selectedFiles.forEach(deleteFile)
                            selectedFiles.removeAll()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Annotations")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isSelecting ? "Cancel" : "Select") {
                        isSelecting.toggle()
                        selectedFiles.removeAll()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSelecting && !selectedFiles.isEmpty {
                        Button("Export CSV") {
                            exportMultipleFilesAsCSV()
                        }
                    }
                }
            }
            .onAppear {
                reloadFiles()
            }

            if !selectedAnnotations.isEmpty {
                VStack {
                    List(selectedAnnotations) { annotation in
                        HStack {
                            Text(annotation.timestamp)
                            Spacer()
                            Text(annotation.label)
                        }
                    }

                    Button("Export to CSV") {
                        if let file = selectedFile {
                            exportAnnotationsToCSV(for: file)
                        }
                    }
                    .padding()
                }
                .navigationTitle(selectedFile?.lastPathComponent ?? "Details")
            } else {
                Text("Select a file to view annotations")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .sheet(isPresented: $showDetail) {
            NavigationView {
                List(selectedAnnotations) { annotation in
                    HStack {
                        Text(annotation.timestamp)
                        Spacer()
                        Text(annotation.label)
                    }
                }
                .navigationTitle(selectedFile?.lastPathComponent ?? "Annotations")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showDetail = false
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Export to CSV") {
                            if let file = selectedFile {
                                exportAnnotationsToCSV(for: file)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $csvToExport) { file in
            ShareSheet(activityItems: [file.url])
        }
    }

    func loadAnnotations(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let container = try? JSONDecoder().decode(AnnotatedFile.self, from: data) else {
            selectedAnnotations = []
            return
        }

        selectedFile = url
        selectedAnnotations = container.annotations
        showDetail = true
    }


    func exportAnnotationsToCSV(for url: URL) {
        guard let data = try? Data(contentsOf: url),
              let annotations = try? JSONDecoder().decode([VideoAnnotation].self, from: data) else { return }

        let csvString = annotations.map { "\($0.timestamp),\($0.label)" }.joined(separator: "\n")
        saveCSV(csvString, filename: url.lastPathComponent.replacingOccurrences(of: ".json", with: ".csv"))
    }

    func exportMultipleFilesAsCSV() {
        let allCSV: String = selectedFiles.compactMap { file in
            guard let data = try? Data(contentsOf: file),
                  let annotations = try? JSONDecoder().decode([VideoAnnotation].self, from: data) else { return nil }

            let name = file.lastPathComponent
            let entries = annotations.map { "\($0.timestamp),\($0.label)" }.joined(separator: "\n")
            return "# \(name)\n\(entries)"
        }.joined(separator: "\n\n")

        saveCSV(allCSV, filename: "ExportedAnnotations.csv")
    }

    func saveCSV(_ content: String, filename: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            csvToExport = ExportableFile(url: fileURL)
        } catch {
            print("❌ Failed to write CSV: \(error)")
        }
    }

    func toggleSelection(for file: URL) {
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
        }
    }

    func deleteFile(_ file: URL) {
        try? FileManager.default.removeItem(at: file)
        if selectedFile == file {
            selectedFile = nil
            selectedAnnotations = []
        }
        reloadFiles()
    }

    func reloadFiles() {
        let unsorted = MetadataManager.shared.listAnnotationFiles()
        files = unsorted.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
    }
}

struct ExportableFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
