import AppKit
import XCTest
@testable import Retot

final class MarkdownExporterTests: XCTestCase {

    // MARK: - Plain Text

    func testPlainTextPassesThrough() {
        let input = NSAttributedString(string: "Hello world")
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testEmptyStringReturnsEmpty() {
        let input = NSAttributedString(string: "")
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "")
    }

    func testMultilineText() {
        let input = NSAttributedString(string: "Line 1\nLine 2\nLine 3")
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - Bold

    func testBoldText() {
        let input = makeAttributedString("bold text", traits: .boldFontMask)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "**bold text**")
    }

    // MARK: - Italic

    func testItalicText() {
        let input = makeAttributedString("italic text", traits: .italicFontMask)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "*italic text*")
    }

    // MARK: - Bold + Italic

    func testBoldItalicText() {
        let input = makeAttributedString("bold italic", traits: [.boldFontMask, .italicFontMask])
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "***bold italic***")
    }

    // MARK: - Strikethrough

    func testStrikethroughText() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ]
        let input = NSAttributedString(string: "deleted", attributes: attrs)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "~~deleted~~")
    }

    // MARK: - Links

    func testExternalLink() {
        let url = URL(string: "https://example.com")!
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .link: url
        ]
        let input = NSAttributedString(string: "click here", attributes: attrs)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "[click here](https://example.com)")
    }

    func testWikiLinkPreservedAsIs() {
        let url = URL(string: "retot://note/Shopping")!
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .link: url
        ]
        let input = NSAttributedString(string: "[[Shopping]]", attributes: attrs)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "[[Shopping]]")
    }

    // MARK: - Headings

    func testLargeFontBecomesH1() {
        let font = NSFont.systemFont(ofSize: 24, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let input = NSAttributedString(string: "Title", attributes: attrs)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "# Title")
    }

    func testMediumFontBecomesH2() {
        let font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let input = NSAttributedString(string: "Subtitle", attributes: attrs)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "## Subtitle")
    }

    func testNormalFontNoHeading() {
        let font = NSFont.systemFont(ofSize: 14)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let input = NSAttributedString(string: "Normal text", attributes: attrs)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "Normal text")
    }

    // MARK: - Mixed Content

    func testMixedPlainAndBold() {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(
            string: "Hello ",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))
        result.append(makeAttributedString("world", traits: .boldFontMask))
        result.append(NSAttributedString(
            string: "!",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        ))

        let markdown = MarkdownExporter.convert(result)
        XCTAssertEqual(markdown, "Hello **world**!")
    }

    // MARK: - Image Attachment

    func testImageAttachmentBecomesMarkdownImage() {
        let attachment = NSTextAttachment()
        attachment.image = NSImage(size: NSSize(width: 10, height: 10))
        let input = NSAttributedString(attachment: attachment)
        let result = MarkdownExporter.convert(input)
        XCTAssertEqual(result, "![image]()")
    }

    // MARK: - Helpers

    private func makeAttributedString(_ text: String, traits: NSFontTraitMask) -> NSAttributedString {
        let fontManager = NSFontManager.shared
        var font = NSFont.systemFont(ofSize: 14)
        font = fontManager.convert(font, toHaveTrait: traits)
        return NSAttributedString(string: text, attributes: [.font: font])
    }
}
