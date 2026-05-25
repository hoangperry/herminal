# Month 11 — Review + Docs + Marketing

**Sprint goal:** Owner asked for "review, tạo docs, marketing." This
slice runs the audit, ships the fixes, fills the missing reference
docs, and produces a multi-channel launch kit. Three sub-phases (A
review, B docs, C marketing) executed in sequence.

**Start date:** 2026-05-25
**Owner:** hoangperry

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M11-A1 | ✅ | Parallel code-reviewer + security-reviewer agents | 1 CRITICAL + 5 HIGH + 11 MEDIUM + 5 LOW findings |
| M11-A2 | ✅ | Fix CRITICAL + 5 HIGH + 2 MEDIUM; write REVIEW.md | Commit `11c65b3` ships the fixes; `docs/REVIEW.md` records what stays deferred |
| M11-B-arch | ✅ | ARCHITECTURE.md + ROADMAP.md | One-page system mental model + public-facing roadmap |
| M11-B-ref | ✅ | FAQ.md + TROUBLESHOOTING.md + KEYBOARD-SHORTCUTS.md | Owner-facing reference docs |
| M11-C-land | ✅ | landing-page.md + comparison.md | Landing source + long-form vs-the-field comparison |
| M11-C-show | ✅ | show-hn.md + product-hunt.md + reddit.md + demo-video.md | 4-channel launch drafts |
| M11/retro | 🔄 | This retro | Final pass after the launch actually happens |

---

## Open Questions

- **Q11-001:** REVIEW.md flags 9 MEDIUM + 5 LOW items as deferred.
  When does the next review cycle fire? Suggested: at v0.2.0 cut
  (deferred items get a re-check), AND on any major libghostty
  bump (the libghostty-coupled findings need a re-validate).
- **Q11-002:** The Sparkle stub in `Updater.swift` references an
  appcast URL that doesn't exist yet (`releases/latest/download/
  appcast.xml`). The release workflow generates it but no v0.1.0
  release has been published. The URL 404s until the owner clicks
  Publish on the draft release. Mention in the launch checklist.

---

## Progress Log

### 2026-05-25 — M11 phase A: parallel review + fix pass

Two specialised agents (code-reviewer + security-reviewer) ran in
parallel against the v0.1.0 codebase. Findings landed in two
~1500-word reports — total 21 items across all severity tiers.

**1 CRITICAL fixed:**
- `Diary.crashFD` was a `static let` on Diary, accessed from the
  signal handler. First read goes through `swift_once`, which
  acquires a runtime lock — fatal in async-signal-safe context.
  Moved to file-scope vars (`_diaryCrashFD`, `_diaryCrashHandler`)
  so signal context hits raw memory with no swift_once path.

**5 HIGH fixed:**
- Test harness env hooks (HERMINAL_TEST_*) compiled into production
  builds → arbitrary command execution + arbitrary file writes.
  Wrapped every hook in `#if DEBUG` so release builds compile them
  out entirely.
- `GhosttyApp` double-free on init failure. Refactored to keep
  handles local until both are known good.
- `BellRegistry` stale-address collision (surface reallocation at
  same memory address inherits old bell history). Added
  `clearBell(forSurfaceAddress:)` + wire from
  `HerminalSurfaceView.deinit`.
- `SSHConfigImporter` multi-target Host emitted wrong hostnames for
  secondary targets. Refactored to buffer all names + flush with
  shared directives.

**2 MEDIUM also fixed in the same pass:**
- ISO8601DateFormatter cached as static instead of recreated per
  log() call.
- Diary file open mode tightened from 0o644 to 0o600.

**9 MEDIUM + 5 LOW deferred** with explicit reasoning in
`docs/REVIEW.md` — most defers gate on "next time this file is
touched anyway" rather than "needs its own slice."

Tests: 79/79 pass (up 2 from 77 with regression tests for the
BellRegistry clearBell behaviour). Integration scripts: 5/5 pass.

### 2026-05-25 — M11 phase B: reference docs

Five new docs landed:

- `ARCHITECTURE.md` — one-page system overview with layered
  diagram (4 SPM modules + GhosttyKit) + 3 data-flow walk-throughs
  (keystroke→render, agent detection, SSH connect). Storage +
  threading + test boundary documented in the same doc.
- `ROADMAP.md` — public-facing version of `month-7.md`'s post-MVP
  plan. Shipped / Next / Themed roadmap (A-G) / Won't ship by
  design / How to influence the roadmap.
- `FAQ.md` — 8 sections covering questions that come up before
  someone reaches for the issue tracker.
- `TROUBLESHOOTING.md` — diagnostic flow with capture commands
  for 7 common symptoms + a "reset everything" path.
- `KEYBOARD-SHORTCUTS.md` — reference card mirroring AppMenu.swift,
  including conflict resolution with macOS system shortcuts.

### 2026-05-25 — M11 phase C: launch kit

Six marketing drafts landed under `docs/launch/`:

- `landing-page.md` — markdown source for the eventual landing
  page; comparison ASCII table inline, CTA buttons top + bottom.
- `comparison.md` — long-form herminal-vs-the-field on 8 axes,
  with explicit "when to pick" and "when NOT to pick" sections.
- `show-hn.md` — HN submission draft. Title alternatives, URL
  rationale (GitHub repo for OSS-of-this-size trust signal),
  first-comment text, defense playbook, "what NOT to do."
- `product-hunt.md` — PH submission draft. Tagline + topics + hero
  image spec + gallery list + 500-word maker's first comment +
  4-hour engagement plan.
- `reddit.md` — 5 subreddit drafts (r/MacOS, r/programming,
  r/swift, r/commandline, r/vietnam) each with different framing
  for that sub's culture. Posting cadence to avoid anti-spam
  flags.
- `demo-video.md` — 90-second silent screen-recording storyboard.
  Caption-only (no voiceover, accent-neutral). Recording checklist
  + A/B re-cut angle for the launch.

All drafts cross-link the canonical sources (README, ARCHITECTURE,
ROADMAP, blog posts) so future canonical-source updates surface in
the marketing copy on next edit rather than silently drifting.

---

## Stats

- 10 commits this slice, `8ea9074` → `0614728`
- 0 production regressions: 79/79 unit tests, 5/5 integration
  scripts still PASS after the fix pass
- 9 new docs (REVIEW + ARCHITECTURE + ROADMAP + FAQ +
  TROUBLESHOOTING + KEYBOARD-SHORTCUTS + 6 marketing files;
  some grouped per commit)
- 1 CRITICAL + 5 HIGH + 2 MEDIUM bugs fixed before any v0.1.0
  publish happens
