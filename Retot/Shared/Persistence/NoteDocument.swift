import Foundation

// MARK: - NoteDocument

struct NoteDocument: Codable, Equatable {
    let version: Int
    let elements: [DocumentElement]
    let images: [ImageReference]

    init(version: Int = 1, elements: [DocumentElement], images: [ImageReference] = []) {
        self.version = version
        self.elements = elements
        self.images = images
    }
}

// MARK: - Document Elements

enum DocumentElement: Codable, Equatable {
    case paragraph(Paragraph)
    case table(Table)
    case pastille(Pastille)
    case image(ImageElement)
}

// MARK: - Paragraph

struct Paragraph: Codable, Equatable {
    let runs: [TextRun]
    let alignment: TextAlignment?

    init(runs: [TextRun], alignment: TextAlignment? = nil) {
        self.runs = runs
        self.alignment = alignment
    }
}

struct TextRun: Codable, Equatable {
    let text: String
    let attributes: TextAttributes
}

struct TextAttributes: Codable, Equatable {
    var fontFamily: String?
    var fontSize: CGFloat?
    var isBold: Bool
    var isItalic: Bool
    var isUnderline: Bool
    var isStrikethrough: Bool
    var foregroundColorHex: String?
    var backgroundColorHex: String?
    var linkURL: String?

    init(
        fontFamily: String? = nil,
        fontSize: CGFloat? = nil,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        foregroundColorHex: String? = nil,
        backgroundColorHex: String? = nil,
        linkURL: String? = nil
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.foregroundColorHex = foregroundColorHex
        self.backgroundColorHex = backgroundColorHex
        self.linkURL = linkURL
    }
}

enum TextAlignment: String, Codable {
    case left
    case center
    case right
    case justified
}

// MARK: - Table

struct Table: Codable, Equatable {
    let columns: Int
    let rows: [[TableCell]]
}

struct TableCell: Codable, Equatable {
    let runs: [TextRun]
    let isHeader: Bool
    let backgroundColorHex: String?

    init(runs: [TextRun], isHeader: Bool = false, backgroundColorHex: String? = nil) {
        self.runs = runs
        self.isHeader = isHeader
        self.backgroundColorHex = backgroundColorHex
    }
}

// MARK: - Pastille

struct Pastille: Codable, Equatable {
    let paragraphs: [Paragraph]
    let backgroundColorHex: String?
    let borderColorHex: String?

    init(paragraphs: [Paragraph], backgroundColorHex: String? = nil, borderColorHex: String? = nil) {
        self.paragraphs = paragraphs
        self.backgroundColorHex = backgroundColorHex
        self.borderColorHex = borderColorHex
    }
}

// MARK: - Image

struct ImageElement: Codable, Equatable {
    let imageId: String
    let width: CGFloat?
    let height: CGFloat?

    init(imageId: String, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.imageId = imageId
        self.width = width
        self.height = height
    }
}

struct ImageReference: Codable, Equatable {
    let id: String
    let filename: String
    let data: Data?

    init(id: String, filename: String, data: Data? = nil) {
        self.id = id
        self.filename = filename
        self.data = data
    }
}
