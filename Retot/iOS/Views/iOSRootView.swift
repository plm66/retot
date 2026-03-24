import SwiftUI

struct iOSRootView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with dots and settings
            HStack(spacing: 0) {
                DotBar_iOS()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 12)
            }

            Divider()

            // Editor
            NoteEditorView_iOS()
                .id(appState.selectedNoteIndex)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: appState.selectedNoteIndex)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView_iOS()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showAIPopover) {
            NavigationStack {
                AIPopoverView()
                    .environmentObject(appState)
                    .navigationTitle("AI")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { appState.showAIPopover = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}
