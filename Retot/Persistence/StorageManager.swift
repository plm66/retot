import AppKit
import Foundation

final class StorageManager {
    private let fileManager = FileManager.default

    func ensureDirectoryStructure() {
        do {
            try fileManager.createDirectory(
                at: StorageConstants.appSupportDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: StorageConstants.notesDirectory,
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
            try data.write(to: StorageConstants.metadataURL, options: .atomic)
        } catch {
            print("Failed to save metadata: \(error)")
        }
    }

    func loadMetadata() -> [Note] {
        let url = StorageConstants.metadataURL
        guard fileManager.fileExists(atPath: url.path) else {
            return Note.defaults()
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode([NoteMetadata].self, from: data)
            return metadata.map { $0.toNote() }
        } catch {
            print("Failed to load metadata: \(error)")
            return Note.defaults()
        }
    }

    // MARK: - Note Content (HTML)

    func saveNoteContent(_ attributedString: NSAttributedString, for id: Int) {
        let url = StorageConstants.noteURL(for: id)
        guard attributedString.length > 0 else {
            // Save empty file for empty notes
            try? Data().write(to: url, options: .atomic)
            return
        }
        do {
            let data = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
            )
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save note \(id): \(error)")
        }
    }

    func loadNoteContent(for id: Int) -> NSAttributedString {
        let url = StorageConstants.noteURL(for: id)
        guard fileManager.fileExists(atPath: url.path) else {
            return NSAttributedString(string: "")
        }
        do {
            let data = try Data(contentsOf: url)
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
            return attributedString
        } catch {
            print("Failed to load note \(id): \(error)")
            return NSAttributedString(string: "")
        }
    }
}
