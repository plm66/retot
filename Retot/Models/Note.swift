import Foundation

struct Note: Identifiable, Equatable {
    let id: Int
    let label: String
    let color: NoteColor
    let lastModified: Date

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
            && lhs.label == rhs.label
            && lhs.color == rhs.color
            && lhs.lastModified == rhs.lastModified
    }

    func withLabel(_ newLabel: String) -> Note {
        Note(
            id: id,
            label: newLabel,
            color: color,
            lastModified: Date()
        )
    }

    func withColor(_ newColor: NoteColor) -> Note {
        Note(
            id: id,
            label: label,
            color: newColor,
            lastModified: Date()
        )
    }

    func withModifiedNow() -> Note {
        Note(
            id: id,
            label: label,
            color: color,
            lastModified: Date()
        )
    }

    static func defaults() -> [Note] {
        NoteColor.defaultPalette.enumerated().map { index, color in
            Note(
                id: index + 1,
                label: "Note \(index + 1)",
                color: color,
                lastModified: Date()
            )
        }
    }
}
