import SwiftUI

@main
struct RetotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Retot", systemImage: "note.text") {
            ContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
