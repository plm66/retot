#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation

/// One-time migration tool that converts legacy RTFD/HTML notes to JSON format.
/// Original RTFD files are kept as backup and never deleted.
enum RTFDMigrator {

    /// Migrates all RTFD/HTML notes to JSON format. Returns count of migrated notes.
    /// Original RTFD/HTML files are kept as backup.
    @discardableResult
    static func migrateIfNeeded(storage: StorageManager, noteIds: [Int]) -> Int {
        var migrated = 0
        for id in noteIds {
            if migrateNote(id: id, storage: storage) {
                migrated += 1
            }
        }
        return migrated
    }

    /// Migrate a single note. Returns true if migration was performed.
    private static func migrateNote(id: Int, storage: StorageManager) -> Bool {
        let fileManager = FileManager.default
        let jsonURL = storage.jsonURLForMigration(for: id)

        // Skip if JSON already exists
        guard !fileManager.fileExists(atPath: jsonURL.path) else {
            return false
        }

        // Load content from legacy formats (RTFD or HTML)
        let content = loadLegacyContent(for: id, storage: storage)
        guard content.length > 0 else {
            return false
        }

        // Save as JSON (this uses the new saveNoteContent which writes JSON)
        storage.saveNoteContent(content, for: id)

        return fileManager.fileExists(atPath: jsonURL.path)
    }

    /// Load content from legacy RTFD or HTML formats.
    private static func loadLegacyContent(for id: Int, storage: StorageManager) -> NSAttributedString {
        let fileManager = FileManager.default

        #if os(macOS)
        // Try RTFD first
        let rtfdURL = storage.rtfdURLForMigration(for: id)
        if fileManager.fileExists(atPath: rtfdURL.path) {
            do {
                return try NSAttributedString(
                    url: rtfdURL,
                    options: [.documentType: NSAttributedString.DocumentType.rtfd],
                    documentAttributes: nil
                )
            } catch {
                print("RTFDMigrator: Failed to load RTFD for note \(id): \(error)")
            }
        }

        // Try HTML fallback
        let htmlURL = storage.htmlURLForMigration(for: id)
        if fileManager.fileExists(atPath: htmlURL.path) {
            do {
                let data = try Data(contentsOf: htmlURL)
                guard !data.isEmpty else { return NSAttributedString(string: "") }
                return try NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                )
            } catch {
                print("RTFDMigrator: Failed to load HTML for note \(id): \(error)")
            }
        }
        #endif

        return NSAttributedString(string: "")
    }
}
