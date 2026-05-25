#!/usr/bin/env bash
# make-dmg.sh — package herminal.app into a polished .dmg.
#
# Why DMG when we already ship .zip:
# - A zip user has to "Open with Finder → drag to /Applications" by
#   hand. A DMG with /Applications symlink makes the drag-to-install
#   gesture obvious and is the macOS convention.
# - Gatekeeper attaches its quarantine bit to the DMG, not each file
#   inside, so once the user clears it for the DMG every launch from
#   /Applications is silent.
# - DMGs are smaller than the equivalent zip when compressed with
#   UDZO/UDBZ — usually 10-20% on a .app of this size.
#
# Usage: Scripts/make-dmg.sh [version]
# If `version` is omitted, derive from the most recent git tag
# (`git describe --tags --abbrev=0`).
#
# Inputs:
# - A signed (and ideally notarised) `.app` from Scripts/sign-and-notarize.sh
#   at .build/release/herminal.app.
#
# Outputs:
# - .build/release/herminal-vX.Y.Z.dmg
#
# Falls back gracefully:
# - No notarisation? Builds the DMG anyway — Gatekeeper prompt persists
#   but the install gesture is the same.
# - hdiutil not available? Should never happen on macOS; the failure
#   message points at the wrong-platform case.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    LATEST_TAG="$(git describe --tags --abbrev=0 2>/dev/null)"
    if [ -z "$LATEST_TAG" ]; then
        echo "ERROR: no git tags exist — cut one first or pass version explicitly" >&2
        exit 2
    fi
    # Strip leading 'v' if present so we accept both forms.
    VERSION="${LATEST_TAG#v}"
fi

APP="$REPO_ROOT/.build/release/herminal.app"
if [ ! -d "$APP" ]; then
    echo "ERROR: signed .app not found at $APP" >&2
    echo "Run Scripts/sign-and-notarize.sh first." >&2
    exit 1
fi

if ! command -v hdiutil >/dev/null; then
    echo "ERROR: hdiutil missing — DMG creation needs macOS" >&2
    exit 1
fi

OUTPUT="$REPO_ROOT/.build/release/herminal-v$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

# 1. Stage layout: .app + Applications symlink. Drag-target convention.
echo "==> Staging DMG contents"
cp -R "$APP" "$STAGING/herminal.app"
ln -s /Applications "$STAGING/Applications"

# 2. Build the DMG with hdiutil. UDZO is the conventional compressed
#    read-only format — broad compatibility, decent compression.
#    `-format UDZO -imagekey zlib-level=9` squeezes the most we can
#    get out of zlib without spending CPU on UDBZ.
echo "==> Building $OUTPUT"
rm -f "$OUTPUT"
hdiutil create \
    -volname "herminal $VERSION" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$OUTPUT" \
    >/dev/null

# 3. Re-sign the DMG itself if the env signer is set — Gatekeeper
#    prefers a signed container even when the .app inside is notarised.
if [ -n "${HERMINAL_SIGNING_IDENTITY:-}" ]; then
    echo "==> Signing the DMG with $HERMINAL_SIGNING_IDENTITY"
    codesign --force --sign "$HERMINAL_SIGNING_IDENTITY" "$OUTPUT"
fi

# 4. Verify what we just made.
SIZE=$(stat -f%z "$OUTPUT")
SIZE_MB=$((SIZE / 1024 / 1024))
echo ""
echo "==> DMG ready"
echo "  Path: $OUTPUT"
echo "  Size: ${SIZE_MB} MB"
echo ""
echo "  Distribute via:"
echo "    gh release upload v$VERSION '$OUTPUT' --clobber"
echo ""
echo "  Or attach during release creation:"
echo "    gh release create v$VERSION '$OUTPUT' [other-assets...]"
