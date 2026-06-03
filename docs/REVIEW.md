# Review report — M11-A (2026-05-25) + M13 (2026-05-26) + C2 (2026-06-03)

Parallel code-reviewer + security-reviewer agents audited the v0.1.0
codebase before publish (M11-A), again after the M12 polish slices
landed (M13 follow-up), and a third time over the v0.3.0–v0.4.2 surface
that had never been reviewed (C2). This document captures what they
found, what shipped fixed, and what stays deferred — so future reviews
start from the right baseline.

---

## C2 follow-up (2026-06-03, scope: v0.3.0–v0.4.2 hunks only)

The polish wave (command palette, hotkey, scrollback search,
drag-resize) and the Sessions milestone (OSC 7, Claude session browser,
session restore, named workspaces) shipped across v0.3.0–v0.4.2 without
a dedicated review pass. C2 closed that gap. Shipped in **v0.4.3**.

| Severity | Found | Fixed | Deferred |
|---|---|---|---|
| CRITICAL | 0 | — | — |
| HIGH | 4 | 3 | 1 (false positive) |
| MEDIUM | 5 | 4 | 1 (accepted) |
| LOW | 3 | 0 | 3 (noted) |

**Verdict:** The one genuinely dangerous finding — **shell injection
via a crafted `~/.claude/projects/*/<stem>.jsonl` filename** flowing
into `claude --resume <id>` — is closed, with a parameterized
regression test (`ClaudeSessionStoreTests`). The remaining HIGH was a
false positive (a main-run-loop `Timer` block can't fire off-main, so
`MainActor.assumeIsolated` never traps; that code is also pre-v0.3, out
of scope).

### C2 — Fixed

- **HIGH (security F1 / code) — shell injection via session id.** The
  Claude session id is a transcript filename stem interpolated into the
  `claude --resume <id>` shell command. A local process can plant any
  filename under `~/.claude/projects/*/`, so a stem like `x; rm -rf ~ #`
  would execute on Resume. `ClaudeSessionStore.isValidSessionID` now
  requires a canonical `UUID(uuidString:)` — the only shape Claude Code
  writes — so a crafted filename never reaches the shell. New
  `ClaudeSessionStoreTests` (12 cases: real UUIDs accepted; metachars +
  wrong shapes rejected).
- **HIGH (code) — `PaneDividerView` tracking-area retain cycle.**
  `NSTrackingArea(owner: self)` retains its owner, forming a self-cycle
  that survived `removeFromSuperview` and leaked one divider per
  split/resize rebuild. `removeFromSuperview()` now drops the tracking
  areas (and the `onDrag` closure) to break it.
- **HIGH (code) — `ClaudeSessionStore` blocked the main thread.**
  `recentProjects()` (a dir stat + 16 KB read per project) ran
  synchronously on `@MainActor` from `refreshClaudePanel`, janking the
  sidebar on open / theme change / prefs change for users with many
  projects. The store is no longer `@MainActor` (it's pure read-only
  I/O) and the scan runs on a `Task.detached(.utility)`, hopping back to
  MainActor only to swap the view.
- **MEDIUM (security F2) — search needle injection.** `"search:\(needle)"`
  is fed to libghostty's line/colon-delimited binding-action grammar.
  Control chars are now stripped so a pasted needle can't smuggle a
  second action (e.g. newline + `close_surface`).
- **MEDIUM (security F3) — PII in the unified log.** `Diary.log`
  forwarded every entry (including full cwd paths) to `NSLog`, which
  lands in the system-wide unified log any local process can read. The
  NSLog forward is now redacted (`Self.redact`) — the local diary file
  keeps full fidelity, the shared log gets the home-username masked.
- **MEDIUM (code) — `CommandPalette` kept a stale query.** The static
  panel was never released, and `hidesOnDeactivate` bypassed `close()`,
  so the typed needle survived into the next ⌘⇧P. `show()` now rebuilds
  fresh and `close()` nils the panel (releasing its SwiftUI tree).
- **MEDIUM (code) — `enableSessionPersistence` undid the opt-out.** With
  restore OFF, AppDelegate clears the saved file, but the unconditional
  immediate persist re-created it from the default launch tab. It's now
  gated on `Preferences.restoreSessionOnLaunch`.
- **MEDIUM (code) — NaN/∞ ratios in `WorkspaceStore.sanitise`.** The
  `$0 > 0` ratio check rejected NaN/−∞ only by evaluation-order luck;
  an explicit `&& $0.isFinite` now also rejects +∞ before it reaches
  the layout math.
- **LOW (security F4) — workspace name not path-guarded.** Names are
  only JSON values today, but `WorkspacesStore.save` now rejects `/` and
  NUL so the name stays safe to use as a filename component later.

### C2 — Deferred

- **HIGH (code) — `MainActor.assumeIsolated` in `Timer` blocks**
  (AppDelegate tick + WorkspaceView agent poll). **False positive +
  out of scope:** `Timer.scheduledTimer` adds to the main run loop,
  which only the main thread drives, so the block always fires on
  main and the assumption holds. Both timers are pre-v0.3 code that's
  run fine for months. No change.
- **MEDIUM (code) — `WorkspaceTab.focusedPane` can index out of
  bounds** if read after `removePane` empties the tab. **Accepted:** the
  invariant is enforced by callers (every `surfaceDidClose` path guards
  `panes.isEmpty` before reading `focusedPane`, and `removePane` only
  empties immediately before the tab is closed). Converting to an
  Optional would cascade through ~10 call sites for a path no caller
  currently reaches. Documented; revisit if a new caller appears.
- **LOW (code) — `normalizeRatios` zero-sum path** is already guarded
  (`guard sum > 0`); noted only.
- **LOW (code) — `SearchOverlayView` 50 ms focus delay** is fragile
  under load but works; a `@FocusState`-driven refactor isn't worth the
  churn now.
- **LOW (code) — `CommandPalette` panel-reuse** subsumed by the MEDIUM
  fix above (now rebuilds fresh).

---

## M13 follow-up summary (2026-05-26, scope: M12 hunks only)

| Severity | Found | Fixed | Deferred |
|---|---|---|---|
| CRITICAL | 0 | — | — |
| HIGH | 4 | 4 | 0 |
| MEDIUM | 4 | 3 | 1 |
| LOW | 3 | 1 | 2 |

**Verdict:** All HIGH findings closed before the M13 review pass
returned. The deferred MEDIUM (shell-path consumption, no caller yet)
is gated to whenever `defaultShellPath` first flows into a libghostty
spawn — `Preferences.validatedDefaultShellPath()` is in place ahead of
that work.

### M13 — Fixed

- **HIGH** `StatusBarView.probe` closure type-annotated `@MainActor` so
  Swift 6 compiler enforces the contract — a future `Task {}` capture
  fails to compile instead of trapping in `MainActor.assumeIsolated`.
- **HIGH** `closeActivePane` now gates on the FOCUSED pane's note
  (`confirmCloseIfNoteExists(forSessionIDs:)`), not the whole tab.
  Previous shape silently discarded notes on panes 2..N inside
  multi-pane tabs because `closeFocusedPane()` returns false when other
  panes remain — the post-hoc check at `closeTab()` never fired.
- **HIGH** `PreferencesWindow` adds a `NSWindow.willCloseNotification`
  observer that nils the static reference on close, so re-opening
  builds a fresh `NSHostingView`. Closes an invisible ordering hazard
  for `@AppStorage` bindings seeded before `registerDefaults()`.
- **HIGH** `closeTab(id:)` re-derives the live tab index by UUID after
  `NSAlert.runModal()` returns. The modal re-enters the main run loop;
  the old shape captured a stale index that could close the wrong tab
  if `tabs` mutated underneath (e.g. ⌘W while the alert is up).
- **MEDIUM** `confirmCloseWithNote` toggle now calls
  `Preferences.broadcastChange()` on flip, matching every other
  `@AppStorage` toggle in `PreferencesView`.
- **MEDIUM** `WindowState.isFrameOnAnyScreen` gains explicit `isFinite`
  guards on width/height/origin so `+infinity` can't slip through the
  `>= 200` floor.
- **LOW** `LatencyProbe.percentile` uses nearest-rank `ceil` instead of
  `Int(n*f)` truncation. Single-line fix shared between live snapshot
  + 10s log flush.

### M13 — Deferred

- **MEDIUM** `Preferences.defaultShellPath` value isn't yet consumed —
  the ShellTab persists it but no spawn path reads it back. Adding
  `Preferences.validatedDefaultShellPath()` now so the consumer in M13+
  has a vetted helper to call (executable-bit + path-prefix check,
  /tmp + /private/tmp rejected). Gate item: wiring up consumption MUST
  route through this helper.
- **MEDIUM** `preferencesDidChange` observer registered without an
  object filter. The originally suggested `object: Preferences.self`
  fix doesn't apply — `Preferences` is a caseless enum with no
  reference identity to filter on. Acceptable: only
  `Preferences.broadcastChange()` posts the notification today, and a
  sentinel object just to enable filtering is overengineering. Revisit
  if anyone introduces a second poster.
- **LOW** `windowDidResize` writes 4 UserDefaults keys per frame during
  a drag-resize. UserDefaults coalesces to disk, but the 4 KVO
  notifications per frame are real micro-overhead. Debounce with a
  0.3 s timer if it ever surfaces in a perf trace.
- **LOW** `WindowState.isFrameOnAnyScreen` accepts a 200x200 window
  whose centre is on-screen but visible area is mostly off (e.g.
  centred at a screen edge). Document-only — matches the explicit
  multi-monitor-straddle intent in the inline comment.

---

## Summary

| Severity | Found | Fixed in M11-A2 | Deferred |
|---|---|---|---|
| CRITICAL | 1 | 1 | 0 |
| HIGH | 5 | 5 | 0 |
| MEDIUM | 11 | 2 | 9 |
| LOW | 5 | 0 | 5 |

**Verdict:** v0.1.0 publish-blockers all closed. The deferred items
are tracked in this doc for the next review cycle.

---

## Fixed

### CRITICAL — Diary signal handler async-signal-safety
`Sources/HerminalApp/Diary.swift` (commit `11c65b3`)

`crashFD` + `crashHandler` were `static let/var` on `Diary` —
both went through `swift_once` lazy init. A signal firing before
the normal-path code touched them, or on a thread holding the
`swift_once` lock, would deadlock the runtime from inside the
handler. The diary failed at the exact moment it's needed.

**Fix:** moved both to file-scope module-level vars (`_diaryCrashFD`,
`_diaryCrashHandler`). The handler closure has no captures so the
`@convention(c)` materialises eagerly without `swift_once`.

### HIGH H-1, H-2 — Test harness env hooks in production builds
`Sources/HerminalApp/AppDelegate.swift` (commit `11c65b3`)

`HERMINAL_TEST_*` env vars (TEXT, SPAWN_COMMAND, SMOKE_PLAN,
STATE_DUMP, AGENT_DUMP, TREE_DUMP, DELAY) let a process that
controls herminal's environment trigger arbitrary code execution or
arbitrary file writes.

**Fix:** wrapped every hook in `#if DEBUG`. Release builds compile
them out entirely; debug builds (test/CI/owner) keep working.
`validatedDumpPath` rejects dump paths outside the temp-directory
hierarchy as defense in depth even within debug.

### HIGH — GhosttyApp double-free on init failure
`Sources/HerminalCore/GhosttyApp.swift` (commit `11c65b3`)

`self.config = config` was assigned BEFORE attempting
`ghostty_app_new`. On `app_new` failure the explicit free + deinit
both ran → double-free.

**Fix:** keep `configHandle` local until BOTH config and app are
known good. Stored properties only assigned at the bottom of init.

### HIGH — BellRegistry stale-address collision
`Sources/HerminalCore/BellRegistry.swift` + `HerminalSurfaceView.swift` (commit `11c65b3`)

Surface freed at address X, libghostty re-allocates a new surface
at the same address (slab allocator reuse is common). New pane
inherited the old surface's bell history → false `needs input`
badge on a fresh agent.

**Fix:** added `BellRegistry.clearBell(forSurfaceAddress:)`.
`HerminalSurfaceView.deinit` calls it before `ghostty_surface_free`
so the registry stays consistent with the live surface set.

### HIGH H-5 — SSHConfigImporter multi-target Host wrong hostnames
`Sources/HerminalDB/SSHConfigImporter.swift` (commit `11c65b3`)

`Host a b c` followed by `HostName real.example.com` used to emit
`a` with the block's directives but `b` and `c` with defaults
(hostname == nickname, no user override, port 22). Per OpenSSH
semantics every target in the Host line gets the same directives.

**Fix:** buffer ALL names in the current block, emit one row per
name when the block closes. Existing test rewritten to assert all
targets share hostname/user/port.

### MEDIUM M-1 — ISO8601DateFormatter recreated per log call
`Sources/HerminalApp/Diary.swift` (commit `11c65b3`)

~100µs per log() call on the hot path. Cached as
`nonisolated(unsafe) static let`.

### MEDIUM M-3 — Diary file world-readable
`Sources/HerminalApp/Diary.swift` (commit `11c65b3`)

Tightened `open()` mode from `0o644` to `0o600`. Diary stores
nothing world-readable.

---

## Deferred (tracked for next review cycle)

### MEDIUM M-2 (security) — Single-quoted SSH user/host not allowlist-validated
`Sources/HerminalApp/Workspace/WorkspaceView.swift:406-418`

`quoted()` correctly escapes single quotes, so shell injection
through stored values is currently impossible. But hostname/user
aren't restricted to RFC-compliant character sets at
`SSHHost.validated()` time. Not exploitable today; latent risk if
command construction is ever changed.

**Defer because:** no exploit path exists; the fix changes the
validation rules and could reject legitimate-but-weird hostnames
some users have. Wait for beta feedback before locking the
allowlist.

### MEDIUM M-2 (code) — `cpuSeconds` integer overflow theoretical
`Sources/HerminalAgent/AgentDetector.swift:243`

`machTotal * UInt64(machTimebase.numer)` can overflow before
dividing by `denom`. On Apple Silicon (`125/3`), the overflow
threshold corresponds to ~147 CPU-years of accumulated mach time —
not reachable in practice.

**Defer because:** practical overflow is impossible. Worth a one-line
fix if we ever touch this function for another reason.

### MEDIUM M-3 (code) — BellRegistry unbounded growth
`Sources/HerminalCore/BellRegistry.swift`

The HIGH bell-collision fix (M11-A2) partially mitigates this —
dead surface entries get cleared by `HerminalSurfaceView.deinit`.
If the deinit path ever fails to fire, the dictionary still grows
unbounded.

**Defer because:** the cleanup-on-deinit path catches the common
case. Add an explicit purge on `recordBell` only if a memory
report shows growth.

### MEDIUM M-4 (security) — Symlink race in Diary log truncation
`Sources/HerminalApp/Diary.swift:183-185`

TOCTOU between size check + `Data(contentsOf:)` + `.atomic` write.
A symlink replace between calls would target whatever the symlink
points at. Only matters on the `/tmp` fallback path (sandbox
environments).

**Defer because:** the fallback path is rare and the attack window
is tiny. Add `O_NOFOLLOW` next time this file is touched.

### MEDIUM M-4 (code) — SSH command hostname logged verbatim in Diary
`Sources/HerminalApp/Workspace/WorkspaceView.swift:201,389`

`addTab(command:title:)` writes the full SSH command (including
hostname) to the Diary. `exportRedacted` doesn't redact hostnames.
A user pasting an export into a GitHub issue exposes internal
hostnames.

**Defer because:** export is opt-in; users see the diary content
before pasting. Add a `[ssh]` category-specific redaction rule in
v0.1.1 if a user reports the leak.

### MEDIUM M-4 (code) — ProcessArgvReader unaligned load
`Sources/HerminalAgent/AgentDetector.swift:149`

`buffer.withUnsafeBytes { $0.load(as: Int32.self) }` requires
4-byte alignment that `[UInt8]` doesn't guarantee. Works on Apple
Silicon because ARM64 handles unaligned loads transparently. UB
per the strict spec.

**Defer because:** swap to `loadUnaligned(as:)` is a one-line fix;
take it on the next AgentDetector touch.

### MEDIUM M-5 (security) — NSLog of HERMINAL_TEST_TEXT
`Sources/HerminalApp/AppDelegate.swift`

Closed in M11-A2 — the production binary doesn't include the test
hooks anymore. Within debug builds the log now only fires when
the var is set + prints `count` not the value. **Effectively closed**;
left here for traceability.

### MEDIUM M-6 (security) — Notarytool credentials persist on self-hosted runners
`.github/workflows/release.yml:97-107`

GitHub-hosted runners are ephemeral so this is no-risk today.
Self-hosted runners would persist the credentials across runs.

**Defer because:** we don't run on self-hosted runners. Add the
`if: always()` cleanup step if we ever do.

### MEDIUM — WorkspaceView agentPollTimer nonisolated(unsafe) relies on AppKit guarantee
`Sources/HerminalApp/Workspace/WorkspaceView.swift:43,79-81`

NSView dealloc happens on the main thread per documented AppKit
contract. `nonisolated(unsafe)` is sound in practice but isn't
type-enforced. The comment now cites the AppKit rule.

**Defer because:** the AppKit guarantee holds; the alternative
(`DispatchQueue.main.async { timer.invalidate() }`) inverts the
ownership story. Revisit if Apple ever changes the rule.

### LOW (5 items, all deferred)

- **LOW L-1 (security):** `allow-dyld-environment-variables`
  entitlement — broad but required by libghostty shell-integration.
  Revisit when libghostty no longer needs it.
- **LOW L-2 (security):** `SSHConfigImporter.parseHosts(at:)`
  accepts arbitrary paths. Defer — call sites always pass the
  default; document caller responsibility.
- **LOW L-3 (security):** Port field not range-clamped on decode
  from SQLite. Not exploitable; harmless to `ssh`. Add guard on
  next NotesStore/SSHHostsStore touch.
- **LOW (code):** Magic `36` for `kVK_Return` — add a named
  constant on next HerminalSurfaceView touch.
- **LOW (code):** `BellRegistry.hasRecentBell` window-boundary
  test gap — add a parameterized test on next BellRegistry touch.

---

## What this review did NOT cover

By scope:
- libghostty internals (report upstream)
- macOS sandbox / TCC model
- User's shell + .zshrc + executed commands
- Performance micro-optimizations
- Suggested feature additions

By depth:
- No fuzzing of the SSH config parser
- No threat modelling of NSTextInputClient ↔ IME interaction
- No supply-chain audit of SPM dependencies (just SQLite.swift +
  libghostty submodule)
- No formal verification of the signal handler async-signal-safety
  (review judged it by static inspection of called APIs)

These are deferred to a hypothetical M12 second-pass review when
the codebase grows or the threat model shifts.

---

## Sources

- code-reviewer agent run, 2026-05-25 (full transcript in agent log)
- security-reviewer agent run, 2026-05-25 (full transcript in agent log)
- Fixes shipped in commit `11c65b3` (M11-A2)
- Each finding cited file_path:line_number against the codebase as
  of commit `11c65b3`.
- C2 follow-up: parallel security-reviewer + code-reviewer agent runs,
  2026-06-03, scope v0.3.0–v0.4.2. Fixes shipped in v0.4.3; F1
  regression test in `Tests/HerminalAppTests/ClaudeSessionStoreTests.swift`.
