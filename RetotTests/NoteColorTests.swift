import XCTest
@testable import Retot

final class NoteColorTests: XCTestCase {

    func testDefaultPaletteHas10Colors() {
        XCTAssertEqual(NoteColor.defaultPalette.count, 10)
    }

    func testAllCasesMatchDefaultPalette() {
        XCTAssertEqual(NoteColor.allCases.count, NoteColor.defaultPalette.count)
    }

    func testRawValueRoundTrip() {
        for color in NoteColor.allCases {
            let raw = color.rawValue
            let restored = NoteColor(rawValue: raw)
            XCTAssertEqual(restored, color, "Round-trip failed for \(raw)")
        }
    }

    func testSwiftUIColorNotNil() {
        for color in NoteColor.allCases {
            // Just verify it doesn't crash
            _ = color.swiftUIColor
        }
    }

    func testNSColorNotNil() {
        for color in NoteColor.allCases {
            let nsColor = color.nsColor
            XCTAssertNotNil(nsColor)
        }
    }

    func testIdentifiableId() {
        for color in NoteColor.allCases {
            XCTAssertEqual(color.id, color.rawValue)
        }
    }

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for color in NoteColor.allCases {
            let data = try encoder.encode(color)
            let decoded = try decoder.decode(NoteColor.self, from: data)
            XCTAssertEqual(decoded, color)
        }
    }
}
