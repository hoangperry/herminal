# Month 3 Retrospective — herminal Agent Dashboard + Notes

**Period:** 2026-05-22
**Sprint goal (PRD roadmap):** Multi-agent dashboard alpha + notes SQLite + basic export.
**Result:** ✅ Goal met. All 5 Month-3 tasks (M3-1..M3-5) done; retrospective is M3-6.

---

## 1. What Got Done

| # | Task | Outcome |
|---|------|---------|
| M3-1 | Notes storage | `NotesStore` — SQLite WAL, Note CRUD; 5 tests |
| M3-2 | Agent detection | `AgentDetector` — process-tree scan via libproc; 3 tests |
| M3-3 | Agent dashboard UI | `AgentDashboardView` sidebar + 2s poll; Cmd+Shift+A |
| M3-4 | Notes panel UI | `NotesPanelView` right sidebar, autosave; Cmd+Shift+N |
| M3-5 | Notes export/import | `NotesExporter` + File-menu Export/Import; 2 tests |

10 new unit tests, all green. Zero crashes. Commits `4e12692` → `b8182da`.

**Month-3 roadmap goal — "dashboard alpha + notes SQLite + export" — is met.**

---

## 2. What We Learned (Lessons & Bugs)

### Architecture
- **libghostty exposes no per-surface shell PID.** Agent detection therefore
  works at the app level: scan herminal's whole process subtree (`libproc`),
  not per-pane. Consequence: the dashboard lists agents for the *window*, it
  cannot yet say *which pane* an agent runs in (Q3-002).
- **Backend-first sequencing paid off.** M3-1 (notes storage) and M3-2 (agent
  detection) are pure logic — unit-tested cleanly with no GUI dependency. Doing
  them first meant the harder UI work built on a verified foundation.
- **`HerminalApp` had to gain `HerminalDB` + `HerminalAgent` dependencies** —
  a linker error caught it. Module dependencies must be declared, not assumed.

### Honest scope of the "agent dashboard alpha"
The dashboard genuinely is alpha:
- Every detected agent shows as "running" — no running/idle/done discrimination
  (needs CPU / process-state sampling).
- No agent↔pane mapping (libghostty PID limitation).
- Node-wrapped agent CLIs reporting as "node" are missed.
PRD M3 explicitly says "alpha", so this is in-scope — but this is herminal's
**core differentiator**, and it is currently shallow. Month 4+ must deepen it.

### Process lesson — the verification gap is now 3 months old
The same wall as Month 2: dashboard and notes-panel *render* was verified
(screenshots via temporary in-code enables), but **no interactive path was
self-verified** — Cmd+Shift+A/N, typing a note, clicking a tab. osascript is
unreliable (focus stealing + Telex composing test input). This debt has
compounded across all three months.

---

## 3. Estimate vs Actual

- **PRD Month-3 plan:** dashboard alpha + notes SQLite + export.
- **Month-2 retro predicted** Month 3 would be slower (no Ghostty reference).
  Actual: it was NOT dramatically slower — because the dashboard was scoped
  honestly as an alpha (a process list), not a deep feature. The notes feature
  (storage → panel → export) went smoothly on SQLite.
- **Caveat (unchanged from M1/M2):** "done" = code shipped, builds green, render
  verified, backend unit-tested. Interactive verification is still owner-pending.

---

## 4. Debt Carried Into Month 4

| Item | Why pending |
|------|-------------|
| #11 Vietnamese IME smoke test | Owner manual test — now 3 months old |
| GUI interactive verification (Q3-001) | osascript unreliable; no fix landed in M3 |
| Agent status discrimination (running/idle/done) | Needs CPU/process-state sampling |
| Agent↔pane mapping | libghostty exposes no per-surface PID |
| Node-wrapped agent detection (Q3-002) | Short-name heuristic misses `node`-hosted CLIs |
| Recursive split trees (Q2-003) | Deferred since Month 2 |
| Drag-to-resize dividers (Q2-002) | Deferred since Month 2 |

---

## 5. Roadmap Adjustment for Month 4

- **Month 4 (per PRD):** SSH Connection Manager UI + markdown round-trip + Codex CLI detection.
  (Markdown round-trip already shipped early in M3-5 — Month 4 is lighter than written.)
- **Must-fix before more UI: the verification gap.** Three months of
  owner-pending interactive checks is the single biggest accumulated risk.
  Recommendation for Month 4 week 1: add an in-app debug command that scripts
  input internally (no osascript, no system IME) so Cmd shortcuts, tab/pane
  switching, and note editing can be self-tested. Or commit to a fixed owner
  test session at each month boundary.
- **Deepen agent detection.** The dashboard is the differentiator; "a list of
  running processes" is not enough. Month 4/5 should add status (busy/idle) and,
  if a libghostty API or a PTY-scraping heuristic allows, agent↔pane mapping.

### Scope re-check (PRD burnout mitigation #4)
- 7-month Option A: M1 ✅, M2 ✅, M3 ✅ — **on track, 3 of 7 months done.**
- **No downgrade to Option B/C needed.** The first three months delivered every
  roadmap milestone. But the verification gap means "delivered" is partly on
  trust — closing it in Month 4 is what makes the on-track claim real.

---

## 6. Honest Self-Assessment

**Good:** Three months, three roadmap milestones, all met. Backend code
(notes storage, agent detection, export) is properly unit-tested — 19 tests
total across the package now. Clean architecture held. Zero crashes in M2+M3.

**Could be better:** The verification gap did not get fixed in Month 3 despite
the Month-2 retro flagging it as the must-fix. It was easier to ship features
than to build test infrastructure — and that is exactly how debt compounds.
herminal still has not been driven by a human for one real session.

**Risk for Month 4:** if the verification gap is deferred again, herminal will
reach the halfway point of a 7-month build with five interactive features none
of which were ever exercised by a person. Fix it first in Month 4, before the
SSH Connection Manager UI.
