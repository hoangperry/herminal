#!/usr/bin/env bash
# verify-title.sh — Regression-guard for the OSC 0/2 title-set path.
#
# Why this exists: v0.2.0 → v0.2.3 audit window discovered that
# GhosttyApp.handleAction only routed GHOSTTY_ACTION_RING_BELL —
# every other action (including SET_TITLE / SET_TAB_TITLE) returned
# false (= unhandled), so the tab strip stayed on "herminal" no
# matter what the shell wrote via OSC 0/2. v0.2.4 wires the action;
# this script ensures it stays wired.
#
# Drives a debug build with HERMINAL_TEST_TITLE=1. The in-app harness
# injects `printf '\033]0;MARKER\007'`, waits for libghostty to
# dispatch the action, and dumps the resulting active_title.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"
DUMP=/tmp/herminal-title-result.txt
MARKER="TITLE_REGRESSION_MARKER_42"

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

pkill -9 -x HerminalApp 2>/dev/null
rm -f "$DUMP"

LOG=$(mktemp)
HERMINAL_TEST_TITLE=1 \
HERMINAL_TEST_TITLE_DUMP="$DUMP" \
"$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

# 8s startup + 2s settle + safety.
for _ in $(seq 1 16); do
    sleep 1
    [ -f "$DUMP" ] && break
done

cleanup() {
    kill -9 $APP_PID 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    rm -f "$LOG" "$DUMP"
}

if [ ! -f "$DUMP" ]; then
    echo "FAIL — title smoke never wrote its result"
    echo "--- herminal log tail ---"
    tail -10 "$LOG"
    cleanup
    exit 1
fi

contains_marker=$(grep "^title_contains_marker=" "$DUMP" | cut -d= -f2)
title=$(grep "^active_title=" "$DUMP" | cut -d= -f2-)

if [ "$contains_marker" = "true" ]; then
    echo "PASS — title set via OSC 0 (title=$title)"
    cleanup
    exit 0
fi

echo "FAIL — title did not update from OSC 0"
echo "  expected: contains $MARKER"
echo "  got     : $title"
echo "--- dump ---"
cat "$DUMP"
echo "--- herminal log tail ---"
tail -10 "$LOG"
cleanup
exit 1
