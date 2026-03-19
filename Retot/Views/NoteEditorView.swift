import AppKit
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

            // Footer
            Divider()
            NoteFooterView()
        }
    }

    private func exportCurrentNote() {
        let note = currentNote
        let content = appState.currentAttributedText
        ExportManager.exportAsMarkdown(note: note, content: content)
    }
}

// MARK: - Footer

struct NoteFooterView: View {
    @EnvironmentObject var appState: AppState

    private var currentNote: Note {
        appState.notes[appState.selectedNoteIndex]
    }

    private var text: String {
        appState.currentAttributedText.string
    }

    private var lineCount: Int {
        let trimmed = text.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .newlines).count
    }

    private var charCount: Int {
        text.count
    }

    private var timeAgo: String {
        let interval = Date().timeIntervalSince(currentNote.lastModified)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    private var wordCount: Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("Dot \(currentNote.id) · \(currentNote.label)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text("|")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))

            Text("\(lineCount) lines · \(charCount) chars · \(wordCount) words")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text("|")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.5))

            Text(timeAgo)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            if !currentNote.tags.isEmpty {
                Text("|")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))

                HStack(spacing: 3) {
                    ForEach(currentNote.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            if appState.savedIndicator {
                Text("Saved")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                    .transition(.opacity)
            } else {
                Text("Auto-save")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .animation(.easeInOut(duration: 0.3), value: appState.savedIndicator)
    }
}
