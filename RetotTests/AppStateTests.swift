import AppKit
import XCTest
@testable import Retot

final class AppStateTests: XCTestCase {

    // AppState init has side effects (timers, iCloud, etc.) but is safe to construct
    // in test environments. It uses the real StorageConstants.activeDirectory.
    // We test behavioral correctness of note operations, not storage paths.

    // MARK: - Note Selection

    func testSelectNote() {
        let state = AppState()

        // Default selection is 0
        XCTAssertEqual(state.selectedNoteIndex, 0)

        // Select note at index 1
        state.selectNote(1)
        XCTAssertEqual(state.selectedNoteIndex, 1)

        // Select note at index 5
        state.selectNote(5)
        XCTAssertEqual(state.selectedNoteIndex, 5)
    }

    func testSelectNoteOutOfBoundsIsIgnored() {
        let state = AppState()
        let initialIndex = state.selectedNoteIndex

        // Negative index should be ignored
        state.selectNote(-1)
        XCTAssertEqual(state.selectedNoteIndex, initialIndex)

        // Index beyond count should be ignored
        state.selectNote(999)
        XCTAssertEqual(state.selectedNoteIndex, initialIndex)
    }

    func testSelectSameNoteIsNoOp() {
        let state = AppState()
        state.selectNote(0)
        // Should not crash or change state
        XCTAssertEqual(state.selectedNoteIndex, 0)
    }

    // MARK: - Note Count

    func testSetNoteCountAddsNotes() {
        let state = AppState()
        let originalCount = state.notes.count

        state.setNoteCount(originalCount + 3)
        XCTAssertEqual(state.notes.count, originalCount + 3)

        // New notes should have sequential IDs and labels
        let lastNote = state.notes.last!
        XCTAssertEqual(lastNote.label, "Note \(originalCount + 3)")

        // Restore original count
        state.setNoteCount(originalCount)
    }

    func testSetNoteCountRemovesNotes() {
        let state = AppState()

        // First ensure we have enough notes
        state.setNoteCount(10)
        XCTAssertEqual(state.notes.count, 10)

        state.setNoteCount(5)
        XCTAssertEqual(state.notes.count, 5)

        // If selected index was beyond new count, it should adjust
        state.setNoteCount(10)
        state.selectNote(8)
        state.setNoteCount(5)
        XCTAssertLessThan(state.selectedNoteIndex, 5)

        // Restore
        state.setNoteCount(10)
    }

    func testSetNoteCountRejectsInvalidValues() {
        let state = AppState()
        let originalCount = state.notes.count

        // Below minimum (3)
        state.setNoteCount(2)
        XCTAssertEqual(state.notes.count, originalCount, "Count below 3 should be rejected")

        // Above maximum (30)
        state.setNoteCount(31)
        XCTAssertEqual(state.notes.count, originalCount, "Count above 30 should be rejected")
    }

    // MARK: - Append Text

    func testAppendTextToNote() {
        let state = AppState()

        // Use a high-index note less likely to have onboarding content
        let testIndex = state.notes.count - 1
        let testNoteId = state.notes[testIndex].id

        // Write known content first to establish JSON as the format
        let seed = NSAttributedString(
            string: "Seed",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        state.storage.saveNoteContent(seed, for: testNoteId)

        // Append text
        state.appendTextToNote(at: testIndex, text: "Appended content")

        let loaded = state.storage.loadNoteContent(for: testNoteId)
        XCTAssertTrue(loaded.string.contains("Appended content"),
                       "Appended text should be present in note content")
        XCTAssertTrue(loaded.string.contains("Service"),
                       "Service separator should be present")
        XCTAssertTrue(loaded.string.contains("Seed"),
                       "Original content should be preserved")
    }

    func testAppendTextPreservesExistingContent() {
        let state = AppState()
        let testIndex = state.notes.count - 1
        let testNoteId = state.notes[testIndex].id

        // Save initial content
        let initial = NSAttributedString(
            string: "Original content",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        state.storage.saveNoteContent(initial, for: testNoteId)

        // Append new text
        state.appendTextToNote(at: testIndex, text: "New text")

        let loaded = state.storage.loadNoteContent(for: testNoteId)
        XCTAssertTrue(loaded.string.contains("Original content"),
                       "Original content should be preserved")
        XCTAssertTrue(loaded.string.contains("New text"),
                       "Appended text should also be present")
    }

    // MARK: - Clear Note

    func testClearNote() {
        let state = AppState()

        // Use the last note to avoid onboarding content interference
        let testIndex = state.notes.count - 1
        let testNoteId = state.notes[testIndex].id

        // Save some content first (establishes JSON format)
        let content = NSAttributedString(
            string: "Content to clear",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )
        state.storage.saveNoteContent(content, for: testNoteId)

        // Select that note so clearNote updates currentAttributedText
        state.selectNote(testIndex)

        // Clear the note
        state.clearNote(testIndex)

        // currentAttributedText should be empty since it's the selected note
        XCTAssertEqual(state.currentAttributedText.string, "")
    }

    func testClearNoteOutOfBoundsIsIgnored() {
        let state = AppState()

        // Should not crash for invalid indices
        state.clearNote(-1)
        state.clearNote(999)
    }

    // MARK: - Toggle Previous Note

    func testTogglePreviousNote() {
        let state = AppState()

        // Initially no previous note
        state.togglePreviousNote()
        XCTAssertEqual(state.selectedNoteIndex, 0, "Should stay at 0 when no previous note")

        // Select note 3, then toggle back
        state.selectNote(3)
        XCTAssertEqual(state.selectedNoteIndex, 3)

        state.togglePreviousNote()
        XCTAssertEqual(state.selectedNoteIndex, 0, "Should toggle back to previous note")
    }
}
