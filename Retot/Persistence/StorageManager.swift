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

    // MARK: - Note Content (RTFD with HTML fallback)

    func saveNoteContent(_ attributedString: NSAttributedString, for id: Int) {
        let url = rtfdURL(for: id)
        guard attributedString.length > 0 else {
            // Remove both RTFD and legacy HTML for empty notes
            try? fileManager.removeItem(at: url)
            try? fileManager.removeItem(at: htmlURL(for: id))
            return
        }
        do {
            let wrapper = try attributedString.fileWrapper(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.rtfd
                ]
            )
            // Remove old RTFD bundle + legacy HTML
            try? fileManager.removeItem(at: url)
            try? fileManager.removeItem(at: htmlURL(for: id))
            try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
        } catch {
            print("Failed to save note \(id) as RTFD: \(error)")
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

    private func rtfdURL(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("note-\(id).rtfd")
    }

    private func htmlURL(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("note-\(id).html")
    }

    func loadNoteContent(for id: Int) -> NSAttributedString {
        // Try RTFD first (new format, supports images)
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

        // Fallback to HTML (old format, no images)
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
    }
}
