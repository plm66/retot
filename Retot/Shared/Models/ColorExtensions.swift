#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

extension PlatformColor {

    static func fromHex(_ hex: String) -> PlatformColor? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        #if os(macOS)
        return PlatformColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
        #else
        return PlatformColor(red: r, green: g, blue: b, alpha: 1.0)
        #endif
    }

    func toHex() -> String {
        #if os(macOS)
        let converted = usingColorSpace(.sRGB) ?? self
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif

        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))

        return String(format: "%02X%02X%02X", ri, gi, bi)
    }
}

extension Color {

    init?(hex: String) {
        guard let color = PlatformColor.fromHex(hex) else { return nil }
        #if os(macOS)
        self.init(nsColor: color)
        #else
        self.init(uiColor: color)
        #endif
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
