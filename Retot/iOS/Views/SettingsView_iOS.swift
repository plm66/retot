import SwiftUI

struct SettingsView_iOS: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var noteCount: Double = 10

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
        }
    }
}
