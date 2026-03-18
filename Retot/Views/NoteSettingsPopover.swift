import SwiftUI

struct NoteSettingsPopover: View {
    let noteIndex: Int
    @ObservedObject var appState: AppState
    let onDone: () -> Void
    @State private var editingLabel: String = ""
    @State private var newTag: String = ""

    private var currentNote: Note {
        appState.notes[noteIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Note Settings")
                        .font(.title2.bold())

                    // Label
                    TextField("Label", text: $editingLabel)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { applyLabel() }

                    // Dot color picker
                    Text("Color")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(NoteColor.allCases) { color in
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: isCurrentColor(color) ? 2 : 0)
                                )
                                .onTapGesture {
                                    appState.updateNoteColor(noteIndex, color: color)
                                }
                        }
                    }

                    // Font Color
                    Divider()

                    Text("Font Color")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    EditorColorPickerGrid(
                        selectedHex: currentNote.fontColorHex,
                        onSelect: { hex in appState.updateNoteFontColor(noteIndex, hex: hex) }
                    )

                    // Background Color
                    Divider()

                    Text("Background Color")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    EditorColorPickerGrid(
                        selectedHex: currentNote.backgroundColorHex,
                        onSelect: { hex in appState.updateNoteBackgroundColor(noteIndex, hex: hex) }
                    )

                    // Tags
                    Divider()

                    Text("Tags")
                        .font(.headline)
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
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Divider()

            // Actions pinned at bottom
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: 500)
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

// MARK: - Editor Color Picker Grid

struct EditorColorPickerGrid: View {
    let selectedHex: String?
    let onSelect: (String?) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            // Default button
            Circle()
                .fill(Color.clear)
                .frame(width: 32, height: 32)
                .overlay(
                    ZStack {
                        Circle().stroke(Color.secondary, lineWidth: 1)
                        if selectedHex == nil {
                            Image(systemName: "checkmark")
                                .font(.body.bold())
                                .foregroundColor(.primary)
                        } else {
                            Text("D")
                                .font(.body.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                )
                .onTapGesture { onSelect(nil) }

            // Color swatches
            ForEach(EditorColorPalette.editorPalette, id: \.hex) { entry in
                Circle()
                    .fill(Color(hex: entry.hex) ?? Color.clear)
                    .frame(width: 32, height: 32)
                    .overlay(
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                            if selectedHex?.uppercased() == entry.hex.uppercased() {
                                Image(systemName: "checkmark")
                                    .font(.body.bold())
                                    .foregroundColor(checkmarkColor(for: entry.hex))
                            }
                        }
                    )
                    .onTapGesture { onSelect(entry.hex) }
                    .help(entry.name)
            }
        }
    }

    private func checkmarkColor(for hex: String) -> Color {
        // Use white checkmark on dark colors, black on light colors
        let darkHexes = ["000000", "333333", "E53535", "6658E4", "1A1A3E"]
        return darkHexes.contains(hex.uppercased()) ? .white : .black
    }
}

struct TagsView: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        if tags.isEmpty {
            Text("No tags")
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            FlowLayout(spacing: 6) {
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
                .font(.body)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.15))
        .cornerRadius(10)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

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
