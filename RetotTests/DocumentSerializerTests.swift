import AppKit
import XCTest
@testable import Retot

final class DocumentSerializerTests: XCTestCase {

    // MARK: - NoteDocument JSON Round-Trip

    func testNoteDocumentEncodeDecode() throws {
        let doc = NoteDocument(
            elements: [
                .paragraph(Paragraph(runs: [
                    TextRun(text: "Hello", attributes: TextAttributes(isBold: true))
                ]))
            ]
        )

        let data = try DocumentSerializer.encode(doc)
        let decoded = try DocumentSerializer.decode(from: data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.elements.count, 1)
        if case .paragraph(let p) = decoded.elements[0] {
            XCTAssertEqual(p.runs[0].text, "Hello")
            XCTAssertTrue(p.runs[0].attributes.isBold)
        } else {
            XCTFail("Expected paragraph element")
        }
    }

    // MARK: - Plain Text Round-Trip

    func testPlainTextRoundTrip() {
        let original = NSAttributedString(
            string: "Simple text\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.textColor
            ]
        )

        let document = DocumentSerializer.serialize(original)
        let restored = DocumentSerializer.deserialize(document)

        XCTAssertEqual(
            restored.string.trimmingCharacters(in: .whitespacesAndNewlines),
            "Simple text"
        )
    }

    // MARK: - Bold/Italic Round-Trip

    func testBoldItalicRoundTrip() {
        let fontManager = NSFontManager.shared
        let boldFont = fontManager.convert(
            NSFont.systemFont(ofSize: 14),
            toHaveTrait: .boldFontMask
        )
        let italicFont = fontManager.convert(
            NSFont.systemFont(ofSize: 14),
            toHaveTrait: .italicFontMask
        )

        let original = NSMutableAttributedString()
        original.append(NSAttributedString(string: "Bold", attributes: [.font: boldFont]))
        original.append(NSAttributedString(string: " "))
        original.append(NSAttributedString(string: "Italic", attributes: [.font: italicFont]))
        original.append(NSAttributedString(string: "\n"))

        let document = DocumentSerializer.serialize(original)

        // Verify the document model
        XCTAssertEqual(document.elements.count, 1)
        if case .paragraph(let p) = document.elements[0] {
            let boldRun = p.runs.first(where: { $0.text == "Bold" })
            XCTAssertNotNil(boldRun)
            XCTAssertTrue(boldRun?.attributes.isBold ?? false)
            XCTAssertFalse(boldRun?.attributes.isItalic ?? true)

            let italicRun = p.runs.first(where: { $0.text == "Italic" })
            XCTAssertNotNil(italicRun)
            XCTAssertTrue(italicRun?.attributes.isItalic ?? false)
            XCTAssertFalse(italicRun?.attributes.isBold ?? true)
        } else {
            XCTFail("Expected paragraph element")
        }

        // Verify round-trip
        let restored = DocumentSerializer.deserialize(document)
        XCTAssertEqual(restored.string, original.string)

        // Check bold attribute survived
        let restoredBoldFont = restored.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertNotNil(restoredBoldFont)
        let restoredTraits = NSFontManager.shared.traits(of: restoredBoldFont!)
        XCTAssertTrue(restoredTraits.contains(.boldFontMask))
    }

    // MARK: - Underline/Strikethrough Round-Trip

    func testUnderlineStrikethroughRoundTrip() {
        let original = NSMutableAttributedString()
        original.append(NSAttributedString(
            string: "Underlined",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        ))
        original.append(NSAttributedString(
            string: " ",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))
        original.append(NSAttributedString(
            string: "Struck",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
        ))
        original.append(NSAttributedString(string: "\n"))

        let document = DocumentSerializer.serialize(original)
        let restored = DocumentSerializer.deserialize(document)

        // Check underline survived
        let underline = restored.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)

        // Find "Struck" in the restored string
        let struckRange = (restored.string as NSString).range(of: "Struck")
        XCTAssertNotEqual(struckRange.location, NSNotFound)
        let strikethrough = restored.attribute(.strikethroughStyle, at: struckRange.location, effectiveRange: nil) as? Int
        XCTAssertEqual(strikethrough, NSUnderlineStyle.single.rawValue)
    }

    // MARK: - Foreground Color Round-Trip

    func testForegroundColorRoundTrip() {
        let redColor = NSColor(srgbRed: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)

        let original = NSAttributedString(
            string: "Red text\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: redColor
            ]
        )

        let document = DocumentSerializer.serialize(original)

        if case .paragraph(let p) = document.elements[0] {
            XCTAssertNotNil(p.runs[0].attributes.foregroundColorHex)
        }

        let restored = DocumentSerializer.deserialize(document)
        let restoredColor = restored.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNotNil(restoredColor)

        // Compare hex values (exact float comparison is unreliable due to color space conversion)
        let originalHex = redColor.toHex()
        let restoredHex = restoredColor?.toHex()
        XCTAssertEqual(originalHex, restoredHex)
    }

    // MARK: - Multi-Paragraph Round-Trip

    func testMultiParagraphRoundTrip() {
        let original = NSMutableAttributedString()
        original.append(NSAttributedString(
            string: "First paragraph\n",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))
        original.append(NSAttributedString(
            string: "Second paragraph\n",
            attributes: [.font: NSFont.systemFont(ofSize: 16)]
        ))

        let document = DocumentSerializer.serialize(original)
        XCTAssertEqual(document.elements.count, 2)

        let restored = DocumentSerializer.deserialize(document)
        XCTAssertTrue(restored.string.contains("First paragraph"))
        XCTAssertTrue(restored.string.contains("Second paragraph"))
    }

    // MARK: - Table Round-Trip

    func testTableRoundTrip() {
        // Build a 2x2 table using the same pattern as RichTextEditor.buildTable
        let table = NSTextTable()
        table.numberOfColumns = 2
        table.collapsesBorders = true
        table.hidesEmptyCells = false

        let original = NSMutableAttributedString()

        for row in 0..<2 {
            for col in 0..<2 {
                let block = NSTextTableBlock(
                    table: table,
                    startingRow: row,
                    rowSpan: 1,
                    startingColumn: col,
                    columnSpan: 1
                )
                block.setWidth(1.0, type: .absoluteValueType, for: .border)
                block.setBorderColor(.separatorColor)
                block.setWidth(6.0, type: .absoluteValueType, for: .padding)
                block.setContentWidth(50.0, type: .percentageValueType)

                if row == 0 {
                    block.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
                }

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [block]

                let isHeader = row == 0
                let font = isHeader
                    ? NSFont.systemFont(ofSize: 13, weight: .semibold)
                    : NSFont.systemFont(ofSize: 13)

                let cellText = isHeader ? "Header \(col)" : "Cell \(row),\(col)"

                let cellString = NSMutableAttributedString(
                    string: "\(cellText)\n",
                    attributes: [
                        .paragraphStyle: paragraphStyle,
                        .font: font,
                        .foregroundColor: NSColor.textColor
                    ]
                )
                original.append(cellString)
            }
        }

        let document = DocumentSerializer.serialize(original)

        // Should have exactly one table element
        XCTAssertEqual(document.elements.count, 1)
        if case .table(let t) = document.elements[0] {
            XCTAssertEqual(t.columns, 2)
            XCTAssertEqual(t.rows.count, 2)
            XCTAssertTrue(t.rows[0][0].isHeader)
            XCTAssertEqual(t.rows[0][0].runs.first?.text, "Header 0")
            XCTAssertEqual(t.rows[1][1].runs.first?.text, "Cell 1,1")
        } else {
            XCTFail("Expected table element")
        }

        // Verify round-trip preserves text
        let restored = DocumentSerializer.deserialize(document)
        XCTAssertTrue(restored.string.contains("Header 0"))
        XCTAssertTrue(restored.string.contains("Cell 1,1"))

        // Verify the restored string has table blocks
        let paraStyle = restored.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let restoredBlocks = paraStyle?.textBlocks ?? []
        XCTAssertTrue(restoredBlocks.contains(where: { $0 is NSTextTableBlock }))
    }

    // MARK: - Pastille Round-Trip

    func testPastilleRoundTrip() {
        // Build a pastille using the same pattern as RetotTextView.createPastille
        let block = NSTextBlock()
        block.setWidth(1.5, type: .absoluteValueType, for: .border)
        block.setBorderColor(RetotTextView.pastilleBorderColor)
        block.setWidth(8.0, type: .absoluteValueType, for: .padding)
        block.backgroundColor = RetotTextView.pastilleBackgroundColor
        block.setContentWidth(100, type: .percentageValueType)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.textBlocks = [block]

        let original = NSAttributedString(
            string: "Pastille content\n",
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.textColor
            ]
        )

        let document = DocumentSerializer.serialize(original)

        // Should have exactly one pastille element
        XCTAssertEqual(document.elements.count, 1)
        if case .pastille(let p) = document.elements[0] {
            XCTAssertEqual(p.paragraphs.count, 1)
            XCTAssertEqual(p.paragraphs[0].runs.first?.text, "Pastille content\n")
            XCTAssertNotNil(p.backgroundColorHex)
        } else {
            XCTFail("Expected pastille element")
        }

        // Verify round-trip
        let restored = DocumentSerializer.deserialize(document)
        XCTAssertTrue(restored.string.contains("Pastille content"))

        // Verify pastille block is present
        let restoredStyle = restored.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let restoredBlocks = restoredStyle?.textBlocks ?? []
        XCTAssertFalse(restoredBlocks.isEmpty)
        // Should NOT be a table block
        XCTAssertFalse(restoredBlocks.contains(where: { $0 is NSTextTableBlock }))
    }

    // MARK: - Mixed Content Round-Trip

    func testMixedContentRoundTrip() {
        let original = NSMutableAttributedString()

        // Regular paragraph
        original.append(NSAttributedString(
            string: "Regular text\n",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))

        // Table (1x2)
        let table = NSTextTable()
        table.numberOfColumns = 2
        table.collapsesBorders = true
        for col in 0..<2 {
            let block = NSTextTableBlock(
                table: table,
                startingRow: 0,
                rowSpan: 1,
                startingColumn: col,
                columnSpan: 1
            )
            block.setWidth(1.0, type: .absoluteValueType, for: .border)
            block.setBorderColor(.separatorColor)
            block.setWidth(6.0, type: .absoluteValueType, for: .padding)
            block.setContentWidth(50.0, type: .percentageValueType)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.textBlocks = [block]

            original.append(NSAttributedString(
                string: "Col \(col)\n",
                attributes: [
                    .paragraphStyle: paragraphStyle,
                    .font: NSFont.systemFont(ofSize: 13)
                ]
            ))
        }

        // Another regular paragraph
        original.append(NSAttributedString(
            string: "After table\n",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))

        let document = DocumentSerializer.serialize(original)
        XCTAssertEqual(document.elements.count, 3) // paragraph, table, paragraph

        if case .paragraph = document.elements[0] {} else { XCTFail("Expected paragraph") }
        if case .table = document.elements[1] {} else { XCTFail("Expected table") }
        if case .paragraph = document.elements[2] {} else { XCTFail("Expected paragraph") }
    }

    // MARK: - Empty Document

    func testEmptyDocumentRoundTrip() {
        let original = NSAttributedString(string: "")
        let document = DocumentSerializer.serialize(original)
        XCTAssertTrue(document.elements.isEmpty)

        let restored = DocumentSerializer.deserialize(document)
        XCTAssertEqual(restored.length, 0)
    }

    // MARK: - Image Round-Trip

    func testImageRoundTrip() {
        // Create a small test image
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 10, height: 10)).fill()
        image.unlockFocus()

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)

        let original = NSMutableAttributedString(attachment: attachment)
        original.append(NSAttributedString(string: "\n"))

        let document = DocumentSerializer.serialize(original)

        XCTAssertFalse(document.images.isEmpty, "Should have extracted image reference")
        XCTAssertNotNil(document.images.first?.data, "Image data should be present")

        // Verify element references the image
        if case .image(let imgElement) = document.elements[0] {
            XCTAssertEqual(imgElement.imageId, document.images[0].id)
            XCTAssertEqual(imgElement.width, 10)
            XCTAssertEqual(imgElement.height, 10)
        } else {
            XCTFail("Expected image element")
        }

        // Verify round-trip
        let restored = DocumentSerializer.deserialize(document)
        let restoredAttachment = restored.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        XCTAssertNotNil(restoredAttachment)
        XCTAssertNotNil(restoredAttachment?.image)
    }

    // MARK: - Link Round-Trip

    func testLinkRoundTrip() {
        let url = URL(string: "https://example.com")!
        let original = NSAttributedString(
            string: "Click here\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .link: url
            ]
        )

        let document = DocumentSerializer.serialize(original)

        if case .paragraph(let p) = document.elements[0] {
            XCTAssertEqual(p.runs[0].attributes.linkURL, "https://example.com")
        }

        let restored = DocumentSerializer.deserialize(document)
        let restoredLink = restored.attribute(.link, at: 0, effectiveRange: nil) as? URL
        XCTAssertEqual(restoredLink, url)
    }

    // MARK: - JSON Serialization Full Round-Trip

    func testFullJSONRoundTrip() throws {
        let fontManager = NSFontManager.shared
        let boldFont = fontManager.convert(
            NSFont.systemFont(ofSize: 16),
            toHaveTrait: .boldFontMask
        )

        let original = NSMutableAttributedString()
        original.append(NSAttributedString(
            string: "Title",
            attributes: [
                .font: boldFont,
                .foregroundColor: NSColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
            ]
        ))
        original.append(NSAttributedString(
            string: "\nBody text\n",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))

        // Serialize to NoteDocument
        let document = DocumentSerializer.serialize(original)

        // Encode to JSON
        let jsonData = try DocumentSerializer.encode(document)
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)

        // Decode from JSON
        let decodedDocument = try DocumentSerializer.decode(from: jsonData)

        // Deserialize back to NSAttributedString
        let restored = DocumentSerializer.deserialize(decodedDocument)

        // Verify text content survived the full JSON round-trip
        XCTAssertTrue(restored.string.contains("Title"))
        XCTAssertTrue(restored.string.contains("Body text"))

        // Verify bold survived
        let restoredFont = restored.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let traits = NSFontManager.shared.traits(of: restoredFont!)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    // MARK: - Font Size Preservation

    func testFontSizePreservation() {
        let original = NSMutableAttributedString()
        original.append(NSAttributedString(
            string: "Small\n",
            attributes: [.font: NSFont.systemFont(ofSize: 10)]
        ))
        original.append(NSAttributedString(
            string: "Large\n",
            attributes: [.font: NSFont.systemFont(ofSize: 24)]
        ))

        let document = DocumentSerializer.serialize(original)
        let restored = DocumentSerializer.deserialize(document)

        let smallFont = restored.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertEqual(smallFont?.pointSize, 10)

        let largeRange = (restored.string as NSString).range(of: "Large")
        let largeFont = restored.attribute(.font, at: largeRange.location, effectiveRange: nil) as? NSFont
        XCTAssertEqual(largeFont?.pointSize, 24)
    }
}
