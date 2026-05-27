#!/usr/bin/env bash
# verify-clipboard.sh — Regression-guard for the libghostty clipboard
# round-trip (write_clipboard_cb + read_clipboard_cb wiring + the
# select_all / copy_to_clipboard binding actions).
#
# Why this exists: v0.2.0 shipped with no-op clipboard callbacks and
# the bug took 12 months to surface because every other check verified
# rendering / input / agents but never asked "did Cmd+C actually move
# bytes?". v0.2.1 wired the callbacks, v0.2.2 wired mouse events so a
# selection could actually exist, this script ensures both stay live.
#
# Drives a debug build of herminal with HERMINAL_TEST_CLIPBOARD=1. The
# in-app harness injects a marker via `echo`, runs select_all +
# copy_to_clipboard, reads NSPasteboard, and dumps the result. The
# script asserts the marker round-tripped.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"
DUMP=/tmp/herminal-clipboard-result.txt
MARKER="CLIPBOARD_REGRESSION_MARKER_42"

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

# Snapshot the current clipboard so we can restore it — the test
# overwrites NSPasteboard.general which would otherwise eat whatever
# the dogfood owner had copied. `pbpaste` returns empty for non-string
# clipboards; that's acceptable degradation.
PRIOR_CLIPBOARD="$(pbpaste 2>/dev/null || true)"

restore_clipboard() {
    if [ -n "${PRIOR_CLIPBOARD-}" ]; then
        printf '%s' "$PRIOR_CLIPBOARD" | pbcopy
    fi
}

pkill -9 -x HerminalApp 2>/dev/null
rm -f "$DUMP"

LOG=$(mktemp)
HERMINAL_TEST_CLIPBOARD=1 \
HERMINAL_TEST_CLIPBOARD_DUMP="$DUMP" \
"$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

# Harness needs ~8s startup + 2s echo + 1s actions + buffer = ~14s.
for _ in $(seq 1 18); do
    sleep 1
    [ -f "$DUMP" ] && break
done

cleanup() {
    kill -9 $APP_PID 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    restore_clipboard
    rm -f "$LOG" "$DUMP"
}

if [ ! -f "$DUMP" ]; then
    echo "FAIL — clipboard smoke never wrote its result (app may have crashed)"
    echo "--- herminal log tail ---"
    tail -10 "$LOG"
    cleanup
    exit 1
fi

# Parse k=v lines from the dump.
has_selection=$(grep "^has_selection=" "$DUMP" | cut -d= -f2)
contains_marker=$(grep "^pasteboard_contains_marker=" "$DUMP" | cut -d= -f2)
pb_len=$(grep "^pasteboard_len=" "$DUMP" | cut -d= -f2)

if [ "$has_selection" = "true" ] && [ "$contains_marker" = "true" ]; then
    echo "PASS — clipboard round-trip (selection=$has_selection, pasteboard_len=$pb_len)"
    cleanup
    exit 0
fi

echo "FAIL — clipboard round-trip"
echo "  has_selection            = $has_selection (expected true)"
echo "  pasteboard_contains_marker = $contains_marker (expected true)"
echo "  pasteboard_len           = $pb_len"
echo "  marker                   = $MARKER"
echo "--- dump ---"
cat "$DUMP"
echo "--- herminal log tail ---"
tail -10 "$LOG"
cleanup
exit 1
