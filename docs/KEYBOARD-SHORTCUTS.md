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
| ⌘D | Split pane vertically | Side-by-side (left/right) |
| ⌘⇧D | Split pane horizontally | Stacked (top/bottom) |
| ⌥⌘← | Focus pane left | Spatial — nearest pane to the left |
| ⌥⌘→ | Focus pane right | Spatial — nearest pane to the right |
| ⌥⌘↑ | Focus pane up | Spatial — nearest pane above |
| ⌥⌘↓ | Focus pane down | Spatial — nearest pane below |

Since v0.5.0 panes split recursively — any pane can split again along
either axis, nesting like tmux. Use ⌥⌘+arrow to move focus between
nested panes by direction (v0.5.1).

---

## Sidebars

| Shortcut | Action | Notes |
|---|---|---|
| ⌘⇧A | Toggle agent dashboard | Left side; mutex with SSH manager |
| ⌘⇧S | Toggle SSH manager | Left side; mutex with agent dashboard |
| ⌘⇧N | Toggle notes panel | Right side; per-session content |
| ⌘⇧L | Toggle light / dark theme | Persists for the session |

The left slot holds at most one sidebar — opening one closes the
other. Closing both reclaims ~280 px of terminal real estate.

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
