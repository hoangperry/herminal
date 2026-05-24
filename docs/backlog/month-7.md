# Month 7 Backlog — herminal Beta Launch + Post-MVP Roadmap

**Sprint goal (PRD roadmap):** Beta release prep + launch + post-MVP roadmap.
**Start date:** 2026-05-25
**Owner:** hoangperry
**Carries debt:** the M6-2 owner dogfood (in flight — day 1 baseline
done; days 2-30 ongoing), plus the post-MVP defer list from M6-3.

> ⚠️ Pre-M7-2 gate (M6 retro): **≥20/30 M6-2 dogfood days = "Y"** to
> "would I use it again tomorrow?" If gate fails, slip M7-2; fix the
> P0/P1 friction the journal flagged before announcing.

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M7-1a | ✅ | OSS hygiene | `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, GitHub issue + PR templates (bug template prompts for diary excerpt + dogfood day) |
| M7-1b | ✅ | CI — GitHub Actions | Two-lane workflow (core-libs fast, full-build slow); caches SPM + libghostty xcframework |
| M7-1c | ✅ | Release tooling | `CHANGELOG.md` (Keep-a-Changelog 1.1), `Scripts/release.sh` (version-gated, dogfood-daily-gated, signed, prints `gh release create` line) |
| M7-1d | ✅ | README v0.1.0 + launch copy | README reflects shipped state with badges + tour; `docs/launch/` has press kit + Twitter thread + LinkedIn post (drafts) |
| M7-2 | 🔄 | Beta launch | Tag `v0.1.0` cut + pushed; draft pre-release on GitHub with ad-hoc-signed `herminal-v0.1.0.zip` (5.7 MB) + CHANGELOG notes. **Owner finishes:** (1) review + publish the draft, (2) post `docs/launch/twitter-thread.md`, (3) post `docs/launch/linkedin-post.md`, (4) re-cut as v0.1.1 once Developer-ID lands so users skip the Gatekeeper warning |
| M7-3 | 🔄 | Month 7 retro + post-MVP roadmap | This file (infrastructure pass done; final pass after M7-2 + first feedback wave) |

---

## Post-MVP roadmap (high-level)

The post-MVP backlog inherits everything deferred during M1-M6 plus
items the M7-2 launch surfaces. Grouping by theme rather than month
because cadence post-beta depends on response, not calendar.

### Theme A — Agent dashboard depth

The differentiator the PRD pitched. M6 shipped CPU-based
running/idle/starting; the next step is making the badge mean more.

- **OSC 9 / BEL "needs input" detection** (Q6-001). Most Claude /
  Codex sessions emit a bell when they're waiting on the user; the
  dashboard should say `needs input` instead of `idle`.
- **Agent ↔ pane mapping**. Requires either libghostty exposing a
  per-surface PID or a PTY-scraping heuristic. Investigate upstream
  with the Ghostty maintainers.
- **Node-wrapped agent detection** (Q3-002). A Claude installed via
  `npx` reports `p_comm=node`. Need an argv check via
  `proc_pidinfo PROC_PIDPATHINFO` to disambiguate.

### Theme B — SSH manager v1

The MVP SSH UI is alpha. To match Termius / SecureCRT comfort:

- Groups / folders for hosts.
- Search / filter in the sidebar.
- `~/.ssh/config` import (Hosts blocks → SSHHost rows).
- Optional keypair-per-host selection (path picker, no key storage).
- Connect-into-active-tab as an alternative to always-new-tab.

### Theme C — Workspace ergonomics

The deferred Q2 items finally land here.

- **Recursive split trees** (Q2-003). Today a tab has one split axis;
  real tmux-style nesting needs a tree, not a list.
- **Drag-to-resize dividers** (Q2-002). NSSplitView didn't behave;
  custom NSView with mouse-down drag is the path.
- **Light theme** (Q5-002). Defer until dogfood says yes.

### Theme D — IME hardening

- Run the 20-phrase Vietnamese checklist (#11) under live conditions
  and file any failing rows.
- Korean / Japanese / Chinese smoke tests at the same scope.
- Candidate window positioning audit (the M5 polish work didn't
  touch `firstRect(forCharacterRange:)`).

### Theme E — Distribution

- First notarized release (waits on Developer-ID enrolment).
- Homebrew formula (cask) for `brew install --cask herminal`.
- Sparkle auto-update integration (post first wave of releases when
  the upgrade flow has more than two data points).
- DMG with branded background (optional polish).

### Theme F — Telemetry-free observability v2

The M6 diary is local-only by design. If beta feedback shows people
want to *share* the diary on crash reports:

- `Diary.export()` that generates a redacted bundle (timestamps
  preserved, any path containing `/Users/<name>` rewritten).
- An opt-in upload toggle that pipes the bundle through the issue
  template instead of an unsupervised server.

### Theme G — Documentation + community

- A short blog post on each of the macOS Sequoia kernel gotchas
  (proc_listchildpids, proc_pid_rusage mach-time) — these will
  surface for anyone else building macOS-native tools.
- A `docs/PATTERNS.md` that captures the `MainActor.assumeIsolated`
  + `nonisolated(unsafe)` recipes we've used three times each.
- Vietnamese-language README variant for the target audience.
- A small contributors guide for "good first issues" that don't
  require deep Swift / libghostty knowledge.

---

## Progress Log

### 2026-05-25 — Month 7 kickoff + infrastructure

**Context carried in:**
- Months 1-6 done. 48 unit tests, 6 integration scripts, dogfood
  daily-runner in place. Day-1 baseline filed by the agent;
  days 2-30 owner-driven.
- M5-3 signing pipeline is ready but waits on the owner's Developer-ID
  enrolment for end-to-end notarization.

**Plan:**
- M7-1 OSS hygiene + CI + release tooling + README polish landed in
  one session (all infrastructure, no behaviour change).
- M7-2 is the actual launch — owner cuts v0.1.0 with
  `Scripts/release.sh`, posts the Twitter + LinkedIn drafts, monitors
  first feedback.
- M7-3 retro is bootstrapped (template ready); final pass after the
  M6-2 dogfood + M7-2 launch are both real-world data, not promises.

### 2026-05-25 — M7-1 infrastructure recap

- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, three
  GitHub templates (bug, feature, PR) — owner email
  `hoangperry@proton.me`, swap before publishing if a different
  address is preferred.
- `.github/workflows/ci.yml` — two jobs. core-libs runs in ~2 min
  for fast PR feedback; full-build runs in 30-45 min cold,
  ~5 min cached. Both cache aggressively (SPM + libghostty
  xcframework keyed on the submodule SHA).
- `CHANGELOG.md` (Keep-a-Changelog 1.1) with the complete [0.1.0]
  block already populated from the M1-M6 retros; future releases
  fill in `## [Unreleased]` then `Scripts/release.sh` promotes.
- `Scripts/release.sh` — version-gated (rejects typos + missing
  CHANGELOG section + duplicate tags), dogfood-daily-gated (won't
  tag if the integration suite is red), signs, zips, and prints the
  exact `git push` + `gh release create` commands for the owner
  to run. We deliberately don't push or publish ourselves — that
  needs explicit authorisation per CLAUDE.md.
- README rewritten to reflect v0.1.0 reality (was still "Month 1
  pre-alpha" with empty MVP checkboxes). Comparison table vs
  iTerm2 / Warp / Wave / Ghostty makes the positioning explicit.
- `docs/launch/` — three drafts the owner edits before posting:
  press kit (single-page hand-out), Twitter thread (6 tweets),
  LinkedIn post (~1300 chars). Screenshot/GIF placeholders pinned
  to `docs/launch/assets/`.

### 2026-05-25 — M7-2 first tag + draft release cut

- `Scripts/release.sh 0.1.0` ran clean: dogfood-daily 5/5 PASS,
  release build assembled, ad-hoc-signed (no Developer-ID yet),
  zipped to `.build/release/herminal-v0.1.0.zip` (5.7 MB), annotated
  git tag `v0.1.0` created locally.
- Tag pushed to origin (`git push origin v0.1.0`).
- Draft pre-release created via `gh release create v0.1.0 --draft
  --prerelease` with the zip as the asset and the [0.1.0] CHANGELOG
  block extracted into `--notes-file`. `--prerelease` flag set
  because the bundle is ad-hoc-signed; users will see the Gatekeeper
  "downloaded from internet" warning until v0.1.1 cuts a notarized
  build.
- Bug found while cutting: `release.sh`'s dirty-tree check tripped
  on libghostty submodule's internal `zig-pkg/` build artefact —
  fixed by switching to `git status --ignore-submodules=dirty`
  (commit `d5abe4a`) before re-running the release.

Owner steps remaining to finish M7-2:
1. Review the draft release at
   `gh release view v0.1.0` (or in the GitHub UI).
2. Click "Publish release" (or `gh release edit v0.1.0 --draft=false`)
   once the assets look right.
3. Drop hero screenshot + agent dashboard GIF into
   `docs/launch/assets/`, update the placeholders in
   `twitter-thread.md` and `linkedin-post.md`.
4. Post the Twitter thread + LinkedIn post.
5. Watch the issue tracker — bug template prompts for diary excerpt
   + dogfood journal day, so triage should be tight.
6. Re-cut as `v0.1.1` notarized once the Developer-ID cert lands
   (the signing pipeline is already env-driven; flip the two env
   vars and `Scripts/release.sh 0.1.1` produces a Gatekeeper-clean
   build).

---

## Open Questions

- **Q7-001:** Should the v0.1.0 announcement come BEFORE or AFTER
  the 30-day dogfood completes? PRD scope says "Month 7 launch", but
  the pre-M7-2 gate from M6 retro says "20/30 days = Y first." If
  dogfood drags, do we slip the launch or relax the gate? Owner
  call once we have enough day-N journal entries to know.
- **Q7-002:** Homebrew tap or cask? A cask is the path users
  expect for a `.app` distribution but requires the cask to live in
  homebrew-cask (community-reviewed) or our own tap. Defer until
  first notarized release lands.
- **Q5-002 (carry):** Light theme — keep deferring until owner
  dogfood says one way or the other.
- **Q6-001 (carry):** OSC 9 / BEL agent status — defer until
  someone reports the dashboard saying `idle` when their Claude
  session is actually waiting for input.
- **Q6-002 (carry):** Diary daily rotation — defer until the file
  hits a size people actually complain about.
