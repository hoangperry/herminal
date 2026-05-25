# Show HN — submission draft

The Hacker News submission needs a title under 80 characters and a
first comment that establishes context. Owner posts when ready; the
text below is the source.

---

## Title (under 80 chars)

```
Show HN: herminal – macOS terminal with built-in AI agent dashboard
```

Alternatives if the agent angle doesn't bite:

```
Show HN: A macOS terminal built around Claude Code + Vietnamese IME
Show HN: Herminal – local-first macOS terminal, 0 telemetry
```

---

## URL

`https://github.com/hoangperry/herminal`

(NOT the landing page — HN voters trust GitHub URLs more for OSS
projects of this size.)

---

## First-comment text (the auto-thread starter)

> Author here. herminal is a 7-month MVP I built solo + with Claude
> Opus 4.7 as a pair. The whole codebase + every retro is open;
> the project audit trail IS the value proposition.
>
> What it does that no other 2026 macOS terminal does:
>
> 1. **Agent dashboard.** Auto-detects `claude` / `codex` /
>    `aider` running in any pane via process-tree walking, infers
>    running/idle/needs-input status from per-PID CPU sampling +
>    BEL detection, attributes each agent to its tab. Catches
>    `npx`-installed and python-script-hosted agents via argv
>    inspection too — `aider` running as `python3 -m aider`
>    appears in the dashboard as `aider (Python)`.
>
> 2. **Vietnamese IME that works.** Telex + VNI verified against
>    a 20-phrase smoke matrix before every release. NSTextInputClient
>    bridge unit-tested separately from the system IME so
>    composition-state bugs surface in CI.
>
> 3. **SSH manager + ~/.ssh/config import.** Stores zero secrets;
>    your keys + Keychain entries stay where you put them. One-
>    click connect spawns `ssh user@host` in a new tab via
>    libghostty's `config.command`.
>
> 4. **Local-first by construction.** No HTTP client in the
>    codebase. The crash diary writes to a file in Application
>    Support; the redaction layer strips home paths so the file is
>    safe to paste into a bug report. Update checks (Sparkle) ship
>    in v0.1.1 and are opt-out.
>
> Engine is libghostty (the new Ghostty 1.3.1 Zig core, embedded
> statically). Shell is Swift 6 + AppKit. Storage is SQLite WAL.
> p95 keystroke-to-render < 5 ms.
>
> Three real kernel bugs I documented along the way that the next
> macOS-native-tools builder might appreciate:
>
> - `proc_listchildpids` is broken on Sequoia — returns garbage on
>   the fill call. Use `sysctl(KERN_PROC_ALL)`. Write-up:
>   docs/blog/01-proc-listchildpids-broken-on-sequoia.md
> - `proc_pid_rusage` returns mach absolute time units, NOT
>   nanoseconds. On Apple Silicon that's a 42× under-report.
>   Write-up: docs/blog/02-proc-pid-rusage-mach-time-units.md
> - libghostty's `exec -l` wrapper prefixes `p_comm` with a dash.
>   `pgrep -x` silently misses every spawned child. Match `^-?<n>$`.
>   Write-up: docs/blog/03-libghostty-exec-l-pcomm-dash.md
>
> Roadmap is feedback-driven. Themes B (SSH groups/search), C
> (recursive splits, drag-resize), F (opt-in diary upload), and
> the rest are all explicitly "wait until beta says it matters."
> If you try it and something hurts, file the issue with the
> bug template — it auto-prompts for the diary excerpt and the
> dogfood-daily output.
>
> Honest about what it doesn't do: no Linux/Windows, no plugin
> marketplace, no cloud sync, no AI chat inside the terminal
> (the agent dashboard is the AI surface). See
> docs/ROADMAP.md "Won't ship by design."

---

## When to post

- Time it for early-morning US Pacific OR mid-morning Vietnam
  time. Both windows give HN's voting-tail enough hours to lift
  the post above the noise threshold before the next CPU/AI/Rust
  news cycle drowns it.
- Don't post on a Tuesday or Wednesday — those are the most
  competitive Show HN days. Friday afternoon US time is often a
  good slot for niche tools.
- Don't post during a major Apple announcement window (WWDC,
  September event) — the macOS angle gets buried under the
  industry coverage.

## Defending the thread

Expected critical-comment patterns + suggested responses:

- **"Why not just use iTerm2 + a plugin?"** — Reasonable. The
  comparison page (docs/launch/comparison.md) has the long-form
  answer; the short version is iTerm2 doesn't have an agent
  surface and the plugin ecosystem isn't there.
- **"Why MIT and not GPL like iTerm2?"** — PRD chose MIT because
  it's the most permissive of the OSI list and matches what
  Ghostty did. No moral position on GPL, just a project-shape
  choice.
- **"Local-only is great but how do I sync between machines?"** —
  We don't. By design. Your shell history + .ssh/config sync
  paths (dotfiles, syncthing, etc.) work unchanged.
- **"Where's the AI chat assistant?"** — Not shipping. The agent
  dashboard surfaces the AI CLIs you're already running; we don't
  duplicate Claude Code inside the terminal.

## What NOT to do in the thread

- Don't downvote critics — voting on your own thread is a
  community-norm violation that often gets the whole submission
  flagged.
- Don't argue about non-goals. "Linux support please" gets a
  pointer to the ROADMAP non-goals list and that's it. Engaging
  beyond that derails the thread.
- Don't bait — every reply should be on-topic to the herminal
  point being raised, not a meta-point about HN itself.
