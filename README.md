# herminal

> AI-native macOS terminal cho Vietnamese developers.

**Status:** Pre-alpha (Month 1 of 7-month MVP roadmap).
**License:** MIT.
**Target:** macOS 14+ Apple Silicon.

---

## Vision

Local-first macOS terminal cho developer Việt chạy Claude Code và agent CLIs hằng ngày: nhanh và native như Ghostty, Vietnamese input đáng tin như iTerm2, tmux/multi-session intact, agent dashboard first-class, và per-session notes bền vững mà không gửi terminal context lên cloud.

## Why herminal?

Không terminal 2026 nào (Warp, iTerm2, Wave, Ghostty) hit đủ 5 yêu cầu cùng lúc:

1. **Tối ưu Claude Code** — streaming agent output không lag
2. **Vietnamese IME** — Telex/VNI Unicode chuẩn xác
3. **tmux + multi-session** — không phá habit hiện tại
4. **Multi-agent dashboard** — biết agent nào đang chạy/blocked/done
5. **Per-terminal persistent notes** — local-first, đính kèm session

herminal là attempt để hit cả 5.

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Terminal engine | [libghostty](https://github.com/ghostty-org/ghostty) (C ABI) | Mature 2026 engine, native performance |
| App language | Swift 6 | Native macOS, AppKit IME control |
| Terminal surface | AppKit NSView + Metal | Pixel-precise IME via `NSTextInputClient` |
| Chrome / panels | SwiftUI | Modern declarative UI cho sidebar/dashboard/notes |
| Notes storage | SQLite WAL | Atomic autosave, relational metadata |
| Distribution | Developer ID DMG + Homebrew | App Store disqualified (sandbox issue) |

## MVP Features (7 months)

- [ ] Claude Code optimized native terminal core (libghostty)
- [ ] Vietnamese IME Telex/VNI correctness
- [ ] Multi-session workspace + tmux-compatible
- [ ] Multi-agent dashboard (Claude Code + Codex detection)
- [ ] Per-terminal persistent notes (SQLite + markdown round-trip)
- [ ] SSH Connection Manager UI
- [ ] Premium Raycast/Linear-style design polish

## Out of Scope (MVP)

- Cross-platform (Linux/Windows) — macOS-only
- App Store distribution — sandbox incompatible
- Cloud sync / accounts / team features
- Plugin marketplace / theming marketplace
- AI chat assistant (separate from agent dashboard)
- tmux `-CC` native control mode (defer v0.2)

## Documentation

| Doc | Purpose |
|---|---|
| [`docs/research/REPORT.md`](docs/research/REPORT.md) | Tại sao xây terminal khó? Stack options. |
| [`docs/research/05-best-terminals-2026.md`](docs/research/05-best-terminals-2026.md) | Master comparison của 11 macOS terminals 2026. |
| [`docs/research/06-user-requirements-scoring.md`](docs/research/06-user-requirements-scoring.md) | Tại sao cần herminal. |
| [`docs/define/herminal.prd.md`](docs/define/herminal.prd.md) | PRD chi tiết, 7-month MVP roadmap. |

## Development

### Prerequisites

- macOS 14+ (Apple Silicon)
- Xcode 26+
- Swift 6.2+

### Build

```bash
# Bootstrap (clone libghostty submodule, build dependencies)
./Scripts/bootstrap.sh

# Build SPM core libraries
swift build

# Run tests
swift test
```

### Project Structure

```
herminal/
├── Package.swift                # SPM root manifest
├── Sources/
│   ├── HerminalCore/           # libghostty C ABI bindings
│   ├── HerminalDB/             # SQLite notes + sessions
│   └── HerminalAgent/          # agent CLI detection heuristics
├── Tests/                       # SPM unit tests
├── App/                         # Xcode .app target (TBD)
├── Vendor/
│   └── libghostty/             # git submodule (TBD)
├── Scripts/                     # bootstrap, build, notarize
└── docs/                        # research + PRD
```

## Roadmap

| Month | Milestone |
|---|---|
| 1 | libghostty spike + Swift app skeleton + IME smoke pass |
| 2 | Premium design system + tabs/splits + tmux-compat |
| 3 | Multi-agent dashboard alpha + notes SQLite + basic export |
| 4 | SSH Connection Manager UI + markdown round-trip + Codex detection |
| 5 | Polish + compatibility matrix 80%+ |
| 6 | Owner dogfood daily-driver 8h+/day, 30 ngày |
| 7 | Beta with 5+ VN devs + GA prep |

## Status

Pre-alpha. Owner dogfooding starts ~Month 6.

---

Made with 🐈 by Yuuhou Meow team
