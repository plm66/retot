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
        }
        currentAttributedText = storage.loadNoteContent(for: notes[0].id)
        setupAutoSave()
        setupTerminationObserver()
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

    // MARK: - Private

    private func setupAutoSave() {
        autoSaveSubscription = saveSubject
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.saveCurrentNoteContent()
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
