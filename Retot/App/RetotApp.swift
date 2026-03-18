import AppKit
import SwiftUI

@main
struct RetotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Retot", systemImage: "circle.grid.2x2.fill") {
            ContentView()
                .environmentObject(appState)
                .frame(width: 680, height: 580)
        }
        .menuBarExtraStyle(.window)
    }
}
