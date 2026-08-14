# Phase 2 — Menu, palette, spawn

Parent: [plan.md](plan.md) · Define: [docs/define/tmux-launcher.md](../../docs/define/tmux-launcher.md)

Depends on phase 1.

## Goal

The three define P0 actions work from Window menu and `⌘⇧P`.

## Steps

1. `WorkspaceView+Tmux.swift`:
   - `newTmuxSession:`
   - `attachTmuxSession:`
   - `attachOrCreateTmuxSession:`
   - Shared preamble: binary, cwd, name.
   - New: `hasSession` → fail closed if exists.
   - Attach…: list → empty alert or popup → `addTab`.
   - Attach or Create: no extra prompt.
   - Diary: action enum only.
2. `AppMenu.swift`: three items, **no** `keyEquivalent`. Place after
   Open Lazygit, then the existing separator + ⌘1–9.
3. `CommandPalette.swift`: three `CommandPaletteAction` rows matching
   those selectors. No `shortcutDisplay`.
4. Do not edit `WorkspaceView.swift` body.

## Manual check (owner)

On a machine with tmux:

- Palette → Attach or Create in this repo → tab titled `tmux · herminal`
  (or slugged name), session listed in `tmux ls`.
- Repeat Attach or Create → same session, not a second name.
- New while that session exists → alert, no new tab.
- Attach… → picker includes the session; picking it opens another
  client tab.
- Quit herminal → `tmux ls` still shows the session.

## Done

Define P0 ACs hold. No new shortcuts. No `WorkspaceView.swift` hunks.
