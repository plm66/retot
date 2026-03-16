import SwiftUI

struct NoteSettingsPopover: View {
    let noteIndex: Int
    @ObservedObject var appState: AppState
    let onDone: () -> Void
    @State private var editingLabel: String = ""
    @State private var newTag: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Note Settings")
                .font(.headline)

            // Label
            TextField("Label", text: $editingLabel)
                .textFieldStyle(.roundedBorder)
                .onSubmit { applyLabel() }

            // Color picker
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

            // Tags
            Divider()

            Text("Tags")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            TagsView(
                tags: appState.notes[noteIndex].tags,
                onRemove: { tag in appState.removeTag(tag, fromNoteAt: noteIndex) }
            )

            HStack {
                TextField("Add tag...", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTag() }
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Actions
            HStack {
                Button("Cancel") { onDone() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Done") {
                    applyLabel()
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 280)
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

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appState.addTag(trimmed, toNoteAt: noteIndex)
        newTag = ""
    }
}

struct TagsView: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        if tags.isEmpty {
            Text("No tags")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            FlowLayout(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(tag: tag, onRemove: { onRemove(tag) })
                }
            }
        }
    }
}

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(10)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
