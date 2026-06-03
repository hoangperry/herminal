#!/usr/bin/env bash
# verify-session-restore.sh — regression-guard for v0.4.1 session
# restore. Closes the one carry-forward gap from the Sessions
# milestone retro (docs/backlog/v0.4-sessions-retrospective.md): the
# snapshot/restore round-trip was only ever verified by hand.
#
# Crafts a known workspace.json (2 tabs, the second with a 2-pane
# vertical split), launches a debug build with HERMINAL_TEST_RESTORE_DUMP
# pointed at a temp file, and asserts the dumped state shows the
# restored shape (tabs=2, panes_per_tab=1,2). The owner's real
# workspace.json is backed up + restored so running this never eats
# the live session.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BIN="$REPO_ROOT/.build/herminal.app/Contents/MacOS/HerminalApp"
WS="$HOME/Library/Application Support/herminal/workspace.json"
DUMP=/tmp/herminal-restore-result.txt

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

# Back up the owner's real session so the test snapshot doesn't clobber it.
BACKUP=""
if [ -f "$WS" ]; then
    BACKUP="$(mktemp)"
    cp "$WS" "$BACKUP"
fi

restore_backup() {
    if [ -n "$BACKUP" ]; then cp "$BACKUP" "$WS"; rm -f "$BACKUP";
    else rm -f "$WS"; fi
}

mkdir -p "$(dirname "$WS")"
cat > "$WS" <<JSON
{
  "activeTabIndex": 1,
  "tabs": [
    { "isVerticalSplit": true, "focusedPaneIndex": 0, "paneRatios": [1.0],
      "panes": [ {"cwd": "$REPO_ROOT"} ] },
    { "isVerticalSplit": true, "focusedPaneIndex": 1, "paneRatios": [0.5, 0.5],
      "panes": [ {"cwd": "$HOME"}, {"cwd": "$REPO_ROOT"} ] }
  ]
}
JSON

pkill -9 -x HerminalApp 2>/dev/null
rm -f "$DUMP"

LOG=$(mktemp)
HERMINAL_TEST_RESTORE_DUMP="$DUMP" "$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

for _ in $(seq 1 12); do
    sleep 1
    [ -f "$DUMP" ] && break
done

cleanup() {
    kill -9 "$APP_PID" 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    restore_backup
    rm -f "$LOG" "$DUMP"
}

if [ ! -f "$DUMP" ]; then
    echo "FAIL — restore dump never written (app may have crashed)"
    tail -10 "$LOG"
    cleanup
    exit 1
fi

tabs=$(grep "^tabs=" "$DUMP" | cut -d= -f2)
panes=$(grep "^panes_per_tab=" "$DUMP" | cut -d= -f2)
active=$(grep "^active_tab=" "$DUMP" | cut -d= -f2)

if [ "$tabs" = "2" ] && [ "$panes" = "1,2" ] && [ "$active" = "1" ]; then
    echo "PASS — session restored (tabs=$tabs, panes_per_tab=$panes, active=$active)"
    cleanup
    exit 0
fi

echo "FAIL — restored shape mismatch"
echo "  expected: tabs=2, panes_per_tab=1,2, active_tab=1"
echo "  got     : tabs=$tabs, panes_per_tab=$panes, active_tab=$active"
echo "--- dump ---"; cat "$DUMP"
cleanup
exit 1
