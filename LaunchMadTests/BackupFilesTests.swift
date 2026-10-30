import Foundation
import XCTest

final class BackupFilesTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupFilesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, in folder: URL, contents: String = "x") throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: folder.appendingPathComponent(name))
    }

    private func permissions(of url: URL) throws -> Int16 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.int16Value ?? -1
    }

    func testCopiesOnlyAllowlistedRegularFilesWithPrivatePermissions() throws {
        let source = root.appendingPathComponent("support", isDirectory: true)
        try write("Data.store", in: source, contents: "store")
        try write("Data.store-wal", in: source)
        try write("cli_history", in: source)
        try write("CustomAppIcon.png", in: source)
        try FileManager.default.createDirectory(at: source.appendingPathComponent("updates"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: source.appendingPathComponent("Data.store-shm"),
                                                   withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))

        let destination = root.appendingPathComponent("backup", isDirectory: true)
        let copied = try BackupFiles.copyStoreFiles(from: source, to: destination)

        XCTAssertEqual(copied, ["Data.store", "Data.store-wal"])
        let contents = try FileManager.default.contentsOfDirectory(atPath: destination.path).sorted()
        XCTAssertEqual(contents, ["Data.store", "Data.store-wal"])
        XCTAssertEqual(try permissions(of: destination), BackupFiles.directoryPermissions)
        XCTAssertEqual(try permissions(of: destination.appendingPathComponent("Data.store")), BackupFiles.filePermissions)
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("Data.store"), encoding: .utf8), "store")
    }

    func testRejectsMissingOrSymlinkedStore() throws {
        let empty = root.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        XCTAssertThrowsError(try BackupFiles.copyStoreFiles(from: empty, to: root.appendingPathComponent("out1")))

        let linked = root.appendingPathComponent("linked", isDirectory: true)
        try write("real.store", in: linked)
        try FileManager.default.createSymbolicLink(at: linked.appendingPathComponent("Data.store"),
                                                   withDestinationURL: linked.appendingPathComponent("real.store"))
        XCTAssertFalse(BackupFiles.containsStore(linked))
        XCTAssertThrowsError(try BackupFiles.copyStoreFiles(from: linked, to: root.appendingPathComponent("out2")))
    }

    func testStagingCopiesStoreAndLeavesBackupUntouched() throws {
        let backup = root.appendingPathComponent("LaunchMad_2026-10-30_10.00.00.launchmad", isDirectory: true)
        try write("Data.store", in: backup, contents: "original")

        let staging = try BackupFiles.stageStoreForReading(from: backup)
        defer { try? FileManager.default.removeItem(at: staging) }

        try Data("changed".utf8).write(to: staging.appendingPathComponent("Data.store"))
        XCTAssertEqual(try String(contentsOf: backup.appendingPathComponent("Data.store"), encoding: .utf8), "original")
        XCTAssertNotEqual(staging.deletingLastPathComponent().standardizedFileURL, backup.deletingLastPathComponent().standardizedFileURL)
    }

    func testFolderNamesRoundTripAndAcceptLegacyNames() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let name = BackupFiles.folderName(for: date)
        XCTAssertTrue(name.hasPrefix(BackupFiles.folderPrefix))
        XCTAssertTrue(name.hasSuffix(BackupFiles.folderSuffix))
        XCTAssertEqual(BackupFiles.date(fromFolderName: name)?.timeIntervalSince1970, date.timeIntervalSince1970)
        XCTAssertNotNil(BackupFiles.date(fromFolderName: "LaunchNext_2026-01-02_03.04.05.launchnext"))
        XCTAssertNil(BackupFiles.date(fromFolderName: "Something_2026-01-02_03.04.05.launchmad"))
        XCTAssertNil(BackupFiles.date(fromFolderName: "LaunchMad_.launchmad"))
    }

    func testPreferenceFilteringDropsUnlistedKeys() {
        let incoming: [String: Any] = [
            "launchMadPinnedAppPaths": ["/Applications/Safari.app"],
            "launchMadRecentAppPaths": ["/Applications/Mail.app"],
            "autoCheckForUpdates": true
        ]
        let filtered = BackupFiles.filteredPreferences(incoming, allowedKeys: ["launchMadPinnedAppPaths"])
        XCTAssertEqual(Set(filtered.keys), ["launchMadPinnedAppPaths"])
    }

    func testPrivateFileWrite() throws {
        let url = root.appendingPathComponent("prefs.plist")
        try BackupFiles.writePrivateFile(Data("a".utf8), to: url)
        XCTAssertEqual(try permissions(of: url), BackupFiles.filePermissions)
    }
}
