import AppKit
import Foundation

final class StorageManager {
    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let notesDirectory: URL
    private let metadataURL: URL

    init(baseDirectory: URL? = nil) {
        let base = baseDirectory ?? StorageConstants.appSupportDirectory
        self.baseDirectory = base
        self.notesDirectory = base.appendingPathComponent("notes", isDirectory: true)
        self.metadataURL = base.appendingPathComponent("metadata.json")
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
            try data.write(to: metadataURL, options: .atomic)
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
        let url = noteURL(for: id)
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

    /// Replace hardcoded black/white text colors with the system dynamic color.
    /// This ensures text stays readable when switching between Light and Dark mode.
    private static func replaceDefaultTextColors(in attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            guard let color = value as? NSColor else {
                // No explicit color → set to system textColor
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

    private func noteURL(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("note-\(id).html")
    }

    func loadNoteContent(for id: Int) -> NSAttributedString {
        let url = noteURL(for: id)
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
            return Self.replaceDefaultTextColors(in: attributedString)
        } catch {
            print("Failed to load note \(id): \(error)")
            return NSAttributedString(string: "")
        }
    }
}
