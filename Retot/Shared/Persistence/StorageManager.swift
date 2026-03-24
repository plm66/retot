#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation

final class StorageManager {
    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let notesDirectory: URL
    private let metadataURL: URL

    init(baseDirectory: URL? = nil) {
        let base = baseDirectory ?? StorageConstants.activeDirectory
        self.baseDirectory = base
        self.notesDirectory = base.appendingPathComponent("notes", isDirectory: true)
        self.metadataURL = base.appendingPathComponent("metadata.json")
    }

    // MARK: - File Coordination (iCloud safety)

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        if StorageConstants.isICloudAvailable {
            var coordinatorError: NSError?
            var writeError: Error?
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { newURL in
                do {
                    try data.write(to: newURL, options: .atomic)
                } catch {
                    writeError = error
                }
            }
            if let coordinatorError = coordinatorError {
                throw coordinatorError
            }
            if let writeError = writeError {
                throw writeError
            }
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    private func coordinatedRead(from url: URL) throws -> Data {
        if StorageConstants.isICloudAvailable {
            var coordinatorError: NSError?
            var result: Result<Data, Error>?
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { newURL in
                do {
                    result = .success(try Data(contentsOf: newURL))
                } catch {
                    result = .failure(error)
                }
            }
            if let coordinatorError = coordinatorError {
                throw coordinatorError
            }
            switch result {
            case .success(let data):
                return data
            case .failure(let error):
                throw error
            case .none:
                throw NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "File coordination returned no result"])
            }
        } else {
            return try Data(contentsOf: url)
        }
    }

    func ensureDirectoryStructure() {
        do {
            try fileManager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: notesDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            print("Failed to create directory structure: \(error)")
        }
    }

    // MARK: - Metadata

    func saveMetadata(_ notes: [Note]) {
        let metadata = notes.map(NoteMetadata.from)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(metadata)
            try coordinatedWrite(data, to: metadataURL)
        } catch {
            print("Failed to save metadata: \(error)")
        }
    }

    func loadMetadata() -> [Note] {
        let url = metadataURL
        guard fileManager.fileExists(atPath: url.path) else {
            return Note.defaults()
        }
        do {
            let data = try coordinatedRead(from: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode([NoteMetadata].self, from: data)
            return metadata.map { $0.toNote() }
        } catch {
            print("Failed to load metadata: \(error)")
            return Note.defaults()
        }
    }

    // MARK: - Path Helpers (JSON format)

    private func jsonURL(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("note-\(id).json")
    }

    private func imagesDirectory(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent("note-\(id)", isDirectory: true)
    }

    // MARK: - Crash Recovery

    private func recoveryURL(for id: Int) -> URL {
        baseDirectory.appendingPathComponent(".recovery-\(id).json")
    }

    func writeRecoveryFile(_ attributedString: NSAttributedString, for id: Int) {
        let url = recoveryURL(for: id)
        guard attributedString.length > 0 else {
            try? fileManager.removeItem(at: url)
            return
        }
        #if os(macOS)
        do {
            let document = DocumentSerializer.serialize(attributedString)
            let jsonData = try DocumentSerializer.encode(document)
            try jsonData.write(to: url, options: .atomic)
        } catch {
            // Recovery write failure is non-fatal
        }
        #endif
    }

    func removeRecoveryFile(for id: Int) {
        let jsonRecovery = recoveryURL(for: id)
        try? fileManager.removeItem(at: jsonRecovery)
        // Also clean up legacy RTFD recovery files
        let legacyRecovery = baseDirectory.appendingPathComponent(".recovery-\(id).rtfd")
        try? fileManager.removeItem(at: legacyRecovery)
    }

    func removeAllRecoveryFiles() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in contents where url.lastPathComponent.hasPrefix(".recovery-") {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Returns (noteId, recoveredContent) pairs for any recovery files newer than their saved counterparts.
    func checkForRecoveryFiles(noteIds: [Int]) -> [(id: Int, content: NSAttributedString)] {
        var recovered: [(id: Int, content: NSAttributedString)] = []
        for id in noteIds {
            let recURL = recoveryURL(for: id)
            guard fileManager.fileExists(atPath: recURL.path) else { continue }

            // Compare modification dates against JSON (primary) or RTFD (legacy)
            let savedURL = jsonURL(for: id)
            let recAttrs = try? fileManager.attributesOfItem(atPath: recURL.path)
            let savedAttrs = try? fileManager.attributesOfItem(atPath: savedURL.path)

            let recDate = recAttrs?[.modificationDate] as? Date ?? .distantPast
            let savedDate = savedAttrs?[.modificationDate] as? Date ?? .distantPast

            guard recDate > savedDate else {
                // Recovery file is older; clean it up
                try? fileManager.removeItem(at: recURL)
                continue
            }

            // Load recovery content from JSON
            do {
                let jsonData = try Data(contentsOf: recURL)
                var document = try DocumentSerializer.decode(from: jsonData)
                document = loadImagesIntoDocument(document, for: id)
                let content = DocumentSerializer.deserialize(document)
                if content.length > 0 {
                    recovered.append((id: id, content: content))
                }
            } catch {
                try? fileManager.removeItem(at: recURL)
            }
        }
        return recovered
    }

    // MARK: - Versioning

    private var versionsDirectory: URL {
        baseDirectory.appendingPathComponent("versions", isDirectory: true)
    }

    private func noteVersionsDirectory(for id: Int) -> URL {
        versionsDirectory.appendingPathComponent("note-\(id)", isDirectory: true)
    }

    func rotateVersions(for id: Int) {
        let dir = noteVersionsDirectory(for: id)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return
        }

        let maxVersions = 5

        // Delete oldest versions (both JSON and legacy RTFD)
        let oldestJSON = dir.appendingPathComponent("v\(maxVersions).json")
        let oldestRTFD = dir.appendingPathComponent("v\(maxVersions).rtfd")
        try? fileManager.removeItem(at: oldestJSON)
        try? fileManager.removeItem(at: oldestRTFD)

        // Shift versions: v4->v5, v3->v4, v2->v3, v1->v2
        for i in stride(from: maxVersions - 1, through: 1, by: -1) {
            // Shift JSON versions
            let srcJSON = dir.appendingPathComponent("v\(i).json")
            let dstJSON = dir.appendingPathComponent("v\(i + 1).json")
            if fileManager.fileExists(atPath: srcJSON.path) {
                try? fileManager.moveItem(at: srcJSON, to: dstJSON)
            }
            // Shift legacy RTFD versions
            let srcRTFD = dir.appendingPathComponent("v\(i).rtfd")
            let dstRTFD = dir.appendingPathComponent("v\(i + 1).rtfd")
            if fileManager.fileExists(atPath: srcRTFD.path) {
                try? fileManager.moveItem(at: srcRTFD, to: dstRTFD)
            }
        }

        // Copy current saved note to v1 (JSON format)
        let currentFile = jsonURL(for: id)
        let v1 = dir.appendingPathComponent("v1.json")
        if fileManager.fileExists(atPath: currentFile.path) {
            try? fileManager.copyItem(at: currentFile, to: v1)
        }
    }

    // MARK: - Note Content (JSON with RTFD/HTML fallback)

    func saveNoteContent(_ attributedString: NSAttributedString, for id: Int) {
        let url = jsonURL(for: id)
        guard attributedString.length > 0 else {
            // Remove JSON file for empty notes (keep RTFD/HTML as backup)
            try? fileManager.removeItem(at: url)
            return
        }

        // Rotate previous version before overwriting
        rotateVersions(for: id)

        do {
            #if os(macOS)
            let document = DocumentSerializer.serialize(attributedString)
            #else
            // iOS: basic serialization — create a simple paragraph document
            let document = NoteDocument(elements: [
                .paragraph(Paragraph(runs: [
                    TextRun(text: attributedString.string, attributes: TextAttributes())
                ]))
            ])
            #endif

            // Save images to disk
            let imgDir = imagesDirectory(for: id)
            if !document.images.isEmpty {
                try fileManager.createDirectory(at: imgDir, withIntermediateDirectories: true)
            }
            for imageRef in document.images {
                if let data = imageRef.data {
                    let imageFileURL = imgDir.appendingPathComponent(imageRef.filename)
                    try coordinatedWrite(data, to: imageFileURL)
                }
            }

            // Strip binary data from image references before writing JSON
            let strippedImages = document.images.map { ref in
                ImageReference(id: ref.id, filename: ref.filename, data: nil)
            }
            let strippedDocument = NoteDocument(
                version: document.version,
                elements: document.elements,
                images: strippedImages
            )

            let jsonData = try DocumentSerializer.encode(strippedDocument)
            try coordinatedWrite(jsonData, to: url)

            // Clean up recovery file after successful save
            removeRecoveryFile(for: id)
        } catch {
            print("Failed to save note \(id) as JSON: \(error)")
        }
    }

    #if os(macOS)
    /// Replace hardcoded black/white text colors with the system dynamic color.
    /// This ensures text stays readable when switching between Light and Dark mode.
    private static func replaceDefaultTextColors(in attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            guard let color = value as? NSColor else {
                // No explicit color -> set to system textColor
                mutable.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
                return
            }
            // Convert to sRGB to compare
            guard let rgb = color.usingColorSpace(.sRGB) else { return }
            let brightness = rgb.redComponent * 0.299 + rgb.greenComponent * 0.587 + rgb.blueComponent * 0.114

            // Replace near-black or near-white (default text colors) with dynamic textColor
            if brightness < 0.1 || brightness > 0.9 {
                mutable.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
            }
        }

        return NSAttributedString(attributedString: mutable)
    }
    #endif

    private func rtfdURL(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("note-\(id).rtfd")
    }

    private func htmlURL(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("note-\(id).html")
    }

    // MARK: - Migration Helpers (internal access for RTFDMigrator)

    func jsonURLForMigration(for id: Int) -> URL {
        jsonURL(for: id)
    }

    func rtfdURLForMigration(for id: Int) -> URL {
        rtfdURL(for: id)
    }

    func htmlURLForMigration(for id: Int) -> URL {
        htmlURL(for: id)
    }

    /// Load image data from disk into a NoteDocument's image references.
    private func loadImagesIntoDocument(_ document: NoteDocument, for id: Int) -> NoteDocument {
        let imgDir = imagesDirectory(for: id)
        let enrichedImages = document.images.map { ref -> ImageReference in
            if ref.data != nil { return ref }
            let imageFileURL = imgDir.appendingPathComponent(ref.filename)
            let data = try? Data(contentsOf: imageFileURL)
            return ImageReference(id: ref.id, filename: ref.filename, data: data)
        }
        return NoteDocument(
            version: document.version,
            elements: document.elements,
            images: enrichedImages
        )
    }

    func loadNoteContent(for id: Int) -> NSAttributedString {
        // Try JSON first (new format, cross-platform)
        let jsonPath = jsonURL(for: id)
        if fileManager.fileExists(atPath: jsonPath.path) {
            do {
                let jsonData = try coordinatedRead(from: jsonPath)
                var document = try DocumentSerializer.decode(from: jsonData)
                document = loadImagesIntoDocument(document, for: id)
                let attributedString = DocumentSerializer.deserialize(document)
                #if os(macOS)
                return Self.replaceDefaultTextColors(in: attributedString)
                #else
                return attributedString
                #endif
            } catch {
                print("Failed to load JSON for note \(id): \(error)")
            }
        }

        #if os(macOS)
        // Fallback to RTFD (legacy format, macOS only)
        let rtfdPath = rtfdURL(for: id)
        if fileManager.fileExists(atPath: rtfdPath.path) {
            do {
                let attributedString = try NSAttributedString(
                    url: rtfdPath,
                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil
                )
                return Self.replaceDefaultTextColors(in: attributedString)
            } catch {
                print("Failed to load RTFD for note \(id): \(error)")
            }
        }

        // Fallback to HTML (oldest legacy format, macOS only)
        let htmlPath = htmlURL(for: id)
        guard fileManager.fileExists(atPath: htmlPath.path) else {
            return NSAttributedString(string: "")
        }
        do {
            let data = try Data(contentsOf: htmlPath)
            guard !data.isEmpty else {
                return NSAttributedString(string: "")
            }
            let attributedString = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            return Self.replaceDefaultTextColors(in: attributedString)
        } catch {
            print("Failed to load HTML for note \(id): \(error)")
            return NSAttributedString(string: "")
        }
        #else
        // iOS: no legacy formats to fall back to
        return NSAttributedString(string: "")
        #endif
    }
}
