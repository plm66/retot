import AppKit
import XCTest
@testable import Retot

final class WikiLinkProcessorTests: XCTestCase {

    // MARK: - Link Detection

    func testDetectsSingleWikiLink() {
        let textStorage = makeTextStorage("Check [[Note 2]] for details")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1", "Note 2"])

        let linkRange = NSRange(location: 6, length: 10) // [[Note 2]]
        let link = textStorage.attribute(.link, at: linkRange.location, effectiveRange: nil)
        XCTAssertNotNil(link)
    }

    func testDetectsMultipleWikiLinks() {
        let textStorage = makeTextStorage("See [[Note 1]] and [[Note 3]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1", "Note 3"])

        let link1 = textStorage.attribute(.link, at: 4, effectiveRange: nil)
        let link2 = textStorage.attribute(.link, at: 19, effectiveRange: nil)
        XCTAssertNotNil(link1)
        XCTAssertNotNil(link2)
    }

    func testNoLinksInPlainText() {
        let textStorage = makeTextStorage("Just some regular text")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])

        var hasLink = false
        textStorage.enumerateAttribute(.link, in: fullRange(textStorage)) { value, _, _ in
            if value != nil { hasLink = true }
        }
        XCTAssertFalse(hasLink)
    }

    func testSingleBracketsNotDetected() {
        let textStorage = makeTextStorage("Array [0] is not a link")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["0"])

        var hasLink = false
        textStorage.enumerateAttribute(.link, in: fullRange(textStorage)) { value, _, _ in
            if value != nil { hasLink = true }
        }
        XCTAssertFalse(hasLink)
    }

    // MARK: - URL Scheme

    func testLinkUsesRetotScheme() {
        let textStorage = makeTextStorage("Go to [[Shopping]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Shopping"])

        let link = textStorage.attribute(.link, at: 6, effectiveRange: nil) as? URL
        XCTAssertEqual(link?.scheme, "retot")
        XCTAssertEqual(link?.host, "note")
    }

    func testLinkEncodesLabel() {
        let textStorage = makeTextStorage("Go to [[My Notes]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["My Notes"])

        let link = textStorage.attribute(.link, at: 6, effectiveRange: nil) as? URL
        XCTAssertNotNil(link)
        XCTAssertTrue(link?.absoluteString.contains("My%20Notes") ?? false)
    }

    // MARK: - Existing vs Non-existing Notes

    func testExistingNoteGetsLinkColor() {
        let textStorage = makeTextStorage("See [[Note 1]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])

        let color = textStorage.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor.linkColor)
    }

    func testNonExistingNoteGetsGrayColor() {
        let textStorage = makeTextStorage("See [[Unknown]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1", "Note 2"])

        let color = textStorage.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor.systemGray)
    }

    // MARK: - Underline Style

    func testWikiLinkGetsUnderline() {
        let textStorage = makeTextStorage("See [[Note 1]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])

        let underline = textStorage.attribute(.underlineStyle, at: 4, effectiveRange: nil) as? Int
        XCTAssertEqual(underline, NSUnderlineStyle.single.rawValue)
    }

    // MARK: - Stale Link Removal

    func testRemovesStaleLinks() {
        let textStorage = makeTextStorage("See [[Note 1]]")

        // First pass: add link
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])
        let linkBefore = textStorage.attribute(.link, at: 4, effectiveRange: nil)
        XCTAssertNotNil(linkBefore)

        // Modify text to remove the wiki syntax
        textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: "See Note 1")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])

        var hasLink = false
        textStorage.enumerateAttribute(.link, in: fullRange(textStorage)) { value, _, _ in
            if let url = value as? URL, url.scheme == "retot" { hasLink = true }
        }
        XCTAssertFalse(hasLink)
    }

    // MARK: - Case Insensitive Matching

    func testCaseInsensitiveNoteMatching() {
        let textStorage = makeTextStorage("See [[note 1]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])

        let color = textStorage.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, NSColor.linkColor, "Case-insensitive match should show as existing")
    }

    // MARK: - Edge Cases

    func testEmptyBracketsNotDetected() {
        let textStorage = makeTextStorage("Empty [[]] brackets")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])

        // [[]] should not match since .+? requires at least one char
        var hasLink = false
        textStorage.enumerateAttribute(.link, in: fullRange(textStorage)) { value, _, _ in
            if value != nil { hasLink = true }
        }
        XCTAssertFalse(hasLink)
    }

    func testNestedBracketsHandled() {
        let textStorage = makeTextStorage("See [[[Note 1]]]")
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: ["Note 1"])

        // Should still detect the inner [[Note 1]]
        var hasLink = false
        textStorage.enumerateAttribute(.link, in: fullRange(textStorage)) { value, _, _ in
            if value != nil { hasLink = true }
        }
        XCTAssertTrue(hasLink)
    }

    // MARK: - Helpers

    private func makeTextStorage(_ text: String) -> NSTextStorage {
        NSTextStorage(string: text)
    }

    private func fullRange(_ textStorage: NSTextStorage) -> NSRange {
        NSRange(location: 0, length: textStorage.length)
    }
}
