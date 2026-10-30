# Handoff prompt: build, verify and release LaunchMad on a Mac

Paste everything below the line into a new Claude Code conversation running **on the Mac** (macOS 26 with Xcode 26 installed), opened in a folder where the repository can be cloned.

---

Take ownership of building, verifying and releasing **LaunchMad**, my offline, privacy-focused macOS launcher.

**Repository:** https://github.com/sadhedgehog/LaunchMad
**Work branch:** `claude/zealous-goodall-n2jiki`, which contains all the source work. `main` is still the old README-only commit.

I authorize you to:

- modify code, commit and push to that branch;
- open a pull request into `main` and merge it once the app is verified;
- create the tag `v3.0.0` (or `v3.0.0-beta.1` if anything is unverified) and publish a GitHub release with the installable ZIP attached.

Do the work yourself. Don't ask me to run terminal commands.

### Context: what was already done (in a Linux environment without Xcode)

- **Rename.** `LaunchNext` became `LaunchMad`:
  - folders `LaunchMad/`, `LaunchMadTests/`, `LaunchMadContextMenuCore/`, `LaunchMadWallpaperCore/`;
  - project `LaunchMad.xcodeproj`, scheme `LaunchMad`;
  - bundle ID `com.sadhedgehog.launchmad`, version 3.0.0 (build 2026103001);
  - ad-hoc signing with no development team;
  - data folder `~/Library/Application Support/LaunchMad`. There is no migration from LaunchNext.
- **Removed:**
  - the updater and update checks, notifications, and About web links;
  - the CLI/TUI, IPC socket server, and shell-profile edits;
  - the Terminal quarantine-removal action;
  - wallpaper diagnostic logs, FPS overlay, the Development settings page and all `print`/`NSLog`. The vendored OpenMultitouchSupport `NSLog` calls are compiled out with a macro.
  - archived AI code, legacy `.lmy`/`.zip` import that used `unzip`, the `getconf` subprocess, and on-disk wallpaper snapshots.
- **English only.** `LaunchMad/Localization.swift` is a single exhaustive `switch`. The `.lproj` folders, `i18n/` and the language picker are gone.
- **SwiftData:**
  - `cloudKitDatabase: .none` on every configuration;
  - autosave off;
  - persistent history purged after saves and on open (`AppStore.purgePersistentHistory`).
- **Backups:**
  - files are allowlisted (`LaunchMad/BackupFiles.swift`) with 0700/0600 permissions, and symlinks are skipped;
  - preferences are allowlisted (`AppStore.generalBackupPreferenceKeys`, `layoutBackupPreferenceKeys`, `allBackupPreferenceKeys`);
  - restore reads from a staged temp copy (`AppStore.restoreLayout(fromBackupFolder:)`);
  - Pinned is included in backups and Last used is excluded.
- **New Pinned and Last used rows above the grid:**
  - logic in `LaunchMad/LauncherShortcutLists.swift`, `LaunchMad/AppStore+LauncherShortcuts.swift`, and the view `LaunchMad/LauncherShortcutRowsView.swift`;
  - placed in `LaunchpadView.launchpadMainContent`, with keyboard handling in `handleShortcutRowKey`;
  - context-menu actions Pin, Unpin and "Remove from Last Used" in `LaunchMadContextMenuCore`;
  - all launches go through `AppStore.launchApplication(_:)`, which records Last used only after `NSWorkspace.openApplication` succeeds.
- **Checks already run:**
  - every Swift file passes `swiftc -parse`;
  - `python3 scripts/check_privacy.py` passes;
  - 34 Foundation-only XCTests pass on Linux.
  - **Nothing has been compiled against the macOS SDK yet**, so expect some compile errors.
- **Reference documents:** `README.md`, `PRIVACY.md`, `VERIFICATION.md`, `RELEASE_NOTES.md`, `scripts/release.sh`.

### Rules

- Preserve the GPL-3.0 license and the LaunchNext/LaunchNow attribution.
- Don't add network features, services, accounts, background helpers, logging or new dependencies.
- **Protect existing installs and data:**
  - Don't overwrite an existing `/Applications/LaunchMad.app` or `/Applications/LaunchNext.app`.
  - Don't delete or modify `~/Library/Application Support/LaunchNext`, LaunchNext's preferences, or any user data without asking me first.
  - If `/Applications/LaunchMad.app` already exists, test from a separate folder (for example `~/LaunchMadTest/`) and ask before replacing it.
- **Signing and security:**
  - Never strip quarantine attributes.
  - Never add Gatekeeper workarounds.
  - Never claim Developer ID signing or notarization unless `codesign`/`spctl`/`stapler` output proves it.
  - If no Developer ID certificate is in the keychain, ship ad-hoc signed and say so plainly.
- Don't make privacy claims stronger than the evidence (sandbox is off, so this is not a firewall).
- Prefer a ZIP of `LaunchMad.app`. Don't let DMG packaging block the release.

### Steps

1. **Check out the branch.** Clone the repo (or fetch if already present) and check out `claude/zealous-goodall-n2jiki`. Check `git log origin/main..HEAD` and that the branch contains any newer remote commits. Read `README.md`, `PRIVACY.md` and `VERIFICATION.md`.
2. **Build.**
   ```
   xcodebuild -project LaunchMad.xcodeproj -scheme LaunchMad -configuration Debug -derivedDataPath build/DerivedData build
   ```
   - Fix compile errors with minimal changes that keep the intended behaviour.
   - Likely spots:
     - API details in `AppStore+LauncherShortcuts.swift` (async `openApplication`, `Task { @MainActor [weak self] in }`);
     - `AppStore.purgePersistentHistory` (`ModelContext.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>())`);
     - `ModelConfiguration(..., cloudKitDatabase: .none)`;
     - `.draggable`/`.dropDestination` in `LauncherShortcutRowsView.swift`;
     - concurrency isolation warnings that became errors;
     - leftovers from large deletions in `SettingsView.swift`, `AppStore.swift`, `LaunchpadApp.swift`, `LaunchpadView.swift` and `BackgroundImageController.swift`.
   - If the asset catalog compiler fails because of a restricted system service, report the exact error rather than working around signing or security.
3. **Test.**
   ```
   xcodebuild test -project LaunchMad.xcodeproj -scheme LaunchMad -destination 'platform=macOS' -derivedDataPath build/DerivedData
   ```
   - Fix real failures. Never skip, disable or weaken a test to get green.
   - Record any test skipped for environment reasons (the two HEIC two-frame fixture tests) as outstanding, not passed.
   - Run `python3 scripts/check_privacy.py`.
4. **Package.** Run `scripts/release.sh` to make a Release build for this Mac's architecture, or use `UNIVERSAL=1` if it works. It:
   - signs ad-hoc, or with `SIGN_IDENTITY` and `NOTARY_PROFILE` if a Developer ID and notary profile really exist;
   - verifies with `codesign`;
   - writes `build/dist/LaunchMad-3.0.0.zip` and `SHA256SUMS.txt`;
   - re-verifies the app extracted from the ZIP.

   Fix the script if needed.
5. **Inspect the bundle.**
   - Check `Info.plist` (identifier, version, no URL schemes or network keys).
   - Confirm there is no `Contents/Resources/Updater`, no `.lproj` folders and no helper executables.
   - Run `codesign -d --entitlements - LaunchMad.app`.
   - Run `otool -L` on the executable and note any network-related frameworks linked.
   - Run `strings` on the binary for `http`/`https` and explain any matches.
6. **Run the app from the ZIP.** Extract the ZIP into a fresh test folder with Finder or `ditto -x -k`, run that copy, and verify:
   - First launch and onboarding, app discovery, search, and launching apps with the mouse and with Return.
   - **Pinned:** pin from the context menu in the grid, folders and search results; unpin; reorder by drag and by Option-←/→; the order survives quitting and relaunching.
   - **Last used:** updates only after a successful launch (try a missing or deleted app and confirm it isn't added); deduplicated; at most 10 entries; Clear; Remove from Last Used; entries for apps deleted from disk disappear on the next open.
   - Both rows in fullscreen and compact (window) layouts, with both renderers (Settings → Performance), together with folders, paging, scrolling and drag-and-drop in the grid.
   - **Keyboard:** search → ↓ Pinned → ↓ Last used → ↓ grid, ↑ back up, Esc.
   - **Settings:** no Updates or Development page, no language picker, About has no web links, and all text is English.
   - **Backup:**
     - Settings → Backup: choose a test folder and create a backup. The folder is 0700, contains only `Data.store*` and `com.sadhedgehog.launchmad.plist`, the plist contains `launchMadPinnedAppPaths` but not `launchMadRecentAppPaths`, and there are no symlinks.
     - Change the layout and pins, then restore and confirm both come back.
   - **Import:** System Launchpad import if available, and a `.db` file import.
   - **LaunchNext data untouched:** `~/Library/Application Support/LaunchNext` and LaunchNext's preferences have the same modification times as before the test.
7. **Network and listeners.** While exercising the app for a few minutes (open/close, search, launch apps, Settings pages, backup), monitor LaunchMad's own process:
   - `lsof -nP -a -p <pid> -i` repeatedly, plus `lsof -nP -a -p <pid> -U` for Unix sockets;
   - `nettop -P -p <pid> -L 1` repeatedly.

   Expect no network connections and no listening sockets. Record the exact commands and output. Attribute any system-framework activity honestly. Don't claim an OS-enforced guarantee.
8. **Documentation.**
   - Update `VERIFICATION.md` with what you actually ran and the results: build, test counts, scan, bundle inspection, manual checklist, network monitoring, ZIP checksum, signing status.
   - Update `RELEASE_NOTES.md` with the date and real signing status.
   - In `README.md`, replace the "Status" note.
   - Optionally add a few screenshots under `docs/screenshots/` and a short `docs/VISUAL_REPORT.md` showing the rows, Settings and About.
9. **Release.**
   - Commit, push the branch, open a PR into `main`, and merge it once everything above passes.
   - Tag the merged commit `v3.0.0`. Use `v3.0.0-beta.1` and a pre-release if anything important is unverified.
   - Publish a GitHub release with `LaunchMad-3.0.0.zip` and `SHA256SUMS.txt` attached. The release notes should come from `RELEASE_NOTES.md` and include install steps for an ad-hoc signed app: System Settings → Privacy & Security → Open Anyway, or Control-click → Open.
   - Download the asset from the release URL and confirm its SHA-256 matches.
10. **Report back:**
    - the commit and PR links, the release link, and the direct ZIP download link with its SHA-256;
    - short install instructions;
    - validation results;
    - remaining limitations.

    If something genuinely blocks a step, report the exact failed command and output, keep the work done so far, and be clear about which of these you reached: prepared source, built app, tested distribution artifact, or published release.
