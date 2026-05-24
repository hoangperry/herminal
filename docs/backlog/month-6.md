# Month 6 Backlog — herminal Dogfood

**Sprint goal (PRD roadmap):** Dogfood — owner uses herminal as
daily-driver for 30 consecutive days, captures friction in a
telemetry-free crash diary, fixes only what blocks normal use.
**Start date:** 2026-05-25
**Owner:** hoangperry
**Carries debt:** #11 IME live owner test, agent↔pane mapping,
node-wrapped agent detection (Q3-002), recursive split trees (Q2-003),
drag-to-resize dividers (Q2-002), first notarized release, light-theme
decision (Q5-002).

> ⚠️ The M5 retro flagged **discipline** as the M6 risk. Dogfood is
> about experiencing what's built, not shipping features. The "When
> NOT to fix" section of `docs/QA/dogfood-checklist.md` is the rule.

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M6-1a | ✅ | Crash diary + log capture | `Diary` singleton; ring buffer + signal handler; writes `~/Library/Application Support/herminal/diary.log` |
| M6-1b | ✅ | Dogfood checklist + journal template + daily-runner | `docs/QA/dogfood-checklist.md`, `docs/QA/dogfood-journal-template.md`, `Scripts/dogfood-daily.sh` (5/5 PASS) |
| M6-pre | ✅ | Agent status discrimination (M3 carry) | `AgentStatusTracker` — CPU-delta heuristic. Dashboard now shows running/idle/starting instead of always-running. **Critical bug fix discovered along the way: `proc_pid_rusage` reports mach absolute time units, NOT nanoseconds — was under-reporting by 42×** |
| M6-2 | 🔄 | 30-day daily-driver run | **Owner manual.** Day 1 baseline filed by agent at `docs/QA/dogfood/day-01-2026-05-25.md` (5/5 dogfood-daily PASS, no leak in 60s extended run, no crashes, one P2 sequencing flake noted). **Days 2-30 are owner-driven.** Pre-M7 gate: ≥20/30 days = "Y" to "would I use it tomorrow?" |
| M6-3 | 🔄 | Month 6 retrospective | This file (template ready; final pass after M6-2 completes) |

## Month 7 plan (preview)

- M7-1: Beta release prep (Twitter/LinkedIn launch checklist, OSS hygiene)
- M7-2: Beta launch + feedback triage
- M7-3: Month 7 retro + roadmap re-plan for post-MVP

---

## Progress Log

### 2026-05-25 — Month 6 kickoff + infrastructure

**Context carried in:**
- Months 1-5 done. 48 unit tests + 5 integration scripts + 1 sign
  pipeline + 1 dogfood runner. Verification gap closed since M4.
- The 3 most-flagged debts across previous retros (verification gap,
  agent status discrimination, IME bridge coverage) are now all
  partially or fully addressed.

**Plan:**
- M6-1 infrastructure first (diary + dogfood docs + daily-runner) so
  the owner can start M6-2 on day 1 without setup overhead.
- One pre-emptive fix on the carry list: agent status discrimination.
  Picked because it's been deferred from M3 across 3 retros and is the
  feature that makes the dashboard differentiating instead of just a
  process list. Keeping the dogfood honest needs the badge to say
  something true.
- M6-2 is owner-only — the AI can't substitute for actually USING
  herminal for 30 days. Infrastructure is ready; the daily journal
  goes into `docs/QA/dogfood/day-NN-YYYY-MM-DD.md`.
- M6-3 retro is bootstrapped (template ready); final pass happens
  after M6-2 completes.

### 2026-05-25 — Mach time-base bug (discovered during M6 pre-emptive)

The agent status work surfaced a latent bug that would have bitten
ANY future CPU-sampling code we write:

`proc_pid_rusage` returns `ri_user_time` and `ri_system_time` in
**mach absolute time units**, not nanoseconds. Apple's docs and most
search results call them nanoseconds, but the actual values come
from `thread->user_time` / `thread->system_time` in xnu, which are
mach-clock counters. On Apple Silicon, `mach_timebase_info` reports
125/3 ≈ 41.67 ns per unit; on Intel Macs it's 1/1.

Empirical confirmation: a 100%-CPU `yes > /dev/null` burning for
500 ms wall reported only 12 ms of CPU through `ri_user_time` if
treated as nanoseconds. After converting via the cached timebase
ratio: 494 ms. **42× under-reporting** — every agent would have
appeared idle.

Fix: cache `mach_timebase_info()` once at the AgentDetector static
init, multiply each sample by `numer / denom`. Documented inline so
the next person to touch CPU sampling doesn't relearn it.

This is the SECOND macOS kernel-API gotcha M4-1/M6 has exposed (after
`proc_listchildpids` returning garbage). Capturing in
`docs/PATTERNS.md` if/when a third one lands.

---

## Open Questions

- **Q6-001:** Should agent status fold libghostty's BEL/OSC 9 escape
  sequences into the heuristic? Some agents (Claude Code) emit BEL on
  "needs input" — that would let the dashboard say `needs input`
  instead of just `idle`. Investigate during M6-2 if it comes up.
- **Q6-002:** Diary file rotation — 1 MB cap is fine for 30 days,
  but a daily-driver might want timestamped rotation (e.g.
  `diary-YYYY-MM-DD.log`) so grepping per-day is easier. Defer to
  end of M6-2 when we have a usage shape.
- **Q5-002 (carry):** Light theme — keep deferring until owner
  dogfood says one way or the other.
