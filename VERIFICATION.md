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

## 3.0.0: macOS build, tests, packaging and smoke test (2026-10-30, GitHub Actions)

These ran on a GitHub-hosted runner with `.github/workflows/macos-verify.yml`:

- **Run:** https://github.com/sadhedgehog/LaunchMad/actions/runs/41119113063, commit `a6082c0`.
- **Runner:** macOS 26.6.2, arm64.
- **Toolchain:** Xcode 26.6 (17F113), Swift 6.3.3, macOS SDK 26.5.

Getting the first build green needed three compile fixes:

- a SwiftUI type-check timeout in `LaunchpadView`;
- an `NSMenuItem.preferredImageVisibility` call from upstream. That API is only in the macOS 27 SDK, so it is now gated with `#if compiler(>=6.4)` and the line is still used when building with Xcode 27;
- an actor-isolation warning in the new drag-payload helper.

| Check | Result |
|---|---|
| Privacy scan | Passed |
| Debug build | Succeeded. 15 warnings, all in pre-existing upstream code (unused locals in `CAGridView`, actor-isolation warnings in `CJKTransliterator`/`CAFolderPresentation`/`BackgroundImageController`, one deprecated `NSWorkspace` API). None are in the new code. |
| Unit tests (`xcodebuild test`) | `** TEST SUCCEEDED **`: 129 test cases passed, 0 failed, 0 skipped. This includes the new `LauncherShortcutListsTests`, `BackupFilesTests` and `AppContextMenuTests`. The two HEIC fixture tests previously reported as skipped elsewhere pass on this runner. |
| Release package (`UNIVERSAL=1 scripts/release.sh`) | `LaunchMad-3.0.0.zip` (9,089,155 bytes), SHA-256 `1d4a007958851e5c479a588046a211493141391591a423f71f20103762fceceb`. Executable is universal (`x86_64 arm64`). Kept as a workflow artifact for 14 days; it is not a release asset. |
| Bundle inspection | See below. |
| Smoke test of the app extracted from the ZIP (about 35 s, no user interaction) | See below. |

**Bundle inspection:**

- `CFBundleIdentifier` is `com.sadhedgehog.launchmad` and `CFBundleShortVersionString` is `3.0.0`.
- `LSUIElement` is true and `LSMinimumSystemVersion` is 26.0.
- `Contents/Resources` holds only `AppIcon.icns` and `Assets.car`: no `.lproj` folders, updater or helper executables.
- Signature: `Signature=adhoc`, `flags=adhoc,runtime` (hardened runtime), no team, no entitlements.
- `codesign --verify --deep --strict` passes on the app extracted from the ZIP.
- The only `http(s)://` string in the binary is the XMP namespace identifier `http://ns.apple.com/namespace/1.0/`.
- **Linked libraries:** Apple system frameworks only. These include the private `MultitouchSupport` framework (optional gestures), `ScreenCaptureKit` (optional wallpaper capture), `GameController`, `SwiftData` and `libsqlite3`. Some Swift overlays are weak-linked by the SDK, for example `libswiftOSLog` and `libswiftXPC`; there are no `os_log`/XPC calls in LaunchMad's code (see the privacy scan).

**Smoke test:**

- **Network:** in three samples 5 s apart, `lsof -i` showed no network sockets, `lsof -U` showed no Unix sockets, and `nettop` showed no traffic.
- **Output:** stdout and stderr were empty (0 bytes).
- **Files:** wrote only `~/Library/Application Support/LaunchMad/Data.store`, `-wal` and `-shm` (folder mode 0700, files 0644) and its own preferences domain. No `~/Library/Logs` or `~/Library/Caches` entries were created.
- **Last used / Pinned:** seeded with a missing and an existing app. Opening the launcher dropped the missing entry from Last used (`("/System/Applications/Calculator.app")`) and kept both Pinned entries, as designed.
- **Kernel control handles:** `lsof` listed two `[ctl com.apple.netsrc]` handles opened inside the process by Apple frameworks. These are kernel control handles, not network connections, and no traffic was recorded. They are noted here because a strict network audit should know about them.

### Not yet verified

These need a person at a Mac. See [docs/MAC_HANDOFF_PROMPT.md](docs/MAC_HANDOFF_PROMPT.md).

- **Interactive use:** clicking, the keyboard, the context menu, dragging to reorder Pinned, a successful launch updating Last used, Clear, folders, compact and fullscreen layouts, both renderers, Settings pages.
- **Backup and restore** through the UI, and a check that the backup folder contents and permissions match PRIVACY.md.
- **Network monitoring** during interactive use (the CI smoke test only covers an idle launch).
- **Gatekeeper first-run** behaviour of the downloaded ad-hoc ZIP on a real Mac ("Open Anyway").
- **Signing:** builds are ad-hoc signed. Developer ID signing and notarization have not been done.
- **Release:** GitHub release, tag and download link.
