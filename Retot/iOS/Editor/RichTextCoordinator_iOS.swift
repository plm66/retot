import UIKit
import Foundation

final class RichTextCoordinator_iOS: NSObject, UITextViewDelegate {
    private weak var appState: AppState?
    private(set) var currentNoteId: Int

    init(appState: AppState, noteId: Int) {
        self.appState = appState
        self.currentNoteId = noteId
        super.init()
    }

    func updateNoteId(_ newId: Int) {
        currentNoteId = newId
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        appState?.currentAttributedText = NSAttributedString(attributedString: textView.attributedText)
        appState?.notifyTextChanged()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        let range = textView.selectedRange
        if range.length > 0 {
            appState?.lastSelectedRange = range
        }
    }
}
