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
- [ ] **Edit menu** shows Cut / Copy / Paste / Select All. Copy
  greyed out when nothing is selected.
- [ ] **Right-click** routes to libghostty (no NSBeep, no missing
  events). Future: hook up a context menu here.
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
- [ ] **Cursor is an I-beam** when hovering the terminal (not the
  default arrow). v0.2.5 lesson — `GHOSTTY_ACTION_MOUSE_SHAPE` was
  unhandled; the terminal surface now defaults to `.iBeam` and
  swaps based on the action (vim mouse mode, URL hover, etc).
- [ ] **Cmd+click a URL** rendered in terminal output (paste a link
  into a `cat` first if your shell doesn't expose any) → default
  browser opens. v0.2.5 lesson — `GHOSTTY_ACTION_OPEN_URL` was
  unhandled. Only `http`, `https`, `mailto` allowed; `file://`
  rejected.
- [ ] **⌘F search** opens the find bar top-right of the active pane;
  typing highlights matches, ⌘G / ⌘⇧G navigates, Esc closes.
- [ ] **Drag-resize splits** (v0.3.3) — split a pane (⌘D), hover the
  gap (cursor → resize arrows), drag to rebalance. Closing a pane
  redistributes the freed space; the survivors never shrink below a
  grabbable sliver.
- [ ] **Claude session browser** (v0.4.0, ⌘⇧C) — sidebar lists
  projects from `~/.claude/projects` by recency with real cwd + git
  branch. Resume opens a tab running `claude --resume <id>` in that
  cwd; the conversation reattaches. Paths with hyphens (e.g.
  `andromeda-next`) resolve correctly (cwd parsed from transcript,
  not the lossy slug).
- [ ] **Pane cwd tracking** — `cd` somewhere, the pane's working dir
  is known internally (OSC 7). Foundation for session restore.

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
- "Running" badge is honest — if the agent is idle, it shouldn't
  say running. (NB: status discrimination ships in M6 carry — until
  then this WILL be wrong; just log it, don't refile.)
- pid shown matches `pgrep <name>`.

### SSH manager

- Add Host → Connect → tab opens with `ssh user@host` running.
- Disconnect → pane stays open with the disconnect message.
- Last-connected timestamp updates on the host list.

### Notes

- Toggle ⌘⇧N → text typed there persists across app restart.
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
