#!/usr/bin/env bash
# dogfood-daily.sh — M6 daily-driver health check.
#
# Runs every integration script in sequence so the dogfood owner gets a
# one-line PASS/FAIL per check without having to remember six script
# names. Designed to be added to a launchd plist or run before the first
# coffee — non-interactive, exits non-zero on any failure.
#
# Also tails the diary so the owner can spot weird entries at a glance
# without leaving the terminal.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIARY="$HOME/Library/Application Support/herminal/diary.log"

CHECKS=(
    "M1-M3 smoke    |verify-smoke-m1-m3.sh"
    "M4-0 baseline  |run-test-harness.sh"
    "M4-1 codex     |verify-codex-detection.sh"
    "M4-4 ssh spawn |verify-ssh-spawn.sh"
    "M5-1 compat    |verify-compat-matrix.sh"
    # v0.2.2 lesson: clipboard / mouse-selection bug hid 12 months
    # because no programmable check verified the round-trip. Bake it in.
    "v0.2.2 copy    |verify-clipboard.sh"
    # v0.2.4: GhosttyApp.handleAction was a one-case switch (RING_BELL).
    # SET_TITLE / SET_TAB_TITLE silently returned false. Bake the
    # round-trip so future audits catch any other unhandled action.
    "v0.2.4 title   |verify-title.sh"
    # v0.4.1: session restore was only ever hand-verified. Craft a
    # snapshot, launch, assert dumpState restored the shape.
    "v0.4.1 restore |verify-session-restore.sh"
    "v0.5.1 pane-nav|verify-pane-nav.sh"
)

# Special baseline call needs args (text + check-file).
baseline_args=$'touch /tmp/herminal-dogfood-baseline.txt\n /tmp/herminal-dogfood-baseline.txt'

failures=0
echo "==> Dogfood daily health check  ($(date +'%Y-%m-%d %H:%M'))"
echo ""

for entry in "${CHECKS[@]}"; do
    IFS='|' read -r label script <<< "$entry"
    label_trimmed="$(echo -n "$label" | sed 's/[[:space:]]*$//')"
    printf "  %-22s ... " "$label_trimmed"
    # The previous check's `pkill -9` is async — give the kernel a beat
    # to release the bundle's resources (Metal layer, PTY fds) before
    # the next check launches a fresh HerminalApp. Without this, the
    # next launch's surface init occasionally races and the inject path
    # silently no-ops.
    pkill -9 -x HerminalApp 2>/dev/null
    sleep 2
    if [ "$script" = "run-test-harness.sh" ]; then
        rm -f /tmp/herminal-dogfood-baseline.txt
        out="$("$REPO_ROOT/Scripts/$script" \
            $'touch /tmp/herminal-dogfood-baseline.txt\n' \
            /tmp/herminal-dogfood-baseline.txt 2>&1)"
    else
        out="$("$REPO_ROOT/Scripts/$script" 2>&1)"
    fi
    if echo "$out" | grep -q "^PASS"; then
        echo "PASS"
    else
        echo "FAIL"
        echo "    ↳ $(echo "$out" | tail -3 | tr '\n' ' ')"
        failures=$((failures + 1))
    fi
done

echo ""
if [ -f "$DIARY" ]; then
    lines=$(wc -l < "$DIARY" | tr -d ' ')
    echo "==> Diary: $lines line(s) in $DIARY"
    last_crash=$(grep "CRASHED" "$DIARY" | tail -1)
    if [ -n "$last_crash" ]; then
        echo "    ⚠️  Last crash entry: $last_crash"
    fi
    echo "    Recent tail:"
    tail -5 "$DIARY" | sed 's/^/      /'
else
    echo "==> Diary not yet created (herminal hasn't run since the last clean)"
fi

echo ""
if [ $failures -eq 0 ]; then
    echo "✅ All ${#CHECKS[@]} checks passed."
    exit 0
fi
echo "❌ $failures/${#CHECKS[@]} checks failed — log the details in today's journal."
exit 1
