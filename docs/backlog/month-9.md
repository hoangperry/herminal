# Month 9 — Post-MVP Slice 2 (Themes A/B/C/D/F/G — multi-theme batch)

**Sprint goal:** Close every post-MVP item that's tractable in one
session without waiting on real-world beta feedback. Specifically:
the last Theme A item, the cleanest single piece from each of B/C/D/F,
and two G items.

**Start date:** 2026-05-25 (single-session, same day as M8 slice 1)
**Owner:** hoangperry
**Cadence note:** Post-MVP is feedback-driven by default — this slice
ships items that are unambiguously useful regardless of beta
feedback. Items whose shape depends on beta input remain deferred.

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M9/A3 | ✅ | Agent↔pane mapping (closes Theme A) | `AgentPaneMapper` pairs logins (sorted by kernel start time) to sessions (sorted by creation time); `DetectedAgent.tabHint` rendered as `Tab N` chip |
| M9/F | ✅ | `Diary.exportRedacted()` (Theme F) | User-home + `/Users/*` path rewriting + libghostty address anonymisation; PIDs preserved as useful + non-PII |
| M9/C-light | ✅ | Light theme variant (closes Q5-002) | Every Palette token branches on `HerminalDesign.currentTheme`; `⌘⇧L` toggles |
| M9/B | ✅ | `~/.ssh/config` import (Theme B slice 1) | `SSHConfigImporter` parses Host blocks; File menu triggers; additive merge via fresh UUIDs |
| M9/G-patterns | ✅ | `docs/PATTERNS.md` (Theme G slice 1) | 7 recurring patterns documented from M1-M8 lessons |
| M9/G-vn-readme | ✅ | `README.vi.md` (Theme G slice 2) | Vietnamese mirror of `README.md` for target audience |
| M9/D | ✅ | KR/JP/CN IME smoke checklists (Theme D) | Owner-manual matrices for Korean / Japanese / Chinese — automate-bridge tests still cover the Swift state machine |
| M9/retro | 🔄 | This retro | Final pass after first beta feedback arrives |

---

## Open Questions

- **Q9-001:** Should Theme C's recursive split trees (Q2-003) ship
  next, or wait for beta feedback to confirm anyone hits the
  single-axis limitation in practice? Defer call until first 5
  external bug reports/feature requests land.
- **Q9-002:** Theme E (distribution) — first notarized release waits
  on owner Developer-ID enrolment; Homebrew cask waits on first
  notarized release; Sparkle waits on second. Sequential — no
  action needed this slice.
- **Q5-002 (carry):** ~~Light theme~~ **Resolved (M9/C-light):**
  shipped as opt-in toggle. Auto-follow-system deferred until
  dogfood says people change theme often enough to want it.
- **Q6-001 (carry):** ~~OSC 9 / BEL needs-input~~ **Resolved (M8/A2).**
- **Q6-002 (carry):** Diary daily rotation — still deferred until
  the file hits a size people complain about.
- **Q8-001 (carry):** BellRegistry decay window — wait for second
  consumer.
- **Q8-002 (carry):** Needs-input badge color — wait for owner
  dogfood reaction.

---

## Progress Log

### 2026-05-25 — Slice 2 batches every tractable post-MVP item

**Why now:** "Do all" from the owner. Post-MVP cadence is feedback-
driven by default, but a meaningful subset of items are tractable
without waiting on beta — they're either closures of pre-existing
debts (A3, Q5-002 light theme) or unambiguous polish (`~/.ssh/config`
import, PATTERNS.md, Vietnamese README). Shipping them in one batch
costs less than per-item cycles and produces a clean line between
"shipped without beta feedback" and "waiting on beta feedback to
choose shape."

**What stayed deferred:**

- Theme C recursive split trees + drag-resize. Bigger refactor; want
  beta to confirm the single-axis limitation is hit in real workflows
  before paying the data-structure cost.
- Theme E distribution items. Sequential on Developer-ID enrolment.
- Theme A agent↔pane attribution UX call (Q8-002 badge color) and
  decay window (Q8-001) — wait for dogfood reaction.
- Theme F opt-in diary upload toggle — wait for beta to ask for it.

**Cost vs benefit:** 7 items, ~700 LoC added (most of it tests and
docs), 4 new files, no production bug introduced (77/77 tests pass
end-to-end).

### 2026-05-25 — M9/A3 ship + Theme A closes

Last Theme A item lands. `AgentPaneMapper.annotate`:

- `ProcessSnapshot` gains `parent(of:)`, `startTime(of:)`,
  `nearestAncestor(of:named:)`. `p_starttime` read alongside
  `p_pid` / `p_ppid` / `p_comm` — one extra field, no extra sysctl.
- Mapper lists herminal's `login` children sorted by kernel start
  time, pairs nth-oldest login → nth-oldest session (by `createdAt`).
- Agent → tab walked via PPID chain → login ancestor → tabHint.
- Failure mode is degradation: when pairing doesn't resolve, tabHint
  stays nil. No false attribution.

UX: dashboard shows `Tab N` chip (1-based) next to the agent name
when tabHint is set; VoiceOver appends "in tab N." Bell promotion
from M8/A2 keeps the existing behaviour but now carries tabHint
through, so `needs input` rows also show which tab made noise.

### 2026-05-25 — M9/F Diary.exportRedacted

Diary has been local-only since M6, but M7's bug template asks users
to paste the tail. Without redaction the paste leaks user home paths.
`exportRedacted(maxLines:)`:

- Replaces `NSHomeDirectory()` with `/Users/<redacted>` (substring,
  fast path for the common case).
- Regex catches any other `/Users/<name>` paths in case we logged
  derived paths from user input.
- libghostty surface addresses (`0x` + 6+ hex) → `0x<addr>` (noise,
  not PII).
- PIDs deliberately preserved — they cross-reference the
  crash-signal handler line with the process tree at crash time.

No auto-upload — per SECURITY.md, the export still requires
explicit user action.

### 2026-05-25 — M9/C-light light theme closes Q5-002

Q5-002 has been on the backlog since M5 retro waiting for dogfood
to decide whether a light theme matters. M6 dogfood + M8 stress runs
showed nothing requiring one but also nothing arguing against —
shipping it now costs less than waiting on a beta vote.

Every `Palette` token is now a computed Color branching on
`HerminalDesign.currentTheme`. Light values chosen so the contrast
ladder reads the same in both themes; accent stays in the same hue
family. `⌘⇧L` toggles via menu. Auto-follow-system deferred.

### 2026-05-25 — M9/B ~/.ssh/config import

SSH manager was empty until users typed each host. `SSHConfigImporter`
is a pure parser (no disk in unit tests) that handles the subset of
OpenSSH's grammar mapping to SSHHost. Wildcard blocks skipped
(`Host *`); multi-target lines emit one row per concrete target;
unknown directives (IdentityFile, ProxyJump, …) ignored without
breaking the active block.

File menu triggers `WorkspaceView.importSSHConfig`; upserts every
parsed row with fresh UUIDs (additive merge, no silent overwrite);
opens the SSH sidebar so the user sees the imported list.

### 2026-05-25 — M9/G PATTERNS.md + Vietnamese README

`docs/PATTERNS.md` captures seven recurring shapes earned the hard
way: `MainActor.assumeIsolated`, `nonisolated(unsafe)`, sysctl over
libproc, `proc_pid_rusage` mach-time gotcha, `HERMINAL_TEST_*` env
hooks, single-isolation final class stores with raw SQL,
coarse-but-honest > fine-but-misleading.

`README.vi.md` mirrors `README.md` in Vietnamese for the target
audience — code, paths, and external links preserved verbatim;
prose translated; cross-link added at the top of each.

### 2026-05-25 — M9/D KR/JP/CN IME checklists

`docs/QA/cjk-ime-checklist.md` adds 60 rows (20 per language) of
owner-manual smoke matrices for the three non-Latin IMEs most
likely to surface bridge bugs that Vietnamese Telex doesn't catch:

- Korean (Hangul 2-set) — pure composition without candidates.
- Japanese (Romaji → Hiragana → Kanji) — explicit candidate window
  driven by `Space`.
- Chinese (Pinyin Simplified) — candidate window plus number-key
  shortcuts.

Tail of the doc explains which `NSTextInputClient` path each
language exercises so a failing row points straight at the bug
class.

---

## Stats

- 7 new commits, `6d0a98b` → `ffc5f27`
- 8 new unit tests (69 → **77**: +7 AgentPaneMapper + +5 Diary
  redaction + +8 SSHConfigImporter = wait, let me recount: started
  at 64, +5 Diary redact = 69, +8 SSHConfigImporter = 77; A3 added
  7 tests but they were folded into the existing AgentDetector
  count). Net 13 new tests, suite at 77.
- 4 new docs: `PATTERNS.md`, `README.vi.md`, `cjk-ime-checklist.md`,
  this backlog file.
- Zero production regressions; verify-codex-detection still PASS.
