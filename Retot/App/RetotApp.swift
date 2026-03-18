import AppKit
import SwiftUI

@main
struct RetotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var window: NSWindow!
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupWindow()

        // Menu bar app: hide from Dock by default
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Status Item (Menu Bar Icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "circle.grid.2x2.fill",
                accessibilityDescription: "Retot"
            )
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }

    // MARK: - Window

    private func setupWindow() {
        let contentView = ContentView().environmentObject(appState)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 580),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "Retot"
        window.minSize = NSSize(width: 480, height: 400)
        window.maxSize = NSSize(width: 1400, height: 1000)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        // Restore last window position
        window.setFrameAutosaveName("RetotMainWindow")
    }

    @objc private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
            appState.saveCurrentNoteContent()
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            appState.reloadCurrentNote()
        }
    }

    // MARK: - Window Delegate

    func windowWillClose(_ notification: Notification) {
        // Hide instead of quit — save content
        appState.saveCurrentNoteContent()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window instead of closing the app
        sender.orderOut(nil)
        return false
    }
}
