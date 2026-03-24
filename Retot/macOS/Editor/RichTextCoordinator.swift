import AppKit
import Foundation

final class RichTextCoordinator: NSObject, NSTextViewDelegate {
    private weak var appState: AppState?
    private(set) var currentNoteId: Int
    private var processingTimer: Timer?

    init(appState: AppState, noteId: Int) {
        self.appState = appState
        self.currentNoteId = noteId
        super.init()
    }

    func updateNoteId(_ newId: Int) {
        currentNoteId = newId
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              let textStorage = textView.textStorage else { return }

        appState?.currentAttributedText = NSAttributedString(attributedString: textStorage)
        appState?.notifyTextChanged()

        // Debounced wiki link processing
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.processWikiLinks(in: textStorage)
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        let range = textView.selectedRange()
        // Only update if there's an actual selection — don't overwrite when focus is lost
        if range.length > 0 {
            appState?.lastSelectedRange = range
        }
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL,
              url.scheme == "retot",
              url.host == "note" else {
            return false
        }

        let label = url.pathComponents
            .dropFirst()
            .joined(separator: "/")
            .removingPercentEncoding ?? ""

        appState?.navigateToNote(named: label)
        return true
    }

    // MARK: - Wiki Links

    private func processWikiLinks(in textStorage: NSTextStorage) {
        guard let noteLabels = appState?.notes.map(\.label) else { return }
        WikiLinkProcessor.processLinks(in: textStorage, noteLabels: noteLabels)
    }
}
