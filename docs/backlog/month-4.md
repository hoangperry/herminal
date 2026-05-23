# Month 4 Backlog — herminal SSH + Codex Detection + Verification

**Sprint goal (PRD roadmap):** SSH Connection Manager UI + Codex CLI detection.
(Markdown round-trip already shipped early in M3-5.)
**Start date:** 2026-05-23
**Owner:** hoangperry
**Carries debt:** #11 IME smoke test + the 3-month-old GUI verification gap.

> ⚠️ Month-3 retro flagged the verification gap as the Month-4 must-fix.
> M4-0 addresses it before any new UI work.

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M1-11 | ⏳ | Vietnamese IME smoke test (20 phrases) | Owner manual test — debt from Month 1 |
| M4-0 | ✅ | GUI test harness (debt fix) | `HERMINAL_TEST_TEXT` env → `ghostty_surface_text` inject; `Scripts/run-test-harness.sh`; 4/4 runs PASS. **Verification gap closed** |
| M4-1 | ⏳ | Codex CLI detection verify | `AgentDetector` already matches "codex"; live-detect Codex spawned in a pane |
| M4-2 | ⏳ | SSH connection model + storage | `SSHHost` model + persisted list (SQLite or plist) |
| M4-3 | ⏳ | SSH Connection Manager UI | Sidebar list with add / edit / connect |
| M4-4 | ⏳ | SSH connect — spawn ssh in new tab | Open a host in a new tab via libghostty `command` |
| M4-5 | ⏳ | Month 4 retrospective | Re-check 7-month scope after the heaviest UI month |

## Month 5 plan (preview)

- M5-1: Compatibility matrix — vim, tmux, fzf, lazygit, btop, starship
- M5-2: Polish — animations, hover/focus states, accessibility pass
- M5-3: Developer-ID codesign + notarize pipeline
- M5-4: Month 5 retro

## Month 6 plan (preview)

- M6-1: Dogfood checklist + telemetry-free crash diary
- M6-2: 30 consecutive days, owner uses herminal as daily-driver
- M6-3: Month 6 retro

---

## Progress Log

### 2026-05-23 — Month 4 kickoff

**Context carried in:**
- Months 1-3 done; 19 + 7 = ~26 unit tests across the package; codebase clean
  (Month 1-3 review found 2 MEDIUM bugs, both fixed in commit `f5a82f0`).
- Verification gap is 3 months old — fixing it FIRST in M4-0 is non-negotiable.

**Plan:**
- M4-0 first (test harness). Then Codex live-detect (M4-1), SSH model (M4-2),
  SSH UI (M4-3), SSH connect (M4-4), retro (M4-5).

---

## Open Questions

- **Q4-001:** SSH host storage — SQLite (reuse NotesStore pattern) vs plist?
  SQLite gives indexing + future filtering; plist is simpler. To decide at M4-2.
