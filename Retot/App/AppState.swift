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
