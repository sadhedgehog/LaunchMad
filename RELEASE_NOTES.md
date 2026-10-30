# LaunchMad release notes

## 3.0.0 (unreleased)

This is the first LaunchMad release. LaunchMad is an offline, privacy-focused fork of LaunchNext 2.4.2.

### New

- **Pinned row.** Pin and unpin apps from any app's context menu. The row keeps your order: drag to reorder, or press Option-←/→ with the keyboard. Pins are included in backups.
- **Last used row.** Shows up to 10 apps you recently opened from LaunchMad, newest first. It updates only after a launch succeeds and is cleared with **Clear**. Only app paths are stored, with no times or counts, and the list is never included in backups.
- **Keyboard navigation** moves between search, Pinned, Last used and the grid.

### Removed

- The updater, update checks, update notifications and release-notes viewer.
- About-page web links.
- The command-line and terminal interfaces, the local socket server, and the shell-profile and PATH changes they made.
- The "Unblock App in Terminal" quarantine-removal action.
- Wallpaper diagnostic logs, the FPS overlay, the developer settings page and console logging.
- All translations and the language picker. The interface is English only.
- The archived AI integration sources.
- Legacy `.lmy`/`.zip` archive import, which needed `unzip`. Import a Launchpad `.db` file directly instead.

### Changed

- New name, bundle identifier (`com.sadhedgehog.launchmad`) and data folder (`~/Library/Application Support/LaunchMad`). Preferences and data from LaunchNext are not migrated or modified.
- Wallpaper captures are kept in memory instead of being cached on disk.
- **Layout database:**
  - SwiftData stores explicitly disable CloudKit.
  - Autosave is off and the layout is saved explicitly.
  - Persistent change history is removed after each save.
  - If the data folder cannot be used, the fallback store is held in memory.
- **Backups:**
  - Backups contain only the layout database and an allowlisted preferences file, with owner-only permissions.
  - Restoring reads the backup from a private temporary copy and never opens the backup itself for writing.
- **Locating the Launchpad database:** the native Launchpad importer finds the database location with a system call rather than running `getconf`.

### Known limitations

See [PRIVACY.md](PRIVACY.md) and [VERIFICATION.md](VERIFICATION.md).
