#!/usr/bin/env bash
# Build, sign, package and verify LaunchMad.app on a Mac with Xcode installed.
#
# Usage:
#   scripts/release.sh                 # ad-hoc signed build for this Mac's architecture
#   UNIVERSAL=1 scripts/release.sh     # arm64 + x86_64
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=launchmad-notary scripts/release.sh   # Developer ID + notarization
#
# Output: build/dist/LaunchMad-<version>.zip and build/dist/SHA256SUMS.txt
# The script never removes quarantine attributes and never installs anything.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="LaunchMad.xcodeproj"
SCHEME="LaunchMad"
CONFIGURATION="Release"
BUILD_ROOT="${ROOT_DIR}/build"
DERIVED_DATA="${BUILD_ROOT}/DerivedData"
DIST_DIR="${BUILD_ROOT}/dist"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

cd "${ROOT_DIR}"

if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_ARGS=(ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
else
  ARCH_ARGS=(ARCHS="$(uname -m)" ONLY_ACTIVE_ARCH=YES)
fi

echo "==> Privacy scan"
python3 scripts/check_privacy.py

echo "==> Building ${SCHEME} (${CONFIGURATION})"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  "${ARCH_ARGS[@]}" \
  CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  clean build

APP_PATH="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/LaunchMad.app"
[[ -d "${APP_PATH}" ]] || { echo "error: ${APP_PATH} not found" >&2; exit 1; }

INFO_PLIST="${APP_PATH}/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${INFO_PLIST}")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INFO_PLIST}")"
[[ "${BUNDLE_ID}" == "com.sadhedgehog.launchmad" ]] || { echo "error: unexpected bundle id ${BUNDLE_ID}" >&2; exit 1; }

echo "==> Signing (${SIGN_IDENTITY})"
# Re-sign the whole bundle so nested code and the app share one consistent signature.
if [[ "${SIGN_IDENTITY}" == "-" ]]; then
  codesign --force --deep --sign - --options runtime --timestamp=none "${APP_PATH}"
else
  codesign --force --deep --sign "${SIGN_IDENTITY}" --options runtime --timestamp "${APP_PATH}"
fi

echo "==> Verifying bundle"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
codesign -dvv "${APP_PATH}" 2>&1 | grep -E 'Identifier|Authority|Signature|TeamIdentifier|Runtime' || true
if find "${APP_PATH}" -name 'SwiftUpdater' -o -name '*.lproj' | grep -q .; then
  echo "error: unexpected updater or localization resources in bundle" >&2; exit 1
fi
lipo -archs "${APP_PATH}/Contents/MacOS/LaunchMad"

mkdir -p "${DIST_DIR}"
ZIP_NAME="LaunchMad-${VERSION}.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
rm -f "${ZIP_PATH}"

if [[ -n "${NOTARY_PROFILE}" && "${SIGN_IDENTITY}" != "-" ]]; then
  echo "==> Notarizing"
  ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${APP_PATH}"
  rm -f "${ZIP_PATH}"
fi

echo "==> Packaging ${ZIP_NAME}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "==> Verifying the app extracted from the ZIP"
CHECK_DIR="$(mktemp -d)"
ditto -x -k "${ZIP_PATH}" "${CHECK_DIR}"
codesign --verify --deep --strict "${CHECK_DIR}/LaunchMad.app"
[[ -x "${CHECK_DIR}/LaunchMad.app/Contents/MacOS/LaunchMad" ]] || { echo "error: executable bit lost" >&2; exit 1; }
spctl --assess --type execute --verbose=2 "${CHECK_DIR}/LaunchMad.app" || \
  echo "note: Gatekeeper assessment failed (expected for ad-hoc signed builds)."
rm -rf "${CHECK_DIR}"

(cd "${DIST_DIR}" && shasum -a 256 "${ZIP_NAME}" > SHA256SUMS.txt)
echo "==> Done: LaunchMad ${VERSION} (${BUILD})"
cat "${DIST_DIR}/SHA256SUMS.txt"
