# LaunchMad

LaunchMad is an offline, privacy-focused application launcher for macOS. It opens a Launchpad-style grid of your apps, with folders, search, keyboard navigation, and two rows at the top for the apps you care about most:

- **Pinned**: apps you choose, in the order you choose.
- **Last used**: the apps you most recently opened from LaunchMad.

LaunchMad has no updater, analytics, accounts, cloud sync, AI features, command-line interface, local servers, or log files. See [PRIVACY.md](PRIVACY.md) for exactly what it stores and what it does not do.

> **Status:** version 3.0.0 builds, passes its 129 unit tests and is packaged as a universal ZIP by CI on macOS 26 ([VERIFICATION.md](VERIFICATION.md)). Interactive testing on a Mac and the GitHub release are still pending, so the installation steps below apply once a release is published.

## Install

1. Download `LaunchMad-<version>.zip` from the [Releases](https://github.com/sadhedgehog/LaunchMad/releases) page.
2. Double-click the ZIP to extract `LaunchMad.app`.
3. Drag `LaunchMad.app` into your **Applications** folder.
4. Open it from Applications.

Releases are **ad-hoc signed** unless the release notes say otherwise. They are not notarized by Apple, so the first time you open LaunchMad macOS will say it cannot verify the developer. To allow it:

- Open **System Settings → Privacy & Security**, scroll to the message about LaunchMad, and click **Open Anyway**. Or, in Finder, Control-click `LaunchMad.app`, choose **Open**, then confirm.

You only need to do this once. LaunchMad never asks you to run Terminal commands or to remove macOS security attributes.

LaunchMad uses its own bundle identifier (`com.sadhedgehog.launchmad`) and its own data folder, so it can sit alongside an existing LaunchNext installation without reading or changing LaunchNext's data.

## Use

- Open LaunchMad from Applications, with your global shortcut, or with a hot corner (configure these in Settings). LaunchMad runs without a Dock icon.
- Type to search. Press **Return** to open the selected app, **Esc** to close.
- **Pinned row:** right-click any app and choose **Pin** (or **Unpin**). Drag pinned apps to reorder them, or select one with the keyboard and press **Option-←/→**.
- **Last used row:** updates after an app opens successfully from LaunchMad. Click **Clear** to empty it, or right-click an app and choose **Remove from Last Used**.
- **Keyboard:** from the search field, **↓** moves into Pinned, then Last used, then the grid. **←/→** moves within a row and **↑** goes back up.
- Settings → General has export/import of your layout and settings. Settings → Backup keeps dated backups in a folder you choose.

## Build from source

Requirements: macOS 26 and Xcode 26.

```bash
git clone https://github.com/sadhedgehog/LaunchMad.git
cd LaunchMad
scripts/release.sh
```

The script runs the privacy scan, builds a Release app for your Mac's architecture, signs it ad-hoc, verifies it, and writes `build/dist/LaunchMad-<version>.zip`. Set `UNIVERSAL=1` for an arm64 + x86_64 build, or `SIGN_IDENTITY` and `NOTARY_PROFILE` to sign with a Developer ID and notarize.

Tests: `xcodebuild test -project LaunchMad.xcodeproj -scheme LaunchMad -destination 'platform=macOS'`. Privacy scan only: `python3 scripts/check_privacy.py`.

## Credits and license

LaunchMad is a fork of [LaunchNext](https://github.com/RoversX/LaunchNext) by RoversX, which is built on [LaunchNow](https://github.com/ggkevinnnn/LaunchNow) by ggkevinnnn. Many thanks to both projects.

LaunchMad is licensed under the GNU General Public License v3.0, the same license as LaunchNow and LaunchNext. See [LICENSE](LICENSE). The bundled OpenMultitouchSupport sources (by Takuto Nakamura, used for the optional trackpad gestures) keep their original copyright notices.
