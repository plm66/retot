import SwiftUI

struct NoteEditorView: View {
    @EnvironmentObject var appState: AppState

    private var currentNote: Note {
        appState.notes[appState.selectedNoteIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(onExport: exportCurrentNote)

            // Tags bar for current note
            if !currentNote.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(currentNote.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                Divider()
            }

            RichTextEditor()
        }
    }

    private func exportCurrentNote() {
        let note = currentNote
        let content = appState.currentAttributedText
        ExportManager.exportAsMarkdown(note: note, content: content)
    }
}
