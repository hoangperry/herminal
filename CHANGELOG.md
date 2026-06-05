# Changelog

All notable changes to herminal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.1] - 2026-06-04

### Added

- **Directional pane navigation.** With recursive splits, "cycle to next
  pane" wasn't enough — `⌥⌘←/→/↑/↓` now move focus to the nearest pane in
  that direction (spatially, on the laid-out frames), the way iTerm2 and
  tmux do. Available from the Window menu and the command palette. No-op
  when there's no pane on that side.

## [0.5.0] - 2026-06-04

Recursive split trees — panes now nest like tmux / iTerm2.

### Added

- **Nested splits.** Any pane can split again along either axis,
  arbitrarily deep — `⌘D` (vertical) / `⌘⇧D` (horizontal) split the
  *focused* pane in place, so you can build layouts like "editor on the
  left, two stacked shells on the right". The old single-axis limit
  (every pane in a tab shared one row or one column) is gone.
- Each split boundary has its own draggable divider; dragging resizes
  that split relative to its own region, so nested panes resize the way
  you'd expect. Closing a pane collapses its split and hands focus to the
  neighbour.

### Changed

- The tab layout is now a binary tree (`LayoutNode`) instead of a flat
  pane list. `workspace.json` gained a `layout` field describing the
  tree; **pre-v0.5 saved sessions still load** — a flat layout folds into
  the equivalent tree on first launch.

### Security

- A parallel code + security review of the refactor (see `docs/REVIEW.md`)
  closed a **boot-loop DoS**: a corrupt or crafted `workspace.json` /
  `workspaces.json` with a deeply-nested layout tree could overflow the
  stack inside the JSON decoder on launch. Both files are now
  depth-checked before decoding, and opening a named workspace runs the
  same sanitiser (cwd validation included) as launch restore.

## [0.4.4] - 2026-06-03

Live working directory surfacing — the terminal now always tells you
where you are. Builds on the v0.4.0 OSC 7 cwd tracking.

### Added

- **Working directory in the status bar.** The bottom strip now leads
  with the focused pane's current directory (abbreviated to `~`),
  truncated from the middle so both the repo root and the leaf dir stay
  readable. The diagnostic chips (tick p95 · agents · diary · theme)
  move to the right.
- **Git branch in the status bar.** When the cwd is inside a git repo,
  the branch shows next to the path (`~/pet-project/herminal · main`).
  Read straight from `.git/HEAD` on each `cd` — no `git` subprocess, no
  polling.
- **Working directory in the tab title.** A tab with no program-set
  title now reads its cwd basename (`api`, `~`) instead of a static
  "herminal". Programs that set their own title (vim, ssh, a prompt with
  `PROMPT_COMMAND`) still win — the OSC 0/2 title always takes priority,
  so nothing regresses for shells that already name their tabs.

## [0.4.3] - 2026-06-03

Quality-hardening release. A parallel security + code-review pass (C2)
over the v0.3.0–v0.4.2 surface — the polish wave and the whole Sessions
milestone, never reviewed before — found and closed one real security
bug plus several correctness issues. No user-facing feature changes.

### Security

- **Shell-injection fix (HIGH).** The Claude session browser interpolated
  a transcript filename stem into the `claude --resume <id>` command,
  which runs via the shell. Because any local process can plant a file
  under `~/.claude/projects/*/`, a crafted filename like `x; rm -rf ~ #`
  could execute when you clicked Resume. The session id is now required
  to be a canonical UUID — the only shape Claude Code writes — so a
  planted filename can never reach the shell. Covered by a new
  parameterized regression test.
- **Search-needle hardening.** Control characters are stripped from the
  ⌘F needle before it's handed to libghostty's binding-action grammar,
  so a pasted needle can't smuggle a second action.
- **Less PII in the unified log.** Diary entries forwarded to `NSLog`
  (readable by any local process via `log stream`) are now redacted —
  the on-disk diary keeps full fidelity, the system-wide log gets the
  home-username masked. Workspace names carrying a path separator or NUL
  are rejected.

### Fixed

- **Sidebar no longer janks** on opening the Claude panel — the
  `~/.claude/projects` scan moved off the main thread.
- **Divider leak** — drag-resize dividers no longer leak via an
  `NSTrackingArea` retain cycle on every split/resize.
- **Command palette** opens with an empty field every time (it used to
  keep the previously-typed query).
- **Session-restore opt-out** is honored — turning restore off no longer
  leaves a snapshot on disk from the launch tab.
- Corrupt (NaN/∞) pane ratios in a hand-edited `workspace.json` can no
  longer reach the layout math.

## [0.4.2] - 2026-06-02

v0.4 milestone slice 3 — **named workspaces**. Closes the Sessions
milestone (Claude browser → restore → named layouts).

### Added

- **Named workspaces.** Save the current tab + split layout under a
  name (Window → "Save Workspace As…", ⌃⌘S, or the command palette),
  reopen it any time from Window → "Open Workspace ▸". Like iTerm2's
  window arrangements, on the same conservative restore policy as
  session restore: layout + per-pane cwd come back as plain shells;
  commands are not replayed.
- The **Open Workspace** submenu is built fresh each time it opens
  (`NSMenuDelegate.menuNeedsUpdate`), so newly-saved layouts show up
  without a relaunch. Hold **Option** on an entry to turn it into a
  delete. Empty state shows a disabled "No saved workspaces".
- New `WorkspacesStore` persists the library to
  `~/Library/Application Support/herminal/workspaces.json` (save
  dedupes by name; sorted case-insensitively for stable menu order).

## [0.4.1] - 2026-06-02

v0.4 milestone slice 2 — **session restore**. Quit with a layout, get
it back on next launch. Builds on the v0.4.0 OSC 7 cwd foundation.

### Added

- **Session restore.** herminal now remembers your tab + split layout
  and reopens it on launch — each pane a plain shell in its last
  working directory. New `WorkspaceStore` persists a JSON snapshot to
  `~/Library/Application Support/herminal/workspace.json` on quit and
  on every structural change (add/close/split tab).
- **Settings → "Restore tabs & panes on launch"** (General tab,
  default on). Turning it off clears the saved snapshot.

### Behaviour notes

- Restore replays the **layout + cwd**, not commands. ssh / claude /
  arbitrary commands are NOT re-run — those are side-effectful
  (network connections, LLM resumes) and surprising on every launch.
  A former ssh pane comes back as a clean local shell.
- Every restored cwd is validated against the local filesystem; a
  stale or remote path (e.g. an ssh pane's remote dir) falls back to
  the shell's home rather than failing to spawn.
- Closing the last tab does NOT overwrite the snapshot — the window
  is closing, so the last real layout survives for next launch.

## [0.4.0] - 2026-06-01

v0.4 milestone slice 1 — **Claude session browser**. The feature the
"terminal for devs living in Claude Code" tagline always promised.

### Added

- **Claude session browser (⌘⇧C).** A new left sidebar reads Claude
  Code's own transcript store at `~/.claude/projects/` and lists every
  project you've run `claude` in — sorted by last-active, showing the
  real cwd, git branch, and how recently you touched it. One click:
  - **Resume** opens a tab running `claude --resume <id>` in the
    project's working directory — reattaches the exact conversation.
  - **Open Shell Here** (context menu) drops a plain shell in that cwd.
- **`ClaudeSessionStore`** — reads only the first 16 KB of each
  project's newest transcript, so a multi-hundred-MB session file
  costs two syscalls, not a parse. The project slug (`/`→`-`) is
  lossy (a real hyphen is indistinguishable from a path separator —
  e.g. `andromeda-next`), so the real cwd is parsed from the
  transcript body, never decoded from the slug.

### Foundation (also new, reused by future session-restore work)

- **OSC 7 working-directory tracking.** `GHOSTTY_ACTION_PWD` is now
  wired — every pane learns its live cwd as the shell reports it.
- **`working_directory` spawn support.** Tabs can open in a specific
  directory (used by Resume + Open Shell Here). Plumbed through
  `HerminalSurfaceView` / `TerminalSession` / `WorkspaceTab` /
  `addTab`.

## [0.3.3] - 2026-05-30

Polish-wave slice 4 — drag-resize splits.

### Added

- **Drag-resize splits.** A draggable handle now sits on the gap
  between split panes — grab it (the cursor turns into the resize
  arrows) and drag to rebalance. Replaces the old fixed even-split.
  `WorkspaceTab` gains a `paneRatios` array (fractions summing to 1.0,
  kept in lock-step with `panes`); `split` halves the focused pane,
  `close`/`removePane` redistribute, and `adjustDivider` moves a
  divider clamped so neither neighbour drops below 8 % of the axis.
- `PaneDividerView` — 8 px transparent hit target centred on the gap,
  platform resize cursor on hover, faint accent line while dragging.

### Notes

- Caret blink phase-reset (audit §7 Open Q2) stays **deferred**:
  libghostty exposes no cursor/blink API to the host — the blink is
  render-side only, so a reset-on-keypress would need an upstream
  libghostty patch. Documented, not attempted.
- This is the final slice of the v0.3 polish wave. Remaining audit
  items (image rendering, semantic double-click, font picker UI) are
  feature work, not polish — they belong in a later milestone.

## [0.3.2] - 2026-05-28

Polish-wave slice 3 — the headline feature.

### Added

- **Scrollback search (⌘F)** — a floating bar appears top-right of
  the active pane. Type to filter, ⌘G / Enter for next match,
  ⌘⇧G for previous, Esc to dismiss. libghostty owns the match
  machinery via `start_search` / `search:<needle>` /
  `navigate_search:next|previous` / `end_search` binding actions;
  HerminalApp owns only the AppKit overlay UI.
- Four new `GhosttyApp.handleAction` cases (START_SEARCH,
  END_SEARCH, SEARCH_TOTAL, SEARCH_SELECTED) bridged to
  AppKit notifications. WorkspaceView's `searchNeedleSubscription`
  (Combine) propagates text-field edits back into the
  `search:<needle>` binding action so libghostty re-scans live as
  the user types.
- Command palette gains a "Find in Terminal…" entry that mirrors
  the ⌘F shortcut so discovery via ⌘⇧P still works.

This closes the audit's top-3 finding — "Terminal mà không search
được output để debug là đồ chơi, không phải công cụ" (docs/research/
09-polish-audit.md §2 row 1).

## [0.3.1] - 2026-05-28

Polish-wave slice 2 — two "magic feature" items.

### Added

- **Command palette (⌘⇧P)** — fuzzy launcher over the workspace.
  Indexes 15 actions (tabs, splits, sidebars, theme, Settings,
  hotkey). NSPanel + SwiftUI, dispatches via the responder chain so
  the palette doesn't reimplement any handler — adding a new menu
  item only needs an entry in `CommandPaletteAction.all`.
- **Global hotkey ⌥Space** (Carbon `RegisterEventHotKey`) brings
  herminal forward from anywhere on macOS, or hides it if already
  key. iTerm2's "gateway-drug" pattern. No accessibility permission
  required (Carbon API doesn't need it; NSEvent monitors would).
  Menu fallback (`Window → Show Hotkey Window`) covers the case
  where the combo is already grabbed by another app.

### Notes

Slice 3 of the wave (scrollback search ⌘F + drag-resize splits +
caret blink reset) deferred — needs a libghostty integration spike
first (open questions in `docs/research/09-polish-audit.md` §7).

## [0.3.0] - 2026-05-28

First slice of the v0.3 polish wave — addresses the owner's "xài
vẫn không đã" feedback diagnosed in `docs/research/09-polish-audit.md`.
This release ships visible chrome polish only; scrollback search +
command palette + hotkey window land in later slices of the wave.

### Added

- **Vibrancy.** `WorkspaceView` now lives inside an
  `NSVisualEffectView(.underWindowBackground, .behindWindow)`. Window
  background blends with whatever sits behind it (the macOS dock,
  another window, a wallpaper) instead of reading as a flat hex
  rectangle. Audit root-cause #1.
- **Content padding.** 6 px inset between the libghostty Metal
  surface and the pane chrome. The previous flush-against-edge
  layout read as cheap. New `HerminalDesign.Geometry.surfaceInset`
  token.
- **Tab inactive opacity.** Non-active, non-hovered tabs render at
  62 % opacity so the active tab reads as the focus point.
- **Right-click context menu** on terminal surfaces — Copy / Paste /
  Select All. Only fires when libghostty isn't capturing the right
  click itself (vim mouse mode wins). Closes audit gap #6.

### Changed

- **Spring animations** for tab hover transition. New
  `Motion.springResponse` / `springDamping` tokens (0.32 / 0.78 —
  Linear.app's published ratio). Replaces `.easeOut` linear at this
  call site; sidebar slide stays on AppKit `NSAnimationContext`.

## [0.2.5] - 2026-05-27

### Fixed / Added

- **I-beam cursor over the terminal** (instead of arrow). The default
  `NSCursor` for `HerminalSurfaceView` is now `.iBeam` — a terminal
  IS a text surface. `GHOSTTY_ACTION_MOUSE_SHAPE` is wired so vim
  mouse mode, URL hover, and resize handles drive the correct cursor
  (pointing-hand, crosshair, etc.). 12 shapes mapped; the long tail
  falls back to `.arrow`.
- **`GHOSTTY_ACTION_OPEN_URL`** — clicking a URL libghostty detected
  in terminal output now opens the user's default browser via
  `NSWorkspace.shared.open`. Scheme allow-list (`http`, `https`,
  `mailto`) — `file://` and arbitrary schemes are rejected so a
  hostile shell can't paste a `file:///etc/passwd` payload that
  pops Finder.

## [0.2.4] - 2026-05-27

### Fixed

- **Tab title updates from shell.** Fourth stub in the audit window:
  `GhosttyApp.handleAction` was a one-case switch (RING_BELL).
  SET_TITLE / SET_TAB_TITLE returned false (= unhandled), so OSC 0/2
  escapes from the shell or libghostty's `set_tab_title` keybinding
  silently disappeared. Now the action is routed via a new
  `surfaceTitleDidChangeNotification` → WorkspaceView rebuilds the
  tab strip with the new title. Restores the default label when the
  shell sets an empty title.

### Added

- `Scripts/verify-title.sh` — programmable round-trip test that
  injects `printf '\033]0;MARKER\007'` and asserts `active_title`
  changes. Runs as part of `dogfood-daily.sh`.

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
