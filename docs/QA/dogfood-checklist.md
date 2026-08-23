# Dogfood Checklist — what to look for during M6

Use this as a reference while running the 30-day daily-driver. Not a
to-do list — a *recognition* list, so when something feels off you can
match it against a known category instead of just trying again.

## Day-1 spot checks

These run once at the start of the 30 days; they don't need re-running
each day.

- [ ] Run `Scripts/verify-smoke-m1-m3.sh` from a clean build.
- [ ] Run `Scripts/verify-codex-detection.sh` after installing a real
  `codex` (or leave the fake from M4-1 in place).
- [ ] Run `Scripts/verify-ssh-spawn.sh` against `localhost` if SSH is
  enabled on the box.
- [ ] Run `Scripts/verify-compat-matrix.sh` once — should be 9/9 from M5-1.
- [ ] Walk through `docs/QA/vietnamese-ime-checklist.md` (the IME
  smoke that's been parked 4 months).
- [ ] Tail `~/Library/Application Support/herminal/diary.log` and
  confirm it's getting populated.

## What to watch for daily

### Performance feel

- p95 keystroke latency stays imperceptible. The M2 latency probe
  reports per-tick into stderr; if a row is >5ms p95 something is
  wrong.
- Scrollback through a large `cat` doesn't stutter.
- Resizing the window stays smooth (no checkerboard pause).

### Interaction quality

- Tab switching feels instant.
- Sidebars slide in/out (M5-2 animation) — no popping.
- Hover states fire on every interactive surface.
- Cmd+T / Cmd+W / Cmd+D shortcuts all work from any window state.

### Core terminal verbs (v0.2.2 lesson — these have a regression history)

Each of these is the kind of UX path that "looks fine" in casual
testing but can silently break with a stub-from-spike. The clipboard
no-op survived 12 months because nobody verified the round-trip
end-to-end. If any of these regress, look first at libghostty's
runtime callbacks / surface events — not the application layer.

- [ ] **Drag-select text** with the mouse. Highlight visible while
  dragging, persists after release.
- [ ] **Cmd+C** with a selection → paste in TextEdit shows the text.
- [ ] **Cmd+V** in a shell prompt → clipboard contents arrive.
- [ ] **Cmd+V with multiline text** → a warning appears with
  **Cancel Paste** focused by default. Cancel sends nothing; **Paste
  Anyway** sends the exact text once.
- [ ] **OSC 52 write** — run
  `printf '\033]52;c;aGVybWluYWwtb3NjNTI=\007'`. Herminal asks before
  replacing the clipboard; **Don’t Allow** keeps the previous clipboard,
  while **Allow Once** writes `herminal-osc52`.
- [ ] **OSC 52 read** → Herminal asks before disclosing the macOS
  clipboard. **Don’t Allow** returns an empty response. Verify keyboard
  focus starts on the safe action and VoiceOver reads the risk explanation.
- [ ] **Edit menu** shows Cut / Copy / Paste / Select All. Copy
  greyed out when nothing is selected.
- [ ] **Right-click** routes to libghostty when the surface claims the
  event and otherwise falls back to Herminal's local context menu with
  Copy, Paste, Select All, and Find in Terminal… (no NSBeep, no missing
  events).
- [ ] **Trackpad scroll** through `cat`-style long output — smooth,
  no kinetic-phase stutter.
- [ ] **Cmd++ / Cmd+-** adjusts font size. (Wired via libghostty
  binding action.)
- [ ] **Cmd+A** selects the whole visible buffer (libghostty
  `select_all` binding).
- [ ] **Type `exit` + Enter** in the default shell. The pane (and
  tab, if it was the last pane) closes automatically. v0.2.3 lesson
  — `close_surface_cb` was a no-op until then, so `exit` left the
  pane locked on "Process exited" until ⌘W.
- [ ] **Tab title updates from shell.** Run
  `printf '\033]0;mytab\007'` in a pane — the tab strip label
  switches to `mytab`. vim / htop / starship-style prompts that set
  OSC 0/2 will keep the tab strip in sync. v0.2.4 lesson — title
  actions were dropped because `handleAction` only routed
  `RING_BELL`. Programmable check lives in `verify-title.sh`.
- [ ] **Full Keyboard Access tab strip.** Enable macOS Full Keyboard
  Access, Tab to a tab chip, then press Return or Space. The teal focus
  outline is visible, the tab activates, and the adjacent close / new-tab
  controls expose distinct VoiceOver names without shortening long titles.
  Toggle the theme or let the shell update its title while focus is in the
  strip; focus must remain on the same control. With Reduce Motion enabled,
  focus and hover state changes must not animate.
- [ ] **First-run welcome modal.** Reset the welcome hint in Settings and
  relaunch. “Got it” receives initial keyboard focus; Return activates it
  and Escape dismisses from anywhere in the card. Clicking the dim backdrop
  does not consume one-shot onboarding. VoiceOver announces “Welcome to
  herminal” as a heading, treats the card as modal content, and reads each
  shortcut as one action-plus-key sentence. After dismissal, typing goes
  straight to the active terminal without another click.
- [ ] **Status bar discovery and VoiceOver summary.** Use View → Hide/Show
  Status Bar, then search “status” in ⌘⇧P and run Toggle Status Bar; both
  paths update the 22 pt strip immediately and persist the choice. Tab to the
  working-directory menu and verify Copy Full Path and Reveal in Finder.
  VoiceOver exposes that menu and the read-only workspace diagnostics as two
  concise stops; decorative folder/branch symbols are not announced separately.
- [ ] **Command palette results.** Open ⌘⇧P, type a query, and use ↑ / ↓
  then Return to run the highlighted command. With Full Keyboard Access,
  Tab to a result and activate it with Return or Space; Esc closes from the
  field or any result. VoiceOver announces each command, optional shortcut,
  result position, and selected state. Reduce Motion disables animated
  selection scrolling.
- [ ] **Cursor is an I-beam** when hovering the terminal (not the
  default arrow). v0.2.5 lesson — `GHOSTTY_ACTION_MOUSE_SHAPE` was
  unhandled; the terminal surface now defaults to `.iBeam` and
  swaps based on the action (vim mouse mode, URL hover, etc).
- [ ] **Cmd+click a URL** rendered in terminal output (paste a link
  into a `cat` first if your shell doesn't expose any) → default
  browser opens. v0.2.5 lesson — `GHOSTTY_ACTION_OPEN_URL` was
  unhandled. Only `http`, `https`, `mailto` allowed; `file://`
  rejected.
- [ ] **⌘F search** opens the find bar top-right of the active pane and
  the first character typed lands in its field immediately. Pressing ⌘F again
  while the bar is open returns focus to the query field. Typing highlights
  matches, ⌘G / ⌘⇧G navigates, and Esc closes. Changing the query immediately
  returns the result chip to “Search in progress” instead of retaining the
  previous query's count. The Previous/Next controls and Edit-menu commands
  stay disabled while the query is empty, scanning, or has no matches, then
  become available with the first result. With VoiceOver, the result count is
  announced as searching / no matches / current match while focus stays in the
  search field, and the Previous, Next, and Close controls keep distinct names
  and shortcut hints; Previous and Next stay unavailable until results exist.
- [ ] **Drag-resize splits** (v0.3.3) — split a pane (⌘D), hover the
  gap (cursor → resize arrows), drag to rebalance. Closing a pane
  redistributes the freed space; the survivors never shrink below a
  grabbable sliver. With Full Keyboard Access, Tab to the divider and
  use ← / → for a side-by-side split or ↑ / ↓ for a stacked split;
  each press moves 5%, Return or Space balances to 50/50, and keyboard
  focus has a stronger teal line than hover. VoiceOver announces the
  splitter orientation, percentage, and adjustable actions.
- [ ] **Claude session browser** (v0.4.0, ⌘⇧C) — sidebar lists
  projects from `~/.claude/projects` by recency with real cwd + git
  branch. Resume opens a tab running `claude --resume <id>` in that
  cwd; the conversation reattaches. Paths with hyphens (e.g.
  `andromeda-next`) resolve correctly (cwd parsed from transcript,
  not the lossy slug).
- [ ] **Claude session filtering.** Open a populated session browser and
  confirm focus lands in Filter sessions. Match by project name, path, and
  Git branch; the count changes to visible/total. Enter a no-match query,
  then use Clear Filter: every session returns, focus returns to the field,
  and VoiceOver announces the result without duplicate count chatter.
- [ ] **Pane cwd tracking** — `cd` somewhere, the pane's working dir
  is known internally (OSC 7). Foundation for session restore.
- [ ] **Session restore** (v0.4.1) — open 2-3 tabs, split one, `cd`
  into different dirs, quit (⌘Q), relaunch. Same tab/split layout
  comes back, each pane in its last directory. Toggle off in
  Settings → "Restore tabs & panes on launch" → relaunch opens a
  single fresh tab. An ssh pane comes back as a local shell (command
  not re-run), at home if its remote cwd doesn't exist locally.
- [ ] **Named workspaces** (v0.4.2) — arrange tabs/splits, Window →
  "Save Workspace As…" (⌃⌘S), name it. Change the layout, then
  Window → "Open Workspace ▸ <name>" restores it. Newly-saved
  entries appear without relaunch. Hold Option on an entry → it
  becomes "Delete <name>".

The programmable check for the first three lives in
`Scripts/verify-clipboard.sh` and runs daily as part of
`dogfood-daily.sh`. The others are owner-eye checks.

### Vietnamese IME

- Telex composition produces correct diacritics.
- No dropped characters when typing fast.
- The IME candidate window appears near the cursor (not at the
  top-left of the screen).
- Switching tabs while composing doesn't strand a preedit.

### Agent dashboard

- Detected agents (claude/codex/aider) show up within 2s.
- [ ] **Agent filtering.** Filter by tool, process, status (including
  “needs input”), and pane number. The visible/total count stays truthful;
  Clear Filter restores every agent and keyboard focus to the field, while
  VoiceOver announces only user-driven result changes.
- [ ] **Keyboard-operable worktree and tmux rows.** With Full Keyboard
  Access enabled, Tab to the primary row action and press Return or Space.
  The leading icon remains inside that action's hit region, focus gets a
  visible teal outline, and the trailing Claude / remove / kill controls are
  announced as separate actions with effect-specific VoiceOver hints. With
  Reduce Motion enabled, hover and focus state changes do not animate.
- "Running" badge is honest — if the agent is idle, it shouldn't
  say running. (NB: status discrimination ships in M6 carry — until
  then this WILL be wrong; just log it, don't refile.)
- pid shown matches `pgrep <name>`.

### SSH manager

- Add Host → Connect → tab opens with `ssh user@host` running.
- Disconnect → pane stays open with the disconnect message.
- Last-connected timestamp updates on the host list.
- [ ] **SSH host filtering.** Open a populated manager and confirm focus
  lands in Filter SSH hosts. Match by nickname, hostname, user, and port,
  including a diacritic-insensitive nickname. A no-match query exposes one
  Clear Filter recovery action; clearing restores all hosts and focus.

### Notes

- Toggle ⌘⇧N → text typed there persists across app restart.
- Before the first edit, the footer stays neutral. After typing, it changes to
  “Saved locally” only when SQLite accepts the write. A failed write shows
  “Save failed” plus a keyboard-accessible Retry action without clearing the
  current draft; VoiceOver announces the first failure without repeating on
  every keystroke, and a successful retry clears the failure state. If the
  existing note cannot be loaded, the editor stays locked and offers Reload
  instead of presenting an empty draft that could overwrite unknown content.
- Export → Markdown round-trips through Import.
- Each tab/session has its own note (no cross-contamination).

## When something breaks

1. Stop using herminal for that task.
2. Copy the last ~30 lines of `diary.log` into today's journal under
   the "Crash diary excerpt" section.
3. If the crash signal handler fired, the diary will have a `=== CRASHED
   signal=N ===` line — capture that too.
4. Run `Scripts/dogfood-daily.sh` to see whether the regression suite
   catches it. If yes, the failing assertion is the bug. If no, add a
   new assertion to the relevant `verify-*.sh` so it does next time.
5. File the issue inline in `docs/QA/dogfood/day-NN-*.md` under "New
   issues filed". Move to `docs/backlog/month-6.md` once triaged.

## When NOT to fix

The dogfood month is for *experiencing* what's built, not for shipping
features. If you feel the urge to fix something mid-day:

- **Yes, fix:** crashes, data loss (lost notes, lost SSH hosts), any
  P0 that blocks normal terminal use.
- **Yes, fix small:** a one-character typo in chrome, a missing
  VoiceOver label.
- **No, log only:** missing features, "would be nice if", performance
  micro-optimizations, UI polish ideas. These go on the M7 launch
  list or the post-MVP backlog.

The M5 retro flagged discipline as the M6 risk. The carry-over list is
already long enough to fill a month — adding to it daily is fine;
acting on it daily is feature work disguised as dogfood.
