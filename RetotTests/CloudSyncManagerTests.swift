import XCTest
@testable import Retot

final class CloudSyncManagerTests: XCTestCase {

    // MARK: - iCloud Availability Fallback

    func testICloudUnavailableFallback() {
        // StorageConstants.activeDirectory should return a valid path even
        // when iCloud is unavailable (CI environments, sandboxed tests).
        // It falls back to local app support.
        let activeDir = StorageConstants.activeDirectory
        XCTAssertFalse(activeDir.path.isEmpty, "Active directory should never be empty")

        // When no custom directory is set and iCloud may not be available,
        // the active directory should still be a usable path
        let fm = FileManager.default
        // The parent of activeDirectory should be creatable
        let parent = activeDir.deletingLastPathComponent()
        XCTAssertTrue(
            fm.fileExists(atPath: parent.path) || fm.isWritableFile(atPath: parent.path),
            "Active directory parent should be accessible"
        )
    }

    // MARK: - Active Directory Priority

    func testActiveDirectoryPriority() {
        // Save and restore original custom directory setting
        let originalCustom = UserDefaults.standard.string(forKey: "retotCustomStoragePath")
        defer {
            if let original = originalCustom {
                UserDefaults.standard.set(original, forKey: "retotCustomStoragePath")
            } else {
                UserDefaults.standard.removeObject(forKey: "retotCustomStoragePath")
            }
        }

        // Create a temporary custom directory
        let customDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetotCustomPriority-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: customDir) }

        // Set custom directory
        StorageConstants.customDirectory = customDir

        // Active directory should now be the custom directory
        let active = StorageConstants.activeDirectory
        XCTAssertEqual(active.path, customDir.path,
                        "Custom directory should take priority over iCloud and local")
        XCTAssertTrue(StorageConstants.isUsingCustomDirectory)

        // Clear custom directory
        StorageConstants.customDirectory = nil
        XCTAssertFalse(StorageConstants.isUsingCustomDirectory)

        // Active directory should fall back to iCloud or local
        let fallback = StorageConstants.activeDirectory
        XCTAssertNotEqual(fallback.path, customDir.path,
                           "Without custom dir, should fall back to iCloud or local")
    }

    // MARK: - CloudSyncManager Initialization

    func testCloudSyncManagerInitialization() {
        let syncManager = CloudSyncManager()

        // Should initialize without crashing
        // iCloudAvailable depends on environment but should be a valid boolean
        _ = syncManager.iCloudAvailable

        // Sync status should start as idle
        XCTAssertEqual(syncManager.syncStatus, .idle)
    }

    // MARK: - SyncStatus Equatable

    func testSyncStatusEquatable() {
        XCTAssertEqual(CloudSyncManager.SyncStatus.idle, CloudSyncManager.SyncStatus.idle)
        XCTAssertEqual(CloudSyncManager.SyncStatus.syncing, CloudSyncManager.SyncStatus.syncing)
        XCTAssertEqual(
            CloudSyncManager.SyncStatus.error("test"),
            CloudSyncManager.SyncStatus.error("test")
        )
        XCTAssertNotEqual(CloudSyncManager.SyncStatus.idle, CloudSyncManager.SyncStatus.syncing)
        XCTAssertNotEqual(
            CloudSyncManager.SyncStatus.error("a"),
            CloudSyncManager.SyncStatus.error("b")
        )
    }
}
