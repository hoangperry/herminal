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
| M5-2 | ⏳ | Polish — animations, hover/focus states, accessibility | Bento-aware design pass, VoiceOver labels |
| M5-3 | ⏳ | Developer-ID codesign + notarize pipeline | Block out a dedicated chunk — historically a weekend sink |
| M5-4 | ⏳ | Month 5 retrospective | 5 of 7 months marker |

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

---

## Open Questions

- **Q5-001:** Where do signing artefacts (the Developer ID cert + the
  notarytool keychain profile) live in CI? Local-only is fine for the
  alpha but post-launch needs an answer. To decide at M5-3.
- **Q5-002:** Should the polish pass introduce a light theme too, or
  stay dark-only for the v1.0 launch? PRD says Raycast/Linear style
  (both have a light theme). To decide at M5-2 kickoff.
