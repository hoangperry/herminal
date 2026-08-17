#!/usr/bin/env bash
# Generate deterministic release provenance from an immutable checked-out tag.

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 TAG OUTPUT" >&2
    exit 2
fi

TAG="$1"
OUTPUT="$2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TAG_COMMIT=$(git -C "$REPO_ROOT" rev-parse --verify "$TAG^{commit}")
HEAD_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD)
if [ "$TAG_COMMIT" != "$HEAD_COMMIT" ]; then
    echo "ERROR: HEAD $HEAD_COMMIT does not match $TAG ($TAG_COMMIT)" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
DEPENDENCIES_JSON=$(mktemp)
OUTPUT_TMP=$(mktemp "${OUTPUT}.tmp.XXXXXX")
trap 'rm -f "$DEPENDENCIES_JSON" "$OUTPUT_TMP"' EXIT

swift package --package-path "$REPO_ROOT" show-dependencies --format json \
    > "$DEPENDENCIES_JSON"

{
    echo "tag=$TAG"
    echo "commit=$HEAD_COMMIT"
    echo
    echo "[git submodules]"
    git -C "$REPO_ROOT" submodule status --recursive
    echo
    echo "[SwiftPM dependencies]"
    python3 "$REPO_ROOT/Scripts/sanitize-swift-dependencies.py" "$REPO_ROOT" \
        < "$DEPENDENCIES_JSON"
} > "$OUTPUT_TMP"

mv "$OUTPUT_TMP" "$OUTPUT"
echo "Generated $OUTPUT"
