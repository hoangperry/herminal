#!/usr/bin/env bash
# verify-pane-nav.sh — regression guard for v0.5.1 directional pane focus.
#
# The split-tree nav logic is geometric: it reads the laid-out pane frames
# and moves focus to the nearest pane in a direction. PaneNavigationTests
# pins the geometry, but only a live run proves the wiring reads real
# frames correctly. The HERMINAL_TEST_NAV harness splits the tab
# vertically (focus lands on the new RIGHT pane, index 1) then moves focus
# LEFT; if nav works the focused pane is index 0, if it no-ops it stays 1.
#
# Asserts: panes_per_tab=2 (the split happened) and focused_pane=0 (focus
# moved left). Runs isolated from session restore (the harness forces a
# clean start + no persistence), so it never touches the owner's session.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BIN="$REPO_ROOT/.build/herminal.app/Contents/MacOS/HerminalApp"
DUMP=/tmp/herminal-nav-result.txt

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

pkill -9 -x HerminalApp 2>/dev/null
rm -f "$DUMP"

LOG=$(mktemp)
HERMINAL_TEST_NAV=1 HERMINAL_TEST_NAV_DUMP="$DUMP" "$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

# 2s startup + split + move + dump ≈ 3s. Wait up to 12s.
for _ in $(seq 1 12); do
    sleep 1
    [ -f "$DUMP" ] && break
done

cleanup() {
    kill -9 "$APP_PID" 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    rm -f "$LOG" "$DUMP"
}

if [ ! -f "$DUMP" ]; then
    echo "FAIL — nav smoke never wrote its result (app may have crashed)"
    tail -10 "$LOG"
    cleanup
    exit 1
fi

panes=$(grep "^panes_per_tab=" "$DUMP" | cut -d= -f2)
focused=$(grep "^focused_pane=" "$DUMP" | cut -d= -f2)

if [ "$panes" = "2" ] && [ "$focused" = "0" ]; then
    echo "PASS — focus moved left to pane 0 (panes_per_tab=$panes)"
    cleanup
    exit 0
fi

echo "FAIL — directional nav did not move focus"
echo "  expected: panes_per_tab=2, focused_pane=0"
echo "  got     : panes_per_tab=$panes, focused_pane=$focused"
echo "--- dump ---"; cat "$DUMP"
cleanup
exit 1
