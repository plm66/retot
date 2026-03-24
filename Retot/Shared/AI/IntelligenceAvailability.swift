import Foundation

struct IntelligenceAvailability {
    /// True if running on Apple Silicon (not Rosetta on Intel)
    static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// True if the device supports Apple Intelligence features
    static var isAvailable: Bool {
        guard isAppleSilicon else { return false }
        #if os(macOS)
        if #available(macOS 15.0, *) {
            return true
        }
        return false
        #else
        if #available(iOS 18.0, *) {
            return true
        }
        return false
        #endif
    }

    /// Translation works on macOS 15+ / iOS 18+ (including Intel via server-side fallback)
    static var supportsTranslation: Bool {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            return true
        }
        return false
        #else
        if #available(iOS 18.0, *) {
            return true
        }
        return false
        #endif
    }

    /// Foundation Models requires Apple Silicon + macOS 26.0+ / iOS 26.0+
    static var supportsFoundationModels: Bool {
        guard isAppleSilicon else { return false }
        #if os(macOS)
        if #available(macOS 26.0, *) {
            return true
        }
        return false
        #else
        if #available(iOS 26.0, *) {
            return true
        }
        return false
        #endif
    }
}
