import Foundation

/// File-level rules for LaunchMad backups.
///
/// A backup is a folder that holds the layout database and an allowlisted
/// preferences file. Only regular files with the names below are ever copied:
/// symbolic links, sockets, sub-directories and unknown files are skipped, and
/// everything written is readable by the current user only.
enum BackupFiles {
    static let folderPrefix = "LaunchMad_"
    static let folderSuffix = ".launchmad"
    static let legacyFolderPrefix = "LaunchNext_"
    static let legacyFolderSuffix = ".launchnext"
    static let storeFileName = "Data.store"
    /// SQLite companions that must travel with the store to keep it consistent.
    static let storeFileNames = [storeFileName, "Data.store-wal", "Data.store-shm"]

    static let directoryPermissions: Int16 = 0o700
    static let filePermissions: Int16 = 0o600

    enum Failure: LocalizedError {
        case missingStore
        case notRegularFile(String)

        var errorDescription: String? {
            switch self {
            case .missingStore:
                return "The backup does not contain a layout database."
            case .notRegularFile(let name):
                return "\(name) is not a regular file."
            }
        }
    }

    static func folderName(for date: Date) -> String {
        folderPrefix + timestampFormatter.string(from: date) + folderSuffix
    }

    /// Parses the creation date from a backup folder name, accepting folders
    /// created by LaunchMad and by the LaunchNext release it was forked from.
    static func date(fromFolderName name: String) -> Date? {
        for (prefix, suffix) in [(folderPrefix, folderSuffix), (legacyFolderPrefix, legacyFolderSuffix)] {
            guard name.hasPrefix(prefix), name.hasSuffix(suffix),
                  name.count > prefix.count + suffix.count else { continue }
            let raw = name.dropFirst(prefix.count).dropLast(suffix.count)
            return timestampFormatter.date(from: String(raw))
        }
        return nil
    }

    /// True when `url` is a regular file and not a symbolic link or special file.
    static func isRegularFile(_ url: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeRegular
    }

    static func containsStore(_ folder: URL) -> Bool {
        isRegularFile(folder.appendingPathComponent(storeFileName))
    }

    /// Creates `folder` (and missing parents) restricted to the current user.
    static func makePrivateDirectory(_ folder: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: folder,
                               withIntermediateDirectories: true,
                               attributes: [.posixPermissions: NSNumber(value: directoryPermissions)])
        try fm.setAttributes([.posixPermissions: NSNumber(value: directoryPermissions)], ofItemAtPath: folder.path)
    }

    /// Copies the allowlisted store files from `source` into `destination`.
    /// Returns the names that were copied. Throws when the store is missing.
    @discardableResult
    static func copyStoreFiles(from source: URL, to destination: URL) throws -> [String] {
        let fm = FileManager.default
        guard containsStore(source) else { throw Failure.missingStore }
        try makePrivateDirectory(destination)

        var copied: [String] = []
        for name in storeFileNames {
            let sourceURL = source.appendingPathComponent(name)
            guard fm.fileExists(atPath: sourceURL.path) else { continue }
            guard isRegularFile(sourceURL) else {
                if name == storeFileName { throw Failure.notRegularFile(name) }
                continue
            }
            let targetURL = destination.appendingPathComponent(name)
            if fm.fileExists(atPath: targetURL.path) || (try? fm.destinationOfSymbolicLink(atPath: targetURL.path)) != nil {
                try fm.removeItem(at: targetURL)
            }
            try fm.copyItem(at: sourceURL, to: targetURL)
            try fm.setAttributes([.posixPermissions: NSNumber(value: filePermissions)], ofItemAtPath: targetURL.path)
            copied.append(name)
        }
        return copied
    }

    /// Writes `data` to `url` with owner-only permissions.
    static func writePrivateFile(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: filePermissions)], ofItemAtPath: url.path)
    }

    /// Copies a backup's store into a fresh private temporary folder so it can be
    /// opened read-only without touching the backup itself. The caller removes
    /// the returned folder when done.
    static func stageStoreForReading(from backup: URL) throws -> URL {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("LaunchMadRestore-\(UUID().uuidString)", isDirectory: true)
        do {
            try copyStoreFiles(from: backup, to: staging)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
        return staging
    }

    /// Filters an imported preferences dictionary to the allowed keys.
    static func filteredPreferences(_ incoming: [String: Any], allowedKeys: Set<String>) -> [String: Any] {
        incoming.filter { allowedKeys.contains($0.key) }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'_'HH.mm.ss"
        return formatter
    }()
}
