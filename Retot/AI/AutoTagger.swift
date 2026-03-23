import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

@available(macOS 26.0, *)
struct AutoTagger {
    #if canImport(FoundationModels)
    @Generable
    struct NoteTags {
        @Guide(description: "3 to 5 short tags describing the main topics, in the language of the text")
        var tags: [String]
    }

    static func generateTags(for text: String) async -> [String] {
        guard !text.isEmpty, text.count > 50 else { return [] }
        do {
            let session = LanguageModelSession(instructions: AIInstructions.autoTag)
            let response = try await session.respond(to: text, generating: NoteTags.self)
            return response.content.tags.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        } catch {
            return []
        }
    }
    #endif
}
