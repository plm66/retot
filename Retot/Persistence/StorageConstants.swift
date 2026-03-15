import Foundation

enum StorageConstants {
    static var appSupportDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Retot", isDirectory: true)
    }

    static var notesDirectory: URL {
        appSupportDirectory.appendingPathComponent("notes", isDirectory: true)
    }

    static var metadataURL: URL {
        appSupportDirectory.appendingPathComponent("metadata.json")
    }

    static func noteURL(for id: Int) -> URL {
        notesDirectory.appendingPathComponent("note-\(id).html")
    }
}
