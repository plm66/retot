import XCTest
@testable import Retot

final class NoteTests: XCTestCase {

    // MARK: - Defaults

    func testDefaultsCreates10Notes() {
        let notes = Note.defaults()
        XCTAssertEqual(notes.count, 10)
    }

    func testDefaultsHaveSequentialIds() {
        let notes = Note.defaults()
        let ids = notes.map(\.id)
        XCTAssertEqual(ids, Array(1...10))
    }

    func testDefaultsHaveUniqueColors() {
        let notes = Note.defaults()
        let colors = Set(notes.map(\.color))
        XCTAssertEqual(colors.count, 10)
    }

    func testDefaultsHaveLabels() {
        let notes = Note.defaults()
        for (index, note) in notes.enumerated() {
            XCTAssertEqual(note.label, "Note \(index + 1)")
        }
    }

    // MARK: - Immutable Updates

    func testWithLabelReturnsNewInstance() {
        let note = Note(id: 1, label: "Original", color: .red, tags: [], lastModified: Date())
        let updated = note.withLabel("Updated")

        XCTAssertEqual(updated.label, "Updated")
        XCTAssertEqual(updated.id, 1)
        XCTAssertEqual(updated.color, .red)
        // Original is unchanged
        XCTAssertEqual(note.label, "Original")
    }

    func testWithColorReturnsNewInstance() {
        let note = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: Date())
        let updated = note.withColor(.blue)

        XCTAssertEqual(updated.color, .blue)
        XCTAssertEqual(updated.id, 1)
        XCTAssertEqual(updated.label, "Test")
        // Original is unchanged
        XCTAssertEqual(note.color, .red)
    }

    func testWithLabelUpdatesLastModified() {
        let originalDate = Date.distantPast
        let note = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: originalDate)
        let updated = note.withLabel("New")

        XCTAssertGreaterThan(updated.lastModified, originalDate)
    }

    func testWithColorUpdatesLastModified() {
        let originalDate = Date.distantPast
        let note = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: originalDate)
        let updated = note.withColor(.blue)

        XCTAssertGreaterThan(updated.lastModified, originalDate)
    }

    func testWithModifiedNowUpdatesDate() {
        let originalDate = Date.distantPast
        let note = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: originalDate)
        let updated = note.withModifiedNow()

        XCTAssertEqual(updated.label, "Test")
        XCTAssertEqual(updated.color, .red)
        XCTAssertGreaterThan(updated.lastModified, originalDate)
    }

    // MARK: - Equatable

    func testEqualityMatchesAllFields() {
        let date = Date()
        let a = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: date)
        let b = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: date)
        XCTAssertEqual(a, b)
    }

    func testInequalityOnLabel() {
        let date = Date()
        let a = Note(id: 1, label: "A", color: .red, tags: [], lastModified: date)
        let b = Note(id: 1, label: "B", color: .red, tags: [], lastModified: date)
        XCTAssertNotEqual(a, b)
    }

    func testInequalityOnColor() {
        let date = Date()
        let a = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: date)
        let b = Note(id: 1, label: "Test", color: .blue, tags: [], lastModified: date)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Tags

    func testDefaultsHaveEmptyTags() {
        let notes = Note.defaults()
        for note in notes {
            XCTAssertTrue(note.tags.isEmpty)
        }
    }

    func testWithTagsReturnsNewInstance() {
        let note = Note(id: 1, label: "Test", color: .red, tags: [], lastModified: Date())
        let updated = note.withTags(["urgent", "work"])

        XCTAssertEqual(updated.tags, ["urgent", "work"])
        XCTAssertTrue(note.tags.isEmpty)
    }

    func testWithTagsPreservesOtherFields() {
        let note = Note(id: 5, label: "Shopping", color: .green, tags: ["personal"], lastModified: Date())
        let updated = note.withTags(["personal", "food"])

        XCTAssertEqual(updated.id, 5)
        XCTAssertEqual(updated.label, "Shopping")
        XCTAssertEqual(updated.color, .green)
    }

    func testInequalityOnTags() {
        let date = Date()
        let a = Note(id: 1, label: "Test", color: .red, tags: ["a"], lastModified: date)
        let b = Note(id: 1, label: "Test", color: .red, tags: ["b"], lastModified: date)
        XCTAssertNotEqual(a, b)
    }
}
