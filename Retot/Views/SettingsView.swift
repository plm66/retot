import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    let onDone: () -> Void
    @State private var ramUsage: String = "..."
    @AppStorage("retotAppearance") private var appearance: String = "system"

    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.title2.bold())

            GroupBox("Appearance") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Theme")
                            .font(.body)
                        Spacer()
                        Picker("", selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .onChange(of: appearance) { newValue in
                            applyAppearance(newValue)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Keyboard Shortcuts") {
                VStack(spacing: 6) {
                    shortcutRow("Cmd+1 — Cmd+0", "Switch to Dot 1–10")
                    shortcutRow("Cmd+Shift+F", "Search all notes")
                    shortcutRow("Cmd+W", "Hide window")
                    shortcutRow("Cmd+N", "Jump to first empty note")
                    shortcutRow("Cmd+Z / Cmd+Shift+Z", "Undo / Redo")
                    shortcutRow("Cmd+B / Cmd+I / Cmd+U", "Bold / Italic / Underline")
                }
                .padding(8)
            }

            GroupBox("Toolbar Guide") {
                VStack(spacing: 6) {
                    shortcutRow("↩ ↪", "Undo / Redo")
                    shortcutRow("B I U S", "Bold, Italic, Underline, Strikethrough")
                    shortcutRow("H", "Toggle heading")
                    shortcutRow("•", "Bullet list")
                    shortcutRow("⊞", "Insert table")
                    shortcutRow("▢▢", "Create pastille (select text first)")
                    shortcutRow("A- A+", "Decrease / Increase font size")
                    shortcutRow("📌", "Pin window on top")
                    shortcutRow("🔍", "Search all notes")
                    shortcutRow("↑", "Export as Markdown")
                }
                .padding(8)
            }

            GroupBox("Right-Click Actions") {
                VStack(spacing: 6) {
                    shortcutRow("On a dot", "Rename, Change Color, Copy, Duplicate, Clear")
                    shortcutRow("On a pastille", "Move to Dot N, Remove Pastille")
                    shortcutRow("On a table", "Delete Table")
                }
                .padding(8)
            }

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

            GroupBox("System") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("RAM Usage (Retot)")
                                .font(.body)
                            Text(ramUsage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Refresh") { updateRAMUsage() }
                    }
                }
                .padding(8)
            }

            Spacer()

            HStack {
                Button("Quit Retot") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)

                Spacer()

                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        } // ScrollView
        .onAppear {
            updateRAMUsage()
            applyAppearance(appearance)
        }
    }

    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        HStack {
            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 180, alignment: .leading)
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func applyAppearance(_ mode: String) {
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil // Follow system
        }
    }

    private func exportAll() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder to export all notes"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        appState.exportAllNotes(to: url)
    }

    private func updateRAMUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1_048_576.0
            ramUsage = String(format: "%.1f MB", usedMB)
        } else {
            ramUsage = "N/A"
        }
    }

    private func importAll() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Import"
        panel.message = "Choose a folder containing retot-metadata.json"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        appState.importAllNotes(from: url)
    }
}
