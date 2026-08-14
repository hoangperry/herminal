#!/usr/bin/env bash
# release.sh — M7-1c herminal release driver.
#
# Cuts a tagged, signed (or notarized), distributable build. Reads the
# next version from `CHANGELOG.md`'s `## [Unreleased]` block — if you
# haven't filled that in, the script will tell you so before doing
# anything destructive.
#
# Steps:
#   1. Verify working tree is clean.
#   2. Verify the version arg matches a `## [VERSION]` header in
#      CHANGELOG.md (so the changelog and the tag never drift).
#   3. Run the full integration suite — release tagging anything red
#      ships a known-bad build, hard fail.
#   4. Build, Developer-ID sign, notarize, and staple via sign-and-notarize.sh.
#   5. Create an annotated git tag `vX.Y.Z`.
#   6. Zip the signed bundle as `herminal-vX.Y.Z.zip`.
#   7. Emit a `gh release create` command for the owner to run
#      (we don't push or release for you — that needs explicit
#      authorisation per CLAUDE.md "executing actions with care").
#
# Usage: Scripts/release.sh 0.1.0
#
# Required env vars (forwarded to sign-and-notarize.sh):
#   HERMINAL_SIGNING_IDENTITY  — Developer-ID signing identity
#   HERMINAL_NOTARY_PROFILE    — notarytool keychain profile
# Public release preparation fails closed when either is absent.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <version>   (e.g. 0.1.0 or 1.2.3-beta.1)" >&2
    exit 2
fi
VERSION="$1"
TAG="v$VERSION"

# A release tag must never point at an ad-hoc or merely signed artifact.
# sign-and-notarize.sh intentionally supports ad-hoc developer smoke builds,
# so the public release driver enforces the stronger contract up front.
if [ -z "${HERMINAL_SIGNING_IDENTITY:-}" ]; then
    echo "ERROR: HERMINAL_SIGNING_IDENTITY is required; refusing an ad-hoc release" >&2
    exit 1
fi
if [ -z "${HERMINAL_NOTARY_PROFILE:-}" ]; then
    echo "ERROR: HERMINAL_NOTARY_PROFILE is required; refusing an unnotarized release" >&2
    exit 1
fi

# Reject the common typo: a leading 'v' on the version arg.
if [[ "$VERSION" == v* ]]; then
    echo "ERROR: pass the version without the 'v' prefix (got: $VERSION)" >&2
    exit 2
fi

# 1. Clean working tree. `--ignore-submodules=dirty` skips the libghostty
#    submodule's internal build artefacts (zig-pkg/, zig-out/, etc.) —
#    what matters for reproducibility is the submodule SHA pin, not its
#    working tree.
if [ -n "$(git status --porcelain --ignore-submodules=dirty)" ]; then
    echo "ERROR: working tree has uncommitted changes" >&2
    git status --short --ignore-submodules=dirty >&2
    exit 1
fi

# 2. CHANGELOG entry matches the version arg.
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
    echo "ERROR: no '## [$VERSION]' section in CHANGELOG.md" >&2
    echo "Move items out of '## [Unreleased]' into a '## [$VERSION]' block first." >&2
    exit 1
fi

# 3. Tag doesn't already exist (locally or upstream).
if git tag --list | grep -q "^$TAG$"; then
    echo "ERROR: tag $TAG already exists locally — bump the version" >&2
    exit 1
fi
if git ls-remote --tags origin "$TAG" | grep -q "$TAG"; then
    echo "ERROR: tag $TAG already exists on origin" >&2
    exit 1
fi

# 4. Integration suite must be green before we tag anything.
echo "==> Running dogfood-daily before tagging"
if ! Scripts/dogfood-daily.sh; then
    echo "ERROR: dogfood-daily.sh failed — fix the red checks before releasing" >&2
    exit 1
fi

# 5. Signed + notarized release build.
echo "==> Building release"
HERMINAL_OUTPUT_DIR="$REPO_ROOT/.build/release" Scripts/sign-and-notarize.sh

APP="$REPO_ROOT/.build/release/herminal.app"
if [ ! -d "$APP" ]; then
    echo "ERROR: signed release bundle not found at $APP" >&2
    exit 1
fi

# Do not create a tag unless the output still satisfies the public release
# contract after the signing script returns.
if ! codesign --verify --deep --strict "$APP"; then
    echo "ERROR: release signature verification failed" >&2
    exit 1
fi
if ! codesign -d --verbose=4 "$APP" 2>&1 | grep -q '^Authority=Developer ID Application:'; then
    echo "ERROR: release is not signed by a Developer ID Application identity" >&2
    exit 1
fi
if ! xcrun stapler validate "$APP"; then
    echo "ERROR: release has no valid stapled notarization ticket" >&2
    exit 1
fi
if ! spctl --assess --type execute --verbose=4 "$APP"; then
    echo "ERROR: Gatekeeper assessment failed" >&2
    exit 1
fi

# 6. Tag the commit.
echo "==> Tagging $TAG"
git tag -a "$TAG" -m "herminal $TAG

See CHANGELOG.md for the full release notes."

# 7. Zip the bundle for distribution.
ZIP="$REPO_ROOT/.build/release/herminal-$TAG.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# 8. Extract the changelog section for the release body.
NOTES_FILE="$(mktemp)"
awk -v v="$VERSION" '
    BEGIN { capture = 0 }
    /^## \[/ {
        if (capture == 1) { exit }
        if ($0 ~ "^## \\[" v "\\]") { capture = 1; next }
    }
    capture == 1 { print }
' CHANGELOG.md > "$NOTES_FILE"

echo ""
echo "==> Release ready"
echo "  Bundle: $APP"
echo "  Zip:    $ZIP"
echo "  Tag:    $TAG (NOT pushed)"
echo ""
echo "  Next steps (owner runs these — not automated for safety):"
echo "    git push origin $TAG"
echo "    gh release create $TAG \\"
echo "        '$ZIP' \\"
echo "        --title 'herminal $TAG' \\"
echo "        --notes-file '$NOTES_FILE'"
echo ""
echo "  Or, if it's a pre-release, add: --prerelease"
echo "  To draft (not publish): --draft"
