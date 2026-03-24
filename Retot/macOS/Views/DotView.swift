import SwiftUI

struct DotView: View {
    let note: Note
    let isSelected: Bool
    let hasContent: Bool
    let onTap: () -> Void
    let onSettings: () -> Void
    let onClear: () -> Void
    let onCopy: () -> Void
    let onDuplicate: (Int) -> Void
    let onDetach: () -> Void
    @EnvironmentObject var appState: AppState

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editingLabel = ""

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .top) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                        .frame(width: dotSize + 6, height: dotSize + 6)
                        .opacity(isSelected ? 1 : 0)

                    Circle()
                        .fill(note.color.swiftUIColor)
                        .frame(width: dotSize, height: dotSize)
                        .shadow(
                            color: isSelected ? note.color.swiftUIColor.opacity(0.6) : .clear,
                            radius: 4
                        )
                        .scaleEffect(isHovering ? 1.1 : 1.0)

                    Text("\(note.id)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }

                // Small badge: white dot for notes with content, green dot for empty slots
                if hasContent {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                        .offset(x: 10, y: 0)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: .green.opacity(0.8), radius: 3)
                        .offset(x: 10, y: 0)
                }
            }
            .frame(width: dotSize + 8, height: dotSize + 8)

            if isEditing {
                TextField("", text: $editingLabel, onCommit: {
                    let trimmed = editingLabel.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        if let index = appState.notes.firstIndex(where: { $0.id == note.id }) {
                            appState.updateNoteLabel(index, label: trimmed)
                        }
                    }
                    isEditing = false
                })
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            } else {
                Text(note.label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .onTapGesture(count: 2) {
                        editingLabel = note.label
                        isEditing = true
                    }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button("Rename...") { onSettings() }
            Button("Change Color...") { onSettings() }

            Divider()

            Button("Open in floating window") {
                if let noteIndex = appState.notes.firstIndex(where: { $0.id == note.id }) {
                    appState.detachNoteIndex = noteIndex
                }
            }

            Divider()

            Button("Copy Note Content") { onCopy() }

            Menu("Duplicate to...") {
                ForEach(Array(appState.notes.enumerated()), id: \.element.id) { index, targetNote in
                    if targetNote.id != note.id {
                        Button("\(targetNote.label) (Dot \(targetNote.id))") {
                            onDuplicate(index)
                        }
                    }
                }
            }

            Divider()

            Button("Clear Note", role: .destructive) { onClear() }
        }
        .accessibilityLabel("Note \(note.id): \(note.label)")
    }

    private var dotSize: CGFloat { 28 }
}
