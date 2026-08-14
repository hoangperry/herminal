# herminal

> Terminal macOS AI-native cho developer Việt chạy Claude Code và agent
> CLIs hằng ngày.

[![CI](https://github.com/hoangperry/herminal/actions/workflows/ci.yml/badge.svg)](https://github.com/hoangperry/herminal/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black.svg)](https://www.apple.com/macos)
[![Swift 6](https://img.shields.io/badge/swift-6-orange.svg)](https://swift.org)

**Trạng thái:** `v1.0.0` release candidate trên `main`; bản public mới nhất là
[`v0.4.2`](https://github.com/hoangperry/herminal/releases/tag/v0.4.2).
Xem [CHANGELOG](CHANGELOG.md).
**Nền tảng:** macOS 14+ Apple Silicon.

> 🇬🇧 English version: [`README.md`](README.md)

![Workspace herminal — agent dashboard ở slot trái, split terminal panes ở giữa, notes per-session bên phải, status bar dưới cùng](docs/assets/window-anatomy.svg)

*Agent đang chạy và worktree bên trái, split ở giữa, notes per-session bên
phải. Slot trái chỉ có một chỗ: agent dashboard và SSH manager thay nhau
chiếm nó.*

<!-- Screenshot app thật sẽ nằm ở đây. Chạy
     Scripts/capture-screenshots.sh (cần cấp Screen Recording +
     Accessibility cho terminal), rồi xoá cặp comment này.

| | |
|---|---|
| ![Split panes với agent dashboard đang mở](docs/assets/screenshot-workspace.png) | ![SSH host manager](docs/assets/screenshot-ssh-manager.png) |
| ![Notes panel per-session](docs/assets/screenshot-notes.png) | ![Preedit Telex đang sống tại shell prompt](docs/assets/screenshot-ime.png) |

-->

---

## herminal là gì

Một terminal macOS local-first xây quanh 2 nhu cầu hằng ngày mà các
terminal 2026 hiện tại đều thiếu một phần:

1. **Bạn chạy Claude Code / Codex / Aider cả ngày** và cần thấy ngay
   agent nào đang sống, idle, hay done — mà không phải mở thêm cửa sổ
   khác để check.
2. **Bạn gõ một ngôn ngữ mà bàn phím tiếng Anh không với tới** — Telex /
   VNI tiếng Việt, Hangul 2-Set tiếng Hàn, romaji tiếng Nhật, Pinyin
   tiếng Trung — và cần composition hiển thị đúng ngay lần đầu, trong
   tmux, trong vim, mọi lúc.

herminal pair engine [libghostty](https://github.com/ghostty-org/ghostty)
(Zig, mature, native performance) với một Swift / AppKit shell quản
lý IME và chrome. Lưu trữ dùng SQLite cho cả per-session notes lẫn
saved SSH hosts. Không cloud, không telemetry, không cần account.

![Một bridge NSTextInputClient phục vụ Telex tiếng Việt, Hangul 2-Set, romaji sang kanji tiếng Nhật và Pinyin tiếng Trung, cùng case Tab-khi-đang-preedit mà cả bốn đều gặp](docs/assets/ime-composition.svg)

*Các API composition nằm ngay trên terminal surface, không giả lập trong
một text field bọc ngoài — nên một bridge phục vụ mọi input method macOS
có. Tiếng Việt là release gate vì nó là persona chính của PRD, không phải
vì code special-case cho nó.*

## Tại sao cần thêm 1 terminal nữa?

Năm 2026 không terminal nào hit đủ 5 thứ cùng lúc:

| Yêu cầu | iTerm2 | Warp | Wave | Ghostty | **herminal** |
|---|---|---|---|---|---|
| Tốc độ native macOS | ✓ | partial | partial | ✓ | ✓ |
| Vietnamese IME + autocomplete khi còn preedit | ✓ | × | × | partial | RC¹ |
| tmux + multi-session | ✓ | partial | × | ✓ | ✓ |
| Dashboard agent built-in | × | partial | × | × | ✓ |
| Notes per-session local-only | × | × | × | × | ✓ |

Dòng IME được score theo tiếng Việt vì đó là persona của rubric. Bridge
bên dưới là generic — tiếng Hàn, Nhật, Trung có smoke matrix riêng ở
[`docs/QA/cjk-ime-checklist.md`](docs/QA/cjk-ime-checklist.md).

Xem [`docs/research/`](docs/research/) cho full comparison + scoring
rubric đã dùng để lập bảng trên.

## Scope v1

Đã có trên `main`; bản public v1 vẫn là release candidate:

- [x] Terminal core native qua libghostty (Metal renderer, p95 keystroke <5ms)
- [x] Vietnamese IME bridge có regression test cho Tab/preedit; live gate Telex/VNI vẫn đang chờ¹
- [x] Workspace multi-session + split dọc/ngang
- [x] Dashboard agent với phân biệt running / idle / starting
- [x] Per-session notes (SQLite WAL) + Markdown round-trip
- [x] SSH Connection Manager + one-click spawn + import từ ~/.ssh/config
- [x] Premium dark chrome (style Raycast/Linear) + light theme variant
- [x] Compatibility với vim, less, htop, fzf, lazygit, btop, starship
- [x] Crash diary local-only (telemetry-free)
- [x] Pipeline Developer-ID codesign + notarize

¹ Implementation và state-transition regressions đã xanh, nhưng matrix với
macOS input source thật vẫn cần một owner run có ngày tháng. Theo dõi tại
[issue #2](https://github.com/hoangperry/herminal/issues/2).

Deferred sang post-MVP — xem [CHANGELOG.md](CHANGELOG.md) "Known
limitations": split tree đệ quy, kéo-resize divider, group/search
trong SSH manager, candidate post-beta.

## Cài đặt

### Homebrew (khuyến nghị)

```sh
brew install --cask hoangperry/herminal/herminal
```

### Tải trực tiếp

1. Tải DMG từ [release mới nhất](https://github.com/hoangperry/herminal/releases/latest).
2. Mở DMG → kéo `herminal.app` vào `/Applications`.
3. Mở app; binary public đã được ký Developer ID và notarize.

### Từ source

```sh
git clone --recurse-submodules https://github.com/hoangperry/herminal
cd herminal
Scripts/bootstrap.sh           # build libghostty xcframework (~5-15 phút cold)
Scripts/make-app-bundle.sh     # đóng gói .app với ad-hoc signature
open .build/herminal.app
```

Yêu cầu: Xcode 26+, Swift 6.2+, [Zig](https://ziglang.org) 0.15.2+
(cho libghostty), `clang` cho binary probe mà integration script dùng.

## Tour nhanh khi mở lần đầu

- **⌘T / ⌘W** — tab mới / đóng pane đang focus (đóng tab khi pane cuối)
- **⌘D / ⌘⇧D** — split dọc / ngang
- **⌘⇧] / ⌘⇧[** — tab kế / tab trước
- **⌘⌥A** — pane Claude mới (split)
- **⌘⌥W** — worktree agent cô lập
- **⌘⇧A** — toggle agent dashboard (agent đang chạy + worktrees)
- **⌘1…⌘9** — nhảy tới tab N / tab cuối
- **⌘⇧S** — toggle SSH host manager (mutex với agent dashboard ở slot trái)
- **⌘⇧N** — toggle notes panel bên phải
- **⌘⇧L** — toggle theme dark / light

Agent được phát hiện bằng cách walk process subtree của herminal —
chạy `claude`, `codex`, hoặc `aider` trong bất kỳ tab nào và chúng
sẽ xuất hiện trong dashboard trong ~2 giây với badge
`running` / `idle` / `starting` (tracking qua CPU sampling) + label
`Tab N` (tab mà PTY đang ở).

![Năm bước của một lần poll agent: timer, snapshot process qua sysctl, classify theo tên hoặc argv, annotate bằng CPU delta và tab hint, render](docs/assets/agent-lifecycle.svg)

*Không agent nào phải hợp tác và không cần API key — signal được suy ra
hoàn toàn từ process tree. `argv` chỉ được đọc để nhận ra wrapper `node` /
`python` / `bun` / `deno`, rồi bỏ ngay. Xem
[`docs/CONTRIBUTOR-TOUR-AGENT-SIGNAL.md`](docs/CONTRIBUTOR-TOUR-AGENT-SIGNAL.md)
để đi theo một signal từ đầu đến cuối.*

## Tech stack

| Layer | Tech | Lý do |
|---|---|---|
| Terminal engine | [libghostty 1.3.1](https://github.com/ghostty-org/ghostty) (C ABI qua Zig) | Mature, native, không Electron |
| App | Swift 6 + AppKit + SwiftUI chrome | Real `NSTextInputClient`, real Metal layer |
| Surface | `NSView` host Metal layer của libghostty | IME pixel-precise |
| Storage | SQLite WAL (notes + SSH hosts) | Local-only, atomic, indexable |
| Distribution | DMG/zip ký Developer ID, notarized + Homebrew cask | Sandbox App Store incompatible |

![Năm layer dependency: HerminalApp, HerminalAgent, HerminalDB, HerminalCore, GhosttyKit.xcframework](docs/assets/architecture.svg)

*libghostty được dùng như một upstream release qua C ABI công bố sẵn —
không fork, không vendor thủ công. Bản đầy đủ ở
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).*

## Repo layout

```
herminal/
├── Sources/
│   ├── HerminalCore/         # libghostty C ABI bridge + BellRegistry
│   ├── HerminalDB/           # NotesStore + SSHHostsStore + SSHConfigImporter
│   ├── HerminalAgent/        # process-subtree detection + status + pane mapping
│   └── HerminalApp/          # NSApp, WorkspaceView, panels, Diary
├── App/                       # Info.plist + entitlements
├── Tests/                     # 143+ Swift Testing unit tests
├── Scripts/                   # bootstrap, bundle, verify-*, dogfood, sign, release, capture-screenshots
├── Vendor/libghostty/         # git submodule (Ghostty v1.3.1)
└── docs/
    ├── assets/               # sơ đồ cho README + screenshot app
    ├── research/             # market scan + scoring
    ├── define/herminal.prd.md # PRD source-of-truth
    ├── backlog/              # task list + retro theo từng month
    ├── QA/                   # IME checklists (VI + CJK), dogfood checklist + journal
    ├── launch/               # press kit + tweet/LinkedIn drafts
    ├── PATTERNS.md           # patterns hay lặp lại trong codebase
    └── RELEASE.md            # signing + notarize guide
```

## Đóng góp

Đọc [CONTRIBUTING.md](CONTRIBUTING.md) trước — project có opinion rõ
ràng về scope. Bug report đi qua
[bug template](.github/ISSUE_TEMPLATE/bug_report.md) (template tự
prompt diary excerpt); security issues đi qua [SECURITY.md](SECURITY.md).

## Tài liệu

| Tài liệu | Mục đích |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | Release notes từng version |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Cách propose thay đổi |
| [SECURITY.md](SECURITY.md) | Cách báo cáo vulnerability |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System overview một trang — đọc trước PR đầu tiên |
| [docs/MAINTAINER-AI-POLICY.md](docs/MAINTAINER-AI-POLICY.md) | Ranh giới human review khi dùng coding agent |
| [docs/BETA.md](docs/BETA.md) | Beta protocol và evidence ledger không telemetry |
| [docs/RELEASE.md](docs/RELEASE.md) | Cách cut signed + notarized release |
| [docs/PATTERNS.md](docs/PATTERNS.md) | Patterns hay lặp trong codebase |
| [docs/define/herminal.prd.md](docs/define/herminal.prd.md) | PRD frame mọi decision |
| [docs/QA/dogfood-checklist.md](docs/QA/dogfood-checklist.md) | Những thứ cần watch khi daily-driver |
| [docs/QA/vietnamese-ime-checklist.md](docs/QA/vietnamese-ime-checklist.md) | 20-phrase Telex/VNI smoke matrix |
| [docs/QA/cjk-ime-checklist.md](docs/QA/cjk-ime-checklist.md) | Smoke matrix IME tiếng Hàn / Nhật / Trung |
| [docs/backlog/](docs/backlog/) | Task list + retro hàng tháng M1 → M9 |

---

Made with 🐈 by Yuuhou Meow team in Việt Nam.
