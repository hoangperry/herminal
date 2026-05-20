#!/usr/bin/env bash
# herminal bootstrap script.
# - Verify toolchain (Xcode, Swift 6+, macOS 14+ Apple Silicon)
# - Initialize libghostty vendor submodule (TBD Month 1 spike)
# - Resolve SPM dependencies

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> herminal bootstrap"
echo "Repo root: $REPO_ROOT"

# --- Toolchain checks
require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: missing required tool: $1" >&2
        exit 1
    fi
}
require swift
require xcrun
require xcodebuild
require git

SWIFT_MAJOR=$(swift --version | awk '/Apple Swift/ {match($0,/[0-9]+\.[0-9]+/); print substr($0,RSTART,RLENGTH)}' | cut -d. -f1)
if [ "${SWIFT_MAJOR:-0}" -lt 6 ]; then
    echo "ERROR: Swift 6+ required. Found: $(swift --version | head -1)" >&2
    exit 1
fi

ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo "WARN: herminal targets Apple Silicon only. Current arch: $ARCH" >&2
fi

# --- libghostty vendor (placeholder for Month 1)
mkdir -p Vendor
if [ ! -d Vendor/libghostty ]; then
    echo "==> libghostty not yet vendored. Plan:"
    echo "    1. Add as git submodule: git submodule add https://github.com/ghostty-org/ghostty.git Vendor/libghostty"
    echo "    2. Build C ABI: cd Vendor/libghostty && zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast lib"
    echo "    3. Expose .xcframework or .dylib to Swift via systemLibrary target"
    echo "    Deferred until Month 1 spike."
fi

# --- SPM resolve
echo "==> Resolving SPM dependencies"
swift package resolve

echo "==> bootstrap complete"
echo "Next: swift build && swift test"
