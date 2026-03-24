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

    /// User-configured custom storage directory (Dropbox, OneDrive, etc.)
    static var customDirectory: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: "retotCustomStoragePath") else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.path, forKey: "retotCustomStoragePath")
            } else {
                UserDefaults.standard.removeObject(forKey: "retotCustomStoragePath")
            }
        }
    }

    /// Returns custom folder > iCloud > local app support (in priority order)
    static var activeDirectory: URL {
        if let custom = customDirectory, FileManager.default.fileExists(atPath: custom.path) {
            return custom
        }
        return iCloudDirectory ?? appSupportDirectory
    }

    static var isUsingCustomDirectory: Bool {
        if let custom = customDirectory, FileManager.default.fileExists(atPath: custom.path) {
            return true
        }
        return false
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
