# Month 4 Retrospective — herminal SSH + Codex Detection + Verification Gap Closed

**Period:** 2026-05-23 → 2026-05-24
**Sprint goal (PRD roadmap):** SSH Connection Manager UI + Codex CLI detection.
**Result:** ✅ Goal met. All 5 Month-4 tasks (M4-0..M4-4) done. **The 3-month
verification gap is closed — and it paid for itself on its first real use.**

---

## 1. What Got Done

| # | Task | Outcome |
|---|------|---------|
| M4-0 | GUI test harness | `HERMINAL_TEST_TEXT` env injects via `ghostty_surface_text`; `Scripts/run-test-harness.sh`. **Verification gap CLOSED** |
| M4-1 | Codex CLI detection verify | Exposed + fixed 2 real bugs (see §2). `Scripts/verify-codex-detection.sh` |
| M4-2 | SSH host model + store | `SSHHost` + `SSHHostsStore` SQLite WAL; 9 unit tests; Q4-001 resolved |
| M4-3 | SSH Connection Manager UI | `SSHHostsPanel` left sidebar with inline add/edit; ⌘⇧S |
| M4-4 | SSH connect — spawn ssh in new tab | `HerminalSurfaceView(command:)` → libghostty `config.command`; `Scripts/verify-ssh-spawn.sh` |

**13 new unit tests this month** (+ 3 integration scripts), all green.
Test count: 19 → 32. Commits `50a2254` → `ab1cd40`. Zero crashes.

**Month-4 roadmap goal is met.**

---

## 2. What We Learned (Lessons & Bugs)

### The verification harness paid for itself on its first real use

M4-1 was a one-line task in the backlog: "AgentDetector already matches
`codex`; live-detect Codex spawned in a pane." Five minutes of work, in
theory.

It took an evening — and surfaced **two real bugs**:

1. **Bracketed paste swallowed harness input.** `ghostty_surface_text`
   routes through `completeClipboardPaste` in libghostty, which honours
   the terminal's bracketed-paste mode. zsh's `bracketed-paste` ZLE widget
   captures the entire payload into the command buffer including any `\n`
   — so the harness's "type then Enter" never actually pressed Enter, and
   nothing executed. Fix: split the inject text on `\n`, send each segment
   as text, and emit a synthesized Return via `ghostty_surface_key`.
2. **`proc_listchildpids` returns garbage on macOS Sequoia.** Direct probe
   on the kernel API: it reports buffer-size bytes on the first call and
   writes 0 on the second, even when the target has live children.
   Replaced with `sysctl(KERN_PROC_ALL)` — the same path `ps` and `pgrep`
   use — indexed by PPID for O(1) child lookup.

Both bugs had been latent since Month 3 (M3-2 shipped the detector and
M3-3 the dashboard) and were masked by unit tests that only covered the
string→enum mapping. The kernel walk had **zero** integration coverage.

This is the single most important lesson of the month: **a test that
exists but doesn't exercise the dangerous parts is worse than no test,
because it gives false confidence.** M4-1 is the first task that ran the
GUI harness end-to-end — the first run that *could* have caught it — and
it did. M4-0 has now justified itself.

### macOS Sequoia surprises

- **AMFI kills moved code-signed binaries.** A copy of `/bin/sleep` to
  `/tmp/codex` gets SIGKILL'd on launch because the cdhash doesn't match
  the expected install location. The test harness has to *compile* a
  fresh `codex` binary; copying or renaming a system binary doesn't work.
- **`p_comm` is set from the executable path, not argv[0].** `exec -a
  codex /bin/sleep` makes `ps -o comm` (which reads argv[0]) show
  "codex", but `proc_name`, `sysctl p_comm`, and AgentDetector all see
  "sleep". For a real test, the binary's real basename must be `codex`.

### Architecture wins that paid back

- **NotesStore pattern was the right model.** SSHHostsStore reuses the
  exact shape (SQLite WAL, single-isolation-domain `final class`,
  `upsert/all/delete`, internal `decode` static), and the AppDelegate
  refactor that pulled out `appSupportFile(_:)` removed the duplicate
  Application-Support plumbing both stores were repeating. One idiom,
  two stores.
- **Validation at the model boundary** (`SSHHost.validated(...)`) means
  `SSHHostFormView` doesn't have to second-guess what's safe to save —
  it submits, catches the typed errors, and surfaces them inline. The
  form view stays a pure UI concern.
- **Test hook env vars are the cleanest way to drive AppKit from a
  script.** `HERMINAL_TEST_SPAWN_COMMAND` exercises the EXACT spawn path
  the SSH connect button uses, without needing an SSH server or
  XCUITest. The hook code (`if let spawnCommand = env[...]`) is 5 lines
  in AppDelegate and gives us full end-to-end coverage.

### Honest scope of M4-3 SSH UI

The Connection Manager is alpha:
- No groups/folders (flat list).
- No search/filter (will need M5 polish when host counts grow).
- No `~/.ssh/config` import (planned for M5 or later).
- Add/Edit form fits in the 280px sidebar but is cramped — popover-style
  on focus would help.
- "Connect" opens a new TAB, not a new PANE within the active tab.
  Inserting into an active tab is a UX call deferred to dogfooding.

PRD §M4 says "SSH Connection Manager UI" — alpha-ness is in scope.

### What `wait-after-command=true` buys us

libghostty automatically sets `wait-after-command=true` when
`config.command` is set. This means the pane stays open after `ssh`
exits, showing the disconnect message and any final output. Without it,
losing the connection would silently destroy the pane and any context
the user was reading. This is the right default and we don't need to
change it.

---

## 3. Estimate vs Actual

- **PRD Month-4 plan:** SSH Connection Manager UI + Codex CLI detection.
- **Month-3 retro predicted** Month 4 would be lighter than written
  ("markdown round-trip already shipped early in M3-5"). Actual:
  M4-1 turned into a real bug hunt and ate the time M4-2..M4-4 should
  have had. But the bug hunt was the *right* use of time — those bugs
  were going to bite later when herminal hit beta testers' real
  workflows.
- **Caveat from prior months — REVERSED.** For the first time, "done"
  now means **also integration-tested end-to-end via real PTY/process
  interactions**, not just "code shipped + unit tests + render
  verified". M4-0/1/4 each have a `Scripts/verify-*.sh` that runs the
  actual app, not a stub. **The verification gap is closed.**

---

## 4. Debt Carried Into Month 5

| Item | Why pending |
|------|-------------|
| #11 Vietnamese IME smoke test | Owner manual test — now 4 months old. Should run during M5 polish |
| Agent status discrimination (running/idle/done) | Still needs CPU/process-state sampling |
| Agent↔pane mapping | libghostty exposes no per-surface PID |
| Node-wrapped agent detection (Q3-002) | Short-name heuristic misses `node`-hosted CLIs |
| Recursive split trees (Q2-003) | Deferred since Month 2 |
| Drag-to-resize dividers (Q2-002) | Deferred since Month 2 |
| SSH UI polish — groups, search, `~/.ssh/config` import | M5 polish work |
| Connect-into-active-tab option | UX call deferred to dogfooding (M6) |
| XCUITest-style UI tests for SwiftUI panels | Beyond M4 scope; harness env-vars cover the spawn path |

The verification debt is **gone** from this list for the first time.

---

## 5. Roadmap Adjustment for Month 5

- **Month 5 (per PRD):** Compatibility matrix (vim/tmux/fzf/lazygit/btop/
  starship) + polish (animations, hover/focus, accessibility) +
  Developer-ID codesign + notarize pipeline.
- **Recommended additions, given M4-1's bug discoveries:**
  - Run the M4-0 harness through every interactive feature once before
    polish — same low effort, would catch any similar latent bugs.
  - Add an integration test that exercises notes-panel typing via the
    test harness (we have the inject; nothing should be silently
    broken).
  - Run #11 Vietnamese IME smoke test during M5 polish — it's been
    parked 4 months.

### Scope re-check (PRD burnout mitigation #4)

- 7-month Option A: M1 ✅, M2 ✅, M3 ✅, M4 ✅ — **on track, 4 of 7
  months done.**
- For the first time, "on track" doesn't have an asterisk: M4 closed
  the verification debt, so the previous "delivered partly on trust"
  caveat no longer applies. Backend is unit-tested, integration paths
  are scripted, and the bugs M4-1 exposed are the kind that would have
  derailed M6 dogfooding if they'd survived.
- **No downgrade to Option B/C needed.**

---

## 6. Honest Self-Assessment

**Good:** The verification gap that compounded across Months 1-3 is
finally closed, and the harness immediately found two real bugs that
unit tests had missed for two months. The SSH feature (model →
storage → UI → spawn) shipped fully wired, with both unit coverage and
end-to-end harness coverage. 32 tests now, zero crashes. Backend
patterns stayed consistent (NotesStore → SSHHostsStore was almost
copy-paste), and the AppDelegate refactor (`appSupportFile(_:)`) kept
duplicated infrastructure to one place.

**Could be better:** M4-1 ate more time than budgeted — debugging
bracketed paste + the broken kernel API was hours not minutes — which
left less room for M4-3 UI polish. The SSH Manager UI works but is
visually basic compared to what a Raycast/Linear-quality design would
need. M5 polish has to land that.

**Risk for Month 5:** signing + notarization is the first interaction
with Apple Developer infrastructure for this project, and that's
historically where solo dev projects lose a weekend. Block it out
deliberately — don't sandwich it between polish tasks.
