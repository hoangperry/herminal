---
title: tmux launcher (PRD Must Feature 3 leftover)
status: draft-from-define
owner: hoangperry
created: 2026-08-15
blockedBy: []
blocks: []
define: docs/define/tmux-launcher.md
---

# tmux launcher — implementation plan

**Define (source of truth):** [`docs/define/tmux-launcher.md`](../../docs/define/tmux-launcher.md)

Do not expand past that define. This file is how to build it.

## Verdict (from validation)

| Idea | Decision |
|---|---|
| new / attach / attach-or-create by repo | **Do** — PRD Must Feature 3, not shipped |
| Broadcast input (`synchronize-panes`) | **Out** — not in PRD; IME + agent-pane risk |
| choose-tree UI | **Out** — fold session list into Attach… |
| Detach PTY / process survives quit | **Out** — libghostty cannot attach an existing PTY; restore policy forbids resurrection |
| tmux `-CC` | **Out** — PRD §6.4 |

Do not implement anything in the Out rows in this plan.

## Goal

Give the user a menu + palette way to start or rejoin a **standard
tmux session inside a herminal tab**, using the focused pane’s cwd.
tmux stays in the PTY. Herminal does not become a multiplexer.

Acceptance (PRD §5 Must Feature 3):

- New tmux session
- Attach existing session
- Attach-or-create by repo name

## Non-goals

- No control-mode client, no native window/pane sync with tmux
- No persist-after-quit, no attach of a live PTY after app restart
- No broadcast to sibling herminal panes
- No choose-tree / 3-level session-window-pane browser
- No change to `⌃B` / in-PTY tmux bindings
- No attempt to map agents inside tmux panes to the dashboard
- Not a competitor to `⌘⌥W` worktrees (git checkout vs process persist)

## Current code (hooks)

- Spawn: `WorkspaceView.addTab(command:title:workingDirectory:)` already
  runs a command in a new tab at a cwd (`ssh`, `claude --resume`).
- List/run helper pattern: `GitWorktree` + `GitRunner` — argv-only
  `/usr/bin/tmux` (or `tmux` via `command -v` resolved once; prefer
  `/opt/homebrew/bin/tmux` only after `FileManager.isExecutableFile`,
  never `PATH` hijack via `env tmux`). Simplest: `Process` with
  `tmux` looked up the same way we resolve `/usr/bin/git` — if
  Homebrew tmux is the only install, search a **fixed** list:
  `/opt/homebrew/bin/tmux`, `/usr/local/bin/tmux`, `/usr/bin/tmux`.
  First executable wins. Missing → alert, no spawn.
- Chrome: `AppMenu` Window menu + `CommandPaletteAction.all`.
- Session name source: focused OSC 7 cwd → `GitWorktree.resolveContext`
  repo basename when available, else last path component.

## Behaviour

### Names

Validate before any argv:

- Allowed: `A–Z a–z 0–9 . _ -`
- Reject: empty, leading `-`, `..`, spaces, `/`, control chars, length > 64
- Slug for attach-or-create: flatten like worktree slug, then validate

Never interpolate a name into a shell string. Spawn command is a
fixed argv joined only after validation, e.g. `tmux new-session -A -s name`.
libghostty `config.command` is a string; build it as
`tmux new-session -A -s` + single-quoted name (reuse
`WorkspaceView` SSH quoting helper). If quoting helper is
file-private, extract or duplicate the one-liner next to `TmuxLaunch`.

### Actions

| UI | What runs | Tab title |
|---|---|---|
| New tmux Session | `tmux new-session -s <name>` — name = validated repo slug; if session exists, fail with alert (do not steal) | `tmux · <name>` |
| Attach tmux Session… | `tmux list-sessions -F #{session_name}` → picker (NSAlert + popup, same shape as worktree dialog) → `tmux attach -t <name>` | `tmux · <name>` |
| Attach or Create tmux | `tmux new-session -A -s <name>` | `tmux · <name>` |

cwd of the new tab = focused pane cwd (nil → tmux default).

Empty session list on Attach… → “No tmux sessions. Create one first.”

### Files (keep small)

| File | Role |
|---|---|
| `Sources/HerminalApp/Workspace/TmuxLaunch.swift` | name validate, slug, list sessions, resolve binary, build command string |
| `Sources/HerminalApp/Workspace/WorkspaceView+Tmux.swift` | `@objc` actions, alerts, `addTab` |
| `AppMenu.swift` / `CommandPalette.swift` | 3 entries, no new shortcut (palette + menu only; leave ⌘⌥* to the cockpit) |
| `Tests/HerminalAppTests/TmuxLaunchTests.swift` | validate/slug/command build/quoting; fake runner for list |
| `docs/KEYBOARD-SHORTCUTS.md` + `CHANGELOG.md` Unreleased | document menu/palette only |

Do not grow `WorkspaceView.swift` except a one-line `addTab` call from the extension.

## Tests (write first)

- accept `herminal`, `my-app`, `foo.bar`
- reject `-evil`, `foo bar`, `foo/bar`, `a$(b)`, empty, 65+ chars
- slug of repo `My App` → `My-App` then validate
- command build: name `foo` → contains `-s` and quoted `foo`; name with `'` is escaped
- list parser: split `tmux list-sessions -F` lines, drop empty
- missing binary: resolve returns nil

No new `verify-*.sh` unless spawn path regresses; reuse
`verify-compat-matrix.sh` (already starts a tmux session).

## Risks

- Other agents edit `AppMenu` / `CommandPalette` / `WorkspaceView` — keep the
  diff to additive menu items + new files.
- `config.command` goes through the user shell: quoting is load-bearing
  (same class as `sshCommand`).
- Dashboard still cannot focus an agent that lives *inside* tmux. Do not
  “fix” that here.

## Done when

- Three palette/menu actions work on a machine with tmux installed
- Unit tests for name + command cover the injection cases above
- No broadcast, no `-CC`, no PTY detach code in the diff

## Validation log

- 2026-08-15 — cut broadcast, choose-tree, `-CC`, persist-after-quit.
  Keep only PRD launcher. Session picker is the Attach… dialog, not a
  tree.
