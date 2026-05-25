# Review report — M11-A (2026-05-25)

Parallel code-reviewer + security-reviewer agents audited the v0.1.0
codebase before publish. This document captures what they found, what
shipped fixed, and what stays deferred — so future reviews start
from the right baseline.

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
