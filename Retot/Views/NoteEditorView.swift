import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(onExport: exportCurrentNote)

            Divider()

            RichTextEditor()
        }
    }

    private func exportCurrentNote() {
        let note = appState.notes[appState.selectedNoteIndex]
        let content = appState.currentAttributedText
        ExportManager.exportAsMarkdown(note: note, content: content)
    }
}
