#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

enum NoteColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case teal
    case blue
    case indigo
    case purple
    case pink
    case brown

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        }
    }

    var platformColor: PlatformColor {
        #if os(macOS)
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .teal: return .systemTeal
        case .blue: return .systemBlue
        case .indigo: return .systemIndigo
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .brown: return .systemBrown
        }
        #else
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .teal: return .systemTeal
        case .blue: return .systemBlue
        case .indigo: return .systemIndigo
        case .purple: return .systemPurple
        case .pink: return .systemPink
        case .brown: return .systemBrown
        }
        #endif
    }

    #if os(macOS)
    var nsColor: NSColor { platformColor }
    #endif

    static let defaultPalette: [NoteColor] = [
        .red, .orange, .yellow, .green, .teal,
        .blue, .indigo, .purple, .pink, .brown
    ]
}
