#!/bin/bash

# SpeachText1.0 Build Profile Router
# Builds the fully open SpeachText1.0 application.
#
# Usage:
#   ./build.sh                    # signed development build
#   ./build.sh public             # signed development build
#   ./build.sh unsigned           # unsigned build (CI/fallback)
#   ./build.sh package            # arm64 release ZIP + DMG (ad-hoc signed)
#   ./build.sh verify             # verify installers already in ./dist

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="${1:-${BUILD_PROFILE:-public}}"
DERIVED_DATA_PATH="${SPEACHTEXT_DERIVED_DATA_PATH:-${PROJECT_DIR}/DerivedData}"

resolve_development_team() {
    local identity
    identity="$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
        | awk 'NR == 1 { identity = $0 } END { print identity }')"
    [ -n "${identity}" ] || return 0

    if [ -n "${SPEACHTEXT_DEVELOPMENT_TEAM:-}" ]; then
        printf '%s\n' "${SPEACHTEXT_DEVELOPMENT_TEAM}"
        return
    fi

    security find-certificate -c "${identity}" -p 2>/dev/null \
        | openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null \
        | sed -n 's/.*OU=\([^,]*\).*/\1/p'
}

run_public_build() {
    local signing_mode="$1"
    local development_team
    local -a build_args=(
        -project SpeachText1.0.xcodeproj
		-scheme SpeachText1.0
        -configuration Debug
        -destination 'platform=macOS'
        -derivedDataPath "${DERIVED_DATA_PATH}"
        -skipPackagePluginValidation
        build
    )

    cd "${PROJECT_DIR}"

    if [ "${signing_mode}" = "unsigned" ]; then
        echo "Running unsigned public SpeachText1.0 build..."
        echo "Accessibility permission may need to be granted again after rebuilding."
        exec xcodebuild "${build_args[@]}" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
    fi

    development_team="$(resolve_development_team)"
    if [ -z "${development_team}" ]; then
        if [ -n "${SPEACHTEXT_DEVELOPMENT_TEAM:-}" ]; then
            printf >&2 'SPEACHTEXT_DEVELOPMENT_TEAM is set to %s, but no Apple Development signing identity was found.\n\n' \
                "${SPEACHTEXT_DEVELOPMENT_TEAM}"
            printf >&2 '%s\n\n' \
                "The team override selects an installed signing identity; it does not replace a certificate."
        else
            printf >&2 'No Apple Development signing identity was found.\n\n'
        fi

        cat >&2 <<'EOF'
For stable Accessibility permission across rebuilds, add any Apple Account in:
  Xcode > Settings > Accounts

Then open Manage Certificates and create an Apple Development certificate.

A free Personal Team is sufficient for local development. If you have multiple
teams, set SPEACHTEXT_DEVELOPMENT_TEAM to the desired 10-character Team ID.

To build without signing instead, run:
  ./build.sh unsigned

Unsigned builds may require Accessibility permission again after rebuilding.
EOF
        exit 1
    fi

    echo "Running signed public SpeachText1.0 build..."
    echo "Build product: ${DERIVED_DATA_PATH}/Build/Products/Debug/SpeachText1.0 Debug.app"
    exec xcodebuild "${build_args[@]}" DEVELOPMENT_TEAM="${development_team}"
}

case "${PROFILE}" in
    public|oss|incremental|fast)
        run_public_build signed
        ;;
    unsigned|ci)
        run_public_build unsigned
        ;;
    package|release)
        exec "${PROJECT_DIR}/scripts/package_release.sh"
        ;;
    verify)
        exec "${PROJECT_DIR}/scripts/verify_release.sh" "${PROJECT_DIR}/dist"
        ;;

    *)
        echo "Unknown build profile: ${PROFILE}"
        echo "Valid profiles: public/oss/incremental/fast, unsigned/ci, package/release, verify"
        exit 1
        ;;
esac
