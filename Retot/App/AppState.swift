import AppKit
import Combine
import Foundation

final class AppState: ObservableObject {
    @Published var notes: [Note]
    @Published var selectedNoteIndex: Int = 0
    @Published var currentAttributedText: NSAttributedString = NSAttributedString(string: "")

    weak var currentTextView: NSTextView?

    private let storage = StorageManager()
    private var autoSaveSubscription: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()
    private var previousNoteIndex: Int?

    init() {
        storage.ensureDirectoryStructure()
        notes = storage.loadMetadata()
        if notes.isEmpty {
            notes = Note.defaults()
            storage.saveMetadata(notes)
            createOnboardingContent()
        }
        currentAttributedText = storage.loadNoteContent(for: notes[0].id)
        setupAutoSave()
        setupTerminationObserver()
        setupSearchShortcut()
    }

    // MARK: - Note Selection

    func selectNote(_ index: Int) {
        guard index >= 0, index < notes.count, index != selectedNoteIndex else { return }
        saveCurrentNoteContent()
        previousNoteIndex = selectedNoteIndex
        selectedNoteIndex = index
        currentAttributedText = storage.loadNoteContent(for: notes[index].id)
    }

    // MARK: - Note Updates (Immutable)

    func updateNoteLabel(_ index: Int, label: String) {
        guard index >= 0, index < notes.count else { return }
        let updated = notes[index].withLabel(label)
        notes = notes.enumerated().map { i, note in
            i == index ? updated : note
        }
        storage.saveMetadata(notes)
    }

    func updateNoteColor(_ index: Int, color: NoteColor) {
        guard index >= 0, index < notes.count else { return }
        let updated = notes[index].withColor(color)
        notes = notes.enumerated().map { i, note in
            i == index ? updated : note
        }
        storage.saveMetadata(notes)
    }

    // MARK: - Font & Background Colors

    func updateNoteFontColor(_ index: Int, hex: String?) {
        guard index >= 0, index < notes.count else { return }
        let updated = notes[index].withFontColor(hex)
        notes = notes.enumerated().map { i, note in
            i == index ? updated : note
        }
        storage.saveMetadata(notes)
    }

    func updateNoteBackgroundColor(_ index: Int, hex: String?) {
        guard index >= 0, index < notes.count else { return }
        let updated = notes[index].withBackgroundColor(hex)
        notes = notes.enumerated().map { i, note in
            i == index ? updated : note
        }
        storage.saveMetadata(notes)
    }

    // MARK: - Tags

    func updateNoteTags(_ index: Int, tags: [String]) {
        guard index >= 0, index < notes.count else { return }
        let updated = notes[index].withTags(tags)
        notes = notes.enumerated().map { i, note in
            i == index ? updated : note
        }
        storage.saveMetadata(notes)
    }

    func addTag(_ tag: String, toNoteAt index: Int) {
        guard index >= 0, index < notes.count else { return }
        let trimmed = tag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !notes[index].tags.contains(trimmed) else { return }
        let newTags = notes[index].tags + [trimmed]
        updateNoteTags(index, tags: newTags)
    }

    func removeTag(_ tag: String, fromNoteAt index: Int) {
        guard index >= 0, index < notes.count else { return }
        let newTags = notes[index].tags.filter { $0 != tag }
        updateNoteTags(index, tags: newTags)
    }

    // MARK: - Bulk Export/Import

    func exportAllNotes(to directory: URL) {
        for note in notes {
            let content = storage.loadNoteContent(for: note.id)
            let markdown = MarkdownExporter.convert(content)
            let fileURL = directory.appendingPathComponent("\(note.label).md")
            try? markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        let metaURL = directory.appendingPathComponent("retot-metadata.json")
        let metadata = notes.map(NoteMetadata.from)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(metadata) {
            try? data.write(to: metaURL, options: .atomic)
        }
    }

    func importAllNotes(from directory: URL) {
        let metaURL = directory.appendingPathComponent("retot-metadata.json")
        guard let data = try? Data(contentsOf: metaURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let metadata = try? decoder.decode([NoteMetadata].self, from: data) else { return }

        notes = metadata.map { $0.toNote() }
        storage.saveMetadata(notes)

        for note in notes {
            let fileURL = directory.appendingPathComponent("\(note.label).md")
            if let markdown = try? String(contentsOf: fileURL, encoding: .utf8) {
                let attributed = NSAttributedString(
                    string: markdown,
                    attributes: [.font: NSFont.systemFont(ofSize: 14)]
                )
                storage.saveNoteContent(attributed, for: note.id)
            }
        }

        currentAttributedText = storage.loadNoteContent(for: notes[selectedNoteIndex].id)
    }

    // MARK: - Content Persistence

    func notifyTextChanged() {
        saveSubject.send()
    }

    func saveCurrentNoteContent() {
        let noteId = notes[selectedNoteIndex].id
        storage.saveNoteContent(currentAttributedText, for: noteId)
        let updated = notes[selectedNoteIndex].withModifiedNow()
        notes = notes.enumerated().map { i, note in
            i == selectedNoteIndex ? updated : note
        }
        storage.saveMetadata(notes)
    }

    // MARK: - Global Search

    struct SearchResult: Identifiable {
        let id = UUID()
        let noteIndex: Int
        let noteLabel: String
        let noteColor: NoteColor
        let excerpt: String
        let matchRange: Range<String.Index>
    }

    @Published var isPinnedOnTop = false
    @Published var isSearching = false
    @Published var searchQuery = ""
    @Published var searchResults: [SearchResult] = []

    func performSearch(_ query: String) {
        searchQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        var results: [SearchResult] = []
        for (index, note) in notes.enumerated() {
            let content: String
            if index == selectedNoteIndex {
                content = currentAttributedText.string
            } else {
                content = storage.loadNoteContent(for: note.id).string
            }

            let lower = content.lowercased()
            var searchStart = lower.startIndex
            while let range = lower.range(of: trimmed, range: searchStart..<lower.endIndex) {
                // Extract excerpt: 40 chars before and after
                let excerptStart = content.index(range.lowerBound, offsetBy: -40, limitedBy: content.startIndex) ?? content.startIndex
                let excerptEnd = content.index(range.upperBound, offsetBy: 40, limitedBy: content.endIndex) ?? content.endIndex
                let excerpt = String(content[excerptStart..<excerptEnd])
                    .replacingOccurrences(of: "\n", with: " ")

                results.append(SearchResult(
                    noteIndex: index,
                    noteLabel: note.label,
                    noteColor: note.color,
                    excerpt: excerpt,
                    matchRange: range
                ))

                searchStart = range.upperBound
                // Limit to 5 results per note
                if results.filter({ $0.noteIndex == index }).count >= 5 { break }
            }
        }
        searchResults = results
    }

    func navigateToSearchResult(_ result: SearchResult) {
        selectNote(result.noteIndex)
        isSearching = false
        searchQuery = ""
        searchResults = []
    }

    // MARK: - Pin on Top

    func togglePinOnTop() {
        isPinnedOnTop.toggle()
        if let window = NSApp.windows.first(where: { $0.title == "Retot" }) {
            window.level = isPinnedOnTop ? .floating : .normal
        }
    }

    // MARK: - Content Check

    func noteHasContent(_ index: Int) -> Bool {
        guard index >= 0, index < notes.count else { return false }
        if index == selectedNoteIndex {
            return currentAttributedText.length > 0
        }
        return storage.loadNoteContent(for: notes[index].id).length > 0
    }

    // MARK: - Pastille Move

    func receivePastille(_ attributedString: NSAttributedString, inNoteAt targetIndex: Int) {
        guard targetIndex >= 0, targetIndex < notes.count else { return }

        // Save current note first (pastille already removed from textStorage)
        saveCurrentNoteContent()

        // Load target note content
        let targetContent = storage.loadNoteContent(for: notes[targetIndex].id)

        // Insert pastille at the beginning of target note
        let combined = NSMutableAttributedString()
        combined.append(attributedString)
        if !attributedString.string.hasSuffix("\n") {
            combined.append(NSAttributedString(string: "\n"))
        }
        combined.append(targetContent)

        // Save target note
        storage.saveNoteContent(combined, for: notes[targetIndex].id)
    }

    // MARK: - Memory Management

    func releaseMemory() {
        currentAttributedText = NSAttributedString(string: "")
        currentTextView = nil
    }

    func reloadCurrentNote() {
        if currentAttributedText.length == 0 {
            currentAttributedText = storage.loadNoteContent(for: notes[selectedNoteIndex].id)
        }
    }

    // MARK: - Wiki Link Navigation

    func navigateToNote(named label: String) {
        guard let index = notes.firstIndex(where: {
            $0.label.localizedCaseInsensitiveCompare(label) == .orderedSame
        }) else {
            return
        }
        selectNote(index)
    }

    // MARK: - Onboarding

    private func createOnboardingContent() {
        let html = """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system, sans-serif; font-size: 14px; }
        h1 { font-size: 20px; font-weight: bold; }
        h2 { font-size: 16px; font-weight: bold; margin-top: 14px; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th { background-color: rgba(0,122,255,0.08); font-weight: 600; text-align: left; padding: 6px; border: 1px solid #888; }
        td { padding: 6px; border: 1px solid #888; }
        </style>
        </head><body>
        <h1>Welcome to Retot</h1>
        <p>Your scratch pad for ideas, passwords, snippets, and everything in between.</p>

        <h2>Quick Start</h2>
        <table>
        <tr><th>Action</th><th>How</th></tr>
        <tr><td>Switch notes</td><td>Click a colored dot, or Cmd+1 to Cmd+0</td></tr>
        <tr><td>Search all notes</td><td>Click the magnifying glass, or Cmd+Shift+F</td></tr>
        <tr><td>Format text</td><td>Select text, then use the toolbar (Bold, Italic, Heading...)</td></tr>
        <tr><td>Insert a table</td><td>Click the table icon in the toolbar</td></tr>
        <tr><td>Paste a table</td><td>Copy a markdown or HTML table and Cmd+V</td></tr>
        <tr><td>Change font size</td><td>Select text, then use the magnifying glass +/- buttons</td></tr>
        <tr><td>Create a pastille</td><td>Select text, click the pastille icon (overlapping rectangles)</td></tr>
        <tr><td>Move a pastille</td><td>Right-click on a pastille, then Move to... Dot N</td></tr>
        <tr><td>Note settings</td><td>Right-click on a dot for rename, color, tags</td></tr>
        <tr><td>App settings</td><td>Click the gear icon</td></tr>
        </table>

        <h2>Tips</h2>
        <p>&#8226; Use <b>[[Note Name]]</b> to create wiki links between notes</p>
        <p>&#8226; Each note has its own font color and background color (in Note Settings)</p>
        <p>&#8226; Your notes are saved automatically as you type</p>
        <p>&#8226; Close the window with the red button — the app stays in the menu bar</p>
        <p>&#8226; This note is yours — edit or delete it anytime!</p>
        </body></html>
        """

        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else { return }

        // Build final content: logo + HTML text
        let finalContent = NSMutableAttributedString()

        // Center paragraph style for logo
        let centerStyle = NSMutableParagraphStyle()
        centerStyle.alignment = .center

        // Add app icon as inline image
        if let appIcon = NSImage(named: "AppIcon") {
            let logoSize: CGFloat = 128
            appIcon.size = NSSize(width: logoSize, height: logoSize)
            let attachment = NSTextAttachment()
            attachment.image = appIcon
            let iconString = NSMutableAttributedString(attachment: attachment)
            iconString.addAttribute(.paragraphStyle, value: centerStyle, range: NSRange(location: 0, length: iconString.length))
            finalContent.append(iconString)
            finalContent.append(NSAttributedString(string: "\n\n"))
        }

        finalContent.append(attributed)
        storage.saveNoteContent(finalContent, for: notes[0].id)
    }

    // MARK: - Private

    private func setupAutoSave() {
        autoSaveSubscription = saveSubject
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.saveCurrentNoteContent()
            }
    }

    private func setupSearchShortcut() {
        NotificationCenter.default.addObserver(
            forName: .retotToggleSearch,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSearching.toggle()
            if self?.isSearching == false {
                self?.searchQuery = ""
                self?.searchResults = []
            }
        }
    }

    private func setupTerminationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveCurrentNoteContent()
        }
    }
}
