# herminal

> AI-native macOS terminal cho Vietnamese developers chạy Claude Code và
> agent CLIs hằng ngày.

**Website:** <https://hoang.tech/herminal/> · **Download:** [latest release](https://github.com/hoangperry/herminal/releases/latest) · **Source:** this repo

[![CI](https://github.com/hoangperry/herminal/actions/workflows/ci.yml/badge.svg)](https://github.com/hoangperry/herminal/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black.svg)](https://www.apple.com/macos)
[![Swift 6](https://img.shields.io/badge/swift-6-orange.svg)](https://swift.org)

**Status:** v1.0.0 — stable ([CHANGELOG](CHANGELOG.md)).
**Platform:** macOS 14+ Apple Silicon.

> 🇻🇳 Phiên bản tiếng Việt: [`README.vi.md`](README.vi.md)

---

## What is herminal

A local-first macOS terminal built around two daily realities the existing
2026 terminals each miss part of:

1. **You run Claude Code / Codex / Aider all day** and need a glanceable
   view of which agents are alive, idle, or done — without an
   open-a-second-window detour.
2. **You write Vietnamese** and need Telex / VNI to land correctly the
   first time, in tmux, in vim, every time.

herminal pairs the [libghostty](https://github.com/ghostty-org/ghostty)
engine (Zig, mature, native performance) with a Swift / AppKit shell that
owns the IME and the chrome. Storage is SQLite for both per-session notes
and saved SSH hosts. No cloud, no telemetry, no account.

## Why a new terminal

In 2026 nothing on the market hits all five at once:

| Need | iTerm2 | Warp | Wave | Ghostty | **herminal** |
|---|---|---|---|---|---|
| Native macOS speed | ✓ | partial | partial | ✓ | ✓ |
| Vietnamese IME reliability | ✓ | × | × | ✓ | ✓ |
| tmux + multi-session | ✓ | partial | × | ✓ | ✓ |
| Built-in agent dashboard | × | partial | × | × | ✓ |
| Local-only persistent notes per session | × | × | × | × | ✓ |

See [`docs/research/`](docs/research/) for the full comparison and
scoring rubric the table is derived from.

## MVP scope (v0.1.0)

All shipped:

- [x] Native terminal core via libghostty (Metal renderer, p95 keystroke <5ms)
- [x] Vietnamese IME via NSTextInputClient (Telex + VNI verified)
- [x] Multi-session workspace + vertical/horizontal splits
- [x] Agent dashboard with running / idle / starting discrimination
- [x] Per-session notes (SQLite WAL) with Markdown round-trip
- [x] SSH Connection Manager with one-click spawn
- [x] Premium dark chrome (Raycast/Linear style)
- [x] tmux compatibility verified against vim, less, htop, fzf, lazygit, btop, starship
- [x] Telemetry-free local crash diary
- [x] Developer-ID codesign + notarize pipeline

Deferred to post-MVP — see [CHANGELOG.md](CHANGELOG.md) "Known
limitations": agent↔pane mapping, recursive split trees, drag-to-resize
dividers, light theme, group/search in SSH manager.

## Install

### Homebrew (recommended)

```sh
brew install --cask hoangperry/herminal/herminal
```

`brew upgrade --cask herminal` keeps it current. The cask installs a
signed + notarized build, so Gatekeeper accepts it silently.

### Direct download

1. Grab `herminal-vX.Y.Z.dmg` from the
   [Releases](https://github.com/hoangperry/herminal/releases/latest) page.
2. Open the DMG → drag `herminal.app` into `/Applications`.
3. Launch — first run is silent (the build is notarized + stapled).

### From source

```sh
git clone --recurse-submodules https://github.com/hoangperry/herminal
cd herminal
Scripts/bootstrap.sh           # builds libghostty xcframework (~5-15 min cold)
Scripts/make-app-bundle.sh     # assembles .app with ad-hoc signature
open .build/herminal.app
```

Prereqs: Xcode 26+, Swift 6.2+, [Zig](https://ziglang.org) 0.15.2+
(for libghostty), `clang` for the kernel-probe binaries used by the
integration scripts.

## First-run quick tour

- **⌘T / ⌘W** — new tab / close current pane (closes tab when last)
- **⌘D / ⌘⇧D** — split vertical / horizontal
- **⌘⇧] / ⌘⇧[** — next / previous tab
- **⌘⇧A** — toggle agent dashboard
- **⌘⇧S** — toggle SSH host manager (mutex with the agent dashboard
  in the left slot)
- **⌘⇧N** — toggle the per-session notes panel on the right

Agents are detected by walking herminal's process subtree — start
`claude`, `codex`, or `aider` in any tab and they'll appear in the
dashboard within ~2 seconds with a `running` / `idle` / `starting`
badge tracked via CPU sampling.

## Tech stack

| Layer | Tech | Why |
|---|---|---|
| Terminal engine | [libghostty 1.3.1](https://github.com/ghostty-org/ghostty) (C ABI via Zig) | Mature, native, no Electron |
| App | Swift 6 + AppKit + SwiftUI chrome | Real `NSTextInputClient`, real Metal layer |
| Surface | `NSView` hosting libghostty's Metal layer | Pixel-precise IME |
| Storage | SQLite WAL (notes + SSH hosts) | Local-only, atomic, indexable |
| Distribution | Developer-ID signed `.app` zip + (planned) Homebrew | App Store sandbox is incompatible |

## Repo layout

```
herminal/
├── Sources/
│   ├── HerminalCore/         # libghostty C ABI bridge
│   ├── HerminalDB/           # NotesStore + SSHHostsStore
│   ├── HerminalAgent/        # process-subtree + CPU-status detection
│   └── HerminalApp/          # NSApp, WorkspaceView, panels, Diary
├── App/                       # Info.plist + entitlements
├── Tests/                     # 48+ Swift Testing unit tests
├── Scripts/                   # bootstrap, bundle, verify-*, dogfood, sign, release
├── Vendor/libghostty/         # git submodule (Ghostty v1.3.1)
└── docs/
    ├── research/             # market scan + scoring
    ├── define/herminal.prd.md # source-of-truth PRD
    ├── backlog/              # monthly task lists + retrospectives
    ├── QA/                   # IME checklist, dogfood checklist + journal
    └── launch/               # press kit + tweet/LinkedIn drafts
```

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) first — the project is
opinionated about what's in scope. Bug reports go through the
[bug template](.github/ISSUE_TEMPLATE/bug_report.md) which prompts for
the diary excerpt; security issues go to
[SECURITY.md](SECURITY.md).

## Documentation

| Doc | Purpose |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | Per-version release notes |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to propose changes |
| [SECURITY.md](SECURITY.md) | How to report vulnerabilities |
| [docs/RELEASE.md](docs/RELEASE.md) | Cutting a signed + notarized release |
| [docs/define/herminal.prd.md](docs/define/herminal.prd.md) | The PRD that frames every decision |
| [docs/QA/dogfood-checklist.md](docs/QA/dogfood-checklist.md) | What to watch for during daily-driver use |
| [docs/QA/vietnamese-ime-checklist.md](docs/QA/vietnamese-ime-checklist.md) | 20-phrase Telex/VNI smoke matrix |
| [docs/backlog/](docs/backlog/) | Monthly task lists + retrospectives M1 → M7 |

---

Made with 🐈 by Yuuhou Meow team in Việt Nam.
