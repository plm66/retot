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
                    hasContent: appState.noteHasContent(index),
                    onTap: { appState.selectNote(index) },
                    onSettings: { settingsNoteIndex = index },
                    onClear: { appState.clearNote(index) },
                    onCopy: { appState.copyNoteContent(index) },
                    onDuplicate: { targetIndex in appState.duplicateNote(from: index, to: targetIndex) },
                    onDetach: {
                        if let delegate = NSApp.delegate as? AppDelegate {
                            delegate.openFloatingNote(index)
                        }
                    }
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
            .frame(width: 26)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}
