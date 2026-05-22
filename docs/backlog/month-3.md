# Month 3 Backlog — herminal Agent Dashboard + Notes

**Sprint goal (PRD roadmap):** Multi-agent dashboard alpha + notes SQLite + basic export.
**Start date:** 2026-05-22
**Owner:** hoangperry
**Carries debt:** #11 (Vietnamese IME smoke test) + Month-2 GUI-verification gap.

> ⚠️ Month-2 retro flagged this as the hard month: the agent dashboard is the
> first feature with **no Ghostty reference** and is herminal's actual
> differentiator. Expect slower, more iterative work than Month 2.

---

## Status Legend
⏳ pending · 🔄 in_progress · ✅ done · ⛔ blocked · 🗑️ deferred

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M1-11 | ⏳ | Vietnamese IME smoke test (20 phrases) | Owner manual test — Telex/VNI; debt from Month 1 |
| M3-1 | ✅ | Notes storage (SQLite WAL) | `NotesStore` — Note model + upsert/fetch/delete/list; WAL; 5 Swift Testing cases pass |
| M3-2 | ✅ | Agent process detection | `AgentDetector` — process-tree scan (libproc) for claude/codex/aider; 3 Swift Testing cases pass |
| M3-3 | ✅ | Agent dashboard sidebar UI | `AgentDashboardView` SwiftUI sidebar + 2s poll; toggle Cmd+Shift+A. Render verified (header/count/empty state) |
| M3-4 | ✅ | Notes panel UI (per-tab) | `NotesPanelView` right sidebar + autosave to `NotesStore`; toggle Cmd+Shift+N. Render verified |
| M3-5 | 🔄 | Notes markdown export / import | Round-trip notes ↔ .md files |
| M3-6 | ⏳ | Month 3 retrospective | Review, re-check 7-month scope |

---

## Progress Log

### 2026-05-22 — Month 3 kickoff

**Context carried in:**
- Month 1 + 2 done: terminal embeds libghostty, renders, tabs, splits, tmux-compat,
  premium chrome. 7-month Option A on track.
- Stack locked (libghostty + Swift + SQLite); no architecture research needed.

**Plan / sequencing:**
- Notes storage first (M3-1): pure backend, unit-testable, no GUI-verification
  dependency — a clean start while the harder dashboard work is scoped.
- Agent detection (M3-2) before dashboard UI (M3-3): the UI needs the data model.
- Notes UI (M3-4) + export (M3-5) build on M3-1.

---

## Deferred / Dropped Items

_None yet._

---

## Open Questions

- **Q3-001:** GUI-verification gap (from Month-2 retro). osascript can't reliably
  drive herminal's GUI (focus stealing + Telex composing test input). Options:
  scheduled owner test sessions, an in-app scripted-input debug mode, or XCUITest.
  Decide before the dashboard/notes UI lands (M3-3 / M3-4).
- **Q3-002:** Agent detection — pure process-tree inspection vs OSC 7/133 + title
  heuristics? PRD says "heuristics over protocol". To settle in M3-2.

---

## Reference

- [Month 2 retrospective](./month-2-retrospective.md)
- [PRD](../define/herminal.prd.md) — Month 3 = dashboard alpha + notes + export
