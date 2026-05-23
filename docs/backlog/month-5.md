# Month 5 Backlog — herminal Compatibility + Polish + Signing

**Sprint goal (PRD roadmap):** Compatibility matrix + polish (animations,
hover/focus, accessibility) + Developer-ID codesign + notarize pipeline.
**Start date:** 2026-05-24
**Owner:** hoangperry
**Carries debt:** #11 IME smoke test (4 months old), SSH UI polish,
agent status discrimination, agent↔pane mapping, node-wrapped agent
detection, recursive split trees, drag-to-resize dividers.

> ⚠️ Month-4 retro flagged signing/notarize as the historical time-sink
> for solo macOS projects. **Block out M5-3 deliberately** — don't
> sandwich between polish tasks.

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M1-11 | 🔄 | Vietnamese IME smoke test (20 phrases) | Swift bridge covered by 8 unit tests (`IMEBridgeTests`). Live Telex composition still owner-pending — checklist at `docs/QA/vietnamese-ime-checklist.md` |
| M5-1 | ✅ | Compatibility matrix — vim, tmux, fzf, lazygit, btop, starship | `Scripts/verify-compat-matrix.sh` — 9/9 PASS (also covers nano, less, htop). Proves each TUI initialises without crash inside libghostty's PTY |
| M5-2 | ✅ | Polish — animations, hover/focus states, accessibility | Sidebar slide-in (`NSAnimationContext` + animator proxy), hover state on tab chips + close X + add buttons + SSH rows, VoiceOver labels on all sidebars + chips + action buttons. 40/40 unit + 4/4 integration scripts still green |
| M5-3 | ✅ | Developer-ID codesign + notarize pipeline | `Scripts/sign-and-notarize.sh` (env-driven, falls back to ad-hoc), `App/herminal.entitlements` (hardened runtime + libghostty exceptions), `docs/RELEASE.md` setup + troubleshooting guide. Ad-hoc fallback verified end-to-end; Developer-ID path waits on the owner's paid Apple Developer cert |
| M5-4 | ✅ | Month 5 retrospective | `month-5-retrospective.md` — 5/7 months done, no scope downgrade. Carry to M6: IME live test + agent status + agent↔pane mapping + first notarized release |

## Month 6 plan (preview)

- M6-1: Dogfood checklist + telemetry-free crash diary
- M6-2: 30 consecutive days, owner uses herminal as daily-driver
- M6-3: Month 6 retro

## Month 7 plan (preview)

- M7-1: Beta release prep (Twitter/LinkedIn launch checklist, OSS hygiene)
- M7-2: Beta launch + feedback triage
- M7-3: Month 7 retro + roadmap re-plan for post-MVP

---

## Progress Log

### 2026-05-24 — Month 5 kickoff

**Context carried in:**
- Months 1-4 done; 32 unit tests + 4 integration scripts; codebase clean
  (verification gap closed in M4; smoke covers M1-M3 menu actions).
- Tooling already on the box: vim, tmux, nano, less, htop.
- Installed via brew for M5-1: fzf, lazygit, btop, starship.

**Plan:**
- M5-1 first. Then IME smoke (M1-11) + polish (M5-2) in parallel.
  Then signing + notarize (M5-3) as a focused block. Retro (M5-4) last.

### 2026-05-24 — M5-1 compatibility matrix: 9/9 PASS

`Scripts/verify-compat-matrix.sh` drives each app via M4-4's
`HERMINAL_TEST_SPAWN_COMMAND` hook, waits 5s, then asserts `p_comm`
matches via `ps -axo comm | grep -E "^-?<needle>$"`. Apps tested:
vim, tmux, nano, less, htop, fzf, lazygit, btop, starship.

All 9 launch and survive — no crash on terminal init, color
allocation, termios setup, mouse capture, or alt-screen entry. Visual
correctness (colors, scrolling, mouse) is NOT asserted here; that
needs screenshot diffing and is deferred to M5-2 polish or owner
dogfood (M6).

Two surprises caught during script development (worth recording so
M5-2 / M6 don't re-trip them):

- **libghostty wraps spawn in `exec -l <cmd>`.** The `-l` flag makes
  the child process a login session, so the kernel records `p_comm`
  with a **leading dash** — `pgrep -x vim` returns 0 matches; the
  real comm is `-vim`. Matcher uses `^-?<needle>$` to accept both.
- **Pipes don't work inside the exec wrapper.** `seq 1 200 | fzf`
  parses as `exec -l seq 1 200` piped to `fzf` — the exec replaces
  the wrapping bash with `seq` (argv[0]=`-seq`), so `fzf` actually
  runs but gets EOF as soon as `seq` finishes its 200 lines. Bare
  `fzf` reading from the PTY works fine.

Both are libghostty behaviours, not herminal bugs — but the SSH
manager's `connectSSH(_:)` builds shell commands with `&&`/`-p` flags
and those work because they stay inside a single `exec -l` argument.
If we ever add pipe-based features (e.g., "pipe shell history into
fzf"), we'll need to wrap them in `bash -c "<pipeline>"` ourselves.

### 2026-05-24 — M1-11 partial close + M5-2 polish pass

**M1-11**: closed the half that's automatable — 8 unit tests on the
`NSTextInputClient` Swift bridge cover the markedText / accumulator
state machine. Owner checklist for live Telex composition lives at
`docs/QA/vietnamese-ime-checklist.md` (20 phrases, defect taxonomy).
The 4-month-old debt is no longer pure debt: the regression-prone
parts (state machine ordering, accumulator vs PTY path) are CI-guarded.

**M5-2 polish pass — three focused additions:**

- **Sidebar slide-in animation.** Toggle handlers now call
  `animateSidebarChange()` which runs `layoutSubtreeIfNeeded()`
  inside an `NSAnimationContext` group with the animator proxy.
  The slide-down completion handler resets `isHidden` so panels
  vanish only after the slide finishes (not at the start).
- **Hover state across every interactive chrome surface** — tab
  chips brighten + close X gets a circle background, SSH rows get
  a teal-tinted border, `+` buttons in tab bar and SSH header
  swap to accent color. Each hover is row-local via per-row
  `@State` so siblings don't redraw.
- **VoiceOver labels** on all sidebars (`AGENTS`, `SSH HOSTS`,
  `NOTES` get `.isHeader` trait), action buttons (Connect, Cancel,
  Add, Close, New Tab), and rows (`accessibilityElement(.combine)`
  collapses each agent/host row into one VoiceOver utterance).
  Status dots inside agent rows are marked `.accessibilityHidden`
  so VoiceOver doesn't read "circle" before the agent name.

Regression check: M1-M3 smoke (7/7), M4-0 baseline, M4-1 codex
detection, M4-4 ssh spawn — all 4 verify scripts still PASS. Unit
suite 40/40.

The Sendable closure dance for `NSAnimationContext.completionHandler`
needed `MainActor.assumeIsolated` around the @MainActor mutations
inside — Swift 6 strict concurrency flagged the bare access, and
the wrap is the correct pattern for this kind of post-animation
cleanup that always runs on the main runloop.

### 2026-05-24 — M5-3 signing + notarize pipeline

Retro flagged this as the historical time-sink for solo macOS projects.
Owner doesn't have a paid Apple Developer cert yet, so the Developer-ID
path can't be exercised end-to-end — but the script + entitlements +
docs are all in place so cutting a notarized release becomes a
~10-minute owner task once the cert lands.

- `App/herminal.entitlements` — hardened runtime with four narrow
  exceptions libghostty needs (`allow-jit`,
  `allow-unsigned-executable-memory`, `allow-dyld-environment-variables`,
  `disable-library-validation`). Tightening these is on the M6+ list
  once we can profile which actually fire under load.
- `Scripts/sign-and-notarize.sh` — env-driven:
  `HERMINAL_SIGNING_IDENTITY` selects the keychain identity,
  `HERMINAL_NOTARY_PROFILE` selects the notarytool credentials
  profile. Falls back to ad-hoc + exits early when neither is set, so
  the same script works for local devs and the release pipeline. Parses
  notarytool JSON output and fails loudly when Apple reports
  "Invalid" — historically a quiet exit-0-but-rejected trap.
- `docs/RELEASE.md` — one-time cert + app-specific password setup,
  cutting-a-release commands, and a Troubleshooting section seeded
  with the three failure modes that bit the M4 spike: AMFI cdhash
  mismatch after rename, missing `--deep` on nested binaries, and
  hardened-runtime exception gaps.

Verified: ad-hoc fallback path runs end-to-end —
`.build/release/herminal.app` is signed (`Signature=adhoc`), launches,
stays alive. Developer-ID path is syntax-checked + the script structure
mirrors the exact `codesign + notarytool + stapler` flow used by real
notarized macOS apps. Owner ETA for first notarized release: end of M6
once the Developer ID enrolment completes.

---

## Open Questions

- **Q5-001:** Where do signing artefacts (the Developer ID cert + the
  notarytool keychain profile) live in CI? Local-only is fine for the
  alpha but post-launch needs an answer. To decide at M5-3.
- **Q5-002:** Should the polish pass introduce a light theme too, or
  stay dark-only for the v1.0 launch? PRD says Raycast/Linear style
  (both have a light theme). To decide at M5-2 kickoff.
