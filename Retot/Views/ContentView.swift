import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            DotBar()

            Divider()

            NoteEditorView()
        }
        .frame(width: 520, height: 420)
    }
}
