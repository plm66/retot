import SwiftUI

struct DotBar: View {
    @EnvironmentObject var appState: AppState
    @State private var settingsNoteIndex: Int?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(appState.notes.enumerated()), id: \.element.id) { index, note in
                DotView(
                    note: note,
                    isSelected: index == appState.selectedNoteIndex,
                    onTap: { appState.selectNote(index) },
                    onSettings: { settingsNoteIndex = index }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .sheet(item: settingsBinding) { wrapper in
            NoteSettingsPopover(
                noteIndex: wrapper.index,
                appState: appState
            )
        }
    }

    private var settingsBinding: Binding<IndexWrapper?> {
        Binding(
            get: { settingsNoteIndex.map(IndexWrapper.init) },
            set: { settingsNoteIndex = $0?.index }
        )
    }
}

private struct IndexWrapper: Identifiable {
    let index: Int
    var id: Int { index }
}
