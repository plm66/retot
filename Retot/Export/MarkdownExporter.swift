import AppKit
import Foundation

enum MarkdownExporter {
    static func convert(_ attributedString: NSAttributedString) -> String {
        var result = ""
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let text = (attributedString.string as NSString).substring(with: range)

            // Check for image attachment
            if let attachment = attributes[.attachment] as? NSTextAttachment,
               attachment.image != nil || attachment.fileWrapper != nil {
                result += "![image]()"
                return
            }

            var segment = text

            // Detect font traits
            let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let traits = font.fontDescriptor.symbolicTraits
            let isBold = traits.contains(.bold)
            let isItalic = traits.contains(.italic)

            // Detect heading by font size
            if font.pointSize >= 24 {
                let lines = segment.components(separatedBy: "\n")
                segment = lines.map { line in
                    line.isEmpty ? line : "# \(line)"
                }.joined(separator: "\n")
            } else if font.pointSize >= 18 {
                let lines = segment.components(separatedBy: "\n")
                segment = lines.map { line in
                    line.isEmpty ? line : "## \(line)"
                }.joined(separator: "\n")
            } else {
                // Apply inline formatting
                if isBold && isItalic {
                    segment = "***\(segment)***"
                } else if isBold {
                    segment = "**\(segment)**"
                } else if isItalic {
                    segment = "*\(segment)*"
                }
            }

            // Strikethrough
            if let strikethrough = attributes[.strikethroughStyle] as? Int,
               strikethrough != 0 {
                segment = "~~\(segment)~~"
            }

            // Links (skip wiki links — preserve as-is)
            if let url = attributes[.link] as? URL {
                if url.scheme == "retot" {
                    // Wiki link — already in [[]] format in the text
                } else {
                    segment = "[\(text)](\(url.absoluteString))"
                }
            }

            result += segment
        }

        return result
    }
}
