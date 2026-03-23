import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ExtractionResultView: View {
    @EnvironmentObject var appState: AppState

    private struct DisplayEntities {
        let todos: [String]
        let dates: [String]
        let names: [String]
        let topics: [String]

        var isEmpty: Bool {
            todos.isEmpty && dates.isEmpty && names.isEmpty && topics.isEmpty
        }
    }

    private var entities: DisplayEntities? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if let raw = appState.extractedEntitiesRaw as? EntityExtractor.ExtractedEntities {
                return DisplayEntities(
                    todos: raw.todos,
                    dates: raw.dates,
                    names: raw.names,
                    topics: raw.topics
                )
            }
        }
        #endif
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundColor(.accentColor)
                Text("Extraction")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            if appState.extractionProcessing {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Extraction en cours...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if let entities, !entities.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !entities.todos.isEmpty {
                            extractionSection(
                                title: "TODOs",
                                icon: "checkmark.circle",
                                items: entities.todos
                            )
                        }
                        if !entities.dates.isEmpty {
                            extractionSection(
                                title: "Dates",
                                icon: "calendar",
                                items: entities.dates
                            )
                        }
                        if !entities.names.isEmpty {
                            extractionSection(
                                title: "Noms",
                                icon: "person",
                                items: entities.names
                            )
                        }
                        if !entities.topics.isEmpty {
                            extractionSection(
                                title: "Sujets",
                                icon: "tag",
                                items: entities.topics
                            )
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Aucune entite extraite.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                Spacer()
                Button("Fermer") {
                    appState.showExtraction = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 480, height: 400)
    }

    private func extractionSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline.bold())
            }
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("\u{2022}")
                        .foregroundColor(.secondary)
                    Text(item)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(.leading, 8)
            }
        }
    }
}
