import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var settingsNoteIndex: Int? = nil
    @State private var showAppSettings = false

    var body: some View {
        VStack(spacing: 0) {
            DotBar(
                settingsNoteIndex: $settingsNoteIndex,
                showAppSettings: $showAppSettings
            )

            Divider()

            if showAppSettings {
                SettingsView(onDone: { showAppSettings = false })
                    .environmentObject(appState)
            } else if let noteIndex = settingsNoteIndex {
                NoteSettingsPopover(
                    noteIndex: noteIndex,
                    appState: appState,
                    onDone: { settingsNoteIndex = nil }
                )
            } else {
                NoteEditorView()
            }
        }
        .onDisappear {
            appState.saveCurrentNoteContent()
            appState.releaseMemory()
        }
        .onAppear {
            appState.reloadCurrentNote()
        }
    }
}
