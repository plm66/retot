import Foundation

struct NoteMetadata: Codable {
    let id: Int
    let label: String
    let colorName: String
    let tags: [String]
    let fontColorHex: String?
    let backgroundColorHex: String?
    let lastModified: Date

    static func from(_ note: Note) -> NoteMetadata {
        NoteMetadata(
            id: note.id,
            label: note.label,
            colorName: note.color.rawValue,
            tags: note.tags,
            fontColorHex: note.fontColorHex,
            backgroundColorHex: note.backgroundColorHex,
            lastModified: note.lastModified
        )
    }

    func toNote() -> Note {
        Note(
            id: id,
            label: label,
            color: NoteColor(rawValue: colorName) ?? .blue,
            tags: tags,
            fontColorHex: fontColorHex,
            backgroundColorHex: backgroundColorHex,
            lastModified: lastModified
        )
    }

    // Support loading old metadata without tags, fontColorHex, backgroundColorHex
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        colorName = try container.decode(String.self, forKey: .colorName)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        fontColorHex = try container.decodeIfPresent(String.self, forKey: .fontColorHex)
        backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
    }

    init(
        id: Int,
        label: String,
        colorName: String,
        tags: [String],
        fontColorHex: String? = nil,
        backgroundColorHex: String? = nil,
        lastModified: Date
    ) {
        self.id = id
        self.label = label
        self.colorName = colorName
        self.tags = tags
        self.fontColorHex = fontColorHex
        self.backgroundColorHex = backgroundColorHex
        self.lastModified = lastModified
    }
}
