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
}
