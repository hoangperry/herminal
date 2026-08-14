# Phase 3 — Docs

Parent: [plan.md](plan.md)

Depends on phase 2.

## Goal

Docs match the shipped menu, not a fantasy mux.

## Steps

1. `CHANGELOG.md` Unreleased / Added — three launcher actions, menu +
   palette, tmux stays in the PTY.
2. `docs/KEYBOARD-SHORTCUTS.md` — under **tmux + nested terminals**,
   add a short table: the three commands live in Window / `⌘⇧P`, no
   keys. State that `⌃B` is unchanged.
3. Do not add a first-run welcome row (no shortcut to teach).

## Done

CHANGELOG + shortcuts mention launcher only. Diff still has no
broadcast / `-CC` / detach.
