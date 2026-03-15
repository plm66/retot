import SwiftUI

@main
struct RetotApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var windowManager = WindowManager()

    var body: some Scene {
        MenuBarExtra("Retot", image: "MenuBarIcon") {
            Button("Open Retot") {
                windowManager.showWindow(appState: appState)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Quit") {
                appState.saveCurrentNoteContent()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

final class WindowManager: ObservableObject {
    private var panel: RetotPanel?

    func showWindow(appState: AppState) {
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if panel == nil {
            let contentView = ContentView()
                .environmentObject(appState)

            let newPanel = RetotPanel(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            newPanel.isMovableByWindowBackground = true
            newPanel.titlebarAppearsTransparent = true
            newPanel.titleVisibility = .hidden
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isReleasedWhenClosed = false
            newPanel.contentView = NSHostingView(rootView: contentView)
            newPanel.minSize = NSSize(width: 400, height: 300)
            newPanel.center()

            panel = newPanel
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class RetotPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
