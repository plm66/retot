import SwiftUI

struct DotBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var settingsNoteIndex: Int?
    @Binding var showAppSettings: Bool

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

            Button(action: { appState.isSearching = true }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Search all notes (Cmd+Shift+F)")
            .frame(width: 26)

            Button(action: { showAppSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .frame(width: 26)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}
