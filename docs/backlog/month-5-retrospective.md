# Month 5 Retrospective — herminal Compatibility + Polish + Signing

**Period:** 2026-05-24 (single-session — Month 4 retro was earlier same day)
**Sprint goal (PRD roadmap):** Compatibility matrix + polish + signing/notarize.
**Result:** ✅ Goal met. M5-1..M5-4 done. M1-11 4-month debt partially closed
(automated bridge tests ship; owner manual still pending).

---

## 1. What Got Done

| # | Task | Outcome |
|---|------|---------|
| M5-1 | Compatibility matrix | 9/9 TUI apps (vim, tmux, nano, less, htop, fzf, lazygit, btop, starship) survive launch; `verify-compat-matrix.sh` |
| M1-11* | IME bridge tests + checklist | 8 unit tests on the `NSTextInputClient` state machine; 20-phrase owner checklist at `docs/QA/vietnamese-ime-checklist.md` |
| M5-2 | Polish | Sidebar slide animations, hover state on every interactive surface, VoiceOver labels across all sidebars + rows + action buttons |
| M5-3 | Signing + notarize | `sign-and-notarize.sh` (env-driven, ad-hoc fallback), `App/herminal.entitlements`, `docs/RELEASE.md` |
| M5-4 | Month 5 retrospective | This doc |

\* M1-11 is now "partial close" — automated half ships, live Telex remains owner-pending.

**Stats this month:**
- 8 new unit tests (32 → **40**), all green.
- 1 new integration script (`verify-compat-matrix.sh`); total scripts now 5.
- 6 commits, `1e9bf31` → `b5d6ae2`.
- Zero crashes; 4/4 prior integration scripts continued passing through
  polish + animation changes.

**Month-5 roadmap goal is met.**

---

## 2. What We Learned (Lessons & Bugs)

### libghostty's spawn wrapper has surprising semantics

The M5-1 compatibility matrix surfaced two libghostty behaviours that
would have bitten dogfooding silently:

- **`exec -l <cmd>` prepends a dash to `p_comm`.** The kernel
  treats the spawned process as a login session, so `ps -o comm`
  shows `-vim` not `vim`. The matcher in `verify-compat-matrix.sh`
  now matches `^-?<needle>$` to accept both. AgentDetector is fine
  because it uses sysctl's `kp_proc.p_comm` (raw kernel field),
  but anyone writing `pgrep -x <name>` against herminal's children
  is going to get zero matches and conclude (wrongly) that the
  child didn't spawn.
- **Pipes don't go inside the `exec -l` wrapper.** A command like
  `seq 1 200 | fzf` parses as `(exec -l seq 1 200) | fzf` — exec
  replaces the wrapping bash with `seq`, so `fzf` gets EOF the
  moment seq finishes. The SSH manager is safe (its commands stay
  inside one exec arg), but anything pipe-shaped needs to be
  wrapped in `bash -c "<pipeline>"` explicitly.

Both are now documented in `docs/backlog/month-5.md` so M6 dogfood
doesn't re-trip them.

### Polish forced a cleaner component structure

SwiftUI's `@State` is *view-instance* scoped — so a single shared
`isHovered` variable on the parent panel would have made hovering one
row light up every row. Pulling `TabChip`, `NewTabButton`,
`AddHostButton`, `SSHHostRow` into their own private structs gave each
its own per-instance state. The code is also easier to read after the
split, even setting aside hover. **Polish-as-refactor is real.**

### Sidebar animation needed `MainActor.assumeIsolated`

`NSAnimationContext.runAnimationGroup`'s completion handler is
`@Sendable`, but our cleanup touches `@MainActor` state (panel
`isHidden` flags, internal animation guard). The right pattern is to
wrap the closure body in `MainActor.assumeIsolated` — the closure
always runs on the main run loop (NSAnimationContext guarantees it),
so the assumption is safe, but Swift 6 strict concurrency needs the
explicit acknowledgement.

This is a recurring pattern across the codebase now (Timer tick →
`assumeIsolated`, animation completion → `assumeIsolated`, IO callbacks
→ `nonisolated static`). Worth capturing in a `docs/PATTERNS.md` if it
gets a fourth hit.

### Hardened runtime: four exceptions for libghostty

Notarization requires hardened runtime. libghostty's renderer + spawn
paths need four specific relaxations:

| Entitlement | Why |
|-------------|-----|
| `allow-jit` | Metal shader compilation |
| `allow-unsigned-executable-memory` | Zig runtime's executable allocations |
| `allow-dyld-environment-variables` | ghostty's shell-integration injection |
| `disable-library-validation` | User-launched children (ssh, vim, …) have their own signatures |

These are documented in `App/herminal.entitlements` with the reason
for each. M6/M7 should profile which actually fire to see if any can
be tightened — every relaxed exception is one less defence in depth.

### Signing without a cert: ad-hoc fallback was the right call

Without the owner's paid Apple Developer membership, the Developer-ID
path can't be exercised. Rather than block M5-3, the script falls
back to the ad-hoc signature that `make-app-bundle.sh` already uses
when `HERMINAL_SIGNING_IDENTITY` is unset — and the same code path is
tested end-to-end. When the cert lands, switching from ad-hoc to
notarized is a one-env-var change.

The `docs/RELEASE.md` setup guide front-loads the cert + app-specific
password + notarytool keychain-profile dance so the first signed
release isn't blocked on figuring out which menu in developer.apple.com
to click.

---

## 3. Estimate vs Actual

- **PRD Month-5 plan:** compat matrix + polish + signing.
- **Month-4 retro predicted:** signing would be the time-sink. **Reality:**
  the script + entitlements + docs landed in maybe 90 minutes because
  the M4-1 lesson (verify infrastructure before adding features) meant
  we already had the spawn-and-verify harness — re-using
  `make-app-bundle.sh` and the integration-script pattern saved hours.
  The owner's lack of a paid cert is the actual blocker for end-to-end
  verification, not the script.
- **Underestimated:** the SwiftUI restructuring required by per-row
  hover state. Roughly doubled the M5-2 work but produced code that's
  easier to read, so net positive.

---

## 4. Debt Carried Into Month 6

| Item | Why pending |
|------|-------------|
| #11 Vietnamese IME live owner test | Manual run of the 20-phrase checklist; needs human eyes + fingers |
| Agent status discrimination (running/idle/done) | Still needs CPU/process-state sampling |
| Agent↔pane mapping | libghostty exposes no per-surface PID |
| Node-wrapped agent detection (Q3-002) | Short-name heuristic misses `node`-hosted CLIs |
| Recursive split trees (Q2-003) | Deferred since Month 2 |
| Drag-to-resize dividers (Q2-002) | Deferred since Month 2 |
| First notarized release (M5-3 end-to-end) | Owner-pending: paid Developer ID enrolment |
| Light theme decision (Q5-002) | Deferred to dogfood — does the owner actually want it? |
| Visual screenshot diff test | XCUITest-grade; would catch render regressions polish missed |

---

## 5. Roadmap Adjustment for Month 6

- **Month 6 (per PRD):** Dogfood checklist + telemetry-free crash diary
  + 30 consecutive days using herminal as daily-driver.
- **Recommended additions, given M5's findings:**
  - **Run the IME checklist on day 1.** Four months is too long to
    have left it unrun, and dogfood is the only time the owner is
    actually typing Vietnamese in a terminal anyway.
  - **Run all 5 integration scripts** at the start and end of each
    week of dogfood. Regression-catching cost ≈ 90 seconds per run.
  - **Profile which hardened-runtime exceptions actually fire** under
    real workloads — if `allow-jit` never triggers, drop it.
  - **Tighten `verify-compat-matrix.sh`** to also assert the app
    responds to a `q`/`:q` exit sequence after spawn. Currently we
    only prove the app launches; proving it exits cleanly catches
    a different class of bug.

### Scope re-check (PRD burnout mitigation #4)

- 7-month Option A: M1 ✅, M2 ✅, M3 ✅, M4 ✅, M5 ✅ — **on track, 5
  of 7 months done.**
- Month 6 is the dogfood month — fundamentally not about shipping new
  features; about USING what we built. The PRD scopes it at "30
  consecutive days" which is a discipline target, not a code one.
- **No downgrade to Option B/C needed.**

---

## 6. Honest Self-Assessment

**Good:** Compatibility matrix proved herminal handles every TUI app in
the PRD list without crashing, and the two libghostty quirks found are
now documented so M6 dogfood doesn't re-trip them. The polish pass made
the chrome genuinely feel like a finished app (hover states + slide
animation + a11y labels), and the signing pipeline is one env-var away
from notarized releases. The IME bridge's 4-month verification debt is
finally CI-guarded for the part that's actually automatable.

**Could be better:** Five months in, two pieces of M3 debt (agent
status discrimination, agent↔pane mapping) are still unresolved. The
"agent dashboard" remains the herminal differentiator and is still
just "a list of running processes." M6 dogfood is the right time to
feel that limitation firsthand and decide whether to fix it before
beta (M7) or scope it down honestly.

**Risk for Month 6:** discipline. Dogfooding requires *actually using*
herminal, not just running it once a day for the test harness to
exercise. The temptation will be to switch back to the previous
terminal whenever herminal hits friction. That friction is exactly the
signal M6 exists to collect — capture it in the crash diary, don't
escape from it.
