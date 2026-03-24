import SwiftUI
import UniformTypeIdentifiers

// MARK: - Share Sheet (UIActivityViewController wrapper)

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Settings View

struct SettingsView_iOS: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var noteCount: Double = 10

    // Import / Export state
    @State private var showImportPicker = false
    @State private var showShareSheet = false
    @State private var exportItems: [Any] = []
    @State private var importResultMessage: String?
    @State private var showImportResult = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Notes") {
                    HStack {
                        Text("Number of notes")
                        Spacer()
                        Text("\(Int(noteCount))")
                            .bold()
                    }
                    Slider(value: $noteCount, in: 3...30, step: 1)
                        .onChange(of: noteCount) { _, newValue in
                            appState.setNoteCount(Int(newValue))
                        }
                }

                Section("Storage") {
                    HStack {
                        Text("iCloud")
                        Spacer()
                        Text(StorageConstants.isICloudAvailable ? "Connected" : "Local only")
                            .foregroundColor(
                                StorageConstants.isICloudAvailable ? .green : .secondary
                            )
                    }
                }

                Section("Data Transfer") {
                    Button(action: exportNotes) {
                        Label("Export All Notes", systemImage: "square.and.arrow.up")
                    }

                    Button(action: { showImportPicker = true }) {
                        Label("Import Notes", systemImage: "square.and.arrow.down")
                    }
                }

                Section("About") {
                    Text("Retot v0.6")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { noteCount = Double(appState.notes.count) }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: exportItems)
                    .presentationDetents([.medium, .large])
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert("Import Result", isPresented: $showImportResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importResultMessage ?? "")
            }
        }
    }

    // MARK: - Actions

    private func exportNotes() {
        guard let tempDir = appState.exportNotesToTempDirectory() else { return }
        exportItems = [tempDir]
        showShareSheet = true
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            appState.importNotesFromFolder(url)
            importResultMessage = "Notes imported successfully."
            showImportResult = true
        case .failure(let error):
            importResultMessage = "Import failed: \(error.localizedDescription)"
            showImportResult = true
        }
    }
}
