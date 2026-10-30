import Foundation

// Pure, Foundation-only state for the "Pinned" and "Last used" rows shown above
// the launcher grid. Applications are identified by their bundle path, which is
// the same stable identifier `AppInfo.id` uses.

/// Ordered, user-controlled list of pinned application paths.
struct PinnedAppList: Equatable {
    static let maximumCount = 64

    private(set) var paths: [String]

    init(paths: [String] = []) {
        self.paths = Array(LauncherShortcutPaths.sanitized(paths).prefix(Self.maximumCount))
    }

    var isEmpty: Bool { paths.isEmpty }

    func contains(_ path: String) -> Bool {
        paths.contains(path)
    }

    /// Appends `path` to the end of the list. Returns `false` when it was already
    /// pinned, the path is empty, or the list is full.
    @discardableResult
    mutating func pin(_ path: String) -> Bool {
        guard LauncherShortcutPaths.isUsable(path),
              !paths.contains(path),
              paths.count < Self.maximumCount else { return false }
        paths.append(path)
        return true
    }

    @discardableResult
    mutating func unpin(_ path: String) -> Bool {
        guard let index = paths.firstIndex(of: path) else { return false }
        paths.remove(at: index)
        return true
    }

    /// Moves `path` by `offset` positions (negative moves it earlier). The result is
    /// clamped to the list bounds. Returns `false` when nothing changed.
    @discardableResult
    mutating func move(_ path: String, by offset: Int) -> Bool {
        guard let index = paths.firstIndex(of: path) else { return false }
        return move(path, to: index + offset)
    }

    /// Moves `path` to `destination` (clamped to the list bounds).
    @discardableResult
    mutating func move(_ path: String, to destination: Int) -> Bool {
        guard let index = paths.firstIndex(of: path) else { return false }
        let target = min(max(destination, 0), paths.count - 1)
        guard target != index else { return false }
        paths.remove(at: index)
        paths.insert(path, at: target)
        return true
    }

    /// Moves `path` so it sits immediately before `target`.
    @discardableResult
    mutating func move(_ path: String, before target: String) -> Bool {
        guard path != target,
              let source = paths.firstIndex(of: path),
              let targetIndex = paths.firstIndex(of: target) else { return false }
        let destination = source < targetIndex ? targetIndex - 1 : targetIndex
        return move(path, to: destination)
    }

    func canMove(_ path: String, by offset: Int) -> Bool {
        guard let index = paths.firstIndex(of: path) else { return false }
        let target = index + offset
        return target >= 0 && target < paths.count && target != index
    }
}

/// Bounded, de-duplicated list of applications most recently launched or
/// activated through LaunchMad, newest first. Only the paths are kept: no
/// timestamps, counts or history.
struct RecentAppList: Equatable {
    static let defaultLimit = 10

    let limit: Int
    private(set) var paths: [String]

    init(paths: [String] = [], limit: Int = RecentAppList.defaultLimit) {
        self.limit = max(1, limit)
        self.paths = Array(LauncherShortcutPaths.sanitized(paths).prefix(self.limit))
    }

    var isEmpty: Bool { paths.isEmpty }

    /// Moves `path` to the front. Call only after a launch or activation succeeded.
    mutating func recordSuccessfulLaunch(_ path: String) {
        guard LauncherShortcutPaths.isUsable(path) else { return }
        paths.removeAll { $0 == path }
        paths.insert(path, at: 0)
        if paths.count > limit {
            paths.removeLast(paths.count - limit)
        }
    }

    @discardableResult
    mutating func remove(_ path: String) -> Bool {
        let before = paths.count
        paths.removeAll { $0 == path }
        return paths.count != before
    }

    /// Drops entries whose application is no longer present.
    @discardableResult
    mutating func removeAll(where isMissing: (String) -> Bool) -> Bool {
        let before = paths.count
        paths.removeAll(where: isMissing)
        return paths.count != before
    }

    mutating func clear() {
        paths.removeAll()
    }
}

enum LauncherShortcutPaths {
    static func isUsable(_ path: String) -> Bool {
        !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Removes empty entries and duplicates while keeping the first occurrence.
    static func sanitized(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(paths.count)
        for path in paths where isUsable(path) && seen.insert(path).inserted {
            result.append(path)
        }
        return result
    }

    /// Maps stored paths to live values, skipping paths that no longer resolve
    /// (for example, an uninstalled application) without altering the order.
    static func resolve<Value>(_ paths: [String], using lookup: (String) -> Value?) -> [Value] {
        paths.compactMap(lookup)
    }
}

/// Persists the two lists in a `UserDefaults` domain. The pinned list is part of
/// the layout and is included in explicit backups; the recent list is local-only
/// state and is excluded from backups by default.
struct LauncherShortcutStore {
    static let pinnedKey = "launchMadPinnedAppPaths"
    static let recentKey = "launchMadRecentAppPaths"

    let defaults: UserDefaults
    let recentLimit: Int

    init(defaults: UserDefaults = .standard, recentLimit: Int = RecentAppList.defaultLimit) {
        self.defaults = defaults
        self.recentLimit = recentLimit
    }

    func loadPinned() -> PinnedAppList {
        PinnedAppList(paths: defaults.stringArray(forKey: Self.pinnedKey) ?? [])
    }

    func savePinned(_ list: PinnedAppList) {
        if list.isEmpty {
            defaults.removeObject(forKey: Self.pinnedKey)
        } else {
            defaults.set(list.paths, forKey: Self.pinnedKey)
        }
    }

    func loadRecent() -> RecentAppList {
        RecentAppList(paths: defaults.stringArray(forKey: Self.recentKey) ?? [], limit: recentLimit)
    }

    func saveRecent(_ list: RecentAppList) {
        if list.isEmpty {
            defaults.removeObject(forKey: Self.recentKey)
        } else {
            defaults.set(list.paths, forKey: Self.recentKey)
        }
    }
}

/// Text payload used only to reorder the Pinned row by dragging. Anything that
/// does not carry the prefix (for example, text dragged from another app) is
/// ignored.
enum PinnedAppDragPayload {
    nonisolated static let prefix = "launchmad-pinned-app:"

    nonisolated static func encode(_ path: String) -> String {
        prefix + path
    }

    nonisolated static func decode(_ payload: String) -> String? {
        guard payload.hasPrefix(prefix) else { return nil }
        let path = String(payload.dropFirst(prefix.count))
        return path.isEmpty ? nil : path
    }
}
