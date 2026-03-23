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

    /// True if the device supports Apple Intelligence features (Apple Silicon + macOS 15+)
    static var isAvailable: Bool {
        guard isAppleSilicon else { return false }
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }

    /// Translation works on macOS 15+ (including Intel via server-side fallback)
    static var supportsTranslation: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }

    /// Foundation Models requires Apple Silicon + macOS 26.0+
    static var supportsFoundationModels: Bool {
        guard isAppleSilicon else { return false }
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }
}
