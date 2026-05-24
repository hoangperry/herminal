# Month 6 Retrospective — herminal Dogfood Infrastructure

**Period:** 2026-05-25 (single-session for M6-1 + M6 pre-emptive +
retro skeleton; M6-2 is the owner's 30-day run logged separately)
**Sprint goal (PRD roadmap):** Dogfood — 30 days daily-driver +
crash diary + minimal-fix discipline.
**Result:** ✅ **Infrastructure** goal met (M6-1 + pre-emptive done).
**M6-2** is owner-pending by design — the AI cannot substitute for 30
days of human terminal use. This retro covers what shipped; the
post-M6-2 amendment lands when the owner finishes day 30.

---

## 1. What Got Done

| # | Task | Outcome |
|---|------|---------|
| M6-1a | Crash diary | `Diary` singleton, 200-entry ring buffer, 30s flush, signal handler (SIGSEGV/BUS/ABRT/ILL/FPE) writing via async-signal-safe `write(2)` |
| M6-1b | Dogfood docs + daily-runner | `dogfood-checklist.md` (recognition list, "when NOT to fix" rule), `dogfood-journal-template.md` (daily-driver journal), `Scripts/dogfood-daily.sh` (5/5 PASS) |
| M6-pre | Agent status discrimination | `AgentStatusTracker` — CPU-delta heuristic via `proc_pid_rusage`. Dashboard finally shows `running` / `idle` / `starting` truthfully instead of always-running |
| M6-2 | 30-day daily-driver | **Owner-pending** — infrastructure ready, 30 days starts at owner's discretion |
| M6-3 | This retro | Bootstrapped now; final pass after M6-2 completes |

**Stats this session:**
- 4 new unit tests (44 → **48**), all green.
- 1 new utility script (`Scripts/dogfood-daily.sh`); script count now 6.
- 3 commits, `c35f41d` → `3aa4184`.
- Zero crashes; dogfood-daily 5/5 green.

---

## 2. What We Learned (Lessons & Bugs)

### The mach-time-base bug — second macOS kernel-API gotcha this project

Working on agent status discrimination surfaced a latent bug that
would have bitten **anything else** in herminal sampling CPU through
`proc_pid_rusage`:

**`ri_user_time` and `ri_system_time` are mach absolute time units, not
nanoseconds.** Apple's API docs scatter both claims; the actual source
of truth is the xnu kernel, where these fields come from
`thread->user_time` / `thread->system_time`, which are mach-clock
counters. On Apple Silicon the timebase is 125/3, so 1 mach unit =
41.67 ns. Treating the field as nanoseconds under-reports CPU by ~42×.

Empirical confirmation: a 100%-CPU `yes` process reported 12 ms over
500 ms wall (= 2.4% CPU) before the fix; 494 ms after (= 99% CPU).
The first test pass without the fix marked the busy process as `.idle`,
which is when the bug became visible.

This is the second `proc_*` gotcha for this project. The first was
M4-1's `proc_listchildpids` returning garbage on macOS Sequoia (forced
the switch to `sysctl(KERN_PROC_ALL)`). If a third hits, it's worth
extracting a `docs/PATTERNS.md` of macOS-kernel-API surprises.

### Dogfood-daily flakiness was sequencing, not the harness

First end-to-end run of `Scripts/dogfood-daily.sh` failed M4-0 baseline
even though the M4-0 harness works fine in isolation. Cause: the
previous check's async `pkill -9` could still hold the killed app's
Metal layer + PTY fds when the next check launched, so the next
HerminalApp's surface init raced and `injectText` silently no-op'd
because `surface` was nil.

Fix: add `pkill -9 -x HerminalApp; sleep 2` between every check in
dogfood-daily. The sleep was the smallest change that made the
sequence stable. We could chase a more deterministic signal
(`pgrep -x` poll, kqueue exit watcher) but for a daily-driver utility
the 2-second cost per check is negligible.

### Diary made a deliberate "no telemetry" promise

The PRD M6 line is "telemetry-free crash diary". `Diary` is local-only
by construction — every write goes to a file in Application Support
plus the existing `NSLog` stream (which Console.app already aggregates
locally). No network, no opt-in upload, no UUIDs that could be a
fingerprint. The signal handler exists ONLY because the dogfood owner
needs to know what killed the app between launches.

If we ever add opt-in upload in M7+ (e.g. for friends/beta testers
who hit a crash), the network code lives behind an explicit toggle and
goes through `Diary.export()` rather than touching the file path.

### Agent status discrimination shipped the M3 differentiator at last

"Agent dashboard" has been pitched since the PRD as herminal's
differentiator — "see what your agents are doing at a glance." For
three months it was just a process list with everything labeled
"running" because the bar for shipping the M3 alpha was process
detection, not activity inference. M6 pre-emptive finally backfills
the inference; the dashboard now genuinely distinguishes a Claude
session waiting for input from one mid-thought.

Two caveats this retro should be honest about:
- The 5% threshold is a guess. M6-2 dogfood is the right time to tune
  it — if the badge flips too aggressively (or sticks too long) the
  owner journal entries will say so.
- "Idle" still doesn't differentiate "waiting for user input" from
  "task done". OSC 9 / BEL escape sniffing (Q6-001) would close that
  gap; deferring until dogfood says it matters.

---

## 3. Estimate vs Actual

- **PRD Month-6 plan:** dogfood checklist + crash diary + 30 days.
- **Infrastructure side:** crash diary + dogfood docs + daily-runner +
  agent status fix landed in one session. Estimated 1-2 days; actual
  ~3 hours because patterns from M4-M5 (env-var test hooks, single-
  isolation `final class` stores, NSAnimationContext muscle memory)
  carried straight in.
- **30-day side:** by definition takes 30 days. No estimate to overshoot.

---

## 4. Debt Carried Into Month 7 (open at end of M6 infrastructure pass)

| Item | Why pending |
|------|-------------|
| #11 Vietnamese IME live owner test | Manual run of the 20-phrase checklist; M6-2 dogfood is the natural window |
| Agent↔pane mapping | libghostty exposes no per-surface PID — would need PTY scraping or a libghostty upstream change |
| Node-wrapped agent detection (Q3-002) | Short-name heuristic misses `node`-hosted CLIs |
| Recursive split trees (Q2-003) | Deferred since Month 2 |
| Drag-to-resize dividers (Q2-002) | Deferred since Month 2 |
| First notarized release | Owner-pending: paid Developer ID enrolment |
| Light theme decision (Q5-002) | Defer until dogfood says yes/no |
| Diary daily rotation (Q6-002) | Defer until M6-2 finishes — usage shape will dictate |
| OSC 9 / BEL agent status (Q6-001) | Defer until M6-2 hits the case |

The dogfood-discipline rule (M5 retro) explicitly says: dogfood is
about *experiencing*, not *fixing*. Items above stay on the list until
the owner journal says they're blocking. M6-2 amendment to this retro
will list which ones actually got promoted.

---

## 5. Roadmap Adjustment for Month 7

- **Month 7 (per PRD):** beta release prep + launch + post-MVP roadmap.
- **Pre-M7 gate:** at least 20 of 30 M6-2 journal entries must
  conclude "Would I use it again tomorrow without forcing myself? **Y**".
  If fewer than 20, M7 launch slips — friction is too high, take a week
  to fix the P0s the journal flagged before promoting to beta.
- **M7 should add:**
  - A real-world bug-report flow (issue template referencing the diary
    excerpt + dogfood journal day).
  - The first notarized release once the Developer ID lands.
  - A short "what's herminal" landing page (or section in README) for
    Twitter/LinkedIn traffic.

### Scope re-check (PRD burnout mitigation #4)

- 7-month Option A: M1 ✅, M2 ✅, M3 ✅, M4 ✅, M5 ✅, M6 ✅
  (infrastructure side) — **on track, 6 of 7 months done.**
- The asterisk on M6 is "30 days happens in real time", not "we missed
  the scope." The fix for that asterisk is the calendar, not the code.
- **No downgrade to Option B/C needed.**

---

## 6. Honest Self-Assessment

**Good:** Infrastructure for the dogfood month is in place: a crash
diary that captures everything the owner needs to debug between
launches, a daily-runner that compresses all 5 integration scripts
into one PASS/FAIL command, a journal template that makes "what
happened today" a 5-minute write instead of a 30-minute writeup. The
agent status discrimination work paid down the most-flagged debt
across three retros and surfaced a real CPU-math bug that would have
affected anything else we measured.

**Could be better:** This retro is structurally incomplete — M6-2 is
the BIG part of the month, and it can't be done in a session. The
shape of this doc says "infrastructure done" but a true Month 6 retro
needs the 30 days of journal entries folded in. Easier to be honest
about that than to fake a single-session retrospective covering
behaviour that hasn't happened yet.

**Risk for Month 7:** if the M6-2 pre-M7 gate (20/30 days = Y) isn't
met, the temptation will be to launch anyway because beta is exciting.
Treating beta as launchable only when daily-driver friction is below
a real bar is the difference between alpha-disguised-as-beta and a
beta someone outside the project would actually use. The discipline
warning from M5 retro carries forward.
