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
