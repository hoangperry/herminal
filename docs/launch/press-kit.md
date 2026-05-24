# herminal — press kit

The single page anyone covering or sharing herminal should be able
to copy from without writing anything from scratch.

## Tagline

> AI-native macOS terminal cho Vietnamese developers chạy Claude Code
> hằng ngày. Local-first, no telemetry, MIT.

(EN) AI-native macOS terminal for Vietnamese developers who live in
Claude Code. Local-first, no telemetry, MIT.

## One-paragraph pitch

In 2026 nothing on the macOS terminal market hits all five at once:
native rendering speed, reliable Vietnamese IME, tmux compatibility,
a built-in dashboard for the AI agents you're running, and per-session
notes that don't get shipped to a cloud. herminal pairs the
[libghostty](https://github.com/ghostty-org/ghostty) engine with a
Swift / AppKit shell that owns the IME and the chrome, and stores
notes + saved SSH hosts in local SQLite. No account, no telemetry,
MIT-licensed.

## Numbers

- **7-month** MVP, solo + AI pair
- **48** unit tests + **6** integration scripts (all green)
- **0** crashes across the M6 stress runs
- **9/9** TUI apps verified in the compatibility matrix (vim, tmux,
  nano, less, htop, fzf, lazygit, btop, starship)
- **<5 ms** p95 keystroke-to-render latency
- **macOS 14+ Apple Silicon** only

## What's new vs the status quo

| | iTerm2 | Warp | Wave | Ghostty | herminal |
|---|---|---|---|---|---|
| Native macOS speed | ✓ | ~ | ~ | ✓ | ✓ |
| Vietnamese IME reliability | ✓ | × | × | ✓ | ✓ |
| tmux + multi-session | ✓ | ~ | × | ✓ | ✓ |
| Built-in agent dashboard | × | ~ | × | × | ✓ |
| Local-only persistent per-session notes | × | × | × | × | ✓ |

## Screenshots / GIFs

*Placeholders — drop the final PNGs into `docs/launch/assets/` and
link them here before announcing.*

- `assets/hero.png` — herminal window with two tabs, the agent
  dashboard open on the left, notes panel on the right, vim running
  in a split.
- `assets/agent-dashboard.gif` — Claude Code starts → badge flips
  from `starting` to `idle` to `running` as a prompt is processed.
- `assets/ssh-connect.gif` — SSH manager → click Connect → new tab
  opens with `ssh user@host` already running.
- `assets/ime-telex.gif` — Telex composition of `tieesng vieejt` →
  `tiếng việt` with the candidate window positioned at the cursor.

## Links

- Repo: https://github.com/hoangperry/herminal
- Releases: https://github.com/hoangperry/herminal/releases
- License: MIT
- Maintainer: Hoang Perry (`hoangperry@proton.me`)

## What we'd love to hear

- Crash reports — include the diary excerpt from
  `~/Library/Application Support/herminal/diary.log`.
- Vietnamese IME edge cases you've hit in OTHER terminals; we want
  to make sure they work here.
- Other agent CLIs we should detect (currently: claude, codex, aider).
- Feedback from Việt devs running tmux + multi-session workflows.

## What's NOT going to happen

- Linux / Windows builds — macOS-only by design.
- Cloud sync, accounts, team features.
- Plugin marketplace, theme marketplace.
- AI chat assistant — the agent dashboard is the AI surface.
- App Store distribution — sandbox is incompatible with how libghostty
  spawns shells.

See [CHANGELOG.md](../../CHANGELOG.md) "Known limitations" for the full
post-MVP defer list, and [CONTRIBUTING.md](../../CONTRIBUTING.md) for
why those calls are made.
