#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${ROOT_DIR}/SpeachText1.0.xcodeproj"
SCHEME="SpeachText1.0"
DERIVED_DATA="${SPEACHTEXT_DERIVED_DATA:-${ROOT_DIR}/DerivedData-Release}"
SOURCE_PACKAGES="${SPEACHTEXT_SOURCE_PACKAGES:-${ROOT_DIR}/.build/SourcePackages}"
DIST_DIR="${ROOT_DIR}/dist"
APP_NAME="SpeachText1.0"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${ROOT_DIR}/Info.plist")"
ARCHIVE_STEM="${APP_NAME}-${VERSION}-macOS-arm64"
PRODUCT_DIR="${DERIVED_DATA}/Build/Products/Release"
APP_PATH="${PRODUCT_DIR}/${APP_NAME}.app"
DMG_ROOT="${DIST_DIR}/dmg-root"

rm -rf "${DIST_DIR}" "${DERIVED_DATA}"
mkdir -p "${DIST_DIR}" "${SOURCE_PACKAGES}"

build_command=(
  xcodebuild build
  -project "${PROJECT}"
  -scheme "${SCHEME}"
  -configuration Release
  -destination 'platform=macOS,arch=arm64'
  -derivedDataPath "${DERIVED_DATA}"
  -clonedSourcePackagesDirPath "${SOURCE_PACKAGES}"
  -skipPackagePluginValidation
  -skipMacroValidation
  ARCHS=arm64
  ONLY_ACTIVE_ARCH=YES
  CODE_SIGN_IDENTITY=
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
)

set -o pipefail
if command -v xcbeautify >/dev/null 2>&1; then
  "${build_command[@]}" | tee "${DIST_DIR}/xcodebuild.log" | xcbeautify
else
  "${build_command[@]}" | tee "${DIST_DIR}/xcodebuild.log"
fi

if [ ! -d "${APP_PATH}" ]; then
  printf 'Release application was not produced at %s\n' "${APP_PATH}" >&2
  exit 1
fi

# Ad-hoc signing keeps the distributed bundle internally consistent without
# pretending to be Developer ID signed or Apple notarized. Do not apply a
# distribution entitlement profile: it would misrepresent this unsigned build.
printf 'Ad-hoc signing application bundle...\n'
codesign --force --deep --sign - --timestamp=none "${APP_PATH}"
printf 'Verifying application bundle signature...\n'
codesign --verify --deep --verbose=2 "${APP_PATH}"
printf 'Creating ZIP installer...\n'
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  "${APP_PATH}" "${DIST_DIR}/${ARCHIVE_STEM}.zip"

printf 'Creating drag-to-Applications DMG...\n'
mkdir -p "${DMG_ROOT}"
/usr/bin/ditto "${APP_PATH}" "${DMG_ROOT}/${APP_NAME}.app"
ln -s /Applications "${DMG_ROOT}/Applications"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_ROOT}" \
  -format UDZO \
  -ov \
  "${DIST_DIR}/${ARCHIVE_STEM}.dmg"
rm -rf "${DMG_ROOT}"

(
  cd "${DIST_DIR}"
  shasum -a 256 "${ARCHIVE_STEM}.dmg" "${ARCHIVE_STEM}.zip" > SHA256SUMS.txt
)

cat > "${DIST_DIR}/release-manifest.json" <<EOF
{
  "name": "${APP_NAME}",
  "version": "${VERSION}",
  "minimum_macos": "15.0",
  "architecture": "arm64",
  "signing": "ad-hoc",
  "notarized": false,
  "dmg": "${ARCHIVE_STEM}.dmg",
  "zip": "${ARCHIVE_STEM}.zip"
}
EOF

printf 'Created:\n  %s\n  %s\n' \
  "${DIST_DIR}/${ARCHIVE_STEM}.dmg" \
  "${DIST_DIR}/${ARCHIVE_STEM}.zip"
