import Foundation
#if canImport(FoundationModels)
import FoundationModels

// MARK: - Search Notes Tool

@available(macOS 26.0, iOS 26.0, *)
struct SearchNotesTool: Tool {
    let name = "searchNotes"
    let description = "Search across all notes for a query string. Returns matching note names and excerpts."

    typealias Output = String

    @Generable
    struct Arguments {
        @Guide(description: "The search query to look for in notes")
        var query: String
    }

    var searchHandler: @Sendable (String) -> String

    func call(arguments: Arguments) async throws -> String {
        return searchHandler(arguments.query)
    }
}

// MARK: - List Notes Tool

@available(macOS 26.0, iOS 26.0, *)
struct ListNotesTool: Tool {
    let name = "listNotes"
    let description = "List all available notes with their names, IDs, and tags."

    typealias Output = String

    @Generable
    struct Arguments {
        @Guide(description: "Set to true to list all notes")
        var listAll: Bool
    }

    var listHandler: @Sendable () -> String

    func call(arguments: Arguments) async throws -> String {
        return listHandler()
    }
}

// MARK: - Read Note Tool

@available(macOS 26.0, iOS 26.0, *)
struct ReadNoteTool: Tool {
    let name = "readNote"
    let description = "Read the full content of a specific note by its ID number."

    typealias Output = String

    @Generable
    struct Arguments {
        @Guide(description: "The note ID number (1-based)")
        var noteId: Int
    }

    var readHandler: @Sendable (Int) -> String

    func call(arguments: Arguments) async throws -> String {
        return readHandler(arguments.noteId)
    }
}
#endif
