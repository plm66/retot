#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation

// MARK: - DocumentSerializer

enum DocumentSerializer {

    // MARK: - JSON Encoding / Decoding

    static func encode(_ document: NoteDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    static func decode(from data: Data) throws -> NoteDocument {
        let decoder = JSONDecoder()
        return try decoder.decode(NoteDocument.self, from: data)
    }

    // MARK: - macOS: NSAttributedString -> NoteDocument

    #if os(macOS)

    static func serialize(_ attributedString: NSAttributedString) -> NoteDocument {
        let string = attributedString.string as NSString
        let fullLength = string.length
        guard fullLength > 0 else {
            return NoteDocument(elements: [])
        }

        var elements: [DocumentElement] = []
        var images: [ImageReference] = []
        var location = 0

        while location < fullLength {
            let paraRange = string.paragraphRange(for: NSRange(location: location, length: 0))

            // Determine what kind of element this paragraph belongs to
            let paraStyle = attributedString.attribute(
                .paragraphStyle, at: paraRange.location, effectiveRange: nil
            ) as? NSParagraphStyle

            let textBlocks = paraStyle?.textBlocks ?? []
            let tableBlock = textBlocks.compactMap { $0 as? NSTextTableBlock }.first
            let pastilleBlock = textBlocks.first(where: { !($0 is NSTextTableBlock) })

            if let tableBlock = tableBlock {
                // Table: collect all consecutive paragraphs belonging to the same table
                let table = tableBlock.table
                let tableResult = collectTable(
                    table: table,
                    from: attributedString,
                    startingAt: location,
                    images: &images
                )
                elements.append(.table(tableResult.element))
                location = tableResult.endLocation
            } else if pastilleBlock != nil {
                // Pastille: collect consecutive pastille paragraphs with the same block
                let pastilleResult = collectPastille(
                    from: attributedString,
                    startingAt: location,
                    images: &images
                )
                elements.append(.pastille(pastilleResult.element))
                location = pastilleResult.endLocation
            } else {
                // Regular paragraph
                let (paragraph, paragraphImages) = serializeParagraph(
                    attributedString,
                    range: paraRange
                )

                // Check if this paragraph contains only an image attachment
                let imageElement = extractStandaloneImage(
                    from: attributedString,
                    range: paraRange,
                    images: &images
                )

                if let imageElement = imageElement {
                    elements.append(.image(imageElement))
                } else {
                    images.append(contentsOf: paragraphImages)
                    elements.append(.paragraph(paragraph))
                }

                location = NSMaxRange(paraRange)
            }
        }

        return NoteDocument(elements: elements, images: images)
    }

    // MARK: - Table Collection

    private static func collectTable(
        table: NSTextTable,
        from attributedString: NSAttributedString,
        startingAt start: Int,
        images: inout [ImageReference]
    ) -> (element: Table, endLocation: Int) {
        let string = attributedString.string as NSString
        let fullLength = string.length
        var location = start
        var cellMap: [(row: Int, col: Int, content: NSAttributedString, block: NSTextTableBlock)] = []

        while location < fullLength {
            let paraRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let paraStyle = attributedString.attribute(
                .paragraphStyle, at: paraRange.location, effectiveRange: nil
            ) as? NSParagraphStyle
            let blocks = paraStyle?.textBlocks ?? []
            guard let block = blocks.compactMap({ $0 as? NSTextTableBlock }).first,
                  block.table === table else {
                break
            }

            // Extract cell content without trailing newline
            var contentRange = paraRange
            let paraText = string.substring(with: paraRange)
            if paraText.hasSuffix("\n") {
                contentRange.length -= 1
            }
            let content = attributedString.attributedSubstring(from: contentRange)
            cellMap.append((row: block.startingRow, col: block.startingColumn, content: content, block: block))
            location = NSMaxRange(paraRange)
        }

        let maxRow = cellMap.map(\.row).max() ?? 0
        let maxCol = cellMap.map(\.col).max() ?? 0
        let columns = maxCol + 1

        var rows: [[TableCell]] = []
        for rowIdx in 0...maxRow {
            var rowCells: [TableCell] = []
            for colIdx in 0...maxCol {
                if let entry = cellMap.first(where: { $0.row == rowIdx && $0.col == colIdx }) {
                    let runs = serializeRuns(entry.content, range: NSRange(location: 0, length: entry.content.length), images: &images)
                    let isHeader = entry.block.backgroundColor != nil && rowIdx == 0
                    let bgHex = entry.block.backgroundColor?.toHex()
                    rowCells.append(TableCell(runs: runs, isHeader: isHeader, backgroundColorHex: bgHex))
                } else {
                    rowCells.append(TableCell(runs: [TextRun(text: " ", attributes: TextAttributes())]))
                }
            }
            rows.append(rowCells)
        }

        return (element: Table(columns: columns, rows: rows), endLocation: location)
    }

    // MARK: - Pastille Collection

    private static func collectPastille(
        from attributedString: NSAttributedString,
        startingAt start: Int,
        images: inout [ImageReference]
    ) -> (element: Pastille, endLocation: Int) {
        let string = attributedString.string as NSString
        let fullLength = string.length
        var location = start
        var paragraphs: [Paragraph] = []
        var backgroundColorHex: String?
        var borderColorHex: String?

        while location < fullLength {
            let paraRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let paraStyle = attributedString.attribute(
                .paragraphStyle, at: paraRange.location, effectiveRange: nil
            ) as? NSParagraphStyle
            let blocks = paraStyle?.textBlocks ?? []
            let pastilleBlock = blocks.first(where: { !($0 is NSTextTableBlock) })

            guard let block = pastilleBlock else { break }

            // Capture pastille styling from the block
            if backgroundColorHex == nil, let bg = block.backgroundColor {
                backgroundColorHex = bg.toHex()
            }
            if borderColorHex == nil {
                let borderColor = block.borderColor(for: .minX)
                if let bc = borderColor {
                    borderColorHex = bc.toHex()
                }
            }

            let (paragraph, _) = serializeParagraph(attributedString, range: paraRange)
            paragraphs.append(paragraph)
            location = NSMaxRange(paraRange)
        }

        return (
            element: Pastille(
                paragraphs: paragraphs,
                backgroundColorHex: backgroundColorHex,
                borderColorHex: borderColorHex
            ),
            endLocation: location
        )
    }

    // MARK: - Standalone Image Extraction

    private static func extractStandaloneImage(
        from attributedString: NSAttributedString,
        range: NSRange,
        images: inout [ImageReference]
    ) -> ImageElement? {
        // A standalone image is a paragraph that contains only the attachment character
        let text = (attributedString.string as NSString).substring(with: range)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // The attachment character is \u{FFFC}
        guard trimmed == "\u{FFFC}" else { return nil }

        // Find the attachment
        var attachmentRange = NSRange(location: 0, length: 0)
        var foundElement: ImageElement?

        attributedString.enumerateAttribute(.attachment, in: range) { value, attrRange, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            let imageData = extractImageData(from: attachment)
            guard let data = imageData else { return }

            let imageId = UUID().uuidString
            let filename = "img-\(imageId).png"
            images.append(ImageReference(id: imageId, filename: filename, data: data))

            let width: CGFloat? = attachment.bounds.width > 0 ? attachment.bounds.width : nil
            let height: CGFloat? = attachment.bounds.height > 0 ? attachment.bounds.height : nil
            foundElement = ImageElement(imageId: imageId, width: width, height: height)
            stop.pointee = true
        }

        return foundElement
    }

    // MARK: - Paragraph Serialization

    private static func serializeParagraph(
        _ attributedString: NSAttributedString,
        range: NSRange
    ) -> (Paragraph, [ImageReference]) {
        var images: [ImageReference] = []
        let runs = serializeRuns(attributedString, range: range, images: &images)

        let alignment = extractAlignment(from: attributedString, at: range.location)

        return (Paragraph(runs: runs, alignment: alignment), images)
    }

    // MARK: - Run Serialization

    private static func serializeRuns(
        _ attributedString: NSAttributedString,
        range: NSRange,
        images: inout [ImageReference]
    ) -> [TextRun] {
        var runs: [TextRun] = []

        attributedString.enumerateAttributes(in: range) { attrs, attrRange, _ in
            let text = (attributedString.string as NSString).substring(with: attrRange)

            // Handle image attachments inline
            if let attachment = attrs[.attachment] as? NSTextAttachment {
                if let imageData = extractImageData(from: attachment) {
                    let imageId = UUID().uuidString
                    let filename = "img-\(imageId).png"
                    images.append(ImageReference(id: imageId, filename: filename, data: imageData))
                    // Represent inline images as a run with the attachment character
                    let attributes = TextAttributes(linkURL: "retot-image://\(imageId)")
                    runs.append(TextRun(text: "\u{FFFC}", attributes: attributes))
                }
                return
            }

            let attributes = extractTextAttributes(from: attrs)
            // Skip empty runs but keep whitespace-only runs (they may be meaningful)
            if text.isEmpty { return }
            runs.append(TextRun(text: text, attributes: attributes))
        }

        return runs
    }

    // MARK: - Attribute Extraction

    private static func extractTextAttributes(from attrs: [NSAttributedString.Key: Any]) -> TextAttributes {
        var result = TextAttributes()

        if let font = attrs[.font] as? NSFont {
            let traits = NSFontManager.shared.traits(of: font)
            result.fontFamily = font.familyName
            result.fontSize = font.pointSize
            result.isBold = traits.contains(.boldFontMask)
            result.isItalic = traits.contains(.italicFontMask)
        }

        if let underline = attrs[.underlineStyle] as? Int, underline != 0 {
            result.isUnderline = true
        }

        if let strikethrough = attrs[.strikethroughStyle] as? Int, strikethrough != 0 {
            result.isStrikethrough = true
        }

        if let color = attrs[.foregroundColor] as? NSColor {
            result.foregroundColorHex = color.toHex()
        }

        if let bgColor = attrs[.backgroundColor] as? NSColor {
            result.backgroundColorHex = bgColor.toHex()
        }

        if let link = attrs[.link] {
            if let url = link as? URL {
                result.linkURL = url.absoluteString
            } else if let urlString = link as? String {
                result.linkURL = urlString
            }
        }

        return result
    }

    private static func extractAlignment(
        from attributedString: NSAttributedString,
        at location: Int
    ) -> TextAlignment? {
        guard location < attributedString.length,
              let paraStyle = attributedString.attribute(
                  .paragraphStyle, at: location, effectiveRange: nil
              ) as? NSParagraphStyle else { return nil }

        switch paraStyle.alignment {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        case .justified: return .justified
        default: return nil
        }
    }

    private static func extractImageData(from attachment: NSTextAttachment) -> Data? {
        // Try getting the image directly and converting to PNG
        if let image = attachment.image {
            return image.pngData()
        }
        // Try the file contents
        if let data = attachment.contents {
            return data
        }
        // Try the file wrapper
        if let wrapper = attachment.fileWrapper, let data = wrapper.regularFileContents {
            return data
        }
        return nil
    }

    #endif // os(macOS) serialization

    // MARK: - Deserialization: NoteDocument -> NSAttributedString

    #if os(macOS)

    static func deserialize(_ document: NoteDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for element in document.elements {
            switch element {
            case .paragraph(let paragraph):
                result.append(deserializeParagraph(paragraph, images: document.images))

            case .table(let table):
                result.append(deserializeTable(table, images: document.images))

            case .pastille(let pastille):
                result.append(deserializePastille(pastille, images: document.images))

            case .image(let imageElement):
                result.append(deserializeImage(imageElement, images: document.images))
            }
        }

        return NSAttributedString(attributedString: result)
    }

    // MARK: - Paragraph Deserialization (macOS)

    private static func deserializeParagraph(
        _ paragraph: Paragraph,
        images: [ImageReference],
        additionalAttributes: [NSAttributedString.Key: Any]? = nil
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for run in paragraph.runs {
            // Check for inline image reference
            if let linkURL = run.attributes.linkURL,
               linkURL.hasPrefix("retot-image://") {
                let imageId = String(linkURL.dropFirst("retot-image://".count))
                if let imageRef = images.first(where: { $0.id == imageId }),
                   let data = imageRef.data,
                   let image = NSImage(data: data) {
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    let attrString = NSAttributedString(attachment: attachment)
                    result.append(attrString)
                    continue
                }
            }

            var attrs = buildAttributes(from: run.attributes)
            if let additional = additionalAttributes {
                for (key, value) in additional {
                    // Don't override font if already set
                    if key == .font && attrs[.font] != nil { continue }
                    attrs[key] = value
                }
            }
            result.append(NSAttributedString(string: run.text, attributes: attrs))
        }

        // Apply paragraph alignment
        if let alignment = paragraph.alignment, result.length > 0 {
            let paraStyle = NSMutableParagraphStyle()
            switch alignment {
            case .left: paraStyle.alignment = .left
            case .center: paraStyle.alignment = .center
            case .right: paraStyle.alignment = .right
            case .justified: paraStyle.alignment = .justified
            }
            result.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: result.length))
        }

        return result
    }

    // MARK: - Table Deserialization (macOS)

    private static func deserializeTable(
        _ table: Table,
        images: [ImageReference]
    ) -> NSAttributedString {
        let rowCount = table.rows.count
        let colCount = table.columns

        let nsTable = NSTextTable()
        nsTable.numberOfColumns = colCount
        nsTable.collapsesBorders = true
        nsTable.hidesEmptyCells = false

        let result = NSMutableAttributedString()

        for (rowIndex, row) in table.rows.enumerated() {
            for colIndex in 0..<colCount {
                let block = NSTextTableBlock(
                    table: nsTable,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: colIndex,
                    columnSpan: 1
                )

                block.setWidth(1.0, type: .absoluteValueType, for: .border)
                block.setBorderColor(.separatorColor)
                block.setWidth(6.0, type: .absoluteValueType, for: .padding)
                block.setContentWidth(100.0 / CGFloat(colCount), type: .percentageValueType)

                let cell: TableCell
                if colIndex < row.count {
                    cell = row[colIndex]
                } else {
                    cell = TableCell(runs: [TextRun(text: " ", attributes: TextAttributes())])
                }

                if cell.isHeader {
                    if let bgHex = cell.backgroundColorHex,
                       let bgColor = NSColor.fromHex(bgHex) {
                        block.backgroundColor = bgColor
                    } else {
                        block.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
                    }
                } else if let bgHex = cell.backgroundColorHex,
                          let bgColor = NSColor.fromHex(bgHex) {
                    block.backgroundColor = bgColor
                }

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [block]

                let isHeader = cell.isHeader
                let defaultFont = isHeader
                    ? NSFont.systemFont(ofSize: 13, weight: .semibold)
                    : NSFont.systemFont(ofSize: 13)

                // Build cell content from runs
                let cellContent = NSMutableAttributedString()
                if cell.runs.isEmpty {
                    cellContent.append(NSAttributedString(string: " "))
                } else {
                    for run in cell.runs {
                        let attrs = buildAttributes(from: run.attributes)
                        cellContent.append(NSAttributedString(string: run.text, attributes: attrs))
                    }
                }

                // Apply paragraph style and default font to the full cell
                let cellString = NSMutableAttributedString(
                    string: cellContent.string + "\n",
                    attributes: [
                        .paragraphStyle: paragraphStyle,
                        .font: defaultFont,
                        .foregroundColor: NSColor.textColor
                    ]
                )

                // Re-apply any per-run attributes on top (bold, italic, colors, etc.)
                // This preserves rich text within table cells
                var offset = 0
                for run in cell.runs {
                    let runLength = (run.text as NSString).length
                    if runLength > 0 {
                        let attrs = buildAttributes(from: run.attributes)
                        let range = NSRange(location: offset, length: runLength)
                        for (key, value) in attrs {
                            cellString.addAttribute(key, value: value, range: range)
                        }
                        // Always keep the paragraph style
                        cellString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                    }
                    offset += runLength
                }

                result.append(cellString)
            }
        }

        return result
    }

    // MARK: - Pastille Deserialization (macOS)

    private static func deserializePastille(
        _ pastille: Pastille,
        images: [ImageReference]
    ) -> NSAttributedString {
        let block = NSTextBlock()
        block.setWidth(1.5, type: .absoluteValueType, for: .border)
        block.setWidth(8.0, type: .absoluteValueType, for: .padding)
        block.setContentWidth(100, type: .percentageValueType)

        if let bgHex = pastille.backgroundColorHex,
           let bgColor = NSColor.fromHex(bgHex) {
            block.backgroundColor = bgColor
        } else {
            block.backgroundColor = RetotTextView.pastilleBackgroundColor
        }

        if let borderHex = pastille.borderColorHex,
           let borderColor = NSColor.fromHex(borderHex) {
            block.setBorderColor(borderColor)
        } else {
            block.setBorderColor(RetotTextView.pastilleBorderColor)
        }

        let result = NSMutableAttributedString()

        for paragraph in pastille.paragraphs {
            let paraContent = deserializeParagraph(paragraph, images: images)
            let mutable = NSMutableAttributedString(attributedString: paraContent)

            // Ensure trailing newline for each pastille paragraph
            if !mutable.string.hasSuffix("\n") {
                mutable.append(NSAttributedString(string: "\n"))
            }

            // Apply pastille block to paragraph style
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
                let style: NSMutableParagraphStyle
                if let existing = value as? NSParagraphStyle {
                    style = existing.mutableCopy() as! NSMutableParagraphStyle
                } else {
                    style = NSMutableParagraphStyle()
                }
                style.textBlocks = [block]
                mutable.addAttribute(.paragraphStyle, value: style, range: range)
            }

            // If no paragraph style was set at all, apply one
            if mutable.attribute(.paragraphStyle, at: 0, effectiveRange: nil) == nil {
                let style = NSMutableParagraphStyle()
                style.textBlocks = [block]
                mutable.addAttribute(.paragraphStyle, value: style, range: fullRange)
            }

            result.append(mutable)
        }

        return result
    }

    // MARK: - Image Deserialization (macOS)

    private static func deserializeImage(
        _ imageElement: ImageElement,
        images: [ImageReference]
    ) -> NSAttributedString {
        guard let imageRef = images.first(where: { $0.id == imageElement.imageId }),
              let data = imageRef.data,
              let image = NSImage(data: data) else {
            return NSAttributedString(string: "")
        }

        let attachment = NSTextAttachment()
        attachment.image = image

        if let width = imageElement.width, let height = imageElement.height {
            attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        }

        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    // MARK: - Attribute Building (macOS)

    private static func buildAttributes(from textAttrs: TextAttributes) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [:]

        // Font
        let size = textAttrs.fontSize ?? 14
        var font: NSFont

        if let family = textAttrs.fontFamily,
           let familyFont = NSFont(name: family, size: size) {
            font = familyFont
        } else {
            font = NSFont.systemFont(ofSize: size)
        }

        if textAttrs.isBold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if textAttrs.isItalic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        attrs[.font] = font

        // Underline
        if textAttrs.isUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        // Strikethrough
        if textAttrs.isStrikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        // Foreground color
        if let hex = textAttrs.foregroundColorHex,
           let color = NSColor.fromHex(hex) {
            attrs[.foregroundColor] = color
        }

        // Background color
        if let hex = textAttrs.backgroundColorHex,
           let color = NSColor.fromHex(hex) {
            attrs[.backgroundColor] = color
        }

        // Link
        if let urlString = textAttrs.linkURL,
           !urlString.hasPrefix("retot-image://"),
           let url = URL(string: urlString) {
            attrs[.link] = url
        }

        return attrs
    }

    #endif // os(macOS) deserialization

    // MARK: - iOS Deserialization

    #if os(iOS)

    static func deserialize(_ document: NoteDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for element in document.elements {
            switch element {
            case .paragraph(let paragraph):
                result.append(deserializeParagraphiOS(paragraph, images: document.images))

            case .table(let table):
                result.append(deserializeTableiOS(table, images: document.images))

            case .pastille(let pastille):
                result.append(deserializePastilleiOS(pastille, images: document.images))

            case .image(let imageElement):
                result.append(deserializeImageiOS(imageElement, images: document.images))
            }
        }

        return NSAttributedString(attributedString: result)
    }

    // MARK: - Paragraph Deserialization (iOS)

    private static func deserializeParagraphiOS(
        _ paragraph: Paragraph,
        images: [ImageReference]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for run in paragraph.runs {
            // Check for inline image reference
            if let linkURL = run.attributes.linkURL,
               linkURL.hasPrefix("retot-image://") {
                let imageId = String(linkURL.dropFirst("retot-image://".count))
                if let imageRef = images.first(where: { $0.id == imageId }),
                   let data = imageRef.data,
                   let image = UIImage(data: data) {
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    result.append(NSAttributedString(attachment: attachment))
                    continue
                }
            }

            let attrs = buildAttributesiOS(from: run.attributes)
            result.append(NSAttributedString(string: run.text, attributes: attrs))
        }

        // Apply alignment
        if let alignment = paragraph.alignment, result.length > 0 {
            let paraStyle = NSMutableParagraphStyle()
            switch alignment {
            case .left: paraStyle.alignment = .left
            case .center: paraStyle.alignment = .center
            case .right: paraStyle.alignment = .right
            case .justified: paraStyle.alignment = .justified
            }
            result.addAttribute(.paragraphStyle, value: paraStyle, range: NSRange(location: 0, length: result.length))
        }

        return result
    }

    // MARK: - Table Deserialization (iOS) - Simple text representation

    private static func deserializeTableiOS(
        _ table: Table,
        images: [ImageReference]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let defaultFont = UIFont.systemFont(ofSize: 14)

        for (rowIndex, row) in table.rows.enumerated() {
            var line = "| "
            for (colIndex, cell) in row.enumerated() {
                let cellText = cell.runs.map(\.text).joined()
                line += cellText
                if colIndex < row.count - 1 {
                    line += " | "
                }
            }
            line += " |\n"

            let isHeader = row.first?.isHeader ?? false
            let font = isHeader
                ? UIFont.boldSystemFont(ofSize: 14)
                : defaultFont

            result.append(NSAttributedString(string: line, attributes: [
                .font: font,
                .foregroundColor: UIColor.label
            ]))

            // Add separator after header row
            if isHeader {
                var separator = "|"
                for _ in 0..<table.columns {
                    separator += "---|"
                }
                separator += "\n"
                result.append(NSAttributedString(string: separator, attributes: [
                    .font: defaultFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]))
            }
        }

        return result
    }

    // MARK: - Pastille Deserialization (iOS) - Background color attribute

    private static func deserializePastilleiOS(
        _ pastille: Pastille,
        images: [ImageReference]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for paragraph in pastille.paragraphs {
            let paraContent = deserializeParagraphiOS(paragraph, images: images)
            let mutable = NSMutableAttributedString(attributedString: paraContent)

            if !mutable.string.hasSuffix("\n") {
                mutable.append(NSAttributedString(string: "\n"))
            }

            // Apply background color for pastille indication on iOS
            if let bgHex = pastille.backgroundColorHex,
               let bgColor = UIColor.fromHex(bgHex) {
                mutable.addAttribute(
                    .backgroundColor,
                    value: bgColor,
                    range: NSRange(location: 0, length: mutable.length)
                )
            }

            result.append(mutable)
        }

        return result
    }

    // MARK: - Image Deserialization (iOS)

    private static func deserializeImageiOS(
        _ imageElement: ImageElement,
        images: [ImageReference]
    ) -> NSAttributedString {
        guard let imageRef = images.first(where: { $0.id == imageElement.imageId }),
              let data = imageRef.data,
              let image = UIImage(data: data) else {
            return NSAttributedString(string: "")
        }

        let attachment = NSTextAttachment()
        attachment.image = image

        if let width = imageElement.width, let height = imageElement.height {
            attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        }

        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    // MARK: - Attribute Building (iOS)

    private static func buildAttributesiOS(from textAttrs: TextAttributes) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [:]

        let size = textAttrs.fontSize ?? 14
        var font: UIFont

        if let family = textAttrs.fontFamily {
            let descriptor = UIFontDescriptor()
                .withFamily(family)
                .withSize(size)
            font = UIFont(descriptor: descriptor, size: size)
        } else {
            font = UIFont.systemFont(ofSize: size)
        }

        // Apply traits
        var traits: UIFontDescriptor.SymbolicTraits = font.fontDescriptor.symbolicTraits
        if textAttrs.isBold { traits.insert(.traitBold) }
        if textAttrs.isItalic { traits.insert(.traitItalic) }
        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        attrs[.font] = font

        if textAttrs.isUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if textAttrs.isStrikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        if let hex = textAttrs.foregroundColorHex,
           let color = UIColor.fromHex(hex) {
            attrs[.foregroundColor] = color
        }

        if let hex = textAttrs.backgroundColorHex,
           let color = UIColor.fromHex(hex) {
            attrs[.backgroundColor] = color
        }

        if let urlString = textAttrs.linkURL,
           !urlString.hasPrefix("retot-image://"),
           let url = URL(string: urlString) {
            attrs[.link] = url
        }

        return attrs
    }

    #endif // os(iOS) deserialization

    // MARK: - fromHex / toHex on UIColor (iOS helper, already on PlatformColor via ColorExtensions)
}

// MARK: - NSImage PNG Data Helper

#if os(macOS)
extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif
