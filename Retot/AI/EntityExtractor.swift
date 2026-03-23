import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
struct EntityExtractor {
    @Generable
    struct ExtractedEntities {
        @Guide(description: "List of action items or TODO tasks found in the text")
        var todos: [String]

        @Guide(description: "List of dates or deadlines mentioned in the text")
        var dates: [String]

        @Guide(description: "List of person names mentioned in the text")
        var names: [String]

        @Guide(description: "List of important topics or keywords")
        var topics: [String]
    }

    static func extract(from text: String) async -> ExtractedEntities? {
        guard !text.isEmpty else { return nil }
        do {
            let session = LanguageModelSession(
                instructions: "Extract structured information from the following text. Be thorough but precise."
            )
            let response = try await session.respond(to: text, generating: ExtractedEntities.self)
            return response.content
        } catch {
            return nil
        }
    }
}
#endif
