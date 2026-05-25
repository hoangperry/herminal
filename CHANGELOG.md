# Changelog

All notable changes to herminal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

**Preferences foundation (M12-P1)**
- `Preferences` enum centralises 8 UserDefaults keys (theme, terminal
  font size + padding, cursor blink, default shell path, status-bar
  visibility, close-with-note confirmation, first-run flag) with a
  single `defaultsDictionary()` registered at launch.
- SwiftUI Settings scene (`PreferencesView`) — 4 tabs (General /
  Appearance / Terminal / Shell), bound via `@AppStorage`, hosted in an
  AppKit window by `PreferencesWindow`. Opens via `⌘,` from the app
  menu.
- Theme picker gains a "Follow System" option that reads
  `NSApp.effectiveAppearance` at launch and on each `Preferences`
  notification, mapping to dark or light. Manual `⌘⇧L` still works
  but resets when the picker is changed.
- AppKit listeners (`WorkspaceView`) repaint chrome when
  `Preferences.didChangeNotification` fires so theme flips from the
  Settings window reflow the tab bar, sidebars, notes pane, and
  window background without a relaunch.

**Agent dashboard depth (Theme A — fully closed in M8/M9)**
- Node/Python-wrapped agent detection via `sysctl(KERN_PROCARGS2)`.
  Catches `npx @anthropic-ai/claude-code`, `python3 -m aider`, etc. —
  agents that previously showed as `node` or `Python`. Display name
  becomes `aider (Python)` for transparency. Closes Q3-002 (M3 carry).
- BEL / OSC 9 → `needs input` agent status. `BellRegistry` (singleton
  in HerminalCore) records bell events from `GHOSTTY_ACTION_RING_BELL`;
  dashboard promotes running/idle → `.needsInput` when any surface
  rang its bell in the last 10s. Closes Q6-001 (M6 carry).
- Agent ↔ pane attribution via `AgentPaneMapper`. Walks each agent's
  PPID chain to its login ancestor, pairs nth-oldest login (by kernel
  start time) with nth-oldest session (by creation time). Dashboard
  shows `Tab N` chip next to each detected agent.

**Workspace + chrome (Theme C slice 1)**
- Light theme variant. Every Palette token branches on
  `HerminalDesign.currentTheme`; `⌘⇧L` toggles between dark and
  light. Auto-follow-system deferred to a later slice. Closes
  Q5-002 (M5 carry).

**SSH manager v1 slice 1 (Theme B)**
- `~/.ssh/config` import. File menu → `Import ~/.ssh/config` parses
  every concrete Host block (wildcard blocks + Match blocks skipped)
  and upserts as `SSHHost` rows with fresh UUIDs (additive merge —
  no silent overwrite).

**Observability (Theme F slice 1)**
- `Diary.exportRedacted()` rewrites user-home paths + libghostty
  surface addresses for safe bug-report pasting. PIDs preserved as
  useful + non-PII. No auto-upload — explicit user action only.

**Documentation (Theme G slice 1)**
- `docs/PATTERNS.md` capturing seven recurring codebase shapes
  (MainActor.assumeIsolated, nonisolated(unsafe), sysctl over
  libproc, mach-time conversion, HERMINAL_TEST_* env hooks,
  single-isolation final-class stores, coarse-but-honest > fine-
  but-misleading).
- `README.vi.md` — Vietnamese mirror of `README.md` for the PRD
  target audience.
- `docs/QA/cjk-ime-checklist.md` — Korean / Japanese / Chinese
  IME smoke matrices (20 phrases each) for owner-manual runs.

**Tooling**
- `HERMINAL_TEST_DELAY=12` in integration scripts. M6+M8 startup
  work (Diary signal handler init, BellRegistry, agent CPU
  sampling) pushed shell-prompt-ready past the previous 8s harness
  window on heavy `.zshrc` setups. AppDelegate default unchanged.

### Fixed

- M8 — Singleton state race in `BellRegistryTests`. Added
  `.serialized` suite trait so Swift Testing doesn't run cases in
  parallel and let one's bells leak into another's counter.
- M9 — `release.sh` dirty-tree check tripped on libghostty
  submodule's untracked `zig-pkg/` build directory. Now uses
  `git status --ignore-submodules=dirty` so the submodule SHA pin
  is what matters, not its working tree.

---

## [0.1.0] — Pre-release (M7 beta)

First public release. 7-month MVP complete: libghostty-backed terminal
core, Vietnamese IME bridge, multi-session workspace with splits,
agent dashboard with running/idle discrimination, per-session SQLite
notes with markdown round-trip, SSH Connection Manager, premium
dark chrome with polish.

### Added

**Terminal core (M1)**
- libghostty 1.3.1 embedded via `GhosttyKit.xcframework` static link
- Swift 6 `HerminalSurfaceView` (AppKit `NSView` + Metal layer)
- `NSTextInputClient` bridge for IME composition (Telex / VNI / KR / JP / CN)
- 60 Hz tick driver for the libghostty event loop
- Keystroke latency probe (p95 < 5 ms keydown → render)

**Workspace (M2)**
- Multi-tab `WorkspaceView` with manual layout (avoided `NSSplitView`)
- Vertical + horizontal pane splits, single-axis per tab
- Premium Raycast/Linear-style dark design system (OKLCH palette,
  SF system fonts, 4-pt spacing grid)
- tmux compatibility verified against vim / less / htop

**Agent + Notes (M3)**
- `AgentDetector` — sysctl-based process subtree walk + agent kind
  matching (claude / codex / aider)
- `AgentDashboardView` left sidebar (Cmd+Shift+A toggle)
- `NotesStore` — SQLite WAL store with atomic upsert
- `NotesPanelView` right sidebar (Cmd+Shift+N), per-session note,
  autosave, Markdown export/import

**Test harness + SSH (M4)**
- `HERMINAL_TEST_TEXT` env hook + `ghostty_surface_text` injection —
  closes the 3-month verification gap
- Bracketed-paste-aware `injectText` (splits on `\n`, sends Enter
  via `ghostty_surface_key`)
- `SSHHost` model + `SSHHostsStore` SQLite WAL persistence
- `SSHHostsPanel` left sidebar (Cmd+Shift+S, mutex with agent panel)
- `connectSSH(_:)` spawns `ssh user@host` in a new tab via
  `libghostty config.command` override

**Compat + polish + signing (M5)**
- Compatibility matrix verified: vim, tmux, nano, less, htop, fzf,
  lazygit, btop, starship — 9/9 launch + persist
- Sidebar slide animation via `NSAnimationContext` + animator proxy
- Hover state on every interactive chrome surface (tab chips, close
  buttons, add buttons, SSH rows)
- VoiceOver accessibility labels across sidebars, rows, action buttons
- `IMEBridgeTests` — 8 unit tests for the Swift `NSTextInputClient`
  state machine
- `Scripts/sign-and-notarize.sh` — Developer-ID signing + notarytool
  + stapler pipeline (env-driven, ad-hoc fallback)
- `App/herminal.entitlements` — hardened runtime with libghostty
  exceptions (JIT, unsigned-mem, dyld-env, library-validation)

**Dogfood infrastructure (M6)**
- `Diary` singleton — telemetry-free local crash diary (ring buffer +
  signal handler writing through pre-opened FD via async-signal-safe
  `write(2)`)
- `Scripts/dogfood-daily.sh` — runs all 5 integration scripts +
  diary tail in one command
- `AgentStatusTracker` — CPU-delta heuristic via `proc_pid_rusage`
  with mach-timebase conversion (running / idle / starting badges)
- Dogfood checklist + journal template + day-1 baseline entry

### Fixed

- M4-1 — `proc_listchildpids` returns garbage on macOS Sequoia;
  AgentDetector now uses `sysctl(KERN_PROC_ALL)` (same path as
  `ps` / `pgrep`).
- M4-1 — Bracketed-paste mode in libghostty swallowed harness Enter;
  `injectText` now splits on `\n` and synthesizes Return via
  `ghostty_surface_key`.
- M6 — `proc_pid_rusage` returns mach absolute time units, not
  nanoseconds; cached `mach_timebase_info()` ratio fixes the 42×
  under-reporting that made every agent look idle.
- M6 — `Scripts/dogfood-daily.sh` flake under back-to-back runs
  (stale `pkill -9` resources); added 2s settling sleep between checks.

### Known limitations (deferred to post-MVP)

- Agent↔pane mapping — libghostty exposes no per-surface PID
- Node-wrapped agent CLI detection (Q3-002)
- Recursive split trees (Q2-003)
- Drag-to-resize pane dividers (Q2-002)
- OSC 9 / BEL "needs input" agent status (Q6-001)
- Light theme variant (Q5-002)
- Group / search / `~/.ssh/config` import in SSH manager
- App Store distribution (sandbox incompatible)
- Cross-platform (Linux / Windows) — macOS-only by design

[Unreleased]: https://github.com/hoangperry/herminal/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/hoangperry/herminal/releases/tag/v0.1.0
