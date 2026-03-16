import AppKit
import SwiftUI

extension NSColor {

    static func fromHex(_ hex: String) -> NSColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    func toHex() -> String {
        let converted = usingColorSpace(.sRGB) ?? self
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)

        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))

        return String(format: "%02X%02X%02X", ri, gi, bi)
    }
}

extension Color {

    init?(hex: String) {
        guard let nsColor = NSColor.fromHex(hex) else { return nil }
        self.init(nsColor: nsColor)
    }
}

struct EditorColorPalette {

    static let editorPalette: [(name: String, hex: String)] = [
        ("Black", "000000"),
        ("White", "FFFFFF"),
        ("Dark Gray", "333333"),
        ("Light Gray", "E5E5E5"),
        ("Red", "E53535"),
        ("Blue", "2580FF"),
        ("Green", "28C864"),
        ("Orange", "F59B0A"),
        ("Purple", "6658E4"),
        ("Brown", "9E7D5A"),
        ("Cream", "FFF8E7"),
        ("Navy", "1A1A3E"),
    ]
}
