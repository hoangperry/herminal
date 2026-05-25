# herminal architecture

One-page system overview. Read this before the first PR — it's the
mental model the rest of the docs assume.

---

## Layers (top to bottom)

```
┌──────────────────────────────────────────────────────────────────┐
│  AppKit chrome + SwiftUI panels        ← Sources/HerminalApp/    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  WorkspaceView (NSView)                                    │  │
│  │  ├── TabBarView (SwiftUI host)                             │  │
│  │  ├── AgentDashboardView | SSHHostsPanel  (left, mutex)     │  │
│  │  ├── NotesPanelView                       (right)          │  │
│  │  └── WorkspaceTab[*]                                       │  │
│  │       └── TerminalSession[*]                               │  │
│  │            └── HerminalSurfaceView (NSView + IME)          │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Diary (telemetry-free crash diary)                              │
│  Updater (Sparkle wiring stub — no SPM dep yet)                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  HerminalAgent — process tree + agent detection                  │
│  ├── AgentDetector (sysctl process walk)                         │
│  ├── ProcessSnapshot (one-shot KERN_PROC_ALL)                    │
│  ├── ProcessArgvReader (KERN_PROCARGS2)                          │
│  ├── AgentStatusTracker (CPU sampling via proc_pid_rusage)       │
│  ├── AgentPaneMapper (login → session pairing by start-time)     │
│  └── AgentKind, AgentStatus, DetectedAgent                       │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  HerminalDB — local persistence                                  │
│  ├── NotesStore (SQLite WAL, per-session notes)                  │
│  ├── NotesExporter (Markdown round-trip)                         │
│  ├── SSHHostsStore (SQLite WAL, SSH host metadata)               │
│  └── SSHConfigImporter (pure parser for ~/.ssh/config)           │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  HerminalCore — libghostty C ABI bridge                          │
│  ├── GhosttyApp (init, runtime config, action dispatch)          │
│  └── BellRegistry (RING_BELL → needs-input signal)               │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  GhosttyKit.xcframework — libghostty 1.3.1 (Zig)                 │
│  Static linked. Owns the Metal layer + PTY + VT parser.          │
└──────────────────────────────────────────────────────────────────┘
```

---

## Data flow — keystroke to render

1. macOS dispatches `keyDown` to `HerminalSurfaceView` (NSView).
2. NSView routes through `NSTextInputClient` so IME can compose.
3. Plain key: `sendKey()` → `ghostty_surface_key()`.
   IME-committed text: `interpretKeyEvents` accumulates →
   `sendKey()` with text.
4. libghostty writes to the PTY's master.
5. Shell reads from the PTY's slave; output flows back through
   libghostty's renderer thread.
6. libghostty's Metal layer renders into the NSView at 60 Hz
   (driven by herminal's tick `Timer`, since libghostty's
   `wakeup_cb` is a no-op for the embedded apprt).

Latency probe (`LatencyProbe`) measures tick overhead in p50/p95/p99.
M2 target: p95 keydown → render < 20 ms. Actual: < 5 ms.

---

## Data flow — agent detection

Runs every 2s on the main actor while the agent dashboard is open
(`WorkspaceView.startAgentPolling`):

1. `AgentDetector.detectAgents()` builds a fresh `ProcessSnapshot`
   via `sysctl(KERN_PROC_ALL)`.
2. Walks herminal's subtree via PPID. For each child:
   - Direct match: `p_comm` matches a known agent name?
   - Wrapper fallback: `p_comm` matches `isInterpreter(name:)`
     (node/python/bun/deno)? Read argv via `ProcessArgvReader`
     and try `AgentKind.detect(interpreterArgv:)`.
3. `AgentStatusTracker.annotate(_:)` samples per-PID CPU via
   `proc_pid_rusage` (mach-time conversion via cached
   `mach_timebase_info`). First sighting = `.unknown`; subsequent
   delta over threshold = `.running`; else `.idle`.
4. `AgentPaneMapper.annotate(_:)` lists herminal's `login` children
   by kernel start time, pairs nth-oldest login → nth-oldest
   `TerminalSession.createdAt`, walks each agent's PPID chain to
   its login ancestor, assigns `tabHint`.
5. `BellRegistry.hasRecentBell(forSurfaceAddress:)` per surface;
   any recent bell → promote running/idle agents to `.needsInput`.
6. `AgentDashboardView` renders the annotated list with status
   color dot + "Tab N" chip.

---

## Data flow — SSH connect

1. User clicks "Connect" on a saved `SSHHost` row.
2. `WorkspaceView.connectSSH(_:)` builds the shell command via
   `sshCommand(for:)` (single-quoted user@host, `-p N` only when
   port != 22).
3. `addTab(command:title:)` creates a new `WorkspaceTab` →
   `TerminalSession(command:)` → `HerminalSurfaceView(command:)`.
4. The command string is `strdup`'d into a heap buffer owned by
   the view (lives for the surface's lifetime, freed in `deinit`).
5. On `viewDidMoveToWindow`, `createSurface()` builds a
   `ghostty_surface_config_s` with `config.command = commandBuffer`.
   libghostty auto-sets `wait-after-command=true` so the pane
   stays visible after `ssh` exits.
6. `sshHostsStore.touchLastConnected(id:)` stamps the host's
   last-connected timestamp.
7. `refreshSSHPanel()` re-renders the panel so the recency badge
   updates immediately.

---

## Storage

| Store | Path | Schema |
|---|---|---|
| Notes | `~/Library/Application Support/herminal/notes.db` | `notes(id, session_id, body, created_at, updated_at)` indexed on `session_id` |
| SSH hosts | `~/Library/Application Support/herminal/ssh-hosts.db` | `ssh_hosts(id, nickname, hostname, username, port, created_at, updated_at, last_connected_at)` indexed on `updated_at DESC` |
| Diary | `~/Library/Application Support/herminal/diary.log` | Append-only text; truncated to ~1 MB at launch |

Both DBs use SQLite WAL. WAL means atomic writes without
blocking readers — relevant because the agent-poll cycle reads
the SSH hosts on every refresh while the UI might be writing
through the add/edit form.

No DBs hit the network. No telemetry.

---

## Threading + isolation

- Everything app-side is `@MainActor` by default.
- libghostty's C callbacks (renderer, IO, runtime) fire from
  arbitrary threads. Wrappers use `nonisolated(unsafe)` for C
  handles + `MainActor.assumeIsolated` for Sendable closures
  that always run on main (see `docs/PATTERNS.md` for the recipes
  and where they're used).
- SQLite stores are `final class` constrained to a single
  isolation domain — `WorkspaceView` (main actor) holds them and
  is the only caller.

---

## Test boundary

| Test type | Location | Coverage |
|---|---|---|
| Unit tests (Swift Testing) | `Tests/Herminal{Core,DB,Agent,App}Tests/` | Logic in each module + bridge state machines (IME, agent matching, CPU sampling, redaction) |
| Integration scripts | `Scripts/verify-*.sh` | Real binary launch with env-driven test hooks (text injection, agent spawn, ssh spawn, compat matrix) |
| Smoke harness | `Scripts/dogfood-daily.sh` | Runs all 5 integration scripts + diary tail |
| Owner-manual | `docs/QA/*.md` | IME composition (Vietnamese + CJK), dogfood journal |

Test hooks (`HERMINAL_TEST_*` env vars) are read ONLY by
`AppDelegate.applicationDidFinishLaunching`. Production paths
never branch on them.

---

## Build + distribute

```
Scripts/bootstrap.sh        → Vendor/libghostty → GhosttyKit.xcframework  (~5-15 min cold)
swift build                 → SPM core libraries
swift test                  → 77 unit tests
Scripts/make-app-bundle.sh  → .build/herminal.app (ad-hoc signed)
Scripts/sign-and-notarize.sh→ .build/release/herminal.app (Developer-ID + notarytool)
Scripts/make-dmg.sh         → .build/release/herminal-vX.Y.Z.dmg
Scripts/release.sh X.Y.Z    → tag + signed build + zip + dmg + draft release
```

CI mirrors this in `.github/workflows/{ci,release}.yml`.

See `docs/RELEASE.md` for the per-release human steps.
