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

    // MARK: - Note Content (RTFD)

    func saveNoteContent(_ attributedString: NSAttributedString, for id: Int) {
        let url = StorageConstants.noteURL(for: id)
        do {
            let wrapper = try attributedString.fileWrapper(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            // Write to temp location first, then replace atomically
            let tempURL = url.deletingLastPathComponent()
                .appendingPathComponent("note-\(id)-temp.rtfd", isDirectory: true)
            if fileManager.fileExists(atPath: tempURL.path) {
                try fileManager.removeItem(at: tempURL)
            }
            try wrapper.write(to: tempURL, options: .atomic, originalContentsURL: nil)
            // Replace original with temp
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: url)
            }
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
            let attributedString = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil
            )
            return attributedString
        } catch {
            print("Failed to load note \(id): \(error)")
            return NSAttributedString(string: "")
        }
    }
}
