import AppKit
import XCTest
@testable import Retot

final class StorageManagerTests: XCTestCase {
    private var storage: StorageManager!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        // Use a temp directory to avoid polluting real app storage
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetotTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = StorageManager(baseDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Directory Structure

    func testEnsureDirectoryStructureCreatesDirectories() {
        storage.ensureDirectoryStructure()

        let notesDir = tempDir.appendingPathComponent("notes", isDirectory: true)

        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: notesDir.path))
    }

    // MARK: - Metadata

    func testSaveAndLoadMetadataRoundTrip() {
        storage.ensureDirectoryStructure()
        let notes = Note.defaults()

        storage.saveMetadata(notes)
        let loaded = storage.loadMetadata()

        XCTAssertEqual(loaded.count, 10)
        XCTAssertEqual(loaded.first?.id, 1)
        XCTAssertEqual(loaded.first?.label, "Note 1")
        XCTAssertEqual(loaded.first?.color, .red)
        XCTAssertEqual(loaded.last?.id, 10)
    }

    func testLoadMetadataReturnsDefaultsWhenNoFile() {
        // Don't save anything — should return defaults
        let loaded = storage.loadMetadata()
        XCTAssertEqual(loaded.count, 10)
    }

    func testSaveMetadataWithCustomLabels() {
        storage.ensureDirectoryStructure()
        var notes = Note.defaults()
        notes[0] = notes[0].withLabel("Shopping")
        notes[1] = notes[1].withColor(.purple)

        storage.saveMetadata(notes)
        let loaded = storage.loadMetadata()

        XCTAssertEqual(loaded[0].label, "Shopping")
        XCTAssertEqual(loaded[1].color, .purple)
    }

    // MARK: - Note Content (HTML)

    func testSaveAndLoadNoteContent() {
        storage.ensureDirectoryStructure()

        let original = NSAttributedString(
            string: "Hello, Retot!",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )

        storage.saveNoteContent(original, for: 1)
        let loaded = storage.loadNoteContent(for: 1)

        XCTAssertEqual(loaded.string.trimmingCharacters(in: .whitespacesAndNewlines), "Hello, Retot!")
    }

    func testLoadNonExistentNoteReturnsEmpty() {
        storage.ensureDirectoryStructure()
        let loaded = storage.loadNoteContent(for: 99)
        XCTAssertEqual(loaded.string, "")
    }

    func testSaveAndLoadRichTextWithBold() {
        storage.ensureDirectoryStructure()

        let fontManager = NSFontManager.shared
        let boldFont = fontManager.convert(
            NSFont.systemFont(ofSize: 14),
            toHaveTrait: .boldFontMask
        )
        let original = NSAttributedString(
            string: "Bold text",
            attributes: [.font: boldFont]
        )

        storage.saveNoteContent(original, for: 2)
        let loaded = storage.loadNoteContent(for: 2)

        XCTAssertEqual(loaded.string.trimmingCharacters(in: .whitespacesAndNewlines), "Bold text")
        let loadedFont = loaded.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(loadedFont)
        XCTAssertTrue(loadedFont?.fontDescriptor.symbolicTraits.contains(.bold) ?? false)
    }

    func testOverwriteExistingNote() {
        storage.ensureDirectoryStructure()

        let first = NSAttributedString(string: "First version")
        storage.saveNoteContent(first, for: 3)

        let second = NSAttributedString(string: "Second version")
        storage.saveNoteContent(second, for: 3)

        let loaded = storage.loadNoteContent(for: 3)
        XCTAssertEqual(loaded.string.trimmingCharacters(in: .whitespacesAndNewlines), "Second version")
    }

    func testMultipleNotesIndependent() {
        storage.ensureDirectoryStructure()

        storage.saveNoteContent(NSAttributedString(string: "Note A"), for: 1)
        storage.saveNoteContent(NSAttributedString(string: "Note B"), for: 2)

        XCTAssertEqual(storage.loadNoteContent(for: 1).string.trimmingCharacters(in: .whitespacesAndNewlines), "Note A")
        XCTAssertEqual(storage.loadNoteContent(for: 2).string.trimmingCharacters(in: .whitespacesAndNewlines), "Note B")
    }

    // MARK: - JSON Format

    func testSaveAndLoadNoteAsJSON() {
        storage.ensureDirectoryStructure()

        let boldFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 14),
            toHaveTrait: .boldFontMask
        )

        let original = NSMutableAttributedString()
        original.append(NSAttributedString(
            string: "Bold heading",
            attributes: [.font: boldFont]
        ))
        original.append(NSAttributedString(
            string: "\nRegular body text\n",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))

        storage.saveNoteContent(original, for: 42)

        // Verify JSON file exists
        let jsonURL = storage.jsonURLForMigration(for: 42)
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path), "JSON file should exist after save")

        // Load it back
        let loaded = storage.loadNoteContent(for: 42)

        // Verify text content
        XCTAssertTrue(loaded.string.contains("Bold heading"))
        XCTAssertTrue(loaded.string.contains("Regular body text"))

        // Verify bold attribute survived
        let loadedFont = loaded.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(loadedFont)
        let traits = NSFontManager.shared.traits(of: loadedFont!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    func testSaveEmptyNoteRemovesJSON() {
        storage.ensureDirectoryStructure()

        // Save non-empty first
        storage.saveNoteContent(NSAttributedString(string: "Content"), for: 50)
        let jsonURL = storage.jsonURLForMigration(for: 50)
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path))

        // Save empty -> should remove JSON
        storage.saveNoteContent(NSAttributedString(string: ""), for: 50)
        XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path))
    }

    func testJSONSaveWithImage() {
        storage.ensureDirectoryStructure()

        // Create a small test image
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 10, height: 10)).fill()
        image.unlockFocus()

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)

        let original = NSMutableAttributedString(attachment: attachment)
        original.append(NSAttributedString(string: "\nSome text\n"))

        storage.saveNoteContent(original, for: 60)

        // Verify images directory was created
        let imgDir = tempDir
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent("note-60", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imgDir.path), "Images directory should exist")

        // Verify at least one image file was written
        let imageFiles = try? FileManager.default.contentsOfDirectory(at: imgDir, includingPropertiesForKeys: nil)
        XCTAssertNotNil(imageFiles)
        XCTAssertFalse(imageFiles?.isEmpty ?? true, "Should have at least one image file")

        // Load it back and verify image is present
        let loaded = storage.loadNoteContent(for: 60)
        let loadedAttachment = loaded.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        XCTAssertNotNil(loadedAttachment, "Image attachment should be present after load")
        XCTAssertNotNil(loadedAttachment?.image, "Image data should be loaded")
    }

    // MARK: - RTFD Migration

    func testRTFDMigration() {
        storage.ensureDirectoryStructure()

        // Manually create an RTFD file (simulating old format)
        let content = NSAttributedString(
            string: "Legacy RTFD content",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        let rtfdURL = storage.rtfdURLForMigration(for: 70)
        do {
            let wrapper = try content.fileWrapper(
                from: NSRange(location: 0, length: content.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            try wrapper.write(to: rtfdURL, options: .atomic, originalContentsURL: nil)
        } catch {
            XCTFail("Failed to create test RTFD: \(error)")
            return
        }

        // Verify no JSON exists yet
        let jsonURL = storage.jsonURLForMigration(for: 70)
        XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path))

        // Run migration
        let migrated = RTFDMigrator.migrateIfNeeded(storage: storage, noteIds: [70])
        XCTAssertEqual(migrated, 1)

        // Verify JSON was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path), "JSON should exist after migration")

        // Verify RTFD was NOT deleted
        XCTAssertTrue(FileManager.default.fileExists(atPath: rtfdURL.path), "RTFD should still exist as backup")

        // Verify content loads correctly
        let loaded = storage.loadNoteContent(for: 70)
        XCTAssertTrue(loaded.string.contains("Legacy RTFD content"))

        // Run migration again -- should skip (already migrated)
        let migratedAgain = RTFDMigrator.migrateIfNeeded(storage: storage, noteIds: [70])
        XCTAssertEqual(migratedAgain, 0, "Should not re-migrate already migrated notes")
    }

    // MARK: - Custom Directory Storage

    func testCustomDirectoryStorage() {
        // Create a separate custom directory
        let customDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetotCustom-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: customDir) }

        let customStorage = StorageManager(baseDirectory: customDir)
        customStorage.ensureDirectoryStructure()

        let content = NSAttributedString(
            string: "Custom dir note",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        customStorage.saveNoteContent(content, for: 1)

        // Verify file was written to custom path
        let jsonURL = customStorage.jsonURLForMigration(for: 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path),
                       "Note should be saved in custom directory")

        // Verify content loads back
        let loaded = customStorage.loadNoteContent(for: 1)
        XCTAssertTrue(loaded.string.contains("Custom dir note"))
    }

    func testCustomDirectoryFallback() {
        // When baseDirectory is nil, StorageManager uses StorageConstants.activeDirectory
        let defaultStorage = StorageManager(baseDirectory: nil)
        // baseDirectory should resolve to some valid path (not crash)
        XCTAssertFalse(defaultStorage.baseDirectory.path.isEmpty,
                        "Default storage should have a valid base directory")
    }

    func testSwitchStorageLocation() {
        storage.ensureDirectoryStructure()

        // Save notes in original location
        storage.saveNoteContent(NSAttributedString(string: "Note A"), for: 1)
        storage.saveNoteContent(NSAttributedString(string: "Note B"), for: 2)
        storage.saveMetadata(Note.defaults())

        // Create new destination
        let newDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetotSwitch-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: newDir) }

        let fm = FileManager.default
        let newNotesDir = newDir.appendingPathComponent("notes", isDirectory: true)
        try? fm.createDirectory(at: newNotesDir, withIntermediateDirectories: true)

        // Copy metadata
        let srcMeta = tempDir.appendingPathComponent("metadata.json")
        let dstMeta = newDir.appendingPathComponent("metadata.json")
        if fm.fileExists(atPath: srcMeta.path) {
            try? fm.copyItem(at: srcMeta, to: dstMeta)
        }

        // Copy notes
        let srcNotes = tempDir.appendingPathComponent("notes", isDirectory: true)
        if let files = try? fm.contentsOfDirectory(at: srcNotes, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for file in files {
                let dest = newNotesDir.appendingPathComponent(file.lastPathComponent)
                if !fm.fileExists(atPath: dest.path) {
                    try? fm.copyItem(at: file, to: dest)
                }
            }
        }

        // Create storage at new location and verify notes are accessible
        let newStorage = StorageManager(baseDirectory: newDir)
        let loadedA = newStorage.loadNoteContent(for: 1)
        let loadedB = newStorage.loadNoteContent(for: 2)
        XCTAssertTrue(loadedA.string.contains("Note A"), "Note A should be accessible after switch")
        XCTAssertTrue(loadedB.string.contains("Note B"), "Note B should be accessible after switch")

        // Verify metadata was copied
        let loadedMeta = newStorage.loadMetadata()
        XCTAssertEqual(loadedMeta.count, 10)
    }

    func testVersionRotationCreatesJSONVersions() {
        storage.ensureDirectoryStructure()

        // Save version 1
        storage.saveNoteContent(NSAttributedString(string: "Version 1"), for: 80)

        // Save version 2 (should rotate v1)
        storage.saveNoteContent(NSAttributedString(string: "Version 2"), for: 80)

        // Check that a version file was created as JSON
        let versionsDir = tempDir
            .appendingPathComponent("versions", isDirectory: true)
            .appendingPathComponent("note-80", isDirectory: true)
        let v1JSON = versionsDir.appendingPathComponent("v1.json")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: v1JSON.path),
            "Version file should be JSON format"
        )
    }
}
