import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var settingsNoteIndex: Int? = nil
    @State private var showAppSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Search bar (when active)
            if appState.isSearching {
                SearchPanelView()
            } else {
                DotBar(
                    settingsNoteIndex: $settingsNoteIndex,
                    showAppSettings: $showAppSettings
                )

                Divider()

                if showAppSettings {
                    SettingsView(onDone: { showAppSettings = false })
                        .environmentObject(appState)
                } else if let noteIndex = settingsNoteIndex {
                    NoteSettingsPopover(
                        noteIndex: noteIndex,
                        appState: appState,
                        onDone: { settingsNoteIndex = nil }
                    )
                } else {
                    NoteEditorView()
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .background(SearchShortcutHandler())
    }
}

// MARK: - Search Panel

struct SearchPanelView: View {
    @EnvironmentObject var appState: AppState
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search all notes...", text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .focused($isFieldFocused)
                    .onChange(of: appState.searchQuery) { newValue in
                        appState.performSearch(newValue)
                    }
                    .onSubmit {
                        if let first = appState.searchResults.first {
                            appState.navigateToSearchResult(first)
                        }
                    }

                Button(action: {
                    appState.isSearching = false
                    appState.searchQuery = ""
                    appState.searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Results
            if appState.searchResults.isEmpty && appState.searchQuery.count >= 2 {
                VStack {
                    Spacer()
                    Text("No results")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.searchResults) { result in
                            SearchResultRow(result: result)
                                .onTapGesture {
                                    appState.navigateToSearchResult(result)
                                }
                        }
                    }
                }
            }
        }
        .onAppear { isFieldFocused = true }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: AppState.SearchResult

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(result.noteColor.swiftUIColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text("Dot \(result.noteIndex + 1) · \(result.noteLabel)")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(result.excerpt)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Keyboard Shortcut Handler

struct SearchShortcutHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = SearchKeyView()
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class SearchKeyView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Cmd+Shift+F → toggle global search
        if event.modifierFlags.contains([.command, .shift]),
           event.charactersIgnoringModifiers == "f" {
            guard let window = self.window,
                  let contentView = window.contentView,
                  contentView is NSView else {
                NotificationCenter.default.post(name: .retotToggleSearch, object: nil)
                return
            }
            NotificationCenter.default.post(name: .retotToggleSearch, object: nil)
            return
        }
        super.keyDown(with: event)
    }
}

extension Notification.Name {
    static let retotToggleSearch = Notification.Name("retotToggleSearch")
}
