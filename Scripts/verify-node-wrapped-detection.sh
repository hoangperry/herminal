#!/usr/bin/env bash
# verify-node-wrapped-detection.sh — M8/A1 integration test.
#
# Closes Q3-002: agents installed via npx/python-script wrappers report
# `p_comm=node` (or `Python`), so name-only matching misses them.
# `AgentDetector` now peeks at argv via sysctl(KERN_PROCARGS2) when the
# process name is a known interpreter — verify that the live spawn path
# catches a python-wrapped fake aider.
#
# Why python and not node: macOS Sequoia ships python3 in the box;
# requiring `node` would force the test to brew-install before running.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

# A "fake aider" Python script — basename `aider` so our argv matcher
# picks it up via the script-name branch (no need to fake the
# `aider-chat` package layout).
FAKE_AIDER=/tmp/aider
cat > "$FAKE_AIDER" <<'PYEOF'
import time
time.sleep(30)
PYEOF

CHECK_FILE=/tmp/herminal-node-wrap-check.txt
AGENT_DUMP=/tmp/herminal-node-wrap-agents.txt

pkill -9 -x HerminalApp 2>/dev/null
pkill -9 -f "python3 $FAKE_AIDER" 2>/dev/null
rm -f "$CHECK_FILE" "$AGENT_DUMP"

# touch then python3-spawn-fake-aider — the same pattern verify-codex
# uses, just with the wrapper interpreter form.
INJECT=$'touch '"$CHECK_FILE"$' && python3 '"$FAKE_AIDER"$'\n'

LOG=$(mktemp)
HERMINAL_TEST_TEXT="$INJECT" \
HERMINAL_TEST_AGENT_DUMP="$AGENT_DUMP" \
HERMINAL_TEST_DELAY=12 \
"$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

# Inject T+12s → dump T+18s → wait 22s (M8: startup pushed past 8s).
sleep 22

cleanup() {
    kill -9 $APP_PID 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    pkill -9 -f "python3 $FAKE_AIDER" 2>/dev/null
    rm -f "$LOG" "$CHECK_FILE" "$FAKE_AIDER"
}

if [ ! -f "$CHECK_FILE" ]; then
    echo "FAIL — shell never executed touch (PTY input broken)"
    cleanup
    exit 1
fi
if [ ! -f "$AGENT_DUMP" ]; then
    echo "FAIL — agent dump missing (Task @MainActor didn't run)"
    cleanup
    exit 1
fi

# We expect a row whose KIND is `aider` and whose process name shows
# the interpreter parenthetical (`aider (Python)`).
if grep -q "^aider " "$AGENT_DUMP"; then
    echo "PASS — AgentDetector classified the python-wrapped fake as aider"
    cat "$AGENT_DUMP"
    cleanup
    exit 0
fi

echo "FAIL — dump exists but no 'aider' line"
echo "--- dump ---"
cat "$AGENT_DUMP"
echo "--- herminal log tail ---"
grep "herminal:" "$LOG" | tail -6
cleanup
exit 1
