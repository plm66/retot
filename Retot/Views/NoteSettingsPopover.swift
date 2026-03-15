import SwiftUI

struct NoteSettingsPopover: View {
    let noteIndex: Int
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editingLabel: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Note Settings")
                .font(.headline)

            TextField("Label", text: $editingLabel)
                .textFieldStyle(.roundedBorder)
                .onSubmit { applyLabel() }

            Text("Color")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 5), spacing: 8) {
                ForEach(NoteColor.allCases) { color in
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: isCurrentColor(color) ? 2 : 0)
                        )
                        .onTapGesture {
                            appState.updateNoteColor(noteIndex, color: color)
                        }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Done") {
                    applyLabel()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 240)
        .onAppear {
            editingLabel = appState.notes[noteIndex].label
        }
    }

    private func applyLabel() {
        let trimmed = editingLabel.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.updateNoteLabel(noteIndex, label: trimmed)
    }

    private func isCurrentColor(_ color: NoteColor) -> Bool {
        appState.notes[noteIndex].color == color
    }
}
