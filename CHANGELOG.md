# Changelog

All notable changes to herminal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.3] - 2026-05-27

### Fixed

- **`exit` now actually closes the pane.** Third stub-from-spike in
  the same audit pass: `close_surface_cb` was a no-op, so when the
  shell exited the pane locked onto the "Process exited" placeholder
  until the user manually ⌘W'd out. Wired to a NotificationCenter
  post → WorkspaceView removes the matching pane (closing the tab
  if it was the last pane in that tab). Used by `exit`, shell crash,
  PTY disconnect.
- New `WorkspaceTab.removePane(at:)` so libghostty can remove a
  non-focused pane (the existing `closeFocusedPane()` assumed the
  user was driving the close).

## [0.2.2] - 2026-05-27

### Fixed

- **Text selection by mouse drag now works.** v0.2.1 wired the
  clipboard callbacks but `HerminalSurfaceView` had no mouseDown /
  mouseDragged / mouseUp handlers, so libghostty never received the
  events that build a selection — `ghostty_surface_has_selection`
  always returned false and Copy stayed grey. Forwarded the full
  mouse-event suite (left/right/middle button, drag, move, scroll
  wheel) to `ghostty_surface_mouse_pos` / `_button` / `_scroll`.
- Right-click and middle-click also forwarded; trackpad scroll uses
  a 2× multiplier to feel right in a terminal (matches the Ghostty
  reference impl).

## [0.2.1] - 2026-05-26

### Fixed

- **Clipboard now works.** ⌘C / ⌘V were no-ops in v0.2.0 because the
  libghostty `read_clipboard_cb` and `write_clipboard_cb` runtime
  callbacks were stubs. Both are now wired to `NSPasteboard.general`,
  and the Edit menu surfaces the standard Cut / Copy / Paste / Select
  All items routed through `ghostty_surface_binding_action`.
- New `ClipboardOwner` protocol in `HerminalCore` lets the C clipboard
  callback round-trip the per-surface userdata pointer back to a live
  `ghostty_surface_t` without dragging `HerminalApp` types across the
  module boundary.

## [0.2.0] - 2026-05-26

First feature release after v0.1.0 beta — bundles M8-M13 work. All
v0.1.0 work shipped except notarization (which v0.2.0 includes for
the first time). Highlights:

- Preferences foundation + Settings scene with Follow System theme.
- Status bar at window bottom (live tick p95, agents, diary size,
  theme).
- First-run welcome hint, tab close confirmation when notes exist,
  window state restoration.
- ~/.ssh/config import. Light theme variant. Agent dashboard depth
  (node/python wrappers, OSC 9 / BEL needs-input promotion, agent ↔
  pane mapping).
- Diary.exportRedacted() for safe bug-report sharing.
- Vietnamese README. PATTERNS.md, ARCHITECTURE.md, REVIEW.md,
  FAQ.md, TROUBLESHOOTING.md, KEYBOARD-SHORTCUTS.md, ROADMAP.md.
- Marketing kit (landing page, Product Hunt, Show HN, Reddit, demo
  script, 3 kernel-gotcha blog drafts).
- Developer-ID signed + notarized + stapled bundle. Gatekeeper-clean
  for end users.

See detail sections under "Added" / "Fixed" below — each bullet
preserves its M8 / M9 / M10 / M11 / M12 / M13 tag for traceability.

### Added

**Window state restoration (M12-P5)**
- Window frame (x/y/width/height) persists across launches via a new
  internal `WindowState` namespace under UserDefaults. Validated on
  load — frames whose centre lies off every currently-attached screen
  fall back to the default centred geometry, so disconnecting a second
  monitor doesn't strand the window.
- Left sidebar (Agents / SSH / none) and Notes panel visibility also
  persist. WorkspaceView restores both BEFORE the first layout pass
  so the user lands in the same workspace shape they left.
- AppDelegate is the NSWindowDelegate; `windowDidMove` / `windowDidResize`
  write the latest frame back to UserDefaults.

**Tab close confirmation (M12-P4)**
- Closing a tab whose panes hold a non-empty note now shows an NSAlert
  asking for confirmation. The check runs on both close paths: the
  TabBar `×` click and the `⌘W` menu shortcut when it would collapse
  the last pane. Multi-pane tabs only prompt when the final pane is
  being closed, so routine pane management stays frictionless.
- Honours the `confirmCloseWithNote` preference — owners who want the
  old fire-and-forget behaviour can disable the check in Settings.
- Note: notes are NOT deleted on tab close; they remain in SQLite
  keyed by the (now-orphaned) session UUID. The prompt makes that
  explicit so the owner can make an informed choice.

**First-run welcome hint (M12-P3)**
- One-shot overlay on first launch: dim backdrop + centred card listing
  the 7 most-used shortcuts (new tab, split right/down, agents, SSH,
  notes, Settings). Dismiss via `Got it`, Enter/Return, or by clicking
  the backdrop. Marks `Preferences.firstRunCompleted = true` and never
  shows again. Stays out of the way for every other launch.

**Status bar (M12-P2)**
- New 22pt strip at the window bottom showing live tick-latency p95
  (from `LatencyProbe.snapshotP95Milliseconds()`), detected agent count
  (cached from the 2 s agent poll regardless of dashboard visibility),
  diary file size, and the current theme — with a `(system)` tag when
  `Follow System` is selected.
- Refreshes once per second from a SwiftUI Timer publisher inside
  `StatusBarView`; the underlying reads are cheap (one sort over ≤600
  doubles + one stat(2) + one int read), so the overhead is negligible.
- Visibility honours the `showStatusBar` preference (M12-P1). Hiding
  the bar removes the strip entirely — sidebars + surface container
  reclaim the height.

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
