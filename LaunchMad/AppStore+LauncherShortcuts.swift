import AppKit

// Pinned and Last used rows. Only bundle paths are stored; the Last used list
// is updated after LaunchMad itself successfully launches or activates an app,
// and nothing about other activity on the Mac is observed.
extension AppStore {
    // MARK: - Launching

    /// Hides the launcher and opens `app`. The Last used row is updated only
    /// when macOS reports that the launch or activation succeeded.
    func launchApplication(_ app: AppInfo) {
        AppDelegate.shared?.hideWindow()
        let url = app.url
        let path = app.url.path
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            do {
                _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
                self?.recordSuccessfulLaunch(path: path)
            } catch {
                NSSound.beep()
            }
        }
    }

    func recordSuccessfulLaunch(path: String) {
        var updated = recentApps
        updated.recordSuccessfulLaunch(path)
        recentApps = updated
    }

    // MARK: - Pinned

    func isPinnedToLauncher(_ app: AppInfo) -> Bool {
        pinnedApps.contains(app.url.path)
    }

    func pinAppToLauncher(_ app: AppInfo) {
        var updated = pinnedApps
        if updated.pin(app.url.path) {
            pinnedApps = updated
        } else if !updated.contains(app.url.path) {
            NSSound.beep()
        }
    }

    func unpinAppFromLauncher(_ app: AppInfo) {
        var updated = pinnedApps
        if updated.unpin(app.url.path) {
            pinnedApps = updated
        }
    }

    func canMovePinnedApp(_ app: AppInfo, by offset: Int) -> Bool {
        pinnedApps.canMove(app.url.path, by: offset)
    }

    func movePinnedApp(_ app: AppInfo, by offset: Int) {
        var updated = pinnedApps
        if updated.move(app.url.path, by: offset) {
            pinnedApps = updated
        }
    }

    /// Moves the pinned app at `path` into the stored position of `target`
    /// (the two swap places when they are neighbours). Used by Option-arrow.
    /// Positions are taken from the stored list, so hidden or missing pinned
    /// apps keep their place.
    func movePinnedApp(path: String, toPositionOf target: AppInfo) {
        guard let destination = pinnedApps.paths.firstIndex(of: target.url.path) else { return }
        var updated = pinnedApps
        if updated.move(path, to: destination) {
            pinnedApps = updated
        }
    }

    /// Moves the pinned app at `path` so it sits immediately before `target`.
    /// Used when a pinned app is dropped onto another one.
    func movePinnedApp(path: String, before target: AppInfo) {
        var updated = pinnedApps
        if updated.move(path, before: target.url.path) {
            pinnedApps = updated
        }
    }

    // MARK: - Last used

    func removeAppFromRecents(_ app: AppInfo) {
        var updated = recentApps
        if updated.remove(app.url.path) {
            recentApps = updated
        }
    }

    func clearRecentApps() {
        recentApps = RecentAppList(limit: recentApps.limit)
    }

    /// Drops Last used entries whose application no longer exists on disk.
    /// Pinned entries are kept (the app may be on a volume that is not mounted)
    /// and are simply not shown while missing.
    func pruneMissingRecentApps() {
        var updated = recentApps
        let fileManager = FileManager.default
        if updated.removeAll(where: { !fileManager.fileExists(atPath: $0) }) {
            recentApps = updated
        }
    }

    // MARK: - Row contents

    /// Apps for the Pinned row, in the user's order. Hidden and missing apps
    /// are skipped without changing the stored order.
    var pinnedRowApps: [AppInfo] {
        resolveLauncherShortcutPaths(pinnedApps.paths)
    }

    /// Apps for the Last used row, newest first.
    var recentRowApps: [AppInfo] {
        resolveLauncherShortcutPaths(recentApps.paths)
    }

    private func resolveLauncherShortcutPaths(_ paths: [String]) -> [AppInfo] {
        guard !paths.isEmpty else { return [] }
        var byPath: [String: AppInfo] = [:]
        byPath.reserveCapacity(apps.count)
        for app in apps where byPath[app.url.path] == nil {
            byPath[app.url.path] = app
        }
        return LauncherShortcutPaths.resolve(paths) { path in
            guard !hiddenAppPaths.contains(path) else { return nil }
            return byPath[path]
        }
    }
}
