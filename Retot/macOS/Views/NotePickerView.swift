import SwiftUI

struct NotePickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var confirmationNoteLabel: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)

                Text("Send to which note?")
                    .font(.headline)

                if let text = appState.receivedServiceText {
                    Text(previewText(text))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            // Note grid
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(Array(appState.notes.enumerated()), id: \.element.id) { index, note in
                    noteButton(note: note, index: index)
                }
            }

            // Confirmation overlay
            if let label = confirmationNoteLabel {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Sent to \(label)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .scale))
            }

            // Cancel button
            Button("Cancel") {
                appState.receivedServiceText = nil
                appState.showNotePicker = false
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
        .frame(width: 360)
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private func noteButton(note: Note, index: Int) -> some View {
        Button {
            insertText(into: index, noteLabel: note.label)
        } label: {
            VStack(spacing: 4) {
                Circle()
                    .fill(note.color.swiftUIColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(note.id)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(note.label)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func insertText(into index: Int, noteLabel: String) {
        guard let text = appState.receivedServiceText else { return }

        appState.appendTextToNote(at: index, text: text)
        appState.receivedServiceText = nil

        // Show brief confirmation then close
        withAnimation(.easeInOut(duration: 0.3)) {
            confirmationNoteLabel = noteLabel
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            appState.showNotePicker = false
            // Navigate to the target note
            appState.selectNote(index)
        }
    }

    private func previewText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 120 {
            return trimmed
        }
        return String(trimmed.prefix(120)) + "..."
    }
}
