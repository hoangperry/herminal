# Month 4 Backlog — herminal SSH + Codex Detection + Verification

**Sprint goal (PRD roadmap):** SSH Connection Manager UI + Codex CLI detection.
(Markdown round-trip already shipped early in M3-5.)
**Start date:** 2026-05-23
**Owner:** hoangperry
**Carries debt:** #11 IME smoke test + the 3-month-old GUI verification gap.

> ⚠️ Month-3 retro flagged the verification gap as the Month-4 must-fix.
> M4-0 addresses it before any new UI work.

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M1-11 | ⏳ | Vietnamese IME smoke test (20 phrases) | Owner manual test — debt from Month 1 |
| M4-0 | ✅ | GUI test harness (debt fix) | `HERMINAL_TEST_TEXT` env → `ghostty_surface_text` inject; `Scripts/run-test-harness.sh`; 4/4 runs PASS. **Verification gap closed** |
| M4-1 | ✅ | Codex CLI detection verify | Exposed 2 real bugs: (1) bracketed-paste swallowed harness `\n`, (2) `proc_listchildpids` broken on macOS Sequoia. Fixed both: `Scripts/verify-codex-detection.sh` 1/1 PASS, AgentDetector now uses `sysctl(KERN_PROC_ALL)` |
| M4-2 | ✅ | SSH connection model + storage | `SSHHost` value type + `SSHHostsStore` SQLite WAL store. 9 tests covering CRUD + validation + last-connected timestamp. Q4-001 resolved: SQLite chosen for symmetry with NotesStore |
| M4-3 | ✅ | SSH Connection Manager UI | Left-sidebar panel (`SSHHostsPanel`) — list + inline add/edit form + Connect/Edit/Delete context menu. Shares the left slot with the agent dashboard (mutually exclusive). Toggle: ⌘⇧S |
| M4-4 | ✅ | SSH connect — spawn ssh in new tab | `HerminalSurfaceView.init(command:)` forwards into libghostty `config.command`. Verified end-to-end via `Scripts/verify-ssh-spawn.sh` |
| M4-5 | ⏳ | Month 4 retrospective | Re-check 7-month scope after the heaviest UI month |

## Month 5 plan (preview)

- M5-1: Compatibility matrix — vim, tmux, fzf, lazygit, btop, starship
- M5-2: Polish — animations, hover/focus states, accessibility pass
- M5-3: Developer-ID codesign + notarize pipeline
- M5-4: Month 5 retro

## Month 6 plan (preview)

- M6-1: Dogfood checklist + telemetry-free crash diary
- M6-2: 30 consecutive days, owner uses herminal as daily-driver
- M6-3: Month 6 retro

---

## Progress Log

### 2026-05-23 — Month 4 kickoff

**Context carried in:**
- Months 1-3 done; 19 + 7 = ~26 unit tests across the package; codebase clean
  (Month 1-3 review found 2 MEDIUM bugs, both fixed in commit `f5a82f0`).
- Verification gap is 3 months old — fixing it FIRST in M4-0 is non-negotiable.

**Plan:**
- M4-0 first (test harness). Then Codex live-detect (M4-1), SSH model (M4-2),
  SSH UI (M4-3), SSH connect (M4-4), retro (M4-5).

### 2026-05-24 — M4-1 verified, 2 bugs exposed

The "easy verification" task turned into a real bug hunt — exactly what the
verification gap was hiding for 3 months.

**Bug 1 — Bracketed paste swallowed harness input.**
`ghostty_surface_text` routes through `completeClipboardPaste` in libghostty,
which honours the terminal's bracketed-paste mode. zsh's `bracketed-paste`
ZLE widget puts the entire payload in the command buffer (including a `\n`)
without executing — so the harness's "type then Enter" never actually
hit Enter. Fixed by splitting the inject text on `\n`, sending each segment
as text, and emitting a synthesized Return key via `ghostty_surface_key` —
that path bypasses the paste handler and triggers real command execution.

**Bug 2 — `proc_listchildpids` returns garbage on macOS Sequoia.**
Direct probe: `proc_listchildpids(HerminalApp_PID, …)` reports 1 byte of data
and 0 children, while `sysctl(KERN_PROC_ALL)` correctly returns the `login`
child. AgentDetector now uses a sysctl-based `ProcessSnapshot` (one snapshot
per detection cycle, indexed by PPID) — same path `ps` and `pgrep` use. Logic
is now O(N) for the snapshot then O(1) for child lookup, instead of O(N) per
node before.

**Why the bugs were not caught earlier:** the existing AgentDetector unit
tests only verified `AgentKind.detect(processName:)` — the string→enum
mapping. The kernel walk had **zero** integration coverage. That's exactly
the kind of gap M4-0 was created to close — and M4-1 is the first task that
actually exercised the GUI harness end-to-end, so this is the first run that
could have caught it. **The verification harness paid for itself on its
first real use.**

**Verify:** `Scripts/verify-codex-detection.sh` builds a purpose-named
`codex` binary (a copy of `/bin/sleep` gets killed by AMFI; a shell script
reports `p_comm=bash`), launches herminal, injects `touch && /tmp/codex 30`,
and asserts the dump file contains a `codex` line. 1/1 PASS.

### 2026-05-24 — M4-2 SSH host model + store

Q4-001 decided in favour of SQLite — same pattern as `NotesStore`, no extra
storage idiom to learn, and `(updated_at DESC)` index keeps the sidebar
ordering cheap once host counts grow. Plist would have been simpler at 5-50
rows but the cost of SQLite at this scale is essentially nil.

- `SSHHost` value type: id, nickname, hostname, user, port (1-65535),
  created_at, updated_at, last_connected_at. Secrets stay out — they
  belong in `~/.ssh/config` or Keychain, not herminal's DB.
- `SSHHost.validated(...)` enforces input rules at the model boundary so
  the UI never has to second-guess what's safe to upsert.
- `SSHHostsStore`: WAL-mode SQLite, `upsert/host/allHosts/delete`, plus
  `touchLastConnected(id:)` which updates only the connect timestamp
  (does NOT bump `updated_at` — connection telemetry should not promote
  the row in the sidebar's recency sort).
- Test coverage: 9 cases — round-trip, in-place update, recency ordering,
  delete, unknown id, validation (empty hostname + port bounds), and
  last-connected stamping.

Full test suite: 29/29 PASS.

### 2026-05-24 — M4-3 SSH Connection Manager UI

Sidebar slot policy: agents and SSH share the LEFT side, mutually
exclusive. The reason — most workflows have either "what's running"
(agents) or "what should I connect to" (SSH hosts) on screen, not both
at once. Stacking them would steal width from the surface and most
users would just hide the one they don't want anyway. A single toggle
hotkey per panel keeps muscle-memory simple.

- `SSHHostsPanel` — list of saved hosts with `Connect` button and
  `Edit` / `Delete` in the context menu. Inline header `+` switches to
  the form view (`SSHHostFormView`) without opening a sheet or popover
  so the panel never loses its place in the layout.
- `SSHHostFormView` — fields for nickname, hostname, user, port. Uses
  `SSHHost.validated(...)` and surfaces the error inline below the form
  rather than throwing or crashing. Edits preserve `createdAt` and
  `lastConnectedAt`, bumping only `updatedAt`.
- `WorkspaceView`: `LeftSidebar` enum (`.none | .agents | .ssh`) drives
  layout. `connectSSH(_:)` stamps `last_connected_at` and logs the
  request — actual `ssh` spawn lands in M4-4.
- `AppDelegate` extracts `appSupportFile(_:)` to centralise the
  Application-Support path resolution that the two stores were
  duplicating, and now opens both `notes.db` and `ssh-hosts.db`.
- Menu: `Toggle SSH Hosts` (⌘⇧S) added under Window.

Smoke test: app launches under the test harness, `ssh-hosts.db` +
`-shm` + `-wal` files appear in `~/Library/Application Support/herminal`
(confirming WAL-mode SQLite init succeeded). UI panel itself is
exercised manually — automated UI tests would require something like
XCUITest, deferred to Month 5 polish.

### 2026-05-24 — M4-4 SSH connect: spawn ssh in a new tab

Wires "Connect" through to a real PTY. libghostty's `surface_config`
has a `command` field that overrides the default shell; when set, it
also flips `wait-after-command=true` so the pane stays visible after
`ssh` exits (so the user can see the disconnect message before closing).

- `HerminalSurfaceView(app:command:)` — optional command, kept in a
  heap-owned C buffer (`strdup`) so the pointer stays valid for the
  full surface lifetime, not just the `withCString` call. Freed in
  `deinit`. `nonisolated(unsafe)` because deinit on NSView is
  nonisolated and the buffer is an `UnsafeMutablePointer` (non-Sendable).
- `TerminalSession.init(app:title:command:)` and
  `WorkspaceTab.init(app:command:title:)` plumb the command down.
- `WorkspaceView.addTab(command:title:)` opens a new tab whose first
  pane runs that command.
- `connectSSH(_:)` now builds the shell command via
  `sshCommand(for:)` (single-quoted user@host, `-p` only when the port
  isn't 22) and opens it in a new tab. Last-connected gets stamped and
  the panel re-renders so the recency badge updates immediately.
- `AppDelegate`: `HERMINAL_TEST_SPAWN_COMMAND` env hook exercises the
  exact same `addTab(command:)` path from a script. Used by
  `Scripts/verify-ssh-spawn.sh` for end-to-end verification without
  needing an SSH server.

Shell-quoting is the kind of thing that's painful to get wrong and easy
to regress, so `SSHCommandTests` covers: port-22 omits the flag,
non-22 emits `-p N`, embedded single quotes get escaped.

Verify: `Scripts/verify-ssh-spawn.sh` PASS. Unit suite 32/32 PASS.

---

## Open Questions

- **Q4-001:** ~~SSH host storage — SQLite vs plist?~~ **Resolved (M4-2):** SQLite.
  Row count stays small (5-50 hosts typical) so the perf delta is essentially
  nil, but SQLite gives us one storage idiom across notes + hosts (less
  cognitive cost) and indexing headroom for future search/filter UI.
