#!/usr/bin/env bash
# herminal bootstrap script.
# - Verify toolchain (Xcode, Swift 6+, macOS 14+ Apple Silicon, Zig 0.15.2, Metal Toolchain)
# - Initialize + build the libghostty vendor submodule
# - Resolve SPM dependencies

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Pinned toolchain versions — keep in sync with docs/backlog/month-1.md.
ZIG_VERSION="0.15.2"
ZIG_BIN="${HOME}/.local/zig/${ZIG_VERSION}/zig"
GHOSTTY_TAG="v1.3.1"

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

# --- Zig 0.15.2 (Ghostty v1.3.1 pins a minimum Zig of 0.15.2; 0.16+ fails to build)
if [ ! -x "$ZIG_BIN" ]; then
    echo "ERROR: Zig ${ZIG_VERSION} not found at ${ZIG_BIN}" >&2
    echo "  Install: mkdir -p ~/.local/zig && cd ~/.local/zig \\" >&2
    echo "    && curl -fsSL https://ziglang.org/download/${ZIG_VERSION}/zig-aarch64-macos-${ZIG_VERSION}.tar.xz | tar -xJ \\" >&2
    echo "    && mv zig-aarch64-macos-${ZIG_VERSION} ${ZIG_VERSION}" >&2
    echo "  (Homebrew 'zig' is 0.16+ and will NOT build Ghostty v1.3.1.)" >&2
    exit 1
fi

# --- Metal Toolchain (Xcode 26 no longer bundles it; the xcframework build needs it)
if ! xcrun -sdk macosx metal --version >/dev/null 2>&1; then
    echo "ERROR: Metal Toolchain missing — required to compile Ghostty's Metal shaders." >&2
    echo "  Install: xcodebuild -downloadComponent MetalToolchain  (~705 MB)" >&2
    exit 1
fi

# --- libghostty vendor submodule
mkdir -p Vendor
if [ ! -e Vendor/libghostty/build.zig ]; then
    echo "==> Initializing libghostty submodule"
    git submodule update --init --recursive Vendor/libghostty
fi

# --- Build libghostty xcframework (skip if already present)
XCFRAMEWORK=$(find Vendor/libghostty/zig-out Vendor/libghostty/macos -maxdepth 3 -name "GhosttyKit.xcframework" 2>/dev/null | head -1 || true)
if [ -z "$XCFRAMEWORK" ]; then
    echo "==> Building libghostty xcframework (ReleaseFast, native ARM64) — this takes a few minutes"
    ( cd Vendor/libghostty && "$ZIG_BIN" build \
        -Doptimize=ReleaseFast \
        -Demit-xcframework=true \
        -Demit-macos-app=false \
        -Dxcframework-target=native )
else
    echo "==> libghostty xcframework already built: $XCFRAMEWORK"
fi

# --- SPM resolve
echo "==> Resolving SPM dependencies"
swift package resolve

echo "==> bootstrap complete"
echo "Next: swift build && swift test"
