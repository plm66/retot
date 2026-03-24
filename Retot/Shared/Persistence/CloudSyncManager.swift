import Foundation
import Combine

final class CloudSyncManager: ObservableObject {
    @Published var iCloudAvailable = false
    @Published var syncStatus: SyncStatus = .idle

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case error(String)
    }

    private var metadataQuery: NSMetadataQuery?

    init() {
        checkiCloudAvailability()
        setupFileMonitoring()
    }

    func checkiCloudAvailability() {
        iCloudAvailable = StorageConstants.isICloudAvailable
    }

    /// Start monitoring iCloud for changes from other devices
    func setupFileMonitoring() {
        guard StorageConstants.isICloudAvailable else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.json'", NSMetadataItemFSNameKey)

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.handleFileChanges(notification)
        }

        query.start()
        metadataQuery = query
    }

    private func handleFileChanges(_ notification: Notification) {
        // Notify AppState that files changed from another device
        NotificationCenter.default.post(name: .retotCloudFilesChanged, object: nil)
    }

    /// Copy local notes to iCloud container (first-time setup)
    func migrateLocalToCloud() {
        guard let cloudDir = StorageConstants.iCloudDirectory else { return }
        let localDir = StorageConstants.appSupportDirectory

        let fm = FileManager.default

        // Ensure cloud directory exists
        try? fm.createDirectory(at: cloudDir, withIntermediateDirectories: true)
        let cloudNotesDir = cloudDir.appendingPathComponent("notes", isDirectory: true)
        try? fm.createDirectory(at: cloudNotesDir, withIntermediateDirectories: true)

        // Copy metadata
        let localMeta = localDir.appendingPathComponent("metadata.json")
        let cloudMeta = cloudDir.appendingPathComponent("metadata.json")
        if fm.fileExists(atPath: localMeta.path), !fm.fileExists(atPath: cloudMeta.path) {
            try? fm.copyItem(at: localMeta, to: cloudMeta)
        }

        // Copy JSON notes and images
        let localNotesDir = localDir.appendingPathComponent("notes", isDirectory: true)
        if let contents = try? fm.contentsOfDirectory(at: localNotesDir, includingPropertiesForKeys: nil) {
            for url in contents {
                let dest = cloudNotesDir.appendingPathComponent(url.lastPathComponent)
                if !fm.fileExists(atPath: dest.path) {
                    try? fm.copyItem(at: url, to: dest)
                }
            }
        }
    }

    deinit {
        metadataQuery?.stop()
    }
}

extension Notification.Name {
    static let retotCloudFilesChanged = Notification.Name("retotCloudFilesChanged")
}
