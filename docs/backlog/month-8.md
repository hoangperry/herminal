# Month 8 — Post-MVP Slice 1 (Theme A: Agent Dashboard Depth)

**Sprint goal:** Ship the first post-MVP slice from `docs/backlog/
month-7.md` § Post-MVP roadmap, Theme A. Two of three Theme-A items
land this slice; the third (agent↔pane mapping) is deliberately
deferred to a focused future session.

**Start date:** 2026-05-25
**Owner:** hoangperry
**Cadence note:** Post-MVP is feedback-driven, not calendar-driven.
"M8" is the slice number, not a calendar month.

> 📌 The M7 retro framed Theme A as the most-pitched differentiator
> and the area "most exposed to alpha criticism." This slice closes
> two of the three known gaps (node-wrapped detection + bell-driven
> needs-input). Per-surface attribution waits.

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M8/A1 | ✅ | Node-wrapped agent detection (Q3-002) | argv via `sysctl(KERN_PROCARGS2)`; `AgentKind.detect(interpreterArgv:)` handles `npx @anthropic-ai/claude-code`, `python3 -m aider`, etc. Display name shows `aider (Python)` for transparency. Verified by `Scripts/verify-node-wrapped-detection.sh` |
| M8/A2 | ✅ | OSC 9 / BEL needs-input (Q6-001) | `BellRegistry` (HerminalCore singleton) + `GhosttyApp.handleAction` dispatches `GHOSTTY_ACTION_RING_BELL`. `WorkspaceView.refreshAgents` promotes running/idle → `.needsInput` when any surface bell rang in the last 10s |
| M8/A3 | ⏳ | Agent↔pane mapping (best-effort) | **Deferred.** Needs a process-tree heuristic (sort logins by start time, pair to sessions by creation order). Worth its own focused session; current "any bell promotes all agents" UX is honest about the missing attribution |
| M8/0 | ✅ | Harness pre-inject delay bump (8s → 12s) | Side fix while running M8 regressions. M6+M8 added enough startup work (Diary signal handler, BellRegistry, agent CPU sampling) that 8s no longer covered heavy `.zshrc` setups. 12s in scripts; AppDelegate default stays 8s for interactive use |
| M8/retro | 🔄 | M8 retrospective + post-MVP cadence reflection | This file (final pass when A3 ships or beta feedback redirects priorities) |

---

## Open Questions

- **Q8-001:** Should `BellRegistry` decay records older than N minutes
  so the `hasRecentBell` window doesn't need to be tuned by the
  caller? Currently the window is per-call (default 10s) — fine for
  one consumer, awkward if multiple consumers want different windows.
  Decide when the SECOND consumer arrives.
- **Q8-002:** Should the dashboard show "needs input" as a special
  badge color (separate from running blue / idle grey) or just text?
  Current implementation: status text shows `needs input`, dot color
  reuses the running blue. Owner UX call after dogfood reaction.
- **Q5-002 (carry):** Light theme — still deferred.
- **Q6-002 (carry):** Diary daily rotation — still deferred.

---

## Progress Log

### 2026-05-25 — M8 slice 1 kicks off

**Why now:** M7 retro said the next themed batch ships "in response to
beta input" but also called out Theme A as the most pitched
differentiator. Two A items (A1 + A2) are tractable in one session
WITHOUT beta feedback because they close known gaps (Q3-002 5-month
debt; Q6-001 fresh from M6 retro). A3 is genuinely better-served by
real beta data telling us which heuristic mistakes hurt most.

**Plan:**
- Ship A1 + A2 in two commits.
- Skip A3 with an honest open-question comment in the dashboard so
  the missing attribution is visible to the user, not invisible debt.
- Bump test-harness delay along the way once it surfaces during
  regression checking — solve the problem in the slice that caused
  it, not in a follow-up.

### 2026-05-25 — M8/A1 ship + Q3-002 close

Q3-002 (deferred since M3): agents installed via npx wrappers
(`npx @anthropic-ai/claude-code`) or python scripts (`aider`) get
`p_comm=node` or `p_comm=Python`, basename-only matching missed them
entirely. Now:

- `AgentDetector.scan` checks `AgentKind.isInterpreter(name:)` after
  the direct-name match fails. If yes, reads argv via
  `sysctl(KERN_PROCARGS2)` and calls `AgentKind.detect(interpreterArgv:)`.
- `detect(interpreterArgv:)` is two-tier: substring match against the
  joined argv catches npm package names (`@anthropic-ai/claude-code`,
  `@openai/codex`, `aider-chat`); basename match on each argv element
  catches global installs (`.bin/claude`, `/tmp/aider`).
- Display name becomes `aider (Python)` / `claude (node)` so the
  dashboard signals BOTH the agent identity and the host interpreter.
  Useful when triaging "is this slow because of the agent or because
  Python startup is slow."

`Scripts/verify-node-wrapped-detection.sh` PASS first run. M4-1's
existing direct-match codex detection still PASSes (no regression
on the simple path).

### 2026-05-25 — M8/A2 ship + Q6-001 close

libghostty fires `GHOSTTY_ACTION_RING_BELL` for every terminal BEL
(\\a) plus visual-bell events. The action_cb was a returning-false
no-op since Month 1 because we had no consumer. M6's agent status
shipped with the badge stuck at `running` / `idle` / `starting` even
when an agent was clearly waiting for input.

- `BellRegistry` (HerminalCore singleton) — thread-safe via NSLock
  (libghostty fires from renderer / IO threads; reads happen on the
  main actor at agent-poll time). Tracks total bell count for tests
  and per-surface last-ring date. `hasRecentBell(within:)` defaults
  to a 10s window so the badge sticks long enough for a human to
  glance at the dashboard.
- `GhosttyApp.handleAction` dispatches RING_BELL with the surface
  address as the registry key. `nonisolated` because the C callback
  runs from libghostty's own threads — Swift 6 strict concurrency
  would otherwise trap.
- `WorkspaceView.refreshAgents` polls the registry on every 2s
  agent-poll tick. If any surface in any tab rang its bell within
  the trailing 10s, every running/idle agent gets promoted to
  `.needsInput`. The starting / unknown / done states pass through
  untouched.

**The any-bell-promotes-all** model is deliberately coarse — per-
surface→specific-agent attribution is M8/A3 (agent↔pane mapping).
Better to over-flag than fake precision. The needs-input badge is a
"someone wants you" prompt; the user can still see which pane is
making noise via macOS's standard bell visual.

### 2026-05-25 — M8/0 harness delay bump (side fix)

While running M8 regressions: dogfood-daily M4-0 baseline started
flaking. Standalone baseline went from 3/3 PASS (M6) to 1/3 PASS
(M8). With `HERMINAL_TEST_DELAY=12`: 3/3 PASS again.

Root cause: M6+M8 added enough launch-time work (Diary signal
handlers install, BellRegistry singleton init, AgentStatusTracker
allocation, surfaceAddresses iteration in the agent poll) that
8s is no longer enough cover for heavy `.zshrc` setups (oh-my-zsh +
pyenv + nvm + plugin chain). Shell-prompt-ready slipped past T+8s
on the dev machine.

Fix: scripts bump `HERMINAL_TEST_DELAY=12` and the per-iteration
sleep windows go 18s → 22s. AppDelegate default stays 8s for
interactive use (HERMINAL_TEST_DELAY is rarely exported there).
Documented inline so the next time-budget tweak finds the comment.

---

**End of M8 slice 1.** Next ship targets either A3 (if it stays
relevant after first beta) or a different theme entirely if beta
feedback redirects priorities.
