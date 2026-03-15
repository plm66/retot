import Foundation

struct NoteMetadata: Codable {
    let id: Int
    let label: String
    let colorName: String
    let tags: [String]
    let lastModified: Date

    static func from(_ note: Note) -> NoteMetadata {
        NoteMetadata(
            id: note.id,
            label: note.label,
            colorName: note.color.rawValue,
            tags: note.tags,
            lastModified: note.lastModified
        )
    }

    func toNote() -> Note {
        Note(
            id: id,
            label: label,
            color: NoteColor(rawValue: colorName) ?? .blue,
            tags: tags,
            lastModified: lastModified
        )
    }

    // Support loading old metadata without tags
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        colorName = try container.decode(String.self, forKey: .colorName)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        lastModified = try container.decode(Date.self, forKey: .lastModified)
    }

    init(id: Int, label: String, colorName: String, tags: [String], lastModified: Date) {
        self.id = id
        self.label = label
        self.colorName = colorName
        self.tags = tags
        self.lastModified = lastModified
    }
}
