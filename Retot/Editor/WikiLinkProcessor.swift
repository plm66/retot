import AppKit
import Foundation

enum WikiLinkProcessor {
    private static let pattern = "\\[\\[(.+?)\\]\\]"

    static func processLinks(in textStorage: NSTextStorage, noteLabels: [String]) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let text = textStorage.string

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        // Remove existing wiki link attributes first
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            if let url = value as? URL, url.scheme == "retot" {
                textStorage.removeAttribute(.link, range: range)
                textStorage.removeAttribute(.underlineStyle, range: range)
                textStorage.addAttribute(
                    .foregroundColor,
                    value: NSColor.textColor,
                    range: range
                )
            }
        }

        // Find and apply wiki link attributes
        let matches = regex.matches(in: text, range: fullRange)
        for match in matches {
            let fullMatchRange = match.range
            guard let labelRange = Range(match.range(at: 1), in: text) else { continue }

            let label = String(text[labelRange])
            let encodedLabel = label.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ) ?? label
            let url = URL(string: "retot://note/\(encodedLabel)")!

            // Check if the label matches an existing note
            let exists = noteLabels.contains {
                $0.localizedCaseInsensitiveCompare(label) == .orderedSame
            }

            textStorage.addAttribute(.link, value: url, range: fullMatchRange)
            textStorage.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: fullMatchRange
            )
            textStorage.addAttribute(
                .foregroundColor,
                value: exists ? NSColor.linkColor : NSColor.systemGray,
                range: fullMatchRange
            )
        }
        textStorage.endEditing()
    }
}
