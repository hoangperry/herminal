#!/usr/bin/env bash
# verify-codex-detection.sh — M4-1 integration test for AgentDetector.
#
# Builds /tmp/codex (a tiny binary whose `p_comm` is literally "codex"),
# launches herminal, asks the test harness to inject a command that spawns
# /tmp/codex inside the pane's shell, then asks AgentDetector to dump.
#
# Exits 0 if the dump contains a "codex" line, non-zero otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"

CODEX_BIN=/tmp/codex
CODEX_SRC=/tmp/codex.c
AGENT_DUMP=/tmp/h_agents.txt
CHECK_FILE=/tmp/h_check.txt

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

# Build /tmp/codex fresh — a copy of /bin/sleep gets killed by AMFI (cdhash
# mismatch), and a shell script reports p_comm=bash. A purpose-built binary
# named "codex" gives the kernel a real p_comm="codex".
cat > "$CODEX_SRC" <<'C_EOF'
#include <unistd.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    int sec = (argc >= 2) ? atoi(argv[1]) : 30;
    sleep(sec);
    return 0;
}
C_EOF
clang -o "$CODEX_BIN" "$CODEX_SRC"
chmod +x "$CODEX_BIN"

pkill -9 -x HerminalApp 2>/dev/null
pkill -9 -x codex 2>/dev/null
rm -f "$AGENT_DUMP" "$CHECK_FILE"

LOG=$(mktemp)
INJECT=$'touch '"$CHECK_FILE"$' && '"$CODEX_BIN"$' 30\n'

HERMINAL_TEST_TEXT="$INJECT" \
HERMINAL_TEST_AGENT_DUMP="$AGENT_DUMP" \
"$APP_BIN" > "$LOG" 2>&1 &
APP_PID=$!

# Inject fires at T+8s, dump at T+14s. Wait 18s for safety.
sleep 18

cleanup() {
    kill -9 $APP_PID 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    pkill -9 -x codex 2>/dev/null
    rm -f "$LOG" "$CODEX_SRC"
}

if [ ! -f "$CHECK_FILE" ]; then
    echo "FAIL — shell never executed the injected touch (PTY input broken)"
    cleanup
    exit 1
fi

if [ ! -f "$AGENT_DUMP" ]; then
    echo "FAIL — agent dump file missing (Task @MainActor didn't run)"
    cleanup
    exit 1
fi

if grep -q "^codex " "$AGENT_DUMP"; then
    COUNT=$(grep -c "^codex " "$AGENT_DUMP")
    echo "PASS — AgentDetector found $COUNT codex agent(s)"
    cat "$AGENT_DUMP"
    cleanup
    exit 0
else
    echo "FAIL — agent dump exists but no 'codex' line"
    echo "--- dump ---"
    cat "$AGENT_DUMP"
    echo "--- herminal log tail ---"
    grep "herminal:" "$LOG" | tail -6
    cleanup
    exit 1
fi
