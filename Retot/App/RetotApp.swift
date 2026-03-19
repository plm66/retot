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
    var floatingWindows: [Int: NSPanel] = [:]
    var floatingTextViews: [Int: NSTextView] = [:]
    private let storage = StorageManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupWindow()
        setupKeyboardShortcuts()
        applyStoredAppearance()
        setupDetachObserver()

        // Menu bar app: hide from Dock by default
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Status Item (Menu Bar Icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "circle.grid.2x2.fill",
                accessibilityDescription: "Retot"
            )
            button.imagePosition = .imageLeading
            button.action = #selector(toggleWindow)
            button.target = self
            updateStatusItemBadge()
        }
    }

    func updateStatusItemBadge() {
        guard let button = statusItem?.button else { return }
        let note = appState.notes[appState.selectedNoteIndex]
        button.title = " \(note.id)"
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
            case "s":
                self.appState.saveCurrentNoteContent()
                self.appState.showSavedFeedback()
                return nil
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
        if sender == window {
            // Main window: hide instead of close
            sender.orderOut(nil)
            return false
        }
        // Floating panels: allow close (triggers willCloseNotification for save)
        return true
    }

    private func setupDetachObserver() {
        appState.$detachNoteIndex
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] index in
                self?.appState.detachNoteIndex = nil
                self?.openFloatingNote(index)
            }
            .store(in: &cancellables)
    }

    // MARK: - Floating Notes

    func openFloatingNote(_ noteIndex: Int) {
        guard noteIndex >= 0, noteIndex < appState.notes.count else { return }

        // If already floating, bring to front
        if let existing = floatingWindows[noteIndex] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        // Save main window note first
        appState.saveCurrentNoteContent()

        let note = appState.notes[noteIndex]
        let content = storage.loadNoteContent(for: note.id)

        // Create NSTextView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = RetotTextView()
        textView.appState = appState
        textView.isRichText = true
        textView.allowsImageEditing = true
        textView.importsGraphics = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textStorage?.setAttributedString(content)

        // Apply note colors
        if let bgHex = note.backgroundColorHex, let bgColor = NSColor.fromHex(bgHex) {
            textView.backgroundColor = bgColor
        }
        if let fgHex = note.fontColorHex, let fgColor = NSColor.fromHex(fgHex) {
            textView.textColor = fgColor
        }

        scrollView.documentView = textView

        // Create floating panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = scrollView
        panel.title = "\(note.label) (Dot \(note.id))"
        panel.minSize = NSSize(width: 250, height: 200)
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior.insert(.canJoinAllSpaces)

        // Position near main window but offset
        let offset = CGFloat(floatingWindows.count) * 30
        if let mainFrame = window?.frame {
            panel.setFrameOrigin(NSPoint(
                x: mainFrame.maxX + 20 + offset,
                y: mainFrame.maxY - 350 - offset
            ))
        } else {
            panel.center()
        }

        // Track for cleanup
        floatingWindows[noteIndex] = panel
        floatingTextViews[noteIndex] = textView

        // Handle close: save content and clean up
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.closeFloatingNote(noteIndex)
        }

        panel.makeKeyAndOrderFront(nil)
    }

    private func closeFloatingNote(_ noteIndex: Int) {
        guard let textView = floatingTextViews[noteIndex],
              let textStorage = textView.textStorage else { return }

        // Save content
        let content = NSAttributedString(attributedString: textStorage)
        let noteId = appState.notes[noteIndex].id
        storage.saveNoteContent(content, for: noteId)

        // If the main window is showing this note, reload
        if appState.selectedNoteIndex == noteIndex {
            appState.currentAttributedText = content
            appState.currentTextView?.textStorage?.setAttributedString(content)
        }

        // Clean up
        floatingWindows.removeValue(forKey: noteIndex)
        floatingTextViews.removeValue(forKey: noteIndex)
    }

    func isNoteFloating(_ noteIndex: Int) -> Bool {
        floatingWindows[noteIndex]?.isVisible == true
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
                self?.updateStatusItemBadge()
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
