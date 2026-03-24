#if os(macOS)
import AppKit
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformImage = UIImage
#endif

// MARK: - Normalized Color Names

extension PlatformColor {
    #if os(macOS)
    static var platformLabel: NSColor { .labelColor }
    static var platformSecondaryLabel: NSColor { .secondaryLabelColor }
    static var platformTextColor: NSColor { .textColor }
    #else
    static var platformLabel: UIColor { .label }
    static var platformSecondaryLabel: UIColor { .secondaryLabel }
    static var platformTextColor: UIColor { .label }
    #endif
}
