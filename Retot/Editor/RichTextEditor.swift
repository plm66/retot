import AppKit
import SwiftUI

class RetotTextView: NSTextView {

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        // Priority 1: HTML content from the pasteboard
        if let htmlData = pasteboard.data(forType: .html) {
            if let attributed = try? NSAttributedString(
                data: htmlData,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            ) {
                let mutable = NSMutableAttributedString(attributedString: attributed)
                // Normalize font to system default where not explicitly styled
                let fullRange = NSRange(location: 0, length: mutable.length)
                mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                    guard let font = value as? NSFont else { return }
                    // Keep bold/italic traits but normalize to system font
                    let traits = NSFontManager.shared.traits(of: font)
                    let size = max(font.pointSize, 12)
                    var newFont = NSFont.systemFont(ofSize: size)
                    if traits.contains(.boldFontMask) {
                        newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .boldFontMask)
                    }
                    if traits.contains(.italicFontMask) {
                        newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .italicFontMask)
                    }
                    mutable.addAttribute(.font, value: newFont, range: range)
                }
                insertAttributedString(mutable)
                return
            }
        }

        // Priority 2: Plain text that looks like a markdown table
        if let plainText = pasteboard.string(forType: .string),
           Self.isMarkdownTable(plainText) {
            let tableAttr = Self.markdownTableToAttributedString(plainText)
            insertAttributedString(tableAttr)
            return
        }

        // Default paste
        super.paste(sender)
    }

    private func insertAttributedString(_ attrString: NSAttributedString) {
        guard let textStorage = self.textStorage else { return }
        let range = selectedRange()
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: attrString)
        textStorage.endEditing()
        let newPos = range.location + attrString.length
        setSelectedRange(NSRange(location: newPos, length: 0))
        didChangeText()
    }

    // MARK: - Markdown Table Detection

    static func isMarkdownTable(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return false }
        // Check if at least 2 lines have pipe characters
        let pipeLines = lines.filter { $0.contains("|") }
        return pipeLines.count >= 2
    }

    // MARK: - Markdown Table to NSTextTable

    static func markdownTableToAttributedString(_ markdown: String) -> NSAttributedString {
        let lines = markdown.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Parse rows, skipping separator lines (lines with only |, -, :, spaces)
        var rows: [[String]] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip separator lines like |---|---|
            if trimmed.allSatisfy({ $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }) {
                continue
            }
            // Split by | and trim
            var cells = trimmed.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            // Remove empty first/last from leading/trailing pipes
            if cells.first?.isEmpty == true { cells.removeFirst() }
            if cells.last?.isEmpty == true { cells.removeLast() }
            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        guard !rows.isEmpty else {
            return NSAttributedString(string: markdown)
        }

        // Determine column count from the row with most cells
        let cols = rows.map(\.count).max() ?? 1

        let table = NSTextTable()
        table.numberOfColumns = cols
        table.collapsesBorders = true
        table.hidesEmptyCells = false

        let result = NSMutableAttributedString()

        // Add newline before table
        result.append(NSAttributedString(string: "\n"))

        for (rowIndex, row) in rows.enumerated() {
            for colIndex in 0..<cols {
                let cellText = colIndex < row.count ? row[colIndex] : ""

                let block = NSTextTableBlock(
                    table: table,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: colIndex,
                    columnSpan: 1
                )

                block.setWidth(1.0, type: .absoluteValueType, for: .border)
                block.setBorderColor(.separatorColor)
                block.setWidth(6.0, type: .absoluteValueType, for: .padding)
                block.setContentWidth(100.0 / CGFloat(cols), type: .percentageValueType)

                // Header row (first row) gets background
                if rowIndex == 0 {
                    block.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
                }

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [block]

                let isHeader = rowIndex == 0
                let font = isHeader
                    ? NSFont.systemFont(ofSize: 13, weight: .semibold)
                    : NSFont.systemFont(ofSize: 13)

                let cellString = NSMutableAttributedString(
                    string: "\(cellText)\n",
                    attributes: [
                        .paragraphStyle: paragraphStyle,
                        .font: font,
                        .foregroundColor: NSColor.textColor
                    ]
                )
                result.append(cellString)
            }
        }

        // Add newline after table
        result.append(NSAttributedString(string: "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ]))

        return result
    }
}

struct RichTextEditor: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> RichTextCoordinator {
        RichTextCoordinator(
            appState: appState,
            noteId: appState.notes[appState.selectedNoteIndex].id
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = RetotTextView()
        textView.isRichText = true
        textView.allowsImageEditing = true
        textView.importsGraphics = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.delegate = context.coordinator

        // Allow rich paste types
        textView.registerForDraggedTypes([
            .rtfd, .rtf, .html, .string, .tiff, .png, .fileURL
        ])

        // Configure text container for wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        // Set default font
        textView.font = NSFont.systemFont(ofSize: 14)

        scrollView.documentView = textView

        // Load initial content and apply note colors
        let currentNote = appState.notes[appState.selectedNoteIndex]
        loadContent(into: textView, noteIndex: appState.selectedNoteIndex)
        applyNoteColors(to: textView, note: currentNote)
        appState.currentTextView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? RetotTextView else { return }

        let currentNote = appState.notes[appState.selectedNoteIndex]
        let currentNoteId = currentNote.id

        // Always apply colors (they may change without note switch)
        applyNoteColors(to: textView, note: currentNote)

        // Only reload content when the selected note changes
        if context.coordinator.currentNoteId != currentNoteId {
            context.coordinator.updateNoteId(currentNoteId)
            loadContent(into: textView, noteIndex: appState.selectedNoteIndex)
            appState.currentTextView = textView
        }
    }

    private func applyNoteColors(to textView: NSTextView, note: Note) {
        if let bgHex = note.backgroundColorHex,
           let bgColor = NSColor.fromHex(bgHex) {
            textView.backgroundColor = bgColor
        } else {
            textView.backgroundColor = .textBackgroundColor
        }

        let fontColor: NSColor
        if let fgHex = note.fontColorHex,
           let fgColor = NSColor.fromHex(fgHex) {
            fontColor = fgColor
        } else {
            fontColor = .textColor
        }
        textView.textColor = fontColor
    }

    private func loadContent(into textView: NSTextView, noteIndex: Int) {
        let content = appState.currentAttributedText
        textView.textStorage?.setAttributedString(content)

        // Set default typing attributes if empty
        if content.length == 0 {
            textView.typingAttributes = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.textColor
            ]
        }
    }

    // Track which note we loaded via coordinator's currentNoteId
    // This avoids the infinite update loop: SwiftUI state change -> updateNSView -> text change -> SwiftUI state change
}
