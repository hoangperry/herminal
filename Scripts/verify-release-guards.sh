#!/usr/bin/env bash
# Verify that release preparation fails before build/tag work when public
# signing or notarization configuration is absent, and that notary JSON parsing
# tolerates the pretty-printed output emitted by notarytool.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_SCRIPT="$REPO_ROOT/Scripts/release.sh"
RELEASE_WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"
CANDIDATE_WORKFLOW="$REPO_ROOT/.github/workflows/release-candidate.yml"
# shellcheck disable=SC1091 # Path is resolved from this script's repo root.
source "$REPO_ROOT/Scripts/release-common.sh"

for script in \
    "$RELEASE_SCRIPT" \
    "$REPO_ROOT/Scripts/sign-and-notarize.sh" \
    "$REPO_ROOT/Scripts/make-dmg.sh"; do
    if ! grep -Fq 'set -euo pipefail' "$script"; then
        echo "FAIL: release path is not configured to stop on command/pipeline failure: $script" >&2
        exit 1
    fi
done

# shellcheck disable=SC2016 # Match the literal workflow variable, not this shell.
if ! grep -Fq 'ditto -c -k --keepParent .build/release/herminal.app "$ZIP"' "$RELEASE_WORKFLOW"; then
    echo "FAIL: release workflow does not package the post-staple app as its final ZIP" >&2
    exit 1
fi

if ! grep -Fq 'Scripts/generate-dependency-manifest.sh "$TAG" "$DEPENDENCIES"' "$RELEASE_WORKFLOW"; then
    echo "FAIL: release workflow bypasses the deterministic dependency manifest generator" >&2
    exit 1
fi

if ! grep -Fq 'REQUESTED_TAG: ${{ inputs.tag }}' "$RELEASE_WORKFLOW" || \
   grep -Fq 'echo "tag=${{ inputs.tag }}"' "$RELEASE_WORKFLOW" || \
   ! grep -Fq '[[ ! "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]' "$RELEASE_WORKFLOW"; then
    echo "FAIL: manual release tags are not isolated and validated as stable semver" >&2
    exit 1
fi

if ! grep -Fq 'contents: read' "$CANDIDATE_WORKFLOW" || \
   grep -Fq 'contents: write' "$CANDIDATE_WORKFLOW" || \
   ! grep -Fq 'Scripts/make-app-bundle.sh release' "$CANDIDATE_WORKFLOW" || \
   ! grep -Fq 'configuration=release' "$CANDIDATE_WORKFLOW" || \
   ! grep -Fq "commit=\$SOURCE_COMMIT" "$CANDIDATE_WORKFLOW"; then
    echo "FAIL: release candidate workflow lost its read-only release/provenance contract" >&2
    exit 1
fi

set +e
source_guard_output=$(env HERMINAL_SOURCE_APP="$REPO_ROOT/does-not-exist.app" \
    "$REPO_ROOT/Scripts/sign-and-notarize.sh" 2>&1)
source_guard_status=$?
set -e
if [ "$source_guard_status" -eq 0 ] || \
   ! grep -Fq 'source app is missing or incomplete' <<< "$source_guard_output"; then
    echo "FAIL: external release candidate input does not fail closed" >&2
    exit 1
fi

expect_guard() {
    local expected="$1"
    shift
    local output status

    set +e
    output=$(env "$@" "$RELEASE_SCRIPT" 0.0.0-release-guard-test 2>&1)
    status=$?
    set -e

    if [ "$status" -eq 0 ] || ! grep -Fq "$expected" <<< "$output"; then
        echo "FAIL: expected release guard: $expected" >&2
        echo "$output" >&2
        return 1
    fi
}

expect_guard \
    "HERMINAL_SIGNING_IDENTITY is required" \
    -u HERMINAL_SIGNING_IDENTITY \
    -u HERMINAL_NOTARY_PROFILE

expect_guard \
    "HERMINAL_NOTARY_PROFILE is required" \
    -u HERMINAL_NOTARY_PROFILE \
    HERMINAL_SIGNING_IDENTITY="Developer ID Application: Test (TESTTEAM)"

if [ "$(normalize_release_version v1.2.3)" != "1.2.3" ] || \
   [ "$(normalize_release_version 1.2.3)" != "1.2.3" ]; then
    echo "FAIL: release version normalization is not idempotent" >&2
    exit 1
fi

changelog_fixture=$(mktemp)
fixture=$(mktemp)
dependencies_fixture=$(mktemp)
dependencies_output=$(mktemp)
trap 'rm -f "$changelog_fixture" "$fixture" "$dependencies_fixture" "$dependencies_output"' EXIT

printf '## [1.2.3] - Unreleased\n' > "$changelog_fixture"
if validate_release_changelog "$changelog_fixture" 1.2.3 >/dev/null 2>&1; then
    echo "FAIL: unreleased changelog header was accepted" >&2
    exit 1
fi
printf '## [1.2.3] - 2026-08-17\n' > "$changelog_fixture"
if ! validate_release_changelog "$changelog_fixture" 1.2.3; then
    echo "FAIL: dated changelog header was rejected" >&2
    exit 1
fi
printf '## [1.2.4] - 2026-08-17\n' > "$changelog_fixture"
if validate_release_changelog "$changelog_fixture" 1.2.3 >/dev/null 2>&1; then
    echo "FAIL: missing release changelog header was accepted" >&2
    exit 1
fi

cat > "$fixture" <<'JSON'
{
  "id": "00000000-0000-0000-0000-000000000000",
  "status": "Accepted"
}
JSON
status=$(notary_json_value "$fixture" status)
if [ "$status" != "Accepted" ]; then
    echo "FAIL: pretty-printed notary JSON was not parsed" >&2
    exit 1
fi

cat > "$dependencies_fixture" <<JSON
{
  "identity": "herminal-private-checkout",
  "name": "herminal",
  "url": "$REPO_ROOT",
  "path": "$REPO_ROOT",
  "dependencies": [{
    "identity": "sqlite.swift",
    "url": "https://github.com/stephencelis/SQLite.swift.git",
    "path": "$REPO_ROOT/.build/checkouts/SQLite.swift",
    "dependencies": []
  }]
}
JSON
python3 "$REPO_ROOT/Scripts/sanitize-swift-dependencies.py" "$REPO_ROOT" \
    < "$dependencies_fixture" > "$dependencies_output"
python3 - "$dependencies_output" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert data["identity"] == "herminal"
assert data["url"] == "."
assert data["path"] == "."
assert data["dependencies"][0]["path"] == ".build/checkouts/SQLite.swift"
assert data["dependencies"][0]["url"].startswith("https://")
PY
if grep -Fq "$REPO_ROOT" "$dependencies_output"; then
    echo "FAIL: dependency manifest leaks its local checkout path" >&2
    exit 1
fi

echo "PASS: public release fails closed and release metadata is deterministic"
