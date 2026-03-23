import AppKit
import SwiftUI

struct EditorToolbar: View {
    @EnvironmentObject var appState: AppState
    let onExport: () -> Void
    @State private var showClearConfirm = false
    @State private var fontSizeText: String = "14"

    var body: some View {
        HStack(spacing: 4) {
            toolbarButton("Undo", systemImage: "arrow.uturn.backward") {
                appState.currentTextView?.undoManager?.undo()
            }
            toolbarButton("Redo", systemImage: "arrow.uturn.forward") {
                appState.currentTextView?.undoManager?.redo()
            }

            Divider()
                .frame(height: 16)

            toolbarButton("Bold", systemImage: "bold") {
                applyFontTrait(.boldFontMask)
            }
            toolbarButton("Italic", systemImage: "italic") {
                applyFontTrait(.italicFontMask)
            }
            toolbarButton("Underline", systemImage: "underline") {
                applyUnderline()
            }
            toolbarButton("Strikethrough", systemImage: "strikethrough") {
                applyStrikethrough()
            }

            Divider()
                .frame(height: 16)

            toolbarButton("Heading", systemImage: "textformat.size.larger") {
                applyHeading()
            }
            toolbarButton("Bullet list", systemImage: "list.bullet") {
                applyBulletList()
            }

            Divider()
                .frame(height: 16)

            toolbarButton("Insert table", systemImage: "tablecells") {
                insertTable()
            }

            Divider()
                .frame(height: 16)

            HStack(spacing: 2) {
                Button(action: { adjustFontSize(by: -2); updateFontSizeText() }) {
                    Text("−")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help("Decrease font size")

                TextField("", text: $fontSizeText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 34, height: 20)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { applyDirectFontSize() }
                    .help("Type a font size (8–72) and press Enter")

                Button(action: { adjustFontSize(by: 2); updateFontSizeText() }) {
                    Text("+")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help("Increase font size")
            }
            .onAppear { updateFontSizeText() }

            Divider()
                .frame(height: 16)

            toolbarButton("AI Assistant", systemImage: "sparkles") {
                appState.showAIPopover.toggle()
            }
            .popover(isPresented: $appState.showAIPopover) {
                AIPopoverView()
                    .environmentObject(appState)
            }
            .disabled(!IntelligenceAvailability.supportsTranslation)
            .opacity(IntelligenceAvailability.supportsTranslation ? 1.0 : 0.5)

            Spacer()

            Button(action: { createPastille() }) {
                Text("Pastille")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderless)
            .help("Create a pastille — a movable content block (select text first)")
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)

            Button(action: { appState.detachNoteIndex = appState.selectedNoteIndex }) {
                Text("Float")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderless)
            .help("Detach current note as a floating window")
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)

            Spacer()

            toolbarButton("Reset text colors", systemImage: "paintbrush") {
                resetTextColors()
            }

            toolbarButton(appState.isPinnedOnTop ? "Unpin window" : "Pin on top", systemImage: appState.isPinnedOnTop ? "pin.fill" : "pin") {
                appState.togglePinOnTop()
            }

            toolbarButton("Search all notes", systemImage: "magnifyingglass") {
                appState.isSearching = true
            }

            toolbarButton("Clear note", systemImage: "trash") {
                showClearConfirm = true
            }
            .alert("Clear this note?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    appState.clearNote(appState.selectedNoteIndex)
                }
            } message: {
                Text("All content in \"\(appState.notes[appState.selectedNoteIndex].label)\" will be deleted. This cannot be undone.")
            }

            toolbarButton("Print / Save as PDF", systemImage: "printer") {
                appState.currentTextView?.printView(nil)
            }

            toolbarButton("Export as Markdown", systemImage: "square.and.arrow.up") {
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
        .help(label)
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

    private func createPastille() {
        guard let textView = appState.currentTextView as? RetotTextView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        textView.createPastille(in: range)
    }

    private func updateFontSizeText() {
        guard let textView = appState.currentTextView else { return }
        let range = textView.selectedRange()
        let index = range.location
        guard let textStorage = textView.textStorage, index < textStorage.length else {
            let font = textView.typingAttributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            fontSizeText = "\(Int(font.pointSize))"
            return
        }
        let font = textStorage.attribute(.font, at: max(0, index > 0 ? index - 1 : 0), effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: 14)
        fontSizeText = "\(Int(font.pointSize))"
    }

    private func applyDirectFontSize() {
        guard let size = Double(fontSizeText),
              size >= 8, size <= 72,
              let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }

        let targetSize = CGFloat(size)
        let range = textView.selectedRange()

        if range.length == 0 {
            var attrs = textView.typingAttributes
            let currentFont = attrs[.font] as? NSFont ?? NSFont.systemFont(ofSize: 14)
            attrs[.font] = NSFontManager.shared.convert(currentFont, toSize: targetSize)
            textView.typingAttributes = attrs
        } else {
            textStorage.beginEditing()
            textStorage.enumerateAttribute(.font, in: range) { value, attrRange, _ in
                guard let currentFont = value as? NSFont else { return }
                let newFont = NSFontManager.shared.convert(currentFont, toSize: targetSize)
                textStorage.addAttribute(.font, value: newFont, range: attrRange)
            }
            textStorage.endEditing()
        }
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

    private func resetTextColors() {
        guard let textView = appState.currentTextView,
              let textStorage = textView.textStorage else { return }

        let range: NSRange
        if textView.selectedRange().length > 0 {
            range = textView.selectedRange()
        } else {
            range = NSRange(location: 0, length: textStorage.length)
        }
        guard range.length > 0 else { return }

        // Clear inline foreground colors
        textStorage.beginEditing()
        textStorage.removeAttribute(.foregroundColor, range: range)
        textStorage.endEditing()

        // Also clear note-level font color so applyNoteColors doesn't re-apply
        appState.updateNoteFontColor(appState.selectedNoteIndex, hex: nil)
        textView.textColor = .textColor
        textView.didChangeText()
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
