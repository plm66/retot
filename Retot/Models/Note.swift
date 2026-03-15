import Foundation

struct Note: Identifiable, Equatable {
    let id: Int
    let label: String
    let color: NoteColor
    let tags: [String]
    let lastModified: Date

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
            && lhs.label == rhs.label
            && lhs.color == rhs.color
            && lhs.tags == rhs.tags
            && lhs.lastModified == rhs.lastModified
    }

    func withLabel(_ newLabel: String) -> Note {
        Note(id: id, label: newLabel, color: color, tags: tags, lastModified: Date())
    }

    func withColor(_ newColor: NoteColor) -> Note {
        Note(id: id, label: label, color: newColor, tags: tags, lastModified: Date())
    }

    func withTags(_ newTags: [String]) -> Note {
        Note(id: id, label: label, color: color, tags: newTags, lastModified: Date())
    }

    func withModifiedNow() -> Note {
        Note(id: id, label: label, color: color, tags: tags, lastModified: Date())
    }

    static func defaults() -> [Note] {
        NoteColor.defaultPalette.enumerated().map { index, color in
            Note(
                id: index + 1,
                label: "Note \(index + 1)",
                color: color,
                tags: [],
                lastModified: Date()
            )
        }
    }
}
