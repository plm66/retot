import AppKit
import Combine
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppState: ObservableObject {
    @Published var notes: [Note]
    @Published var selectedNoteIndex: Int = 0
    @Published var currentAttributedText: NSAttributedString = NSAttributedString(string: "")

    weak var currentTextView: NSTextView?

    private let storage = StorageManager()
    private var autoSaveSubscription: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()
    private var previousNoteIndex: Int?

    private let autoTagSubject = PassthroughSubject<Void, Never>()
    private var autoTagSubscription: AnyCancellable?

    init() {
        storage.ensureDirectoryStructure()
        notes = storage.loadMetadata()
        if notes.isEmpty {
            let count = UserDefaults.standard.integer(forKey: "retotNoteCount")
            notes = Note.defaults(count: count > 0 ? count : 10)
            storage.saveMetadata(notes)
            createOnboardingContent()
        }
        currentAttributedText = storage.loadNoteContent(for: notes[0].id)
        setupAutoSave()
        setupAutoTag()
        setupTerminationObserver()
        setupSearchShortcut()
        prewarmFoundationModels()
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
        autoTagSubject.send()
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

    // MARK: - Format Painter
    @Published var formatPainterActive = false
    var capturedAttributes: [NSAttributedString.Key: Any]? = nil

    var lastSelectedRange: NSRange = NSRange(location: 0, length: 0)

    @Published var isPinnedOnTop = false
    @Published var savedIndicator = false
    @Published var detachNoteIndex: Int? = nil

    // MARK: - macOS Service
    @Published var receivedServiceText: String? = nil
    @Published var showNotePicker = false
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

    // MARK: - Note Count

    func setNoteCount(_ newCount: Int) {
        guard newCount >= 3, newCount <= 30 else { return }
        saveCurrentNoteContent()

        let currentCount = notes.count
        if newCount > currentCount {
            // Add new notes
            let palette = NoteColor.defaultPalette
            let newNotes = (currentCount..<newCount).map { index in
                Note(
                    id: index + 1,
                    label: "Note \(index + 1)",
                    color: palette[index % palette.count],
                    tags: [],
                    lastModified: Date()
                )
            }
            notes = notes + newNotes
        } else if newCount < currentCount {
            // Remove excess notes (from the end)
            notes = Array(notes.prefix(newCount))
            if selectedNoteIndex >= newCount {
                selectedNoteIndex = newCount - 1
                currentAttributedText = storage.loadNoteContent(for: notes[selectedNoteIndex].id)
            }
        }
        storage.saveMetadata(notes)
        UserDefaults.standard.set(newCount, forKey: "retotNoteCount")
    }

    // MARK: - Save Feedback

    func showSavedFeedback() {
        savedIndicator = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.savedIndicator = false
        }
    }

    // MARK: - Clear & Duplicate

    func clearNote(_ index: Int) {
        guard index >= 0, index < notes.count else { return }
        let empty = NSAttributedString(string: "")
        storage.saveNoteContent(empty, for: notes[index].id)
        if index == selectedNoteIndex {
            currentAttributedText = empty
            // Also clear the NSTextView directly to prevent auto-save restoring old content
            currentTextView?.textStorage?.setAttributedString(empty)
        }
    }

    func duplicateNote(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < notes.count,
              targetIndex >= 0, targetIndex < notes.count else { return }

        let sourceContent: NSAttributedString
        if sourceIndex == selectedNoteIndex {
            saveCurrentNoteContent()
            sourceContent = currentAttributedText
        } else {
            sourceContent = storage.loadNoteContent(for: notes[sourceIndex].id)
        }

        // Prepend to target note
        let targetContent = storage.loadNoteContent(for: notes[targetIndex].id)
        let combined = NSMutableAttributedString()
        combined.append(sourceContent)
        if !sourceContent.string.hasSuffix("\n") {
            combined.append(NSAttributedString(string: "\n"))
        }
        combined.append(targetContent)
        storage.saveNoteContent(combined, for: notes[targetIndex].id)

        // Reload if viewing target
        if targetIndex == selectedNoteIndex {
            currentAttributedText = combined
        }
    }

    // MARK: - Copy Note

    func copyNoteContent(_ index: Int) {
        guard index >= 0, index < notes.count else { return }
        let content: NSAttributedString
        if index == selectedNoteIndex {
            content = currentAttributedText
        } else {
            content = storage.loadNoteContent(for: notes[index].id)
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([content])
    }

    // MARK: - Pin on Top

    func togglePinOnTop() {
        isPinnedOnTop.toggle()
        if let window = NSApp.windows.first(where: { $0.title.hasPrefix("Retot") }) {
            if isPinnedOnTop {
                window.level = .floating
                window.hidesOnDeactivate = false
                window.collectionBehavior.insert(.canJoinAllSpaces)
            } else {
                window.level = .normal
                window.hidesOnDeactivate = true
                window.collectionBehavior.remove(.canJoinAllSpaces)
            }
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

    // MARK: - Service Text Insertion

    func appendTextToNote(at index: Int, text: String) {
        guard index >= 0, index < notes.count else { return }

        let noteId = notes[index].id
        let existingContent = storage.loadNoteContent(for: noteId)

        let combined = NSMutableAttributedString()
        combined.append(existingContent)

        // Add separator newline if existing content doesn't end with one
        if existingContent.length > 0, !existingContent.string.hasSuffix("\n") {
            combined.append(NSAttributedString(string: "\n"))
        }

        // Add a visual separator
        let separatorAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        combined.append(NSAttributedString(
            string: "--- Received via Service (\(timestamp)) ---\n",
            attributes: separatorAttrs
        ))

        // Append the received text with default font
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.textColor
        ]
        combined.append(NSAttributedString(string: text, attributes: textAttrs))
        combined.append(NSAttributedString(string: "\n", attributes: textAttrs))

        // Save
        storage.saveNoteContent(combined, for: noteId)

        // Update modification date
        let updated = notes[index].withModifiedNow()
        notes = notes.enumerated().map { i, note in
            i == index ? updated : note
        }
        storage.saveMetadata(notes)

        // If this note is currently displayed, reload it
        if index == selectedNoteIndex {
            currentAttributedText = combined
            currentTextView?.textStorage?.setAttributedString(combined)
        }
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

    // MARK: - Format Painter Actions

    func captureFormat() {
        guard let textView = currentTextView,
              let textStorage = textView.textStorage else { return }
        let index = textView.selectedRange().location
        guard index < textStorage.length else { return }
        capturedAttributes = textStorage.attributes(at: index, effectiveRange: nil)
        formatPainterActive = true
    }

    func applyFormat() {
        guard let textView = currentTextView,
              let textStorage = textView.textStorage,
              let attrs = capturedAttributes else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }

        let formattingKeys: [NSAttributedString.Key] = [
            .font, .foregroundColor, .backgroundColor,
            .underlineStyle, .strikethroughStyle
        ]

        textStorage.beginEditing()
        for key in formattingKeys {
            if let value = attrs[key] {
                textStorage.addAttribute(key, value: value, range: range)
            }
        }
        textStorage.endEditing()
        textView.didChangeText()

        formatPainterActive = false
        capturedAttributes = nil
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

    // MARK: - AI Features

    @Published var showAIPopover = false
    @Published var showTranslation = false
    @Published var textForTranslation = ""
    @Published var translationHadSelection = false

    // Foundation Models AI
    @Published var aiProcessing = false
    @Published var aiResult: String? = nil
    @Published var showAIResult = false
    @Published var aiResultLabel: String = ""
    @Published var aiHadSelection = false

    // AI Assistant (Tool Calling)
    @Published var showAIAssistant = false
    @Published var assistantMessages: [(role: String, content: String)] = []
    @Published var assistantProcessing = false

    // Entity Extraction
    @Published var showExtraction = false
    @Published var extractionProcessing = false
    @Published var extractedEntitiesRaw: Any? = nil

    func processWithAI(label: String, instruction: String, text: String) {
        guard !text.isEmpty else { return }
        let selected = hasTextSelection
        aiProcessing = true
        aiResult = nil
        aiResultLabel = label
        aiHadSelection = selected
        showAIResult = true

        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            Task { @MainActor in
                do {
                    let session = LanguageModelSession(instructions: AIInstructions.system)
                    let stream = session.streamResponse(to: "\(instruction):\n\n\(text)")
                    for try await partial in stream {
                        aiResult = partial.content
                    }
                    aiProcessing = false
                } catch {
                    aiProcessing = false
                    aiResult = nil
                }
            }
            #else
            aiProcessing = false
            aiResult = nil
            #endif
        } else {
            aiProcessing = false
            aiResult = nil
        }
    }

    var hasTextSelection: Bool {
        guard let textView = currentTextView else { return false }
        return textView.selectedRange().length > 0
    }

    func getSelectedText() -> String {
        guard let textView = currentTextView,
              let textStorage = textView.textStorage else { return "" }
        let range = textView.selectedRange()
        guard range.length > 0 else { return "" }
        return textStorage.attributedSubstring(from: range).string
    }

    func getFullText() -> String {
        guard let textView = currentTextView,
              let textStorage = textView.textStorage else { return "" }
        return textStorage.string
    }

    func replaceSelection(with text: String) {
        guard let textView = currentTextView,
              let textStorage = textView.textStorage else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: text)
        textStorage.endEditing()
        textView.didChangeText()
    }

    // MARK: - Prewarm

    private func prewarmFoundationModels() {
        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            Task {
                // Access the model to trigger loading/caching
                let _ = SystemLanguageModel.default
            }
            #endif
        }
    }

    // MARK: - AI Assistant (Tool Calling)

    func sendAssistantMessage(_ text: String) {
        assistantMessages.append((role: "user", content: text))
        assistantProcessing = true

        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            Task { @MainActor in
                do {
                    let response = try await performAssistantQuery(text)
                    assistantMessages.append((role: "assistant", content: response))
                } catch {
                    assistantMessages.append(
                        (role: "assistant", content: "Desole, une erreur est survenue: \(error.localizedDescription)")
                    )
                }
                assistantProcessing = false
            }
            #else
            assistantMessages.append(
                (role: "assistant", content: "Foundation Models n'est pas disponible sur cette machine.")
            )
            assistantProcessing = false
            #endif
        } else {
            assistantMessages.append(
                (role: "assistant", content: "Foundation Models necessite macOS 26.0 ou plus recent.")
            )
            assistantProcessing = false
        }
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func performAssistantQuery(_ text: String) async throws -> String {
        // Snapshot data for Sendable closures
        let noteSnapshot = buildNoteSnapshot()

        let searchTool = SearchNotesTool(searchHandler: { query in
            Self.searchNotesInSnapshot(noteSnapshot, query: query)
        })

        let listTool = ListNotesTool(listHandler: {
            Self.listNotesInSnapshot(noteSnapshot)
        })

        let readTool = ReadNoteTool(readHandler: { noteId in
            Self.readNoteInSnapshot(noteSnapshot, noteId: noteId)
        })

        let session = LanguageModelSession(
            tools: [searchTool, listTool, readTool],
            instructions: """
            \(AIInstructions.system)
            Tu as acces a des outils pour interagir avec les notes de l'utilisateur.
            Utilise-les quand c'est pertinent pour repondre aux questions.
            """
        )

        let response = try await session.respond(to: text)
        return response.content
    }
    #endif

    private struct NoteSnapshotEntry: Sendable {
        let id: Int
        let label: String
        let tags: [String]
        let content: String
    }

    private func buildNoteSnapshot() -> [NoteSnapshotEntry] {
        let storage = StorageManager()
        return notes.enumerated().map { index, note in
            let content: String
            if index == selectedNoteIndex {
                content = currentAttributedText.string
            } else {
                content = storage.loadNoteContent(for: note.id).string
            }
            return NoteSnapshotEntry(id: note.id, label: note.label, tags: note.tags, content: content)
        }
    }

    private static func searchNotesInSnapshot(_ snapshot: [NoteSnapshotEntry], query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { return "Query too short (minimum 2 characters)" }

        var results: [String] = []
        for note in snapshot {
            let lower = note.content.lowercased()
            if let range = lower.range(of: trimmed) {
                let content = note.content
                let start = content.index(
                    range.lowerBound,
                    offsetBy: -min(40, content.distance(from: content.startIndex, to: range.lowerBound)),
                    limitedBy: content.startIndex
                ) ?? content.startIndex
                let end = content.index(
                    range.upperBound,
                    offsetBy: min(100, content.distance(from: range.upperBound, to: content.endIndex)),
                    limitedBy: content.endIndex
                ) ?? content.endIndex
                let excerpt = String(content[start..<end]).replacingOccurrences(of: "\n", with: " ")
                results.append("- Note \(note.id) (\(note.label)): ...\(excerpt)...")
            }
        }
        if results.isEmpty { return "No results found for '\(query)'" }
        return results.joined(separator: "\n")
    }

    private static func listNotesInSnapshot(_ snapshot: [NoteSnapshotEntry]) -> String {
        return snapshot.map { note in
            let tagsStr = note.tags.isEmpty ? "" : " [tags: \(note.tags.joined(separator: ", "))]"
            return "- Note \(note.id): \(note.label)\(tagsStr)"
        }.joined(separator: "\n")
    }

    private static func readNoteInSnapshot(_ snapshot: [NoteSnapshotEntry], noteId: Int) -> String {
        guard let note = snapshot.first(where: { $0.id == noteId }) else {
            return "Note with ID \(noteId) not found"
        }
        let truncated = note.content.count > 2000
            ? String(note.content.prefix(2000)) + "... (truncated)"
            : note.content
        return "Note \(noteId) (\(note.label)):\n\(truncated)"
    }

    // MARK: - Entity Extraction

    func extractEntities(from text: String) {
        guard !text.isEmpty else { return }
        extractionProcessing = true
        showExtraction = true

        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            extractedEntitiesRaw = nil
            Task { @MainActor in
                let result = await EntityExtractor.extract(from: text)
                extractedEntitiesRaw = result
                extractionProcessing = false
            }
            #else
            extractionProcessing = false
            #endif
        } else {
            extractionProcessing = false
        }
    }

    // MARK: - Private

    private func setupAutoSave() {
        autoSaveSubscription = saveSubject
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.saveCurrentNoteContent()
            }
    }

    private func setupAutoTag() {
        autoTagSubscription = autoTagSubject
            .debounce(for: .seconds(10), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.triggerAutoTag()
            }
    }

    private func triggerAutoTag() {
        guard IntelligenceAvailability.supportsFoundationModels else { return }
        let text = currentAttributedText.string
        guard text.count > 50 else { return }
        let noteIndex = selectedNoteIndex
        let existingTags = notes[noteIndex].tags

        if #available(macOS 26.0, *) {
            #if canImport(FoundationModels)
            Task { @MainActor in
                let newTags = await AutoTagger.generateTags(for: text)
                guard !newTags.isEmpty else { return }
                // Only update if tags actually changed
                let sorted = newTags.sorted()
                let existingSorted = existingTags.sorted()
                guard sorted != existingSorted else { return }
                // Only update if still on the same note
                guard self.selectedNoteIndex == noteIndex else { return }
                self.updateNoteTags(noteIndex, tags: newTags)
            }
            #endif
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
