import Foundation

struct Note: Identifiable, Equatable {
    let id: Int
    let label: String
    let color: NoteColor
    let tags: [String]
    let fontColorHex: String?
    let backgroundColorHex: String?
    let lastModified: Date

    init(
        id: Int,
        label: String,
        color: NoteColor,
        tags: [String],
        fontColorHex: String? = nil,
        backgroundColorHex: String? = nil,
        lastModified: Date
    ) {
        self.id = id
        self.label = label
        self.color = color
        self.tags = tags
        self.fontColorHex = fontColorHex
        self.backgroundColorHex = backgroundColorHex
        self.lastModified = lastModified
    }

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
            && lhs.label == rhs.label
            && lhs.color == rhs.color
            && lhs.tags == rhs.tags
            && lhs.fontColorHex == rhs.fontColorHex
            && lhs.backgroundColorHex == rhs.backgroundColorHex
            && lhs.lastModified == rhs.lastModified
    }

    func withLabel(_ newLabel: String) -> Note {
        Note(
            id: id, label: newLabel, color: color, tags: tags,
            fontColorHex: fontColorHex, backgroundColorHex: backgroundColorHex,
            lastModified: Date()
        )
    }

    func withColor(_ newColor: NoteColor) -> Note {
        Note(
            id: id, label: label, color: newColor, tags: tags,
            fontColorHex: fontColorHex, backgroundColorHex: backgroundColorHex,
            lastModified: Date()
        )
    }

    func withTags(_ newTags: [String]) -> Note {
        Note(
            id: id, label: label, color: color, tags: newTags,
            fontColorHex: fontColorHex, backgroundColorHex: backgroundColorHex,
            lastModified: Date()
        )
    }

    func withFontColor(_ hex: String?) -> Note {
        Note(
            id: id, label: label, color: color, tags: tags,
            fontColorHex: hex, backgroundColorHex: backgroundColorHex,
            lastModified: Date()
        )
    }

    func withBackgroundColor(_ hex: String?) -> Note {
        Note(
            id: id, label: label, color: color, tags: tags,
            fontColorHex: fontColorHex, backgroundColorHex: hex,
            lastModified: Date()
        )
    }

    func withModifiedNow() -> Note {
        Note(
            id: id, label: label, color: color, tags: tags,
            fontColorHex: fontColorHex, backgroundColorHex: backgroundColorHex,
            lastModified: Date()
        )
    }

    static func defaults(count: Int = 10) -> [Note] {
        let palette = NoteColor.defaultPalette
        return (0..<count).map { index in
            Note(
                id: index + 1,
                label: "Note \(index + 1)",
                color: palette[index % palette.count],
                tags: [],
                lastModified: Date()
            )
        }
    }
}

// MARK: - Block Model

struct Block: Identifiable, Equatable, Codable {
    let id: UUID
    let type: BlockType
    let htmlContent: String

    enum BlockType: String, Codable {
        case freeText
        case pastille
    }

    init(id: UUID = UUID(), type: BlockType, htmlContent: String) {
        self.id = id
        self.type = type
        self.htmlContent = htmlContent
    }

    func withContent(_ newHtml: String) -> Block {
        Block(id: id, type: type, htmlContent: newHtml)
    }

    func toPastille() -> Block {
        Block(id: id, type: .pastille, htmlContent: htmlContent)
    }

    func toFreeText() -> Block {
        Block(id: id, type: .freeText, htmlContent: htmlContent)
    }
}
