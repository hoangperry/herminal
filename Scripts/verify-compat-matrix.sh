#!/usr/bin/env bash
# verify-compat-matrix.sh — M5-1 compatibility smoke for TUI apps.
#
# For each app in the matrix: spawn it inside herminal via the M4-4
# command-spawn hook, wait a few seconds, then assert the process
# survives (i.e., the app initialised its terminal IO without
# crashing). Visual correctness is not asserted here — that requires
# screenshot diffing, deferred to M5-2 polish.
#
# Per-app expectation: the BINARY appears in herminal's subtree with
# its real `p_comm`. If a TUI crashes on init (color allocation,
# termios, mouse setup, …) it dies inside the 3s window and the test
# catches it.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
APP_BIN="$APP_BUNDLE/Contents/MacOS/HerminalApp"

if [ ! -x "$APP_BIN" ]; then
    echo "==> herminal not built; running make-app-bundle.sh"
    "$REPO_ROOT/Scripts/make-app-bundle.sh" >/dev/null
fi

# Matrix: "label|spawn_command|process_name_to_match".
# - spawn_command runs in the new tab's shell
# - process_name_to_match is what pgrep should find inside the
#   herminal subtree before we kill it
MATRIX=(
    "vim|vim /tmp/herminal-compat.txt|vim"
    "tmux|tmux new-session -d -s herminal-compat 'sleep 30'|tmux"
    "nano|nano /tmp/herminal-compat.txt|nano"
    "less|less /etc/hosts|less"
    "htop|htop|htop"
    # libghostty's spawn wraps `<cmd>` in `exec -l <cmd>`, so a piped
    # right-hand side won't be inside the exec — fzf goes bare and reads
    # from the PTY. lazygit doesn't need a wrapper either.
    "fzf|fzf --reverse|fzf"
    "lazygit|lazygit|lazygit"
    "btop|btop|btop"
    # starship is a shell prompt, not a TUI — proxy it via a bash that
    # eval-init starships and stays alive long enough for ps to see it.
    "starship|bash -c 'eval \"\$(starship init bash)\"; sleep 30'|bash"
)

run_one() {
    local label="$1"
    local cmd="$2"
    local needle="$3"

    pkill -9 -x HerminalApp 2>/dev/null
    pkill -9 -x "$needle" 2>/dev/null
    pkill -9 -x -- "-$needle" 2>/dev/null
    sleep 1

    local log; log=$(mktemp)
    HERMINAL_TEST_SPAWN_COMMAND="$cmd" "$APP_BIN" > "$log" 2>&1 &
    local app_pid=$!
    # Spawn fires at T+2s; give the app another 3s to initialise.
    sleep 5

    # libghostty's spawn wraps `<cmd>` in `exec -l <cmd>`, which marks the
    # process as a login session — the kernel records p_comm with a leading
    # dash. Match both shapes so the test stays right even if the wrapper
    # changes upstream.
    local hits
    hits=$(ps -axo comm | grep -cE "^-?${needle}$")
    kill -9 $app_pid 2>/dev/null
    pkill -9 -x HerminalApp 2>/dev/null
    pkill -9 -x "$needle" 2>/dev/null
    pkill -9 -x -- "-$needle" 2>/dev/null
    pkill -9 -f "herminal-compat" 2>/dev/null
    rm -f "$log" /tmp/herminal-compat.txt

    if [ "$hits" -ge 1 ]; then
        printf "  %-10s ✅ alive (%d process)\n" "$label" "$hits"
        return 0
    fi
    printf "  %-10s ❌ never spawned or crashed\n" "$label"
    return 1
}

failures=0
echo "==> Compatibility matrix"
for entry in "${MATRIX[@]}"; do
    IFS='|' read -r label cmd needle <<< "$entry"
    if ! run_one "$label" "$cmd" "$needle"; then
        failures=$((failures + 1))
    fi
done

if [ $failures -eq 0 ]; then
    echo "PASS — ${#MATRIX[@]}/${#MATRIX[@]} apps launched and persisted"
    exit 0
fi
echo "FAIL — $failures/${#MATRIX[@]} apps did not survive launch"
exit 1
