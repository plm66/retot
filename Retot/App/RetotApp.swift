import SwiftUI

@main
struct RetotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: RetotPanel?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    @objc private func statusItemClicked() {
        if let existing = panel, existing.isVisible {
            existing.close()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
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

            panel = newPanel
        }

        positionPanelBelowStatusItem()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionPanelBelowStatusItem() {
        guard let panel = panel,
              let button = statusItem.button,
              let buttonWindow = button.window else {
            panel?.center()
            return
        }

        let buttonFrame = buttonWindow.convertToScreen(button.frame)
        let panelWidth = panel.frame.width
        let x = buttonFrame.midX - panelWidth / 2
        let y = buttonFrame.minY - panel.frame.height - 4

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

final class RetotPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
