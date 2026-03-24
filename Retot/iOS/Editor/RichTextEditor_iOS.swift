import SwiftUI
import UIKit

class RetotTextView_iOS: UITextView {
    weak var appState: AppState?
}

struct RichTextEditor_iOS: UIViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> RichTextCoordinator_iOS {
        RichTextCoordinator_iOS(
            appState: appState,
            noteId: appState.notes[appState.selectedNoteIndex].id
        )
    }

    func makeUIView(context: Context) -> RetotTextView_iOS {
        let textView = RetotTextView_iOS()
        textView.appState = appState
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsEditingTextAttributes = true
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.delegate = context.coordinator
        textView.backgroundColor = .systemBackground
        textView.autocorrectionType = .default
        textView.autocapitalizationType = .sentences
        textView.keyboardDismissMode = .interactive

        // Load initial content and apply note colors
        let currentNote = appState.notes[appState.selectedNoteIndex]
        loadContent(into: textView, noteIndex: appState.selectedNoteIndex)
        applyNoteColors(to: textView, note: currentNote)
        appState.currentTextView_iOS = textView

        return textView
    }

    func updateUIView(_ textView: RetotTextView_iOS, context: Context) {
        let currentNote = appState.notes[appState.selectedNoteIndex]
        let currentNoteId = currentNote.id

        // Always apply colors (they may change without note switch)
        applyNoteColors(to: textView, note: currentNote)

        // Only reload content when the selected note changes
        if context.coordinator.currentNoteId != currentNoteId {
            context.coordinator.updateNoteId(currentNoteId)
            loadContent(into: textView, noteIndex: appState.selectedNoteIndex)
            appState.currentTextView_iOS = textView
        }
    }

    private func applyNoteColors(to textView: UITextView, note: Note) {
        if let bgHex = note.backgroundColorHex,
           let bgColor = UIColor.fromHex(bgHex) {
            textView.backgroundColor = bgColor
        } else {
            textView.backgroundColor = .systemBackground
        }

        let fontColor: UIColor
        if let fgHex = note.fontColorHex,
           let fgColor = UIColor.fromHex(fgHex) {
            fontColor = fgColor
        } else {
            fontColor = .label
        }
        textView.tintColor = fontColor
        var attrs = textView.typingAttributes
        attrs[.foregroundColor] = fontColor
        textView.typingAttributes = attrs
    }

    private func loadContent(into textView: UITextView, noteIndex: Int) {
        let content = appState.currentAttributedText
        textView.attributedText = content

        // Set default typing attributes if empty
        if content.length == 0 {
            textView.typingAttributes = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ]
        }
    }
}
