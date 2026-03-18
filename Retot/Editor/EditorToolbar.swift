import AppKit
import SwiftUI

struct EditorToolbar: View {
    @EnvironmentObject var appState: AppState
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            toolbarButton("bold", systemImage: "bold") {
                applyFontTrait(.boldFontMask)
            }
            toolbarButton("italic", systemImage: "italic") {
                applyFontTrait(.italicFontMask)
            }
            toolbarButton("underline", systemImage: "underline") {
                applyUnderline()
            }
            toolbarButton("strikethrough", systemImage: "strikethrough") {
                applyStrikethrough()
            }

            Divider()
                .frame(height: 16)

            toolbarButton("heading", systemImage: "textformat.size.larger") {
                applyHeading()
            }
            toolbarButton("list", systemImage: "list.bullet") {
                applyBulletList()
            }

            Divider()
                .frame(height: 16)

            toolbarButton("table", systemImage: "tablecells") {
                insertTable()
            }

            Divider()
                .frame(height: 16)

            toolbarButton("decrease font", systemImage: "minus.magnifyingglass") {
                adjustFontSize(by: -2)
            }
            toolbarButton("increase font", systemImage: "plus.magnifyingglass") {
                adjustFontSize(by: 2)
            }

            Spacer()

            toolbarButton("export", systemImage: "square.and.arrow.up") {
                onExport()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func toolbarButton(
        _ label: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
    }

    private func applyFontTrait(_ trait: NSFontTraitMask) {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let fontManager = NSFontManager.shared
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let newFont = fontManager.convert(currentFont, toHaveTrait: trait)
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
    }

    private func applyUnderline() {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        textStorage.beginEditing()
        let hasUnderline = textStorage.attribute(
            .underlineStyle,
            at: range.location,
            effectiveRange: nil
        ) as? Int ?? 0

        if hasUnderline != 0 {
            textStorage.removeAttribute(.underlineStyle, range: range)
        } else {
            textStorage.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: range
            )
        }
        textStorage.endEditing()
    }

    private func applyStrikethrough() {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        textStorage.beginEditing()
        let hasStrikethrough = textStorage.attribute(
            .strikethroughStyle,
            at: range.location,
            effectiveRange: nil
        ) as? Int ?? 0

        if hasStrikethrough != 0 {
            textStorage.removeAttribute(.strikethroughStyle, range: range)
        } else {
            textStorage.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: range
            )
        }
        textStorage.endEditing()
    }

    private func applyHeading() {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let currentFont = textStorage.attribute(
            .font,
            at: range.location,
            effectiveRange: nil
        ) as? NSFont ?? NSFont.systemFont(ofSize: 14)

        let newSize: CGFloat = currentFont.pointSize >= 20 ? 14 : 24
        let newFont = NSFont.systemFont(ofSize: newSize, weight: newSize >= 20 ? .bold : .regular)

        textStorage.beginEditing()
        textStorage.addAttribute(.font, value: newFont, range: range)
        textStorage.endEditing()
    }

    private func insertTable() {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }

        let rows = 3
        let cols = 3
        let insertionPoint = textView.selectedRange().location

        let table = NSTextTable()
        table.numberOfColumns = cols
        table.collapsesBorders = true
        table.hidesEmptyCells = false

        let tableString = NSMutableAttributedString()

        // Add a newline before the table if not at start
        if insertionPoint > 0 {
            tableString.append(NSAttributedString(string: "\n"))
        }

        for row in 0..<rows {
            for col in 0..<cols {
                let block = NSTextTableBlock(
                    table: table,
                    startingRow: row,
                    rowSpan: 1,
                    startingColumn: col,
                    columnSpan: 1
                )

                // Cell styling
                block.setWidth(1.0, type: .absoluteValueType, for: .border)
                block.setBorderColor(.separatorColor)
                block.setWidth(6.0, type: .absoluteValueType, for: .padding)
                block.setContentWidth(100.0 / CGFloat(cols), type: .percentageValueType)

                // Header row gets a subtle background
                if row == 0 {
                    block.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
                }

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [block]

                let isHeader = row == 0
                let font = isHeader
                    ? NSFont.systemFont(ofSize: 13, weight: .semibold)
                    : NSFont.systemFont(ofSize: 13)

                let cellText = isHeader ? "Header" : " "

                let cellString = NSMutableAttributedString(
                    string: "\(cellText)\n",
                    attributes: [
                        .paragraphStyle: paragraphStyle,
                        .font: font,
                        .foregroundColor: NSColor.textColor
                    ]
                )
                tableString.append(cellString)
            }
        }

        // Add a newline after the table
        tableString.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ]))

        textStorage.beginEditing()
        let range = textView.selectedRange()
        textStorage.replaceCharacters(in: range, with: tableString)
        textStorage.endEditing()

        // Place cursor after the table
        let newPosition = insertionPoint + tableString.length
        textView.setSelectedRange(NSRange(location: newPosition, length: 0))
    }

    private func adjustFontSize(by delta: CGFloat) {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }

        let range = textView.selectedRange()

        if range.length == 0 {
            var attrs = textView.typingAttributes
            let currentFont = attrs[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            let newSize = max(8, min(72, currentFont.pointSize + delta))
            let newFont = NSFontManager.shared.convert(currentFont, toSize: newSize)
            attrs[.font] = newFont
            textView.typingAttributes = attrs
            return
        }

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
            guard let currentFont = value as? NSFont else { return }
            let newSize = max(8, min(72, currentFont.pointSize + delta))
            let newFont = NSFontManager.shared.convert(currentFont, toSize: newSize)
            textStorage.addAttribute(.font, value: newFont, range: attrRange)
        }
        textStorage.endEditing()
    }

    private func applyBulletList() {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let text = textStorage.string as NSString
        let lineRange = text.lineRange(for: range)
        let lineText = text.substring(with: lineRange)

        textStorage.beginEditing()
        if lineText.hasPrefix("• ") {
            let newText = String(lineText.dropFirst(2))
            textStorage.replaceCharacters(in: lineRange, with: newText)
        } else {
            textStorage.replaceCharacters(in: lineRange, with: "• \(lineText)")
        }
        textStorage.endEditing()
    }
}
