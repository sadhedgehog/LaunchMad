# LaunchMad verification record

This file records what has actually been checked, and how. Update it whenever a check is run, and keep unverified items clearly marked.

## 3.0.0: source preparation (2026-10-30, Linux cloud environment)

This work was done in a Linux environment with no Xcode or macOS SDK, so it could not build or run the app.

**Base.** Remote `main` at `7298d66`, a README-only change on top of the RoversX/LaunchNext source. The earlier local work from a ChatGPT session (`91b6d8d…`) and its handoff archives were not available in this environment. The privacy work was therefore redone from the LaunchNext source.

### Verified

| Check | Result |
|---|---|
| Syntax check of every Swift source with `swiftc -parse` (Swift 6.1.3, Linux) | 84 files pass |
| `python3 scripts/check_privacy.py` | Passes on 85 application source files with 23 rule groups. Every `ModelConfiguration` sets `cloudKitDatabase: .none`. |
| Privacy scan run against the unmodified LaunchNext sources, to confirm it detects problems | Fails as expected: logging, Terminal/quarantine, socket, notification, shell-profile, updater and CloudKit-default findings |
| Unit tests for the Foundation-only new code, run on Linux with XCTest | 34 tests, 0 failures. `LauncherShortcutListsTests` (14), `BackupFilesTests` (6), `AppContextMenuTests` (14). |
| English string table | 389 keys, each mapped by an exhaustive `switch`. Every key referenced in code exists, unreferenced keys were removed, and no non-English UI strings remain. The only CJK literals left are folder names matched in the macOS Launchpad database. |
| Project file | Parses with the `pbxproj` library. Four targets: `LaunchMad`, `LaunchMadTests`, `LaunchMadContextMenuCore`, `LaunchMadWallpaperCore`. Bundle ID `com.sadhedgehog.launchmad`, version 3.0.0 (build 2026103001), ad-hoc signing (`CODE_SIGN_IDENTITY = -`), no development team. |

`AppContextMenuTests` is annotated `@MainActor`. Linux XCTest cannot discover `@MainActor` test classes, so the Linux run used a copy without the class-level attribute. The Xcode test target runs the original file.

### Not yet verified

These need a Mac with Xcode 26. They are listed in [docs/MAC_HANDOFF_PROMPT.md](docs/MAC_HANDOFF_PROMPT.md).

- **Xcode build:** a full Debug and Release build of `LaunchMad.app`, with type checking against the macOS SDK. Compile errors are possible because the edits were made without a compiler.
- **Tests on macOS:** the full test suite, including the wallpaper tests that need ImageIO and AppKit. Two upstream tests that need two-frame HEIC fixtures were previously reported as skipped.
- **Running the app:** launching, search, Pinned (pin, unpin, reorder, persistence), Last used (updated only after a successful launch, bounded, Clear, removal of missing apps), keyboard navigation, folders, compact and fullscreen layouts, backup and restore, and import.
- **Network:** monitoring the running app for connections and listening sockets.
- **Bundle contents:** no updater binary, no `.lproj` folders, correct identifier and version.
- **Packaging:** building the ZIP with `scripts/release.sh`, then verifying the signature and executable bit of the app extracted from the ZIP, and running that copy.
- **Signing:** builds are ad-hoc signed. Developer ID signing and notarization have not been done.
- **Release:** GitHub release, tag and download link.
