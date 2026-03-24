import SwiftUI

struct NoteEditorView_iOS: View {
    @EnvironmentObject var appState: AppState

    private var currentNote: Note {
        appState.notes[appState.selectedNoteIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tags
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

            // Editor
            RichTextEditor_iOS()
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        EditorToolbar_iOS()
                    }
                }

            // Footer
            Divider()
            NoteFooter_iOS()
        }
        .sheet(isPresented: $appState.showAIResult) {
            AIResultView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showAIAssistant) {
            AIAssistantView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showExtraction) {
            ExtractionResultView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Footer

struct NoteFooter_iOS: View {
    @EnvironmentObject var appState: AppState

    private var currentNote: Note {
        appState.notes[appState.selectedNoteIndex]
    }

    private var text: String {
        appState.currentAttributedText.string
    }

    private var wordCount: Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private var charCount: Int {
        text.count
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(currentNote.label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text("\u{00B7}")
                .foregroundColor(.secondary)

            Text("\(wordCount) words \u{00B7} \(charCount) chars")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            if appState.savedIndicator {
                Text("Saved")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.3), value: appState.savedIndicator)
    }
}
