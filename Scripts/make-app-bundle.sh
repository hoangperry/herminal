#!/usr/bin/env bash
# Package the HerminalApp SPM executable into a macOS .app bundle.
# A real bundle (with Info.plist + bundle identifier) is required for the app
# to register with the window server, keep its run loop alive, and receive
# keyboard input correctly. Usage: Scripts/make-app-bundle.sh [debug|release]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CONFIG="${1:-debug}"
APP_NAME="herminal"
APP="$REPO_ROOT/.build/${APP_NAME}.app"

echo "==> Building HerminalApp ($CONFIG)"
if [ "$CONFIG" = "release" ]; then
    swift build --product HerminalApp -c release
    BIN_DIR="$(swift build --product HerminalApp -c release --show-bin-path)"
else
    swift build --product HerminalApp
    BIN_DIR="$(swift build --product HerminalApp --show-bin-path)"
fi

BIN="$BIN_DIR/HerminalApp"
if [ ! -x "$BIN" ]; then
    echo "ERROR: built binary not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/HerminalApp"
cp "$REPO_ROOT/App/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc codesign so the bundle is launchable locally.
codesign --force --sign - "$APP" >/dev/null 2>&1 || \
    echo "WARN: ad-hoc codesign failed (bundle may still run)"

echo "==> Bundle ready: $APP"
echo "Launch with: open \"$APP\""
