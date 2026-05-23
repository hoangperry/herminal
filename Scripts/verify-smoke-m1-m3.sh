#!/usr/bin/env bash
# verify-smoke-m1-m3.sh — Smoke test for the interactive features built
# in Months 1-3 (tabs, splits, sidebars, mutex policy) and Month 4
# (SSH sidebar mutex with agents). Drives WorkspaceView through every
# menu action without OS-level focus tricks, then asserts the dumped
# state matches what each action should have done.
#
# Triggered by the M4 retrospective: "Run the M4-0 harness through every
# interactive feature once before polish — same low effort, would catch
# any similar latent bugs." (M4-1 caught two bugs the unit tests had
# missed for 2 months; this smoke run is the same idea applied to M1-3.)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"
STATE=/tmp/herminal-smoke-state.txt

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

pkill -9 -x HerminalApp 2>/dev/null
rm -f "$STATE"

LOG=$(mktemp)
HERMINAL_TEST_SMOKE_PLAN=1 \
HERMINAL_TEST_STATE_DUMP="$STATE" \
"$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

# Plan spans T+2s startup + 9 actions at 0.5s spacing + dump = ~10s.
# Wait 14s for safety.
for _ in $(seq 1 14); do
    sleep 1
    [ -f "$STATE" ] && break
done

cleanup() {
    kill -9 $APP_PID 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    rm -f "$LOG" "$STATE"
}

if [ ! -f "$STATE" ]; then
    echo "FAIL — smoke plan never wrote its state dump (app may have crashed)"
    echo "--- herminal log tail ---"
    tail -10 "$LOG"
    cleanup
    exit 1
fi

# Assertions: each line in $STATE must match the expected post-plan value.
# Expected sequence:
#   start (1 tab, 1 pane) → +2 tabs → 2 splits on active → toggle 3 sidebars
#   → nextTab x2 → prevTab → closeActivePane (kills the 1-pane tab)
# Resulting: 2 tabs (the old tab 1 + tab 2 with 3 panes), active=0, sidebars
# left=ssh (ssh wins over agents due to mutex) + notes=true.
declare -A expected=(
    [tabs]="2"
    [active_tab]="0"
    [panes_per_tab]="1,3"
    [active_split_axis]="vertical"
    [focused_pane]="0"
    [left_sidebar]="ssh"
    [notes_visible]="true"
)

failures=0
for key in "${!expected[@]}"; do
    want="${expected[$key]}"
    got=$(grep "^$key=" "$STATE" | head -1 | cut -d= -f2-)
    if [ "$got" = "$want" ]; then
        echo "  ok   $key = $got"
    else
        echo "  FAIL $key: want='$want' got='$got'"
        failures=$((failures + 1))
    fi
done

if [ $failures -eq 0 ]; then
    echo "PASS — 7/7 state assertions, no crash across 9 interactive actions"
    cleanup
    exit 0
fi

echo "FAIL — $failures assertion(s) failed"
echo "--- full state ---"
cat "$STATE"
echo "--- smoke log lines ---"
grep "herminal: smoke" "$LOG"
cleanup
exit 1
