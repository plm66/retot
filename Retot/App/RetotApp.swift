import AppKit
import Combine
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
        setupKeyboardShortcuts()
        applyStoredAppearance()

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
        updateWindowTitle()
        setupTitleObserver()
        window.minSize = NSSize(width: 480, height: 400)
        window.maxSize = NSSize(width: 1400, height: 1000)
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.delegate = self
        window.center()

        // Restore last window position
        window.setFrameAutosaveName("RetotMainWindow")
    }

    private func setupKeyboardShortcuts() {
        // Cmd+1 through Cmd+9 for dots 1-9, Cmd+0 for dot 10
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.shift),
                  let chars = event.charactersIgnoringModifiers,
                  let self = self else { return event }

            switch chars {
            case "1": self.appState.selectNote(0); return nil
            case "2": self.appState.selectNote(1); return nil
            case "3": self.appState.selectNote(2); return nil
            case "4": self.appState.selectNote(3); return nil
            case "5": self.appState.selectNote(4); return nil
            case "6": self.appState.selectNote(5); return nil
            case "7": self.appState.selectNote(6); return nil
            case "8": self.appState.selectNote(7); return nil
            case "9": self.appState.selectNote(8); return nil
            case "0": self.appState.selectNote(9); return nil
            case "w":
                self.window.orderOut(nil)
                self.appState.saveCurrentNoteContent()
                return nil
            case "n":
                // Go to first empty note
                if let emptyIndex = self.appState.notes.firstIndex(where: { note in
                    !self.appState.noteHasContent(self.appState.notes.firstIndex(where: { $0.id == note.id }) ?? 0)
                }) {
                    self.appState.selectNote(emptyIndex)
                }
                return nil
            case "f":
                if event.modifierFlags.contains(.shift) {
                    self.appState.isSearching.toggle()
                    if !self.appState.isSearching {
                        self.appState.searchQuery = ""
                        self.appState.searchResults = []
                    }
                    return nil
                }
                return event
            default: return event
            }
        }
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

    // MARK: - Window Title

    private func updateWindowTitle() {
        let note = appState.notes[appState.selectedNoteIndex]
        window.title = "Retot — \(note.label) (Dot \(note.id))"
    }

    private func setupTitleObserver() {
        appState.$selectedNoteIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWindowTitle()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Appearance

    private func applyStoredAppearance() {
        let mode = UserDefaults.standard.string(forKey: "retotAppearance") ?? "system"
        switch mode {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}
