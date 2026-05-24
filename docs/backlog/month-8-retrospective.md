# Month 8 Retrospective — Post-MVP Slice 1 (Theme A: Agent Dashboard Depth)

**Period:** 2026-05-25 (single-session)
**Sprint goal:** Ship the first post-MVP slice from M7's roadmap —
Theme A (agent dashboard depth).
**Result:** ✅ Two of three Theme-A items ship (A1 node-wrapped
detection, A2 BEL → needs-input). The third (A3 agent↔pane mapping)
deferred with an explicit "needs its own focused session" note.

This is the first post-MVP slice — cadence is feedback-driven, not
calendar-driven, so "M8" is the slice number, not a calendar month.
Final pass on this retro waits until either A3 ships or beta feedback
redirects priorities.

---

## 1. What Got Done

| # | Task | Outcome |
|---|------|---------|
| M8/A1 | Node-wrapped agent detection (Q3-002) | argv-aware classifier closes a 5-month-old debt. `aider (Python)` / `claude (node)` display names attribute both agent identity AND host interpreter |
| M8/A2 | OSC 9 / BEL needs-input (Q6-001) | `BellRegistry` + `GhosttyApp.handleAction` wire libghostty's RING_BELL into agent status. Coarse "any-bell-promotes-all" mapping until A3 lands |
| M8/A3 | Agent↔pane mapping | Deferred — needs its own session to design the process-tree heuristic carefully (sort logins by start time, pair to sessions by creation order) |
| M8/0 | Harness pre-inject delay bump | Side fix discovered during regression; 8s no longer covers heavy `.zshrc` after M6+M8 added startup work; scripts bump to 12s |

**Stats this slice:**
- 9 new unit tests (48 → **57**: +5 node-wrapped + +4 BellRegistry)
- 1 new integration script (`verify-node-wrapped-detection.sh`); total 7
- 3 commits, `780ff1c` → `83db6fc`
- Zero crashes; dogfood-daily 5/5 PASS after the delay bump

---

## 2. What We Learned

### Two M6 debts closed in one session

Q3-002 (node-wrapped, 5 months old) and Q6-001 (OSC 9 / BEL, 1
slice old) both landed inside a single session despite living in
two different modules (HerminalAgent + HerminalCore). The unifying
shape: BOTH gaps existed because nobody had wired the kernel /
libghostty signal we needed, not because the signal was unavailable.
`sysctl(KERN_PROCARGS2)` and `GHOSTTY_ACTION_RING_BELL` were both
sitting there since Month 1 — the cost of NOT closing them was
"agent dashboard shows process names you don't recognise" and
"agent status doesn't reflect actual readiness for input."

Lesson: when a debt is shaped like "we need to read X but never
wired Y," the wire-in is usually shorter than the retrospective
makes it sound. M8/A1 was ~100 lines including tests; M8/A2 was
~80. Both took less than the M6 retro's hand-waving suggested.

### Coarse-but-honest > fine-but-misleading

A2's "any bell anywhere promotes ALL agents" UX is wrong in
attribution but right in spirit. The alternative — guess per-surface
attribution without the data — would have shipped a worse UX (some
agents wrongly flagged, some wrongly not). Coarse-but-honest is the
right default until A3 lands; the user still hears the bell from
macOS itself, so they can disambiguate by ear without us faking
visual precision.

This pattern echoes M6's `unknown → idle` first-sighting handling
in `AgentStatusTracker`. Honesty about what we DON'T know is a
feature, not a bug.

### The delay creep is real and will keep happening

M8 startup work (Diary signal handler init, BellRegistry singleton,
agent CPU sampling on every poll) added enough latency to push
shell-prompt past the 8s harness window. M5 already had a similar
moment when polish + a11y wiring slowed first-paint. Every slice
ADDS something at launch; the harness delay needs to be tuned
alongside, or the test suite becomes a load detector instead of a
correctness check.

Action item: post-MVP slice 2 (whenever it ships) should treat
`HERMINAL_TEST_DELAY` as a budget — if startup work would push past
12s, that's a sign to defer or lazy-load the work.

### Theme A is now 2/3 done — the remaining piece is the hardest

A3 (agent↔pane mapping) is genuinely the most complex of the Theme A
trio. It needs:

- A way to associate herminal's spawned login children with the
  `TerminalSession` that triggered their spawn.
- A heuristic when libghostty doesn't expose per-surface PIDs:
  sort logins by kernel start time, sort sessions by creation
  time, pair by order. Brittle under tab close + reopen.
- Or wait for an upstream libghostty change exposing
  `ghostty_surface_pid()`.

Doing it badly is worse than not doing it (false attribution is
worse than no attribution per § 2.2 above). Deferring to a focused
session is the right call.

---

## 3. Estimate vs Actual

- Estimated: 1 session for A1 + A2; A3 deferred up-front.
- Actual: matched. The delay-bump side fix added ~10 minutes that
  weren't in the plan but were the right thing to fix in the slice
  that surfaced it.

---

## 4. Carry Into Slice 2

| Item | Origin | Why pending |
|------|--------|-------------|
| Agent↔pane mapping (A3) | M7 roadmap Theme A | Needs a focused session for the heuristic + UX call |
| All other M7 post-MVP themes (B-G) | M7 roadmap | Feedback-driven — wait for beta input to prioritise |
| Q8-001: BellRegistry decay window | This slice | Decide when a second consumer appears |
| Q8-002: needs-input badge color | This slice | Owner UX call after dogfood reaction |
| Owner-pending: M6-2 dogfood days 2-30 | M6 carry | Calendar time, not code |
| Owner-pending: M7-2 social launch | M7 carry | Owner posts when ready |

---

## 5. Honest Self-Assessment

**Good:** Two real M-numbered debts closed in one session, both with
integration coverage that exercises the actual signal source
(`sysctl(KERN_PROCARGS2)` for A1, `GHOSTTY_ACTION_RING_BELL`
dispatch for A2). The display-name change for A1 (`aider (Python)`)
and the coarse-but-honest UX for A2 (`any-bell-promotes-all`) both
demonstrate a pattern of being honest about uncertainty rather than
shipping false precision. dogfood-daily still 5/5 PASS after the
slice landed; CHANGELOG didn't need a hot-fix entry.

**Could be better:** A3 deferred without a date. Honest about the
defer reason but worth flagging that the agent dashboard "Theme A"
batch is 2/3 — the remaining 1/3 is the one that, when done well,
makes the dashboard say "Claude in Tab 2" instead of just "Claude
running somewhere." For dogfood + beta-feedback purposes, "somewhere"
is sufficient; for the v1.0 narrative, "Tab 2" is the difference.

**Risk for slice 2:** the delay-creep observation. If slice 2 adds
more startup work, the harness budget may need another bump. Need
to be honest with each slice about whether the work belongs at
launch or deferred to first-use, because once dogfood-daily becomes
unreliable the entire verification loop suffers.
