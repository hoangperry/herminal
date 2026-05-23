#!/usr/bin/env bash
# run-test-harness.sh — drive herminal with scripted text, verify output.
#
# Usage:
#   Scripts/run-test-harness.sh "<text-to-inject>" "<path-that-shell-should-create>"
#
# Example:
#   Scripts/run-test-harness.sh $'touch /tmp/foo\n' /tmp/foo
#
# Mechanism:
#   - Builds the .app bundle if missing.
#   - Launches herminal under lldb (in a background subshell) with
#     HERMINAL_TEST_TEXT set so AppDelegate injects the text directly
#     into the active surface via ghostty_surface_text — bypassing the
#     keyboard, osascript, and the system input source (Telex).
#   - Waits long enough for the harness to inject + the shell to execute.
#   - Asserts the expected side-effect file exists.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <text-to-inject> <expected-file>" >&2
    exit 2
fi
TEXT="$1"
CHECK_FILE="$2"

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

rm -f "$CHECK_FILE"
pkill -9 -x HerminalApp 2>/dev/null

LOG=$(mktemp)
( HERMINAL_TEST_TEXT="$TEXT" lldb --batch -o "run" "$APP_BIN" > "$LOG" 2>&1 & )

# Poll for the side-effect file rather than relying on a fixed sleep —
# the shell startup + injection settling time varies on a busy machine.
# (Injection itself happens around T+4s; allow several more seconds for
# the shell to actually execute the command.)
for _ in $(seq 1 25); do
    sleep 1
    [ -f "$CHECK_FILE" ] && break
done

pkill -9 -x HerminalApp 2>/dev/null
pkill -9 lldb 2>/dev/null
pkill -9 -f "/usr/bin/login" 2>/dev/null

if [ -f "$CHECK_FILE" ]; then
    echo "PASS — $CHECK_FILE created"
    rm -f "$LOG"
    exit 0
else
    echo "FAIL — $CHECK_FILE not created"
    echo "--- herminal log ---"
    grep "herminal:" "$LOG" | tail -6
    rm -f "$LOG"
    exit 1
fi
