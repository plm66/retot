#if os(macOS)
import AppKit
#else
import UIKit
#endif
import SwiftUI

struct AIResultView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: iconForLabel)
                    .foregroundColor(.accentColor)
                Text(appState.aiResultLabel)
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Content
            if appState.aiProcessing {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Traitement en cours...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if let result = appState.aiResult {
                ScrollView {
                    Text(result)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Impossible de traiter le texte.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                if appState.aiHadSelection, appState.aiResult != nil {
                    Button("Remplacer") {
                        if let result = appState.aiResult {
                            appState.replaceSelection(with: result)
                        }
                        appState.showAIResult = false
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }

                if appState.aiResult != nil {
                    Button("Copier") {
                        if let result = appState.aiResult {
                            #if os(macOS)
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(result, forType: .string)
                            #else
                            UIPasteboard.general.string = result
                            #endif
                        }
                    }
                }

                Spacer()

                Button("Fermer") {
                    appState.showAIResult = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 480, height: 360)
    }

    private var iconForLabel: String {
        switch appState.aiResultLabel {
        case "Résumé": return "doc.plaintext"
        case "Reformulation": return "arrow.triangle.2.circlepath"
        case "Correction": return "checkmark.circle"
        default: return "sparkles"
        }
    }
}
