#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${1:-${ROOT_DIR}/dist}"
if [[ "${DIST_DIR}" != /* ]]; then
  DIST_DIR="${ROOT_DIR}/${DIST_DIR}"
fi

MANIFEST="${DIST_DIR}/release-manifest.json"
[ -f "${MANIFEST}" ] || { echo "Missing release manifest: ${MANIFEST}" >&2; exit 1; }

VERSION="$(plutil -extract version raw -o - "${MANIFEST}")"
DMG_NAME="$(plutil -extract dmg raw -o - "${MANIFEST}")"
ZIP_NAME="$(plutil -extract zip raw -o - "${MANIFEST}")"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

for required in "${DMG_PATH}" "${ZIP_PATH}" "${DIST_DIR}/SHA256SUMS.txt"; do
  [ -s "${required}" ] || { echo "Missing or empty release artifact: ${required}" >&2; exit 1; }
done

(
  cd "${DIST_DIR}"
  shasum -a 256 -c SHA256SUMS.txt
)

hdiutil verify "${DMG_PATH}"

TMP_DIR="$(mktemp -d)"
MOUNT_POINT=""
cleanup() {
  if [ -n "${MOUNT_POINT}" ] && mount | grep -Fq " on ${MOUNT_POINT} "; then
    hdiutil detach "${MOUNT_POINT}" -quiet || true
  fi
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

/usr/bin/ditto -x -k "${ZIP_PATH}" "${TMP_DIR}/zip"
ZIP_APP="${TMP_DIR}/zip/SpeachText1.0.app"
[ -d "${ZIP_APP}" ] || { echo "ZIP does not contain SpeachText1.0.app" >&2; exit 1; }

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${ZIP_APP}/Contents/Info.plist")"
BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${ZIP_APP}/Contents/Info.plist")"
[ "${BUNDLE_ID}" = "com.speachtext.app" ] || { echo "Unexpected bundle identifier: ${BUNDLE_ID}" >&2; exit 1; }
[ "${BUNDLE_VERSION}" = "${VERSION}" ] || { echo "Unexpected bundle version: ${BUNDLE_VERSION}" >&2; exit 1; }

BINARY="${ZIP_APP}/Contents/MacOS/SpeachText1.0"
[ -x "${BINARY}" ] || { echo "Missing application executable: ${BINARY}" >&2; exit 1; }
ARCHS="$(lipo -archs "${BINARY}")"
case " ${ARCHS} " in
  *" arm64 "*) ;;
  *) echo "Application does not contain arm64: ${ARCHS}" >&2; exit 1 ;;
esac
codesign --verify --deep --strict --verbose=2 "${ZIP_APP}"

MOUNT_POINT="$(hdiutil attach "${DMG_PATH}" -readonly -nobrowse | awk 'END {print $NF}')"
[ -d "${MOUNT_POINT}/SpeachText1.0.app" ] || { echo "DMG does not contain SpeachText1.0.app" >&2; exit 1; }
[ -L "${MOUNT_POINT}/Applications" ] || { echo "DMG does not contain an Applications shortcut" >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "${MOUNT_POINT}/SpeachText1.0.app"
hdiutil detach "${MOUNT_POINT}" -quiet
MOUNT_POINT=""

printf 'Verified SpeachText1.0 %s (%s) ZIP and DMG installers.\n' "${VERSION}" "${ARCHS}"
