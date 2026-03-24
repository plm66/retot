import Foundation

enum StorageConstants {
    static var appSupportDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Retot", isDirectory: true)
    }

    static var iCloudDirectory: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.erasmus.retot")?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    /// Returns iCloud directory if available, otherwise local app support
    static var activeDirectory: URL {
        iCloudDirectory ?? appSupportDirectory
    }

    static var isICloudAvailable: Bool {
        iCloudDirectory != nil
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
