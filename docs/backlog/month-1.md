# Month 1 Backlog — herminal libghostty Spike

**Sprint goal:** Prove libghostty can be embedded in a Swift macOS app — spawn `zsh -l`, render text, accept input including Vietnamese IME, with p95 keydown→render < 20ms.

**Start date:** 2026-05-20
**Owner:** hoangperry
**Deadline (Month 1 PRD):** ~2026-06-20 (4 weeks)

---

## Status Legend
- ⏳ pending
- 🔄 in_progress
- ✅ done
- ⛔ blocked
- 🗑️ dropped/deferred

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| 6 | ✅ | Install Zig toolchain | brew zig=0.16.0 too new; Ghostty v1.3.1 needs 0.15.2 → installed to `~/.local/zig/0.15.2` |
| 1 | ✅ | Vendor libghostty as git submodule | Pinned to tag `v1.3.1` at `Vendor/libghostty` |
| 2 | ✅ | Read libghostty build + embedding docs | `include/ghostty.h` (33KB C ABI) + `module.modulemap` (module `GhosttyKit`) ready |
| 3 | ✅ | Build libghostty static library / xcframework | `GhosttyKit.xcframework` (macos-arm64, `libghostty-fat.a`) built ReleaseFast |
| 10 | ✅ | Wire libghostty into SPM | `.binaryTarget` GhosttyKit + linker frameworks; `swift build` green |
| 8 | ✅ | FFI smoke test: call ghostty version | `Ghostty.info` wraps `ghostty_info()`; 2 Swift Testing cases pass |
| 4 | 🔄 | App target for macOS app | Pivot: SPM `executableTarget` HerminalApp instead of manual .xcodeproj (see Q-002) |
| 5 | ⏳ | AppKit NSView terminal surface skeleton | HerminalView : NSView, hosts ghostty_surface |
| 9 | 🔄 | Spawn login shell via libghostty PTY | Run `ls`, `pwd`, `echo` correctly |
| 7 | ⏳ | Implement NSTextInputClient for IME | Marked text, commit, candidate position |
| 11 | ⏳ | Vietnamese IME smoke test (20 phrases) | Telex + VNI |
| 12 | ⏳ | Latency benchmark p95 < 20ms | Light + heavy load |
| 13 | ✅ | Initialize Month-1 backlog doc | This file — kept updated as work proceeds |

---

## Progress Log

### 2026-05-20 — Sprint kickoff

**Done:**
- Project structure: SPM core libs (HerminalCore/DB/Agent) + tests passing (4/4) ✅
- Public OSS repo created: https://github.com/hoangperry/herminal ✅
- Initial commit `0a28416 feat: bootstrap herminal project` ✅
- Discovery + Define phases complete (PRD 499 dòng locked Option A 7-month MVP) ✅

**Starting:**
- Zig install via Homebrew (background)
- libghostty submodule vendor

**Decisions Today:**
- libghostty pinned to stable tag (not main branch) — avoid ABI churn during Month 1
- Will use `systemLibrary` SPM target with module.modulemap to expose C ABI to Swift
- App/ Xcode project created MANUALLY by owner (Xcode CLI cannot reliably auto-gen)

**Blockers / Risks Surfaced:**
- None yet. Watching for: libghostty C ABI maturity, Zig build flakiness, xcframework vs static .a packaging

### 2026-05-22 — libghostty build run

**Done:**
- Zig 0.15.2 installed to `~/.local/zig/0.15.2` (Homebrew default 0.16.0 too new — Ghostty v1.3.1 pins min 0.15.2) ✅
- `libghostty-vt` dylib built OK → `Vendor/libghostty/zig-out/lib/libghostty-vt.dylib` (VT/terminal-state engine, no renderer) ✅
- Build reached 161/167 steps before failing

**Blocker — BLOCK-001: Metal Toolchain missing → RESOLVED**
- `zig build -Demit-xcframework=true` failed at Metal shader compile step:
  `error: cannot execute tool 'metal' due to missing Metal Toolchain`
- Root cause: Xcode 26 no longer bundles the Metal Toolchain by default; it is a separately downloadable component (~705 MB).
- Fix applied: `xcodebuild -downloadComponent MetalToolchain` → installed Metal Toolchain 17B54. `metal --version` confirms `air64-apple-darwin25.3.0`.
- Impact while blocked: full `GhosttyKit.xcframework` (Metal renderer) blocked. `libghostty-vt` unaffected.
- ACTION: add Metal Toolchain check + download hint to `Scripts/bootstrap.sh` so contributors hit this once, documented.

### 2026-05-22 (cont.) — FFI bridge working

**Done:**
- Metal Toolchain 17B54 installed → BLOCK-001 resolved ✅
- `GhosttyKit.xcframework` built (ReleaseFast, macos-arm64) → `Vendor/libghostty/macos/GhosttyKit.xcframework` ✅ (task #3)
- `Package.swift`: added `.binaryTarget` GhosttyKit + 11 linked frameworks on HerminalCore ✅ (task #10)
- `HerminalCore.Ghostty.info` wraps `ghostty_info()` C ABI → build mode + version ✅
- FFI smoke test: 2 Swift Testing cases pass — proves Swift ⇄ libghostty bridge works ✅ (task #8)
- `swift build` green (1.4s), `swift test` 6 tests pass (4 XCTest + 2 Swift Testing)
- `Scripts/bootstrap.sh` rewritten: pins Zig 0.15.2, checks Metal Toolchain, auto-builds xcframework

**Decisions Today:**
- **Q-002 resolved:** App target = SPM `executableTarget` (`HerminalApp`), NOT a hand-made `.xcodeproj`. Keeps the spike fully scriptable (`swift run`); a real `.app` bundle with signing/entitlements is deferred to Month 2.
- New tests use Swift Testing (`import Testing`); legacy XCTest files left as-is.
- Known cosmetic warning: GhosttyKit umbrella header omits `ghostty/vt/*.h` — harmless for the embedding API.

**Next:**
- `HerminalApp` executable: NSApplication + window — task #4
- `HerminalView : NSView` hosting a `ghostty_surface_t` — task #5
- Spawn `zsh -l` via libghostty, render `ls`/`pwd`/`echo` — task #9

---

## Deferred / Dropped Items

_None yet._

---

## Open Questions

- **Q-001 (resolved):** Package libghostty as `.binaryTarget` (xcframework) vs `systemLibrary`? → **`.binaryTarget`** chosen — `swift build`/`swift test` link cleanly with explicit linked frameworks.
- **Q-002 (resolved):** App target = manual `.xcodeproj` vs SPM `executableTarget`? → **`executableTarget`** for the spike (scriptable, CI-friendly). Real signed `.app` bundle deferred to Month 2.
- **Q-003 (open):** libghostty needs `ghostty_init` + a `ghostty_runtime_config_s` with several callbacks (clipboard, action, etc.). How many callbacks are mandatory for a minimal surface that just renders a shell? To be answered while implementing task #5/#9.

---

## Reference

- [PRD](../define/herminal.prd.md) — 7-month MVP scope
- [Discovery REPORT](../research/REPORT.md) — Tại sao xây terminal khó
- [Terminal comparison](../research/05-best-terminals-2026.md)
