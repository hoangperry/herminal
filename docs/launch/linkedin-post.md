# LinkedIn launch post (draft)

LinkedIn audience is slower-reading and more professional than X —
this is one long post, not a thread. Owner edits before posting.

---

**herminal v0.1.0 — a macOS terminal built for the way I work in 2026**

I ship most of my code through Claude Code, write half my notes in
Vietnamese, and live in tmux. No terminal on the market in 2026 hits
all of that at once — so I spent the last seven months building one.

**What it is**

herminal is a local-first macOS terminal pairing the
[libghostty](https://github.com/ghostty-org/ghostty) engine with a
Swift / AppKit shell. It's MIT-licensed, sends nothing over the
network, and is built specifically for developers who:

→ run AI agents (Claude Code, Codex, Aider) as part of their daily
   workflow and want a glanceable view of which agents are alive,
   idle, or done
→ write Vietnamese in their commits, READMEs, and PRs — and need
   Telex / VNI to land correctly in tmux, in vim, the first time
→ care about latency (<5 ms p95 keystroke to render) and don't
   want their terminal session shipped to anyone's cloud

**The opinionated bits**

- Built-in **agent dashboard** with running / idle / starting badges,
  inferred from per-PID CPU sampling. Catches `claude`, `codex`,
  `aider` out of the box; the detection layer is open for more.
- **SSH Connection Manager** — saved hosts, one-click connect spawns
  `ssh user@host` into a new tab via libghostty's `config.command`
  override. No keystroke macros, no terminal multiplexer config.
- **Per-session notes** in local SQLite with Markdown round-trip.
  Each terminal session has its own note that persists across
  restarts. No account, no sync.
- **Telemetry-free crash diary** for dogfooding — recent app events
  + signal handler write to a local file. The only "phone home" is
  literally the user reading the file.

**The numbers**

- 7-month MVP, solo developer + AI pair (Claude Opus 4.7)
- 48 unit tests, 6 integration scripts, 0 crashes in M6 stress runs
- 9 / 9 TUI apps verified in the compatibility matrix (vim, tmux,
  nano, less, htop, fzf, lazygit, btop, starship)
- 2 real macOS Sequoia bugs found and worked around along the way
  (`proc_listchildpids` returns garbage; `proc_pid_rusage` uses
  mach absolute time units, not nanoseconds) — write-ups in the
  repo for the next person who'll hit them

**Where it isn't**

macOS-only. No cross-platform plans. No cloud sync. No App Store
build (the sandbox is incompatible with how libghostty spawns
shells). No AI chat assistant — the agent dashboard is the AI
surface, the terminal is the workspace.

**Try it**

- Repo: https://github.com/hoangperry/herminal
- Releases: https://github.com/hoangperry/herminal/releases
- Bug template + dogfood checklist live in the repo so the feedback
  loop is structured from day one.

Particularly want feedback from Vietnamese developers running
tmux-heavy + agent-heavy workflows. If something feels off, the
bug template tells you exactly what to include — there's a
crash-diary excerpt prompt that makes triage straight-forward.

#macOS #Swift #DeveloperTools #Terminal #ClaudeCode #VietnameseDev

---

## Notes for the owner

- Drop a screenshot in BEFORE the text — LinkedIn previews lead
  with the image and people scroll past plain text.
- The recommended length on LinkedIn caps at ~1300 chars before
  "see more" cuts; the draft above is close to that. Pulling the
  bullet bullets up and the numbers down would tighten more.
- Tag relevant people on first comment (Ghostty author, Vietnamese
  dev community accounts) rather than in the main post.
