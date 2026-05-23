#!/usr/bin/env bash
# sign-and-notarize.sh — M5-3 Developer-ID signing + Apple notarization.
#
# Builds the release .app, signs it with the Developer ID Application
# identity in the keychain, submits to Apple's notary service, and
# staples the resulting ticket. The output is a Gatekeeper-clean
# bundle that double-click users can launch without the
# "downloaded from the internet" prompt.
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
#
# Falls back to ad-hoc signing (the same path `make-app-bundle.sh` uses)
# when neither variable is set — useful in CI smoke runs that can't
# touch the keychain.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUTPUT_DIR="${HERMINAL_OUTPUT_DIR:-$REPO_ROOT/.build/release}"
APP_NAME="herminal"
ENTITLEMENTS="$REPO_ROOT/App/herminal.entitlements"

# 1. Release build via the shared bundle script (gives us .build/herminal.app
#    with Info.plist + ad-hoc signature). We re-sign over the ad-hoc id.
echo "==> Building release bundle"
"$REPO_ROOT/Scripts/make-app-bundle.sh" release >/dev/null

SRC_APP="$REPO_ROOT/.build/herminal.app"
mkdir -p "$OUTPUT_DIR"
APP="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$APP"
cp -R "$SRC_APP" "$APP"

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

# notarytool exits 0 even when Apple says "Invalid", so check the JSON.
status=$(grep -o '"status":"[^"]*"' "$OUTPUT_DIR/notary-result.json" | head -1 | cut -d\" -f4)
if [ "$status" != "Accepted" ]; then
    echo "==> Notarization FAILED (status=$status)" >&2
    echo "Fetch the log with:" >&2
    submission_id=$(grep -o '"id":"[^"]*"' "$OUTPUT_DIR/notary-result.json" | head -1 | cut -d\" -f4)
    echo "  xcrun notarytool log $submission_id --keychain-profile $HERMINAL_NOTARY_PROFILE" >&2
    exit 1
fi

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo ""
echo "==> Done. Notarized bundle: $APP"
echo "Distribute the .app (or re-zip it). Users can open it without the"
echo "Gatekeeper unknown-developer prompt."
