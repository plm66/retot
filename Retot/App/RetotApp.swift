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
    private var popoverWindow: RetotPanel?
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.grid.2x2.fill", accessibilityDescription: "Retot")
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }

    @objc private func toggleWindow() {
        if let window = popoverWindow, window.isVisible {
            window.close()
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        if popoverWindow == nil {
            let contentView = ContentView()
                .environmentObject(appState)

            let panel = RetotPanel(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isMovableByWindowBackground = true
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: contentView)
            panel.minSize = NSSize(width: 400, height: 300)

            popoverWindow = panel
        }

        // Position near the status item
        if let button = statusItem.button {
            let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
            let windowSize = popoverWindow!.frame.size
            let x = buttonFrame.midX - windowSize.width / 2
            let y = buttonFrame.minY - windowSize.height - 4
            popoverWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        popoverWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class RetotPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
