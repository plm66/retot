import Foundation

struct NoteMetadata: Codable {
    let id: Int
    let label: String
    let colorName: String
    let lastModified: Date

    static func from(_ note: Note) -> NoteMetadata {
        NoteMetadata(
            id: note.id,
            label: note.label,
            colorName: note.color.rawValue,
            lastModified: note.lastModified
        )
    }

    func toNote() -> Note {
        Note(
            id: id,
            label: label,
            color: NoteColor(rawValue: colorName) ?? .blue,
            lastModified: lastModified
        )
    }
}
