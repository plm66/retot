import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2.bold())

            GroupBox("Bulk Operations") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Export All Notes")
                                .font(.body)
                            Text("Exports all 10 notes as Markdown + metadata JSON")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Export...") { exportAll() }
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Import All Notes")
                                .font(.body)
                            Text("Imports from a folder with retot-metadata.json")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Import...") { importAll() }
                    }
                }
                .padding(8)
            }

            GroupBox("Data") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Storage Location")
                                .font(.body)
                            Text(StorageConstants.appSupportDirectory.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Reveal") {
                            NSWorkspace.shared.selectFile(
                                nil,
                                inFileViewerRootedAtPath: StorageConstants.appSupportDirectory.path
                            )
                        }
                    }
                }
                .padding(8)
            }

            Spacer()

            Button("Done") { onDone() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 400, height: 320)
    }

    private func exportAll() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to export all notes"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            appState.exportAllNotes(to: url)
        }
    }

    private func importAll() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Import"
        panel.message = "Choose a folder containing retot-metadata.json"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            appState.importAllNotes(from: url)
        }
    }
}
