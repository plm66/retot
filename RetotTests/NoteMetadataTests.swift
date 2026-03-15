import XCTest
@testable import Retot

final class NoteMetadataTests: XCTestCase {

    // MARK: - Codable Round-trip

    func testEncodeDecodeRoundTrip() throws {
        let note = Note(id: 3, label: "Shopping", color: .green, tags: ["food"], lastModified: Date())
        let metadata = NoteMetadata.from(note)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NoteMetadata.self, from: data)

        XCTAssertEqual(decoded.id, 3)
        XCTAssertEqual(decoded.label, "Shopping")
        XCTAssertEqual(decoded.colorName, "green")
    }

    func testFromNotePreservesAllFields() {
        let date = Date()
        let note = Note(id: 5, label: "Work", color: .indigo, tags: ["urgent"], lastModified: date)
        let metadata = NoteMetadata.from(note)

        XCTAssertEqual(metadata.id, 5)
        XCTAssertEqual(metadata.label, "Work")
        XCTAssertEqual(metadata.colorName, "indigo")
        XCTAssertEqual(metadata.lastModified, date)
    }

    func testToNotePreservesAllFields() {
        let date = Date()
        let metadata = NoteMetadata(id: 7, label: "Ideas", colorName: "purple", tags: ["creative"], lastModified: date)
        let note = metadata.toNote()

        XCTAssertEqual(note.id, 7)
        XCTAssertEqual(note.label, "Ideas")
        XCTAssertEqual(note.color, .purple)
        XCTAssertEqual(note.lastModified, date)
    }

    func testToNoteWithInvalidColorFallsBackToBlue() {
        let metadata = NoteMetadata(id: 1, label: "Test", colorName: "neon", tags: [], lastModified: Date())
        let note = metadata.toNote()

        XCTAssertEqual(note.color, .blue)
    }

    // MARK: - Tags

    func testTagsRoundTrip() throws {
        let note = Note(id: 1, label: "Test", color: .red, tags: ["urgent", "work"], lastModified: Date())
        let metadata = NoteMetadata.from(note)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NoteMetadata.self, from: data)

        XCTAssertEqual(decoded.tags, ["urgent", "work"])
    }

    func testMissingTagsDecodesAsEmpty() throws {
        // Simulate old metadata without tags field
        let json = """
        {"id":1,"label":"Test","colorName":"red","lastModified":"2026-01-01T00:00:00Z"}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(NoteMetadata.self, from: data)

        XCTAssertEqual(decoded.tags, [])
    }

    // MARK: - Array Encoding

    func testEncodeDecodeArray() throws {
        let notes = Note.defaults()
        let metadataArray = notes.map(NoteMetadata.from)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadataArray)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([NoteMetadata].self, from: data)

        XCTAssertEqual(decoded.count, 10)
        XCTAssertEqual(decoded.first?.id, 1)
        XCTAssertEqual(decoded.last?.id, 10)
    }
}
