import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    let onDone: () -> Void
    @State private var ramUsage: String = "..."
    @AppStorage("retotAppearance") private var appearance: String = "system"
    @State private var noteCount: Double = 10

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Settings")
                        .font(.title2.bold())

            GroupBox("Notes") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Number of notes")
                            .font(.body)
                        Spacer()
                        Text("\(Int(noteCount))")
                            .font(.body.monospacedDigit().bold())
                            .frame(width: 30)
                    }
                    Slider(value: $noteCount, in: 3...30, step: 1)
                        .onChange(of: noteCount) { newValue in
                            appState.setNoteCount(Int(newValue))
                        }
                }
                .padding(8)
            }

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

            // Reference - 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GroupBox {
                    DisclosureGroup("Keyboard Shortcuts") {
                        VStack(alignment: .leading, spacing: 4) {
                            shortcutRow("Cmd+1–0", "Switch Dot 1–10")
                            shortcutRow("Cmd+S", "Save")
                            shortcutRow("Cmd+P", "Print / PDF")
                            shortcutRow("Cmd+W", "Hide window")
                            shortcutRow("Cmd+N", "First empty note")
                            shortcutRow("Cmd+⇧+F", "Search all")
                            shortcutRow("Cmd+Z/⇧+Z", "Undo / Redo")
                            shortcutRow("Cmd+B/I/U", "Bold / Italic / Underline")
                        }
                        .padding(.top, 4)
                    }
                }

                GroupBox {
                    DisclosureGroup("Toolbar") {
                        VStack(alignment: .leading, spacing: 4) {
                            shortcutRow("↩ ↪", "Undo / Redo")
                            shortcutRow("B I U S", "Bold, Italic, Underline, Strike")
                            shortcutRow("H", "Heading")
                            shortcutRow("•", "Bullet list")
                            shortcutRow("⊞", "Insert table")
                            shortcutRow("✨", "AI Assistant")
                            shortcutRow("📌", "Pin on top")
                            shortcutRow("🔍", "Search")
                            shortcutRow("🖨", "Print / PDF")
                            shortcutRow("↑", "Export Markdown")
                        }
                        .padding(.top, 4)
                    }
                }

                GroupBox {
                    DisclosureGroup("DotBar") {
                        VStack(alignment: .leading, spacing: 4) {
                            shortcutRow("Click", "Select note")
                            shortcutRow("Double-click", "Rename inline")
                            shortcutRow("⊞+ button", "Detach floating")
                            shortcutRow("⚙ button", "App settings")
                        }
                        .padding(.top, 4)
                    }
                }

                GroupBox {
                    DisclosureGroup("Right-Click") {
                        VStack(alignment: .leading, spacing: 4) {
                            shortcutRow("On dot", "Rename, Color, Detach, Copy...")
                            shortcutRow("On pastille", "Move to Dot N, Remove")
                            shortcutRow("On table", "Delete Table")
                        }
                        .padding(.top, 4)
                    }
                }
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
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(StorageConstants.isICloudAvailable ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(StorageConstants.isICloudAvailable ? "iCloud: Connected" : "iCloud: Local only")
                                    .font(.body)
                            }
                            Text(StorageConstants.activeDirectory.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Reveal") {
                            NSWorkspace.shared.selectFile(
                                nil,
                                inFileViewerRootedAtPath: StorageConstants.activeDirectory.path
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

                }
                .padding(24)
            } // ScrollView

            Divider()

            HStack {
                Button("Quit Retot") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)

                Spacer()

                Button("Done") { onDone() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        } // outer VStack
        .onAppear {
            noteCount = Double(appState.notes.count)
            updateRAMUsage()
            applyAppearance(appearance)
        }
    }

    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        HStack {
            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
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
