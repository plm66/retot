import AppKit
import SwiftUI

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

        let textView = NSTextView()
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
        guard let textView = scrollView.documentView as? NSTextView else { return }

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
