# Twitter / X launch thread (draft)

Owner edits before posting. Tweet 1 is the hook + screenshot/GIF.
Each tweet ≤ 280 chars; thread length ~6 tweets — long enough to
say something, short enough to read in one breath.

---

**1/** Just shipped herminal v0.1.0 — a macOS terminal built for the
way I actually use my terminal in 2026: Claude Code running half the
day, Vietnamese in the other half, tmux always.

Local-first, MIT, no telemetry. → github.com/hoangperry/herminal

[hero.png — herminal window with agent dashboard + vim split]

---

**2/** The why: no terminal in 2026 hits all five at once —

✓ native macOS speed
✓ Vietnamese IME that actually works
✓ tmux + multi-session
✓ a built-in dashboard for the AI agents you're running
✓ per-session notes that never leave your machine

So I built it.

---

**3/** Engine is libghostty (great Zig terminal core, mature in 2026).
Shell is Swift / AppKit / SwiftUI. IME goes through `NSTextInputClient`
so Telex / VNI land correctly the first time. Notes + SSH hosts live
in local SQLite. Nothing phones home.

---

**4/** Agent dashboard is the differentiator. Walks herminal's process
subtree via `sysctl(KERN_PROC_ALL)`, samples per-PID CPU with
`proc_pid_rusage`, and tags each detected agent
`running` / `idle` / `starting`.

Catches claude, codex, aider out of the box.

[agent-dashboard.gif]

---

**5/** Two real bugs found while building it that I haven't seen written
up anywhere:

– `proc_listchildpids` returns garbage on macOS Sequoia
– `proc_pid_rusage` returns mach absolute time units, not nanoseconds
  (42× under-reporting if you trust the field name)

Fixes + write-ups in the repo.

---

**6/** 7-month build, solo + AI pair (Claude Opus 4.7). 48 unit tests,
6 integration scripts, 0 crashes in stress runs. Beta install:

📦 github.com/hoangperry/herminal/releases
📖 github.com/hoangperry/herminal#install
🐛 github.com/hoangperry/herminal/issues/new/choose

Would love your feedback meow~

---

## Notes for the owner

- Replace `[hero.png]` and `[agent-dashboard.gif]` placeholders with
  real assets before posting (drop in `docs/launch/assets/`).
- Tweets 1, 2, and 6 are the most important — if the thread gets cut
  off in feeds, those three still tell the story.
- Pin tweet 1 on the profile for the first week.
- Reply to early signal — if anyone reports a crash, ask for the
  diary excerpt linked in the bug template.
