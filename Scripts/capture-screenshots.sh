#!/usr/bin/env bash
# capture-screenshots.sh — produce the README / press-kit screenshots.
#
# Launches the built app, drives it with System Events keystrokes, and
# captures the window rect into docs/assets/. Deterministic enough to
# re-run at every release so the images never drift from the chrome.
#
# Two macOS permissions are required for the host terminal (iTerm2,
# Terminal.app, whatever runs this script):
#   • Privacy & Security → Accessibility            (to send keystrokes)
#   • Privacy & Security → Screen & System Audio Recording  (to capture)
# Grant them, then QUIT AND REOPEN the terminal — TCC only re-reads the
# grant at process launch.
#
# The Vietnamese IME shot cannot be automated: switching the system
# input source is not scriptable without further entitlements. This
# script prints the manual recipe for it at the end.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/docs/assets"

# Window geometry. 1440x900 is the smallest 16:10 that still leaves the
# terminal panes readable once GitHub scales the image down to ~890 px.
# Clamped to the actual display (CI runners are 1024x768) with a margin
# so the menu bar and Dock never bleed into the rect.
read -r DISP_W DISP_H < <(osascript -e 'tell application "Finder" to get bounds of window of desktop' | awk -F', ' '{print $3, $4}')
WIN_W=$(( DISP_W - 64 < 1440 ? DISP_W - 64 : 1440 ))
WIN_H=$(( DISP_H - 88 < 900 ? DISP_H - 88 : 900 ))
WIN_X=$(( (DISP_W - WIN_W) / 2 ))
WIN_Y=$(( (DISP_H - WIN_H) / 2 + 14 ))

# --- resolve the app: prefer a fresh local build over /Applications ---
APP_BUNDLE="$REPO_ROOT/.build/herminal.app"
if [ ! -x "$APP_BUNDLE/Contents/MacOS/HerminalApp" ]; then
    APP_BUNDLE="/Applications/herminal.app"
fi
if [ ! -x "$APP_BUNDLE/Contents/MacOS/HerminalApp" ]; then
    echo "ERROR: no herminal.app found." >&2
    echo "  Build one first: Scripts/bootstrap.sh && Scripts/make-app-bundle.sh" >&2
    exit 1
fi
APP_VERSION=$(defaults read "$APP_BUNDLE/Contents/Info.plist" \
    CFBundleShortVersionString 2>/dev/null || echo "unknown")
echo "==> Using $APP_BUNDLE (v$APP_VERSION)"

# --- fail fast on a missing Screen Recording grant -------------------
# screencapture prints "could not create image from rect" and exits 1
# when TCC denies it. Probing 1x1 px costs nothing and turns a set of
# silently-missing PNGs into one actionable error.
PROBE=$(mktemp -t herminal-shot-probe).png
if ! screencapture -x -R 0,0,1,1 "$PROBE" 2>/dev/null || [ ! -s "$PROBE" ]; then
    rm -f "$PROBE"
    echo "ERROR: screencapture is blocked for this terminal." >&2
    echo "  System Settings → Privacy & Security → Screen & System Audio" >&2
    echo "  Recording → enable $(basename "${TERM_PROGRAM:-your terminal}")," >&2
    echo "  then quit and reopen it." >&2
    exit 1
fi
rm -f "$PROBE"

mkdir -p "$OUT_DIR"

# --- helpers ---------------------------------------------------------

# Send a keystroke to herminal. Args: key [modifier-list]
# e.g. keystroke "a" "command down, shift down"
keystroke() {
    osascript -e "tell application \"System Events\" to tell process \"HerminalApp\"
        keystroke \"$1\" using {${2:-}}
    end tell" >/dev/null 2>&1
}

# Type a literal line into the focused pane and press Return.
type_line() {
    osascript -e "tell application \"System Events\" to tell process \"HerminalApp\"
        keystroke \"$1\"
        key code 36
    end tell" >/dev/null 2>&1
}

# Capture the window rect into docs/assets/<name>.png
shoot() {
    local name="$1"
    sleep 1.2
    if screencapture -x -R "$WIN_X,$WIN_Y,$WIN_W,$WIN_H" "$OUT_DIR/$name.png"; then
        echo "    ✓ docs/assets/$name.png"
    else
        echo "    ✗ failed: $name" >&2
    fi
}

# --- launch ----------------------------------------------------------
pkill -9 -x HerminalApp 2>/dev/null
sleep 1
# Suppress the one-time welcome overlay — it covers the workspace and
# swallows the scripted keystrokes on a fresh machine.
defaults write com.hoangperry.herminal preferences.firstRun.completed -bool true
open -a "$APP_BUNDLE"
sleep 5   # libghostty needs a moment to bring up the Metal layer + first PTY

osascript -e "tell application \"System Events\" to tell process \"HerminalApp\"
    set frontmost to true
    set position of window 1 to {$WIN_X, $WIN_Y}
    set size of window 1 to {$WIN_W, $WIN_H}
end tell" >/dev/null 2>&1 || {
    echo "ERROR: cannot drive HerminalApp via System Events." >&2
    echo "  Grant Accessibility to this terminal, then quit and reopen it." >&2
    exit 1
}
sleep 1

# --- 1. workspace: split panes + agent dashboard ---------------------
# HERMINAL_SHOT_CWD (optional): cd the panes there first — on CI the
# shell opens in $HOME, which is not a git repo and would show errors.
echo "==> workspace"
if [ -n "${HERMINAL_SHOT_CWD:-}" ]; then
    type_line "cd '$HERMINAL_SHOT_CWD'"
fi
type_line "clear && git -c color.ui=always log --oneline -6"
keystroke "d" "command down"                 # ⌘D — split vertical
sleep 1
if [ -n "${HERMINAL_SHOT_CWD:-}" ]; then
    type_line "cd '$HERMINAL_SHOT_CWD' && clear"
fi
type_line "git -c color.ui=always status -sb && ls Sources/"
sleep 2
# The detector polls only while the dashboard is open, so open it
# BEFORE spawning the agent — otherwise the shot lands between ticks.
keystroke "a" "command down, shift down"     # ⌘⇧A — agent dashboard
# HERMINAL_SHOT_SPAWN_AGENT (optional): start a process named `claude`
# so the dashboard has a real detection to show. CI provides a stub
# binary; on a dev machine the real CLI works the same.
if [ -n "${HERMINAL_SHOT_SPAWN_AGENT:-}" ]; then
    type_line "claude 300 >/dev/null 2>&1 &"
    sleep 7   # several 2s detector polls: appear + settle past "starting"
fi
shoot "screenshot-workspace"

# --- 2. ssh manager (mutex: replaces the dashboard in the left slot) --
echo "==> ssh manager"
keystroke "s" "command down, shift down"     # ⌘⇧S
shoot "screenshot-ssh-manager"

# --- 3. Claude session browser (third occupant of the left slot) -----
# Was never captured, so this panel's chrome had no visual coverage at all
# while its two slot-mates did.
echo "==> claude sessions"
keystroke "c" "command down, shift down"     # ⌘⇧C
shoot "screenshot-claude-sessions"

# --- 4. notes panel --------------------------------------------------
echo "==> notes"
keystroke "c" "command down, shift down"     # close the left slot
keystroke "n" "command down, shift down"     # ⌘⇧N — notes on the right
shoot "screenshot-notes"

echo
echo "==> Done. Leaving herminal open so you can take the IME shot by hand:"
echo "    1. Switch the input source to Vietnamese Telex (⌃Space)."
echo "    2. Type  tieesng vieejt  and stop while the preedit is underlined."
echo "    3. ⌘⇧4, drag the window region, save as:"
echo "       docs/assets/screenshot-ime.png"
echo "    The same recipe with a Korean, Japanese or Chinese input source"
echo "    produces the equivalent shot — see docs/QA/cjk-ime-checklist.md."
