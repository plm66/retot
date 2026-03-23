import SwiftUI

struct AIPopoverView: View {
    @EnvironmentObject var appState: AppState

    private var selectedOrFullText: String {
        let selected = appState.getSelectedText()
        return selected.isEmpty ? appState.getFullText() : selected
    }

    private var hasSelection: Bool {
        appState.hasTextSelection
    }

    private var hasFoundationModels: Bool {
        IntelligenceAvailability.supportsFoundationModels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Assistant (Tool Calling)
            Button(action: triggerAssistant) {
                Label("Assistant", systemImage: "bubble.left.and.text.bubble.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .disabled(!hasFoundationModels)

            Divider()

            // Translation - available now
            Button(action: triggerTranslation) {
                Label("Traduire", systemImage: "globe")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .disabled(appState.getFullText().isEmpty)

            Divider()

            // Résumer
            Button(action: triggerResumer) {
                Label("Résumer", systemImage: "doc.plaintext")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .disabled(!hasFoundationModels || selectedOrFullText.isEmpty)

            // Reformuler - requires selection
            Button(action: triggerReformuler) {
                Label("Reformuler", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .disabled(!hasFoundationModels || !hasSelection)

            // Corriger
            Button(action: triggerCorriger) {
                Label("Corriger", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .disabled(!hasFoundationModels || selectedOrFullText.isEmpty)

            Divider()

            // Extraire
            Button(action: triggerExtraire) {
                Label("Extraire", systemImage: "text.magnifyingglass")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .disabled(!hasFoundationModels || selectedOrFullText.isEmpty)
        }
        .padding(.vertical, 6)
        .frame(width: 180)
        .font(.system(size: 13))
    }

    private func triggerAssistant() {
        appState.showAIPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.showAIAssistant = true
        }
    }

    private func triggerExtraire() {
        let text = selectedOrFullText
        appState.showAIPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.extractEntities(from: text)
        }
    }

    private func triggerTranslation() {
        let selected = appState.getSelectedText()
        let hadSelection = !selected.isEmpty
        appState.textForTranslation = hadSelection ? selected : appState.getFullText()
        appState.translationHadSelection = hadSelection
        appState.showAIPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.showTranslation = true
        }
    }

    private func triggerResumer() {
        let text = selectedOrFullText
        appState.showAIPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.processWithAI(
                label: "Résumé",
                instruction: AIInstructions.resumer,
                text: text
            )
        }
    }

    private func triggerReformuler() {
        let text = appState.getSelectedText()
        guard !text.isEmpty else { return }
        appState.showAIPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.processWithAI(
                label: "Reformulation",
                instruction: AIInstructions.reformuler,
                text: text
            )
        }
    }

    private func triggerCorriger() {
        let text = selectedOrFullText
        appState.showAIPopover = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.processWithAI(
                label: "Correction",
                instruction: AIInstructions.corriger,
                text: text
            )
        }
    }
}
