import AppKit
import SwiftUI

class RetotTextView: NSTextView {

    weak var appState: AppState?

    // MARK: - Format Painter

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if appState?.formatPainterActive == true && selectedRange().length > 0 {
            appState?.applyFormat()
        }
    }

    // MARK: - Print

    override func printView(_ sender: Any?) {
        // Create a temporary copy with print-friendly colors
        guard let textStorage = self.textStorage else {
            super.printView(sender)
            return
        }

        let printContent = NSMutableAttributedString(attributedString: textStorage)
        let fullRange = NSRange(location: 0, length: printContent.length)

        // Force black text for printing
        printContent.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if let color = value as? NSColor {
                let brightness = color.usingColorSpace(.sRGB).map {
                    $0.redComponent * 0.299 + $0.greenComponent * 0.587 + $0.blueComponent * 0.114
                } ?? 0.5
                // Light text (designed for dark background) → make it black
                if brightness > 0.7 {
                    printContent.addAttribute(.foregroundColor, value: NSColor.black, range: range)
                }
            }
        }

        // Create a temporary text view for printing
        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        printView.textStorage?.setAttributedString(printContent)
        printView.backgroundColor = .white
        printView.textContainerInset = NSSize(width: 36, height: 36)
        printView.isEditable = false

        let printOp = NSPrintOperation(view: printView)
        printOp.printInfo.isHorizontallyCentered = false
        printOp.printInfo.isVerticallyCentered = false
        printOp.runModal(for: self.window!, delegate: nil, didRun: nil, contextInfo: nil)
    }

    // MARK: - Paste

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

    // MARK: - Pastille Helpers

    static let pastilleBackgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.06)
    static let pastilleBorderColor = NSColor.controlAccentColor.withAlphaComponent(0.35)

    func isPastille(at charIndex: Int) -> Bool {
        guard let textStorage = self.textStorage,
              charIndex >= 0, charIndex < textStorage.length else { return false }
        guard let paraStyle = textStorage.attribute(
            .paragraphStyle, at: charIndex, effectiveRange: nil
        ) as? NSParagraphStyle else { return false }
        // A pastille is a non-table text block
        return paraStyle.textBlocks.contains { !($0 is NSTextTableBlock) }
    }

    func pastilleRange(at charIndex: Int) -> NSRange? {
        guard isPastille(at: charIndex),
              let textStorage = self.textStorage else { return nil }
        let string = textStorage.string as NSString
        let length = string.length

        // Find the paragraph containing charIndex
        let paraRange = string.paragraphRange(for: NSRange(location: charIndex, length: 0))

        // Expand upward to include contiguous pastille paragraphs
        var start = paraRange.location
        while start > 0 {
            let prevParaRange = string.paragraphRange(for: NSRange(location: start - 1, length: 0))
            if isPastille(at: prevParaRange.location) {
                start = prevParaRange.location
            } else {
                break
            }
        }

        // Expand downward
        var end = NSMaxRange(paraRange)
        while end < length {
            if isPastille(at: end) {
                let nextParaRange = string.paragraphRange(for: NSRange(location: end, length: 0))
                end = NSMaxRange(nextParaRange)
            } else {
                break
            }
        }

        return NSRange(location: start, length: end - start)
    }

    func createPastille(in range: NSRange) {
        guard let textStorage = self.textStorage else { return }
        let string = textStorage.string as NSString
        let paraRange = string.paragraphRange(for: range)

        let block = NSTextBlock()
        block.setWidth(1.5, type: .absoluteValueType, for: .border)
        block.setBorderColor(Self.pastilleBorderColor)
        block.setWidth(8.0, type: .absoluteValueType, for: .padding)
        block.backgroundColor = Self.pastilleBackgroundColor
        block.setContentWidth(100, type: .percentageValueType)

        textStorage.beginEditing()
        var loc = paraRange.location
        while loc < NSMaxRange(paraRange) {
            let currentParaRange = string.paragraphRange(for: NSRange(location: loc, length: 0))
            let existingStyle = textStorage.attribute(
                .paragraphStyle, at: loc, effectiveRange: nil
            ) as? NSParagraphStyle ?? NSParagraphStyle.default
            let newStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle

            // Skip paragraphs inside tables
            let isInTable = newStyle.textBlocks.contains { $0 is NSTextTableBlock }
            if isInTable {
                loc = NSMaxRange(currentParaRange)
                continue
            }

            newStyle.textBlocks = [block]
            textStorage.addAttribute(.paragraphStyle, value: newStyle, range: currentParaRange)
            loc = NSMaxRange(currentParaRange)
        }
        textStorage.endEditing()
        didChangeText()
    }

    func removePastilleFormatting(in range: NSRange) {
        guard let textStorage = self.textStorage else { return }
        let string = textStorage.string as NSString

        textStorage.beginEditing()
        var loc = range.location
        while loc < NSMaxRange(range) {
            let currentParaRange = string.paragraphRange(for: NSRange(location: loc, length: 0))
            if let existingStyle = textStorage.attribute(
                .paragraphStyle, at: loc, effectiveRange: nil
            ) as? NSParagraphStyle {
                let newStyle = existingStyle.mutableCopy() as! NSMutableParagraphStyle
                // Remove only non-table blocks (pastille blocks)
                newStyle.textBlocks = newStyle.textBlocks.filter { $0 is NSTextTableBlock }
                textStorage.addAttribute(.paragraphStyle, value: newStyle, range: currentParaRange)
            }
            loc = NSMaxRange(currentParaRange)
        }
        textStorage.endEditing()
        didChangeText()
    }

    // MARK: - Table Helpers

    func tableBlock(at charIndex: Int) -> NSTextTableBlock? {
        guard let textStorage = self.textStorage,
              charIndex >= 0, charIndex < textStorage.length,
              let paraStyle = textStorage.attribute(
                  .paragraphStyle, at: charIndex, effectiveRange: nil
              ) as? NSParagraphStyle else { return nil }
        return paraStyle.textBlocks.compactMap { $0 as? NSTextTableBlock }.first
    }

    func parseTable(at charIndex: Int) -> (table: NSTextTable, cells: [[NSAttributedString]], tableRange: NSRange)? {
        guard let textStorage = self.textStorage,
              let range = tableRange(at: charIndex) else { return nil }

        var table: NSTextTable?
        var cellMap: [(row: Int, col: Int, content: NSAttributedString)] = []
        let string = textStorage.string as NSString
        var loc = range.location

        while loc < NSMaxRange(range) {
            let paraRange = string.paragraphRange(for: NSRange(location: loc, length: 0))
            if let block = tableBlock(at: loc) {
                if table == nil { table = block.table }
                // Extract cell content without trailing newline
                var contentRange = paraRange
                let paraText = string.substring(with: paraRange)
                if paraText.hasSuffix("\n") {
                    contentRange.length -= 1
                }
                let content = textStorage.attributedSubstring(from: contentRange)
                cellMap.append((row: block.startingRow, col: block.startingColumn, content: content))
            }
            loc = NSMaxRange(paraRange)
        }

        guard let foundTable = table else { return nil }

        let maxRow = cellMap.map(\.row).max() ?? 0
        let maxCol = cellMap.map(\.col).max() ?? 0
        var grid: [[NSAttributedString]] = Array(
            repeating: Array(repeating: NSAttributedString(string: " "), count: maxCol + 1),
            count: maxRow + 1
        )
        for cell in cellMap {
            if cell.row <= maxRow, cell.col <= maxCol {
                grid[cell.row][cell.col] = cell.content
            }
        }

        return (table: foundTable, cells: grid, tableRange: range)
    }

    func buildTable(rows: [[NSAttributedString]], headerRow: Bool = true) -> NSAttributedString {
        let rowCount = rows.count
        let colCount = rows.map(\.count).max() ?? 1

        let table = NSTextTable()
        table.numberOfColumns = colCount
        table.collapsesBorders = true
        table.hidesEmptyCells = false

        let result = NSMutableAttributedString()

        for (rowIndex, row) in rows.enumerated() {
            for colIndex in 0..<colCount {
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
                block.setContentWidth(100.0 / CGFloat(colCount), type: .percentageValueType)

                let isHeader = headerRow && rowIndex == 0
                if isHeader {
                    block.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
                }

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.textBlocks = [block]

                let font = isHeader
                    ? NSFont.systemFont(ofSize: 13, weight: .semibold)
                    : NSFont.systemFont(ofSize: 13)

                let cellContent: NSAttributedString
                if colIndex < row.count {
                    cellContent = row[colIndex]
                } else {
                    cellContent = NSAttributedString(string: " ")
                }

                // Build cell: use content text but apply table paragraph style
                let cellString = NSMutableAttributedString(
                    string: cellContent.string + "\n",
                    attributes: [
                        .paragraphStyle: paragraphStyle,
                        .font: font,
                        .foregroundColor: NSColor.textColor
                    ]
                )
                result.append(cellString)
            }
        }

        return result
    }

    func isTable(at charIndex: Int) -> Bool {
        guard let textStorage = self.textStorage,
              charIndex >= 0, charIndex < textStorage.length else { return false }
        guard let paraStyle = textStorage.attribute(
            .paragraphStyle, at: charIndex, effectiveRange: nil
        ) as? NSParagraphStyle else { return false }
        return paraStyle.textBlocks.contains { $0 is NSTextTableBlock }
    }

    func tableRange(at charIndex: Int) -> NSRange? {
        guard isTable(at: charIndex),
              let textStorage = self.textStorage else { return nil }
        let string = textStorage.string as NSString
        let length = string.length

        let paraRange = string.paragraphRange(for: NSRange(location: charIndex, length: 0))

        var start = paraRange.location
        while start > 0 {
            let prevParaRange = string.paragraphRange(for: NSRange(location: start - 1, length: 0))
            if isTable(at: prevParaRange.location) {
                start = prevParaRange.location
            } else {
                break
            }
        }

        var end = NSMaxRange(paraRange)
        while end < length {
            if isTable(at: end) {
                let nextParaRange = string.paragraphRange(for: NSRange(location: end, length: 0))
                end = NSMaxRange(nextParaRange)
            } else {
                break
            }
        }

        return NSRange(location: start, length: end - start)
    }

    // MARK: - Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        let point = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: point)

        // Reset colors item (always available)
        let resetColorsItem = NSMenuItem(
            title: "Reset Text Colors",
            action: #selector(resetTextColorsAction(_:)),
            keyEquivalent: ""
        )
        resetColorsItem.target = self
        menu.insertItem(resetColorsItem, at: 0)
        menu.insertItem(.separator(), at: 1)

        // Table context menu
        if isTable(at: charIndex) {
            menu.insertItem(.separator(), at: 0)

            let deleteTableItem = NSMenuItem(
                title: "Delete Table",
                action: #selector(deleteTableAction(_:)),
                keyEquivalent: ""
            )
            deleteTableItem.representedObject = charIndex
            deleteTableItem.target = self
            menu.insertItem(deleteTableItem, at: 0)

            let deleteColItem = NSMenuItem(
                title: "Delete Column",
                action: #selector(deleteColumnAction(_:)),
                keyEquivalent: ""
            )
            deleteColItem.representedObject = charIndex
            deleteColItem.target = self
            menu.insertItem(deleteColItem, at: 0)

            let deleteRowItem = NSMenuItem(
                title: "Delete Row",
                action: #selector(deleteRowAction(_:)),
                keyEquivalent: ""
            )
            deleteRowItem.representedObject = charIndex
            deleteRowItem.target = self
            menu.insertItem(deleteRowItem, at: 0)

            menu.insertItem(.separator(), at: 0)

            let addColRightItem = NSMenuItem(
                title: "Add Column Right",
                action: #selector(addColumnRightAction(_:)),
                keyEquivalent: ""
            )
            addColRightItem.representedObject = charIndex
            addColRightItem.target = self
            menu.insertItem(addColRightItem, at: 0)

            let addColLeftItem = NSMenuItem(
                title: "Add Column Left",
                action: #selector(addColumnLeftAction(_:)),
                keyEquivalent: ""
            )
            addColLeftItem.representedObject = charIndex
            addColLeftItem.target = self
            menu.insertItem(addColLeftItem, at: 0)

            let addRowBelowItem = NSMenuItem(
                title: "Add Row Below",
                action: #selector(addRowBelowAction(_:)),
                keyEquivalent: ""
            )
            addRowBelowItem.representedObject = charIndex
            addRowBelowItem.target = self
            menu.insertItem(addRowBelowItem, at: 0)

            let addRowAboveItem = NSMenuItem(
                title: "Add Row Above",
                action: #selector(addRowAboveAction(_:)),
                keyEquivalent: ""
            )
            addRowAboveItem.representedObject = charIndex
            addRowAboveItem.target = self
            menu.insertItem(addRowAboveItem, at: 0)
        }

        // Pastille context menu
        if isPastille(at: charIndex) {
            menu.insertItem(.separator(), at: 0)

            let removeItem = NSMenuItem(
                title: "Remove Pastille",
                action: #selector(removePastilleAction(_:)),
                keyEquivalent: ""
            )
            removeItem.representedObject = charIndex
            removeItem.target = self
            menu.insertItem(removeItem, at: 0)

            if let notes = appState?.notes,
               let selectedIndex = appState?.selectedNoteIndex {
                let moveItem = NSMenuItem(title: "Move to...", action: nil, keyEquivalent: "")
                let moveMenu = NSMenu()
                for (index, note) in notes.enumerated() {
                    if index != selectedIndex {
                        let noteItem = NSMenuItem(
                            title: "\(note.label) (Dot \(note.id))",
                            action: #selector(movePastilleAction(_:)),
                            keyEquivalent: ""
                        )
                        noteItem.tag = index
                        noteItem.representedObject = charIndex
                        noteItem.target = self
                        moveMenu.addItem(noteItem)
                    }
                }
                moveItem.submenu = moveMenu
                menu.insertItem(moveItem, at: 0)
            }
        }

        // Image context menu
        if let attachment = imageAttachment(at: charIndex) {
            menu.insertItem(.separator(), at: 0)

            let sizes: [(String, CGFloat)] = [
                ("Small (128px)", 128),
                ("Medium (256px)", 256),
                ("Large (512px)", 512),
                ("Extra Large (768px)", 768),
                ("Original Size", 0)
            ]

            let resizeItem = NSMenuItem(title: "Resize Image", action: nil, keyEquivalent: "")
            let resizeMenu = NSMenu()
            for (label, width) in sizes {
                let item = NSMenuItem(
                    title: label,
                    action: #selector(resizeImageAction(_:)),
                    keyEquivalent: ""
                )
                item.tag = Int(width)
                item.representedObject = charIndex
                item.target = self
                resizeMenu.addItem(item)
            }
            resizeItem.submenu = resizeMenu
            menu.insertItem(resizeItem, at: 0)

            let deleteImgItem = NSMenuItem(
                title: "Delete Image",
                action: #selector(deleteImageAction(_:)),
                keyEquivalent: ""
            )
            deleteImgItem.representedObject = charIndex
            deleteImgItem.target = self
            menu.insertItem(deleteImgItem, at: 0)
        }

        return menu
    }

    // MARK: - Image Helpers

    private func imageAttachment(at charIndex: Int) -> NSTextAttachment? {
        guard let textStorage = self.textStorage,
              charIndex >= 0, charIndex < textStorage.length else { return nil }
        return textStorage.attribute(.attachment, at: charIndex, effectiveRange: nil) as? NSTextAttachment
    }

    @objc private func resizeImageAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let textStorage = self.textStorage,
              charIndex >= 0, charIndex < textStorage.length,
              let attachment = textStorage.attribute(.attachment, at: charIndex, effectiveRange: nil) as? NSTextAttachment else { return }

        let targetWidth = CGFloat(sender.tag)

        if targetWidth == 0 {
            // Original size: reset bounds
            attachment.bounds = .zero
        } else if let image = attachment.image {
            let aspect = image.size.height / image.size.width
            attachment.bounds = CGRect(x: 0, y: 0, width: targetWidth, height: targetWidth * aspect)
        } else {
            attachment.bounds = CGRect(x: 0, y: 0, width: targetWidth, height: targetWidth * 0.75)
        }

        // Force layout refresh
        let range = NSRange(location: charIndex, length: 1)
        textStorage.beginEditing()
        textStorage.edited(.editedAttributes, range: range, changeInLength: 0)
        textStorage.endEditing()
        didChangeText()
    }

    @objc private func deleteImageAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let textStorage = self.textStorage,
              charIndex >= 0, charIndex < textStorage.length else { return }
        textStorage.beginEditing()
        textStorage.deleteCharacters(in: NSRange(location: charIndex, length: 1))
        textStorage.endEditing()
        didChangeText()
    }

    @objc private func deleteTableAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let range = tableRange(at: charIndex),
              let textStorage = self.textStorage else { return }
        textStorage.beginEditing()
        textStorage.deleteCharacters(in: range)
        textStorage.endEditing()
        didChangeText()
    }

    @objc private func addRowAboveAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let block = tableBlock(at: charIndex),
              var parsed = parseTable(at: charIndex),
              let textStorage = self.textStorage else { return }

        let rowIndex = block.startingRow
        let emptyRow = Array(repeating: NSAttributedString(string: " "), count: parsed.cells[0].count)
        parsed.cells.insert(emptyRow, at: rowIndex)

        replaceTable(range: parsed.tableRange, with: parsed.cells, in: textStorage)
    }

    @objc private func addRowBelowAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let block = tableBlock(at: charIndex),
              var parsed = parseTable(at: charIndex),
              let textStorage = self.textStorage else { return }

        let rowIndex = block.startingRow
        let emptyRow = Array(repeating: NSAttributedString(string: " "), count: parsed.cells[0].count)
        parsed.cells.insert(emptyRow, at: rowIndex + 1)

        replaceTable(range: parsed.tableRange, with: parsed.cells, in: textStorage)
    }

    @objc private func addColumnLeftAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let block = tableBlock(at: charIndex),
              var parsed = parseTable(at: charIndex),
              let textStorage = self.textStorage else { return }

        let colIndex = block.startingColumn
        let emptyCell = NSAttributedString(string: " ")
        for rowIdx in 0..<parsed.cells.count {
            parsed.cells[rowIdx].insert(emptyCell, at: colIndex)
        }

        replaceTable(range: parsed.tableRange, with: parsed.cells, in: textStorage)
    }

    @objc private func addColumnRightAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let block = tableBlock(at: charIndex),
              var parsed = parseTable(at: charIndex),
              let textStorage = self.textStorage else { return }

        let colIndex = block.startingColumn
        let emptyCell = NSAttributedString(string: " ")
        for rowIdx in 0..<parsed.cells.count {
            parsed.cells[rowIdx].insert(emptyCell, at: colIndex + 1)
        }

        replaceTable(range: parsed.tableRange, with: parsed.cells, in: textStorage)
    }

    @objc private func deleteRowAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let block = tableBlock(at: charIndex),
              var parsed = parseTable(at: charIndex),
              let textStorage = self.textStorage else { return }

        // Don't delete if only one row
        guard parsed.cells.count > 1 else { return }

        let rowIndex = block.startingRow
        parsed.cells.remove(at: rowIndex)

        replaceTable(range: parsed.tableRange, with: parsed.cells, in: textStorage)
    }

    @objc private func deleteColumnAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let block = tableBlock(at: charIndex),
              var parsed = parseTable(at: charIndex),
              let textStorage = self.textStorage else { return }

        // Don't delete if only one column
        guard (parsed.cells.first?.count ?? 0) > 1 else { return }

        let colIndex = block.startingColumn
        for rowIdx in 0..<parsed.cells.count {
            if colIndex < parsed.cells[rowIdx].count {
                parsed.cells[rowIdx].remove(at: colIndex)
            }
        }

        replaceTable(range: parsed.tableRange, with: parsed.cells, in: textStorage)
    }

    private func replaceTable(range: NSRange, with cells: [[NSAttributedString]], in textStorage: NSTextStorage) {
        let newTable = buildTable(rows: cells, headerRow: true)
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: newTable)
        textStorage.endEditing()
        didChangeText()
    }

    @objc private func resetTextColorsAction(_ sender: NSMenuItem) {
        guard let textStorage = self.textStorage else { return }
        let range: NSRange
        if selectedRange().length > 0 {
            range = selectedRange()
        } else {
            range = NSRange(location: 0, length: textStorage.length)
        }
        guard range.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.removeAttribute(.foregroundColor, range: range)
        textStorage.endEditing()

        // Also clear note-level font color
        if let state = appState {
            state.updateNoteFontColor(state.selectedNoteIndex, hex: nil)
        }
        self.textColor = .textColor
        didChangeText()
    }

    @objc private func removePastilleAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let range = pastilleRange(at: charIndex) else { return }
        removePastilleFormatting(in: range)
    }

    @objc private func movePastilleAction(_ sender: NSMenuItem) {
        guard let charIndex = sender.representedObject as? Int,
              let range = pastilleRange(at: charIndex),
              let textStorage = self.textStorage else { return }

        let targetIndex = sender.tag

        // Extract pastille content
        let pastilleText = textStorage.attributedSubstring(from: range)

        // Remove from current note
        textStorage.beginEditing()
        textStorage.deleteCharacters(in: range)
        textStorage.endEditing()
        didChangeText()

        // Move to target note
        appState?.receivePastille(pastilleText, inNoteAt: targetIndex)
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
        textView.appState = appState
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

        if #available(macOS 15.0, *) {
            textView.writingToolsBehavior = .complete
        }

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
        // Only set typing attributes for new text — don't override per-range colors
        textView.insertionPointColor = fontColor
        var attrs = textView.typingAttributes
        attrs[.foregroundColor] = fontColor
        textView.typingAttributes = attrs
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
