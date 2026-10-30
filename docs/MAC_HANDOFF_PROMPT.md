# Handoff prompt: hands-on testing and release of LaunchMad on a Mac

Paste everything below the line into a new Claude Code conversation running **on the Mac** (macOS 26 or later). Xcode is only needed if a fix turns out to be necessary. The `gh` CLI must be signed in to GitHub.

---

Finish and publish **LaunchMad 3.0.0**, my offline, privacy-focused macOS launcher. Work efficiently: the build, tests and packaging are already done by CI, so don't rebuild unless you must change code.

- **Repo:** https://github.com/sadhedgehog/LaunchMad
- **Branch:** `claude/zealous-goodall-n2jiki`. `main` is still at `7298d66`, which is an ancestor of the branch.

I authorize you to push to that branch, fast-forward `main` to the tested commit, create the tag `v3.0.0`, and publish the GitHub release with the ZIP. Do it yourself; don't ask me to run commands.

### What is already verified

GitHub Actions (`.github/workflows/macos-verify.yml`, Xcode 26.6 on macOS 26.6) runs on every push and has already verified:

- privacy scan;
- Debug build;
- 129 unit tests pass, 0 skipped;
- `UNIVERSAL=1 scripts/release.sh`: ad-hoc signed, hardened runtime, universal `LaunchMad-3.0.0.zip` plus `SHA256SUMS.txt`, uploaded as artifact `launchmad-<sha>`;
- bundle inspection: no `.lproj` folders, updater or helpers;
- a 35-second launch of the app extracted from the ZIP: no network or Unix sockets, no output, no logs or caches, and Last used drops missing apps while Pinned keeps them.

Details are in `VERIFICATION.md`. Read `README.md`, `PRIVACY.md` and `VERIFICATION.md` first; they are short.

### Rules

- **Keep these:** the GPL-3.0 license and the LaunchNext/LaunchNow credits.
- **Don't add:** network features, logging, helpers or dependencies.
- **Leave existing installs and data alone:**
  - Don't touch `/Applications/LaunchNext.app`, `~/Library/Application Support/LaunchNext` or LaunchNext's preferences.
  - Don't replace an existing `/Applications/LaunchMad.app` without asking.
  - Test from `~/LaunchMadTest/`.
- **Signing and Gatekeeper:**
  - Never strip quarantine attributes and never add Gatekeeper workarounds.
  - The release is ad-hoc signed and not notarized. Say so; don't claim otherwise.
  - When macOS blocks the first launch, use System Settings → Privacy & Security → **Open Anyway**. Do this through the UI, or ask me to click it if you can't.

### Steps

1. **Fetch the tested ZIP.**
   - `git fetch origin claude/zealous-goodall-n2jiki`.
   - Confirm the latest run for the branch HEAD is green: `gh run list --branch claude/zealous-goodall-n2jiki --limit 3`.
   - Download that run's artifact with `gh run download <run-id> -n launchmad-<sha> -D ~/LaunchMadTest/artifact`.
   - Check `shasum -a 256` against `SHA256SUMS.txt`.
   - Extract with `ditto -x -k` into `~/LaunchMadTest/`.
2. **Hands-on checks.** Run `~/LaunchMadTest/LaunchMad.app` and check each of these. Use screenshots or the accessibility tree as needed. Ask me only for actions you genuinely cannot perform.
   - The grid opens, search works, and Return/Esc behave.
   - The **Pinned** and **Last used** rows show above the grid in fullscreen and compact modes (Settings → Appearance), and with both renderers (Settings → Performance).
   - **Pin and Unpin** from the right-click menu on a grid app, a folder app and a search result. Reorder by dragging and with Option-←/→. The order survives quitting and relaunching.
   - Opening an app adds it to the front of **Last used** with no duplicates, at most 10 entries. **Clear** and **Remove from Last Used** work.
   - **Keyboard:** search → ↓ Pinned → ↓ Last used → ↓ grid, and ↑ back up.
   - **Settings:** no Updates or Development page, no language picker, About shows attribution text without links, all text is English.
   - **Backup:**
     - Back up to `~/LaunchMadTest/backups`. The folder is 0700 and contains only `Data.store*` and `com.sadhedgehog.launchmad.plist`. The plist has `launchMadPinnedAppPaths` and does not have `launchMadRecentAppPaths`.
     - Change the pins and layout, then restore and confirm they come back.
   - **During the checks above**, run `lsof -nP -a -p $(pgrep -x LaunchMad) -i` and `nettop -P -L 1 -p $(pgrep -x LaunchMad)` a few times. Expect no connections.
3. **If something is broken:** make the smallest fix, run `python3 scripts/check_privacy.py`, push, wait for CI to pass, then repeat steps 1–2 on the new ZIP.
4. **Update the docs:**
   - Add a short "interactive verification" section to `VERIFICATION.md` with what you actually checked and saw.
   - Put today's date and the ad-hoc signing status in `RELEASE_NOTES.md`.
   - In `README.md`, replace the Status note with a link to the release.
   - Commit, push, and wait for CI on that commit to pass.
5. **Release:**
   - Fast-forward `main`: `git push origin <final-sha>:main`. It must be a fast-forward; stop and ask if it isn't.
   - Tag the commit: `git tag v3.0.0 <final-sha> && git push origin v3.0.0`.
   - Download the final commit's CI artifact and check its checksum.
   - Launch it once from `~/LaunchMadTest` as a quick check.
   - Run `gh release create v3.0.0 LaunchMad-3.0.0.zip SHA256SUMS.txt --title "LaunchMad 3.0.0" --notes-file <notes>`. The notes come from `RELEASE_NOTES.md` and include install steps for an ad-hoc app: unzip, move to Applications, then the first-launch Open Anyway step.
   - Download the asset from the release and confirm its SHA-256.
6. **Report back to me:**
   - links to the release, the ZIP download and the tested commit;
   - the SHA-256;
   - three-line install instructions;
   - the checks you did;
   - any remaining limitations.
