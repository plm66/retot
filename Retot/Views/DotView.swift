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
    @EnvironmentObject var appState: AppState

    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editingLabel = ""

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                    .frame(width: dotSize + 6, height: dotSize + 6)
                    .opacity(isSelected ? 1 : 0)

                Circle()
                    .fill(note.color.swiftUIColor)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(hasContent ? 1.0 : 0.25)
                    .shadow(
                        color: isSelected ? note.color.swiftUIColor.opacity(0.6) : .clear,
                        radius: 4
                    )
                    .scaleEffect(isHovering ? 1.1 : 1.0)

                Text("\(note.id)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
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
                Text(hasContent ? note.label : "(empty)")
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : (hasContent ? .secondary : .secondary.opacity(0.4)))
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
