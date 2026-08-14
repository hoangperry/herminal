#!/usr/bin/env bash
# sign-and-notarize.sh — M5-3 Developer-ID signing + Apple notarization.
#
# Builds the release .app, signs it with the Developer ID Application
# identity in the keychain, submits to Apple's notary service, and
# staples the resulting ticket. Gatekeeper can validate the output as a known
# developer build; macOS may still show its standard first-open confirmation.
#
# Required env vars (one-time setup at the bottom of this file):
#   HERMINAL_SIGNING_IDENTITY   — Common name of your Developer ID cert.
#                                 Example: "Developer ID Application:
#                                 Hoang Perry (TEAMID12345)"
#   HERMINAL_NOTARY_PROFILE     — notarytool keychain profile name.
#                                 Stored once via `notarytool store-credentials`.
#
# Optional:
#   HERMINAL_OUTPUT_DIR         — Where to drop the signed .app and .zip.
#                                 Defaults to .build/release.
#   HERMINAL_SOURCE_APP         — Existing release-optimized candidate app.
#                                 When set, skip the local build and sign a copy.
#
# Falls back to ad-hoc signing (the same path `make-app-bundle.sh` uses)
# when neither variable is set — useful in CI smoke runs that can't
# touch the keychain.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

OUTPUT_DIR="${HERMINAL_OUTPUT_DIR:-$REPO_ROOT/.build/release}"
APP_NAME="herminal"
ENTITLEMENTS="$REPO_ROOT/App/herminal.entitlements"
# shellcheck disable=SC1091 # Path is resolved from this script's repo root.
source "$REPO_ROOT/Scripts/release-common.sh"

# 1. Build locally or import a release-optimized candidate produced by the
#    read-only GitHub workflow. In both cases we sign a copy and never mutate
#    the source artifact.
if [ -n "${HERMINAL_SOURCE_APP:-}" ]; then
    SRC_APP="$HERMINAL_SOURCE_APP"
    echo "==> Importing release candidate"
else
    echo "==> Building release bundle"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" release >/dev/null
    SRC_APP="$REPO_ROOT/.build/herminal.app"
fi

if [ ! -d "$SRC_APP" ] || [ ! -x "$SRC_APP/Contents/MacOS/HerminalApp" ]; then
    echo "ERROR: source app is missing or incomplete" >&2
    exit 1
fi
if [ "$(/usr/bin/defaults read "$SRC_APP/Contents/Info" CFBundleIdentifier 2>/dev/null || true)" != "com.hoangperry.herminal" ]; then
    echo "ERROR: source app has an unexpected bundle identifier" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
APP="$OUTPUT_DIR/$APP_NAME.app"
SRC_APP_ABS="$(cd "$(dirname "$SRC_APP")" && pwd -P)/$(basename "$SRC_APP")"
APP_ABS="$(cd "$OUTPUT_DIR" && pwd -P)/$APP_NAME.app"
if [ "$SRC_APP_ABS" = "$APP_ABS" ]; then
    echo "ERROR: source app must be outside the output directory" >&2
    exit 1
fi
rm -rf "$APP"
ditto "$SRC_APP" "$APP"

# 2. Sign or ad-hoc — branch on env config presence.
if [ -z "${HERMINAL_SIGNING_IDENTITY:-}" ]; then
    echo "==> No HERMINAL_SIGNING_IDENTITY set — falling back to ad-hoc"
    codesign --force --deep --sign - "$APP"
    echo "ad-hoc signed: $APP"
    echo "(Skip notarization in ad-hoc mode — Apple won't accept it.)"
    exit 0
fi

echo "==> Signing with identity: $HERMINAL_SIGNING_IDENTITY"
# --deep so libghostty.dylib and any embedded frameworks inherit the
# signature; --options runtime enables hardened runtime which is
# REQUIRED for notarization. Entitlements relax the parts of hardened
# runtime that libghostty + spawned children would otherwise trip on.
codesign --force --deep --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$HERMINAL_SIGNING_IDENTITY" \
    "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | head -5
spctl --assess --type execute --verbose=4 "$APP" 2>&1 | head -5 || true

# 3. Skip notarization when no profile is configured — local devs may
#    only need the signature for personal testing.
if [ -z "${HERMINAL_NOTARY_PROFILE:-}" ]; then
    echo "==> No HERMINAL_NOTARY_PROFILE set — signed but not notarized"
    exit 0
fi

# 4. Zip + notarize + staple. notarytool wants the .app in a zip;
#    stapler then writes the ticket back into the .app itself so the
#    .zip can be discarded.
ZIP="$OUTPUT_DIR/$APP_NAME.zip"
rm -f "$ZIP"
echo "==> Zipping for notarization submission"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary (this can take a few minutes)"
xcrun notarytool submit "$ZIP" \
    --keychain-profile "$HERMINAL_NOTARY_PROFILE" \
    --wait \
    --output-format json | tee "$OUTPUT_DIR/notary-result.json"

# notarytool exits 0 even when Apple says "Invalid", so parse the JSON. Use
# plutil rather than whitespace-sensitive grep: notarytool may pretty-print
# `"status": "Accepted"` or emit compact JSON depending on Xcode version.
status=$(notary_json_value "$OUTPUT_DIR/notary-result.json" status || true)
if [ "$status" != "Accepted" ]; then
    echo "==> Notarization FAILED (status=${status:-unparseable})" >&2
    submission_id=$(notary_json_value "$OUTPUT_DIR/notary-result.json" id || true)
    if [ -n "$submission_id" ]; then
        echo "Fetch the log with:" >&2
        echo "  xcrun notarytool log $submission_id --keychain-profile $HERMINAL_NOTARY_PROFILE" >&2
    fi
    exit 1
fi

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Verifying notarized release"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=4 "$APP"

echo ""
echo "==> Done. Notarized bundle: $APP"
echo "Distribute the .app (or re-zip it). Gatekeeper can validate the"
echo "Developer ID and stapled notarization ticket."
