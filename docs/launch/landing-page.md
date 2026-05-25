# herminal landing page (markdown source)

Source for the eventual `herminal.app` / GitHub Pages landing
page. Convert to HTML via your preferred static-site generator
(Astro / Eleventy / plain pandoc) — the markdown structure is the
content; the visual treatment is a separate design pass.

---

<div align="center">

# herminal

### macOS terminal cho dev người Việt sống trong Claude Code.

[![Download v0.1.0](https://img.shields.io/badge/Download-v0.1.0%20beta-teal?style=for-the-badge)](https://github.com/hoangperry/herminal/releases/latest)
[![GitHub stars](https://img.shields.io/github/stars/hoangperry/herminal?style=for-the-badge)](https://github.com/hoangperry/herminal)
[![MIT](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](https://github.com/hoangperry/herminal/blob/main/LICENSE)

*Local-first. No telemetry. No account. macOS 14+ Apple Silicon.*

</div>

---

## The two daily realities nothing else covers

In 2026, every macOS terminal misses part of the picture:

```
                  Native    VN IME   tmux   Agent      Local notes
                  speed              compat dashboard  per session
─────────────────────────────────────────────────────────────────
iTerm2            ✓         ✓        ✓      ✗          ✗
Warp              partial   ✗        partial  partial   ✗
Wave              partial   ✗        ✗      ✗          ✗
Ghostty           ✓         ✓        ✓      ✗          ✗
─────────────────────────────────────────────────────────────────
herminal          ✓         ✓        ✓      ✓          ✓
```

herminal pairs the [libghostty](https://github.com/ghostty-org/ghostty)
engine — Zig core, native Metal renderer, sub-5ms keystroke
latency — with a Swift/AppKit shell that owns the IME and the
chrome. It's everything iTerm2 gets right, plus the two things
2025-era terminals decided to skip.

---

## See your agents at a glance

When `claude`, `codex`, or `aider` runs in any tab, the dashboard
catches it within 2 seconds:

```
┌──────────────────────────┐
│  AGENTS                3 │
├──────────────────────────┤
│  ● Claude Code   Tab 1   │  ← running (blue)
│    pid 53241 · running   │
│                          │
│  ● Codex         Tab 2   │  ← needs input (BEL fired)
│    pid 53244 · needs in… │
│                          │
│  ○ Aider         Tab 3   │  ← idle
│    pid 53289 · idle      │
└──────────────────────────┘
```

It catches npm-installed agents (`npx @anthropic-ai/claude-code`)
and Python wrappers (`python3 -m aider`) too — argv inspection,
not just process name matching.

Status badge inferred from per-PID CPU sampling + BEL detection.
Tab attribution from process-tree walking.

---

## Vietnamese Telex that actually works

`tieesng vieejt` → `tiếng việt` — first try, in vim, in tmux, in a
fast-typing burst.

NSTextInputClient bridge that's verified against a 20-phrase smoke
checklist before every release. KR / JP / CN smoke matrices also
ready for the next audience expansion.

The Vietnamese IME ladder is the kind of thing macOS handles
correctly out of the box AND that Electron terminals reliably
break.

---

## SSH manager built around `~/.ssh/config`

- One-click import of your existing config
- One-click connect spawns `ssh user@host` in a new tab
- Per-host last-connected timestamp in the sidebar
- Stores ZERO secrets — your keys + passwords stay where you put
  them today

You're not migrating; you're skinning what already works.

---

## Per-session notes that never leave your machine

Each terminal session has its own SQLite-backed note. Autosaved.
Markdown round-trip via File → Export / Import.

The notes don't get shipped to a cloud, don't get scraped for
training data, don't sync to a marketing CRM. They sit in
`~/Library/Application Support/herminal/notes.db` and that's the
end of the story.

---

## What we promise we won't do

- **No telemetry.** No HTTP client. No analytics SDK. No crash
  reporter that phones home. Network activity = whatever YOU run
  in a terminal pane.
- **No cloud sync.** Your notes are yours.
- **No account.** Don't email us; we don't have a mailing list.
- **No plugin marketplace.** v1 scope is intentional.
- **No AI chat assistant inside the terminal.** The dashboard is
  the AI surface; the terminal is the workspace.
- **No App Store distribution.** The sandbox kills how libghostty
  spawns shells.
- **No Linux/Windows builds.** macOS-only by design.

These are load-bearing. PRs to add them get politely declined.

---

## Built with discipline

| | |
|---|---|
| **MVP** | 7 months, solo developer + Claude Opus 4.7 pair |
| **Tests** | 79 unit tests, 5 integration scripts, all green |
| **Crashes shipped** | 0 in dogfood, 0 in stress runs |
| **Kernel bugs documented** | 3 — Sequoia gotchas the next macOS-native-tools builder won't have to discover |
| **Lines of Swift** | ~6,000 — small enough to read in an evening |
| **External deps** | 2 — SQLite.swift, libghostty |

Full retrospective for each month is in the repo at `docs/backlog/`.
The audit trail is the value proposition.

---

## Install

### From a tagged release

```sh
# Once v0.1.0 lands on GitHub Releases:
curl -L https://github.com/hoangperry/herminal/releases/latest/download/herminal-v0.1.0.zip -o herminal.zip
unzip herminal.zip -d /Applications/
open /Applications/herminal.app
```

### Via Homebrew (post-Developer-ID)

```sh
brew tap hoangperry/herminal
brew install --cask herminal
```

### From source

```sh
git clone --recurse-submodules https://github.com/hoangperry/herminal
cd herminal
Scripts/bootstrap.sh && Scripts/make-app-bundle.sh
open .build/herminal.app
```

---

## Status + next

**v0.1.0 beta — ships now.** Every PRD MVP feature plus the first
post-MVP wave (node-wrapped agent detection, BEL needs-input, agent
↔ pane attribution, light theme, .ssh/config import, redacted diary
export).

**v0.1.1 — once owner Developer-ID enrolment lands.** Notarized
build, Homebrew cask publish, Sparkle auto-update wiring.

**v0.2.x — beta-feedback-driven.** Recursive split trees, drag-
resize, opt-in diary upload, more agent kinds. We ship what beta
testers actually ask for.

[See the full roadmap →](https://github.com/hoangperry/herminal/blob/main/docs/ROADMAP.md)

---

<div align="center">

## Try it

[![Download v0.1.0](https://img.shields.io/badge/Download-v0.1.0%20beta-teal?style=for-the-badge)](https://github.com/hoangperry/herminal/releases/latest)

Open a bug → tell us what you want next.

</div>
