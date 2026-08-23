# Keyboard shortcuts

Reference card for every keybinding herminal owns. The bindings
LIVE in `Sources/HerminalApp/AppMenu.swift` — this doc mirrors
that file; if they ever diverge, the menu source is authoritative.

> ⌘ = Command · ⇧ = Shift · ⌥ = Option · ⌃ = Control

---

## Tab + pane management

| Shortcut | Action | Notes |
|---|---|---|
| ⌘T | New tab | Spawns `$SHELL` |
| ⌘W | Close pane | Closes the tab when the last pane goes |
| ⌘⇧] | Next tab | Wraps at the end of the strip |
| ⌘⇧[ | Previous tab | Wraps at the beginning |
| ⌘1…⌘8 | Select tab N | No-op when that tab does not exist |
| ⌘9 | Select last tab | FlightDeck / Ghostty convention |
| ⌘D | Split pane vertically | Side-by-side (left/right) |
| ⌘⇧D | Split pane horizontally | Stacked (top/bottom) |
| ⌥⌘← | Focus pane left | Spatial — nearest pane to the left |
| ⌥⌘→ | Focus pane right | Spatial — nearest pane to the right |
| ⌥⌘↑ | Focus pane up | Spatial — nearest pane above |
| ⌥⌘↓ | Focus pane down | Spatial — nearest pane below |
| ⌘⇧↩ | Zoom pane | Maximize the focused pane; toggle to restore (v1.0) |

Since v0.5.0 panes split recursively — any pane can split again along
either axis, nesting like tmux. Use ⌥⌘+arrow to move focus between
nested panes by direction (v0.5.1); the first arrow while zoomed exits
zoom. `⌘⇧↩` maximizes the focused pane and toggles back (v1.0).

With macOS Full Keyboard Access enabled, Tab/Shift-Tab can also move
directly through the tab strip. Return or Space selects the focused tab;
the next focus stop closes that tab, and the final `+` control opens a
new terminal tab. A visible teal outline follows keyboard focus.

Tab can also focus a split divider. Use ← / → on a vertical divider or
↑ / ↓ on a horizontal divider to resize the adjacent panes in 5% steps;
Return or Space balances that split back to 50/50. VoiceOver exposes the
same divider as an adjustable splitter and announces its current percentage.

## Font size

| Shortcut | Action | Notes |
|---|---|---|
| ⌘+ | Bigger text | Scales every pane; View menu (v1.0) |
| ⌘− | Smaller text | Scales every pane |
| ⌘0 | Actual size | Resets to the Settings default |

## App + window management

| Shortcut | Action | Notes |
|---|---|---|
| ⌘, | Settings… | Standard macOS app-settings binding |
| ⌘H | Hide herminal | Standard app hide |
| ⌘⌥H | Hide Others | Hides every other app |
| ⌘M | Minimize | Native macOS window minimize |
| ⌥Space | Show Hotkey Window | In-app fallback if the global hotkey cannot be registered |

About herminal, Services, Show All, window Zoom, and Bring All to Front
stay in the native menus with no default shortcut.

## Workspace chrome

| Shortcut | Action | Notes |
|---|---|---|
| (no shortcut) | Show / Hide Status Bar | View menu or search “status” in ⌘⇧P |

The status bar exposes the focused pane directory as a keyboard-accessible
actions menu for copying the full path or revealing it in Finder. VoiceOver
keeps that menu and the read-only workspace diagnostics as two concise stops;
the diagnostics include tick p95, agent count, diary size, and theme.

## Search + command surfaces

| Shortcut | Action | Notes |
|---|---|---|
| ⌘F | Find in terminal… | Opens the scrollback search overlay; press again to refocus its query |
| ⌘G | Find next | Search overlay or Edit menu |
| ⌘⇧G | Find previous | Search overlay or Edit menu |
| ⌘/ | Keyboard Shortcuts… | Opens the searchable reference generated from the current app menus |
| ⌘⇧P | Command Palette… | Search commands, settings, and support actions |

The command palette also exposes **Copy Redacted Diagnostics for Bug
Report** with no direct shortcut. Type `diagnostics` to reach the same
privacy-safe copy flow available from the Help menu.

---

## Agents + worktrees

FlightDeck-style cockpit. Agents are detected automatically; these
shortcuts *launch* them.

| Shortcut | Action | Notes |
|---|---|---|
| ⌘⌥A | New agent pane | Vertical split running `claude` in the current cwd |
| ⌘⌥T | New agent tab | New tab running `claude` in the current cwd |
| ⌘⌥W | New agent worktree… | Isolated `../<repo>.worktrees/<branch>` + agent |
| ⌘⌥G | Open lazygit | New tab at the current cwd |
| ⌘⇧A | Toggle agent dashboard | Live agents + worktree list |

## Sidebars

| Shortcut | Action | Notes |
|---|---|---|
| ⌘⇧A | Toggle agent dashboard | Left side; mutex with SSH manager |
| ⌘⇧S | Toggle SSH manager | Left side; mutex with agent dashboard |
| ⌘⇧C | Toggle Claude Sessions | Left side; browse and resume local Claude projects |
| ⌘⇧N | Toggle notes panel | Right side; per-session content |
| ⌘⇧L | Toggle light / dark theme | Persists for the session |

The left slot holds at most one sidebar — opening one closes the
other. Closing both reclaims ~280 px of terminal real estate.

Inside the Agent Dashboard, an intentional ⌘⇧A open focuses New Agent
Pane when no agents are running, or the first running agent mapped to a
terminal pane. Return or Space launches the empty-state action or jumps
to the mapped pane; in a git repo, Tab also reaches New Agent Worktree.
Routine sidebar refreshes do not reclaim focus.

Inside the SSH manager, an intentional ⌘⇧S open moves focus to the
first useful action: Import for an empty list, or the first saved host.
Use Tab/Shift-Tab to move and Return or Space to connect. Tab once more
to the host's Actions menu for Edit/Delete. In the host form, Hostname
receives focus; Return saves a valid host and Escape cancels. Validation
returns focus to the field that needs attention.

Inside Claude Sessions, an intentional ⌘⇧C open focuses New Agent Pane
when no sessions exist, or Filter sessions when the list is populated.
Tab reaches resumable sessions and their Actions menus for Open Shell Here.
Refreshes and restored sidebar state do not take focus away from the terminal.

---

## File menu

| Shortcut | Action | Notes |
|---|---|---|
| (no shortcut) | Export note… | Active session's note → markdown file |
| (no shortcut) | Import note… | Markdown file → active session's note |
| (no shortcut) | Import ~/.ssh/config | One-shot import; opens SSH sidebar after |

The export/import items don't have shortcuts because they're rare
operations and we'd rather leave the keys free for daily-use
actions.

---

## Inside the terminal

Once the terminal pane has focus, libghostty owns the keystrokes —
herminal doesn't intercept them. So everything your shell normally
binds works unchanged:

- ⌃A / ⌃E — beginning / end of line (readline / zsh default)
- ⌃R — history search
- ⌃C — interrupt
- ⌃D — EOF / exit
- ⌥← / ⌥→ — word-jump (if your shell binds them; zsh's default
  doesn't, but `bindkey "^[[1;3D" backward-word` does)

If a herminal shortcut and a libghostty shortcut both bind the same
key, herminal wins (it's higher in the responder chain). The
shortcuts above are deliberately chosen to AVOID conflicts with
common shell + tmux bindings.

---

## tmux + nested terminals

When you run tmux inside herminal, tmux owns the keystrokes that
match its prefix (default `⌃B`). herminal's ⌘ shortcuts still work
because tmux doesn't see Command-key combinations on macOS —
they're translated by macOS before they reach libghostty.

So you can use ⌘T to open a herminal tab AND ⌃B C to open a tmux
window inside the active herminal pane. No conflict.

The Window menu and command palette (`⌘⇧P`) can start or rejoin a
named session (New… / Attach… / Attach or Create). Those actions have
no extra shortcut — `⌃B` is unchanged. New… prompts for a name
(repo slug prefilled). The tmux *client* lives in the new tab; the
tmux *server* survives that tab closing. The agent dashboard lists
live sessions: click to attach, trash to kill (with confirm). Rows
show window count, last activity, the session folder when it is not
the session name, the first few window titles when there is more
than one window, and a **Here** chip when this
window already attached. Newest activity is listed first. Dashboard
**New** attach-or-creates the repo-named session; **Named…** opens
the name dialog. Attach… uses the same status line. A second attach
focuses the exact existing pane.

---

## Vietnamese IME

When the macOS input source is Vietnamese Telex or VNI:

| Sequence | Result | Notes |
|---|---|---|
| `ddd` | `đd` | Telex's `dd → đ` then a literal `d` |
| `aw` | `ă` | |
| `oo` | `ô` | |
| `ow` | `ơ` | |
| `tieesng` | `tiếng` | full Telex composition |

The composition happens in macOS's IME engine — herminal just
displays the underlined preview through the
`NSTextInputClient.setMarkedText` path. See
`docs/QA/vietnamese-ime-checklist.md` for the 20-phrase test
matrix.

---

## Programmatic / scripted control

Herminal exposes no IPC API in v0.1.0 — you can't `osascript` it.
For test scripting use the `HERMINAL_TEST_*` env hooks documented
in `docs/PATTERNS.md` and `Scripts/verify-*.sh`.

(Production builds have those hooks compiled out — they exist only
in `#if DEBUG` builds. See `docs/REVIEW.md` for the why.)

---

## Conflicts with macOS system shortcuts

| Shortcut | macOS default | herminal | Resolution |
|---|---|---|---|
| ⌘W | Close window | Close pane / tab | Pane wins — we re-bind in the File menu |
| ⌘⇧] | (mostly free) | Next tab | herminal binds it via menu; system rarely conflicts |
| ⌘⇧L | (system: open Downloads in Safari) | Toggle theme | herminal wins when herminal is frontmost; Safari binding still works elsewhere |
| ⌘D | Bookmark (in some apps) | Split vertical | Same — context-dependent on the frontmost app |

If a herminal shortcut conflicts with a system service you actually
need, the path is to override the system shortcut in
System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts.
herminal doesn't (yet) ship its own remapping UI; that's a v0.2+
candidate if anyone asks.
