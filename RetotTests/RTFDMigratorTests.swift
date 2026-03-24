import AppKit
import XCTest
@testable import Retot

final class RTFDMigratorTests: XCTestCase {
    private var storage: StorageManager!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetotMigratorTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = StorageManager(baseDirectory: tempDir)
        storage.ensureDirectoryStructure()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Skip Existing JSON

    func testMigrationSkipsExistingJSON() {
        // Save a JSON note first
        let content = NSAttributedString(
            string: "Already migrated",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        storage.saveNoteContent(content, for: 1)

        // Also create an RTFD file with different content
        let rtfdContent = NSAttributedString(
            string: "Old RTFD content",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        let rtfdURL = storage.rtfdURLForMigration(for: 1)
        do {
            let wrapper = try rtfdContent.fileWrapper(
                from: NSRange(location: 0, length: rtfdContent.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            try wrapper.write(to: rtfdURL, options: .atomic, originalContentsURL: nil)
        } catch {
            XCTFail("Failed to create test RTFD: \(error)")
            return
        }

        // Run migration - should skip since JSON exists
        let migrated = RTFDMigrator.migrateIfNeeded(storage: storage, noteIds: [1])
        XCTAssertEqual(migrated, 0, "Should not migrate when JSON already exists")

        // Verify original JSON content is preserved (not overwritten)
        let loaded = storage.loadNoteContent(for: 1)
        XCTAssertTrue(loaded.string.contains("Already migrated"),
                       "Original JSON content should be preserved")
    }

    // MARK: - Migration Count

    func testMigrationCountsCorrectly() {
        // Create RTFD files for notes 1, 2, 3
        for id in 1...3 {
            let content = NSAttributedString(
                string: "Legacy note \(id)",
                attributes: [.font: NSFont.systemFont(ofSize: 14)]
            )
            let rtfdURL = storage.rtfdURLForMigration(for: id)
            do {
                let wrapper = try content.fileWrapper(
                    from: NSRange(location: 0, length: content.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
                )
                try wrapper.write(to: rtfdURL, options: .atomic, originalContentsURL: nil)
            } catch {
                XCTFail("Failed to create test RTFD for note \(id): \(error)")
                return
            }
        }

        // Pre-create JSON for note 2 (should be skipped)
        storage.saveNoteContent(
            NSAttributedString(string: "Existing JSON for 2", attributes: [.font: NSFont.systemFont(ofSize: 14)]),
            for: 2
        )

        // Migrate notes 1-3 (note 2 already has JSON)
        let migrated = RTFDMigrator.migrateIfNeeded(storage: storage, noteIds: [1, 2, 3])
        XCTAssertEqual(migrated, 2, "Should migrate 2 notes (notes 1 and 3)")

        // Verify all three notes are now loadable
        for id in 1...3 {
            let loaded = storage.loadNoteContent(for: id)
            XCTAssertGreaterThan(loaded.length, 0, "Note \(id) should have content after migration")
        }
    }

    // MARK: - Empty Notes

    func testMigrationHandlesEmptyNotes() {
        // Note IDs with no RTFD or HTML files at all
        let migrated = RTFDMigrator.migrateIfNeeded(storage: storage, noteIds: [90, 91, 92])
        XCTAssertEqual(migrated, 0, "Should migrate 0 notes when no legacy files exist")

        // Verify no JSON files were created
        for id in [90, 91, 92] {
            let jsonURL = storage.jsonURLForMigration(for: id)
            XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path),
                           "No JSON should be created for empty legacy notes")
        }
    }
}
