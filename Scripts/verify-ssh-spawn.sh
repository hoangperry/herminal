#!/usr/bin/env bash
# verify-ssh-spawn.sh — M4-4 integration test for the SSH spawn path.
#
# Proves that `WorkspaceView.addTab(command:title:)` actually runs the
# command via libghostty's `config.command` field — which is the exact
# mechanism the SSH manager uses for "Connect". We exercise it through
# the `HERMINAL_TEST_SPAWN_COMMAND` env hook so the test stays end-to-end
# (real binary, real PTY, real exec) without depending on an SSH server.
#
# Exits 0 if the spawned command runs and creates the expected marker
# file inside the timeout window.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"
MARKER=/tmp/herminal-m4-4-marker.txt

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

pkill -9 -x HerminalApp 2>/dev/null
rm -f "$MARKER"

LOG=$(mktemp)
HERMINAL_TEST_SPAWN_COMMAND="touch $MARKER && sleep 30" \
"$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

# The spawn task waits 2s after launch for the first tab to settle, then
# adds the second tab with the command. Touch fires immediately on exec.
# 8s gives the spawn + fork + exec + touch comfortable headroom.
for _ in $(seq 1 8); do
    sleep 1
    [ -f "$MARKER" ] && break
done

cleanup() {
    kill -9 $APP_PID 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    rm -f "$LOG" "$MARKER"
}

if [ -f "$MARKER" ]; then
    echo "PASS — libghostty spawned the override command (marker created)"
    cleanup
    exit 0
fi

echo "FAIL — spawn command never executed; marker missing"
echo "--- herminal log tail ---"
grep "herminal:" "$LOG" | tail -6
cleanup
exit 1
