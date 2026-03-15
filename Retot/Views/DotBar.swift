import SwiftUI

struct DotBar: View {
    @EnvironmentObject var appState: AppState
    @State private var settingsNoteIndex: Int?
    @State private var showAppSettings = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(appState.notes.enumerated()), id: \.element.id) { index, note in
                DotView(
                    note: note,
                    isSelected: index == appState.selectedNoteIndex,
                    onTap: { appState.selectNote(index) },
                    onSettings: { settingsNoteIndex = index }
                )
                .frame(maxWidth: .infinity)
            }

            Button(action: { showAppSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .frame(width: 30)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .sheet(item: settingsBinding) { wrapper in
            NoteSettingsPopover(
                noteIndex: wrapper.index,
                appState: appState
            )
        }
        .sheet(isPresented: $showAppSettings) {
            SettingsView()
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
