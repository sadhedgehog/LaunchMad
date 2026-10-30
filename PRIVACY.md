# LaunchMad privacy

LaunchMad is designed to work entirely on your Mac. This document says what it stores, what it reads, what it does not do, and where those claims stop.

## What LaunchMad does not do

LaunchMad's own code contains none of the following:

- **Network access:** no update checks, downloads, telemetry, analytics, crash reporting, accounts, cloud sync or web links. There is no networking code (`URLSession`, Network framework, web views or sockets).
- **Background services:** no helper processes, launch agents, local socket or XPC servers, and no command-line or terminal interface.
- **Logs:** no log files, diagnostic logs, audit logs or console logging. The diagnostic `NSLog` calls in the bundled OpenMultitouchSupport code are compiled out.
- **External commands:** no shell commands, AppleScript or Terminal automation, and no editing of shell profiles. It never offers to remove macOS quarantine attributes.
- **Notifications:** none.
- **AI features:** none.
- **iCloud sync:** none. CloudKit is explicitly disabled in every SwiftData store configuration.

`scripts/check_privacy.py` checks the application sources for these patterns. It runs as the first step of `scripts/release.sh`.

## What LaunchMad stores

| What | Where | Notes |
|---|---|---|
| Layout: pages, app positions, folders and their apps | `~/Library/Application Support/LaunchMad/Data.store` (plus SQLite `-wal`/`-shm` files) | Saved explicitly, not autosaved. SwiftData's change history is deleted after each save and when the store opens. |
| Settings | `~/Library/Preferences/com.sadhedgehog.launchmad.plist` | Appearance, layout options, shortcuts, hot corner, hidden apps, custom app titles, extra app folders, backup folder and uninstaller choice. |
| Pinned apps | Same preferences file, key `launchMadPinnedAppPaths` | An ordered list of app bundle paths (at most 64). |
| Last used apps | Same preferences file, key `launchMadRecentAppPaths` | At most 10 app bundle paths, newest first. No timestamps, counts or history. Updated only after LaunchMad itself successfully opens or activates an app. Entries for apps that no longer exist are removed when the launcher opens. Clear it with **Clear** in the Last used row. |
| Custom app icon (only if you choose one) | `~/Library/Application Support/LaunchMad/CustomAppIcon.png` | The icon is also applied to the LaunchMad app bundle in Finder (see Limits). |
| Backups (only when you create one) | A folder you choose | Contains only `Data.store` and its SQLite companions, plus an allowlisted preferences file. Pinned apps are included; Last used is never included. Folders are created with owner-only permissions (0700, files 0600). Symbolic links and unknown files are never copied. |

These are kept in memory only and never written to disk:

- Wallpaper captures used for the background.
- Icon caches.
- Search indexes.

LaunchMad does not use or migrate LaunchNext's preferences or its `~/Library/Application Support/LaunchNext` folder. You can still import a LaunchNext backup folder by choosing it in Settings.

## What LaunchMad reads, and only when you use the feature

- **Applications** in `/Applications`, `/System/Applications`, `~/Applications` and any folders you add. These are read to list apps and their icons.
- **Wallpaper background** (off by default): macOS's wallpaper settings in `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`. If you choose the desktop-capture option, LaunchMad also asks for Screen Recording permission so it can capture the desktop wallpaper. Captures stay in memory.
- **Global shortcut:** registers one system hotkey.
- **Hot corner** (off by default): watches the mouse pointer's position while enabled.
- **Trackpad gestures** (experimental, off by default): reads raw touch input through Apple's private MultitouchSupport framework while enabled.
- **Game controller** (off by default): reads controller input while enabled.
- **Import from the system Launchpad, or from a `.db` file you pick:** reads that SQLite database in read-only mode. Archives are not extracted.
- **Backup restore:** copies the chosen backup's database into a private temporary folder, reads the layout from that copy and deletes the copy. Only preference keys you select, and that LaunchMad backs up at all, are applied.
- **Launch at login:** registers LaunchMad with macOS (`SMAppService`) only if you turn the setting on.
- **Uninstaller:** if you choose an uninstaller app, LaunchMad opens it with the app you selected.
- **Voice feedback** (off by default): uses the on-device macOS speech synthesizer.

## Limits of these claims

- **App Sandbox is off.** LaunchMad runs with hardened runtime but without App Sandbox, so macOS does not enforce the restrictions above. They hold because the code does not do those things, and the privacy scan checks the sources. LaunchMad is not a firewall.
- **macOS itself** may record activity independently of LaunchMad, for example launch services, Screen Time, crash reports created by macOS, and unified system logs written by Apple frameworks. Apps you open from LaunchMad have their own network and logging behaviour.
- **Deleted data is not securely erased.** Clearing a list or deleting a backup removes the data normally. SQLite journals, free pages and copies made by Time Machine or other backup tools can remain on disk until overwritten.
- **Custom icons change the app bundle.** Applying a custom LaunchMad icon writes a Finder icon into the app bundle, which changes the bundle after it was signed. Use **Reset** to remove it.
- **The privacy scan is static.** It looks for known patterns in LaunchMad's sources and cannot prove runtime behaviour. Runtime network monitoring is recorded in [VERIFICATION.md](VERIFICATION.md) only once it has been performed.
