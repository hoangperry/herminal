# herminal

> Terminal macOS AI-native cho developer Việt chạy Claude Code và agent
> CLIs hằng ngày.

[![CI](https://github.com/hoangperry/herminal/actions/workflows/ci.yml/badge.svg)](https://github.com/hoangperry/herminal/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black.svg)](https://www.apple.com/macos)
[![Swift 6](https://img.shields.io/badge/swift-6-orange.svg)](https://swift.org)

**Trạng thái:** v0.1.0 beta — M7/7 ([CHANGELOG](CHANGELOG.md)).
**Nền tảng:** macOS 14+ Apple Silicon.

> 🇬🇧 English version: [`README.md`](README.md)

---

## herminal là gì

Một terminal macOS local-first xây quanh 2 nhu cầu hằng ngày mà các
terminal 2026 hiện tại đều thiếu một phần:

1. **Bạn chạy Claude Code / Codex / Aider cả ngày** và cần thấy ngay
   agent nào đang sống, idle, hay done — mà không phải mở thêm cửa sổ
   khác để check.
2. **Bạn viết tiếng Việt** và cần Telex / VNI hiển thị đúng ngay lần
   đầu, trong tmux, trong vim, mọi lúc.

herminal pair engine [libghostty](https://github.com/ghostty-org/ghostty)
(Zig, mature, native performance) với một Swift / AppKit shell quản
lý IME và chrome. Lưu trữ dùng SQLite cho cả per-session notes lẫn
saved SSH hosts. Không cloud, không telemetry, không cần account.

## Tại sao cần thêm 1 terminal nữa?

Năm 2026 không terminal nào hit đủ 5 thứ cùng lúc:

| Yêu cầu | iTerm2 | Warp | Wave | Ghostty | **herminal** |
|---|---|---|---|---|---|
| Tốc độ native macOS | ✓ | partial | partial | ✓ | ✓ |
| Vietnamese IME đáng tin | ✓ | × | × | ✓ | ✓ |
| tmux + multi-session | ✓ | partial | × | ✓ | ✓ |
| Dashboard agent built-in | × | partial | × | × | ✓ |
| Notes per-session local-only | × | × | × | × | ✓ |

Xem [`docs/research/`](docs/research/) cho full comparison + scoring
rubric đã dùng để lập bảng trên.

## Scope MVP (v0.1.0)

Tất cả đã ship:

- [x] Terminal core native qua libghostty (Metal renderer, p95 keystroke <5ms)
- [x] Vietnamese IME qua NSTextInputClient (Telex + VNI đã verify)
- [x] Workspace multi-session + split dọc/ngang
- [x] Dashboard agent với phân biệt running / idle / starting
- [x] Per-session notes (SQLite WAL) + Markdown round-trip
- [x] SSH Connection Manager + one-click spawn + import từ ~/.ssh/config
- [x] Premium dark chrome (style Raycast/Linear) + light theme variant
- [x] Compatibility với vim, less, htop, fzf, lazygit, btop, starship
- [x] Crash diary local-only (telemetry-free)
- [x] Pipeline Developer-ID codesign + notarize

Deferred sang post-MVP — xem [CHANGELOG.md](CHANGELOG.md) "Known
limitations": split tree đệ quy, kéo-resize divider, group/search
trong SSH manager, candidate post-beta.

## Cài đặt

### Từ tagged release (khuyến nghị một khi v0.1.0 đã publish)

1. Download `herminal-v0.1.0.zip` từ trang
   [Releases](https://github.com/hoangperry/herminal/releases).
2. Giải nén → kéo `herminal.app` vào `/Applications`.
3. Mở. Gatekeeper có thể show cảnh báo lần đầu; các lần sau im
   lặng (build đã được notarize).

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
- **⌘⇧A** — toggle agent dashboard
- **⌘⇧S** — toggle SSH host manager (mutex với agent dashboard ở slot trái)
- **⌘⇧N** — toggle notes panel bên phải
- **⌘⇧L** — toggle theme dark / light

Agent được phát hiện bằng cách walk process subtree của herminal —
chạy `claude`, `codex`, hoặc `aider` trong bất kỳ tab nào và chúng
sẽ xuất hiện trong dashboard trong ~2 giây với badge
`running` / `idle` / `starting` (tracking qua CPU sampling) + label
`Tab N` (tab mà PTY đang ở).

## Tech stack

| Layer | Tech | Lý do |
|---|---|---|
| Terminal engine | [libghostty 1.3.1](https://github.com/ghostty-org/ghostty) (C ABI qua Zig) | Mature, native, không Electron |
| App | Swift 6 + AppKit + SwiftUI chrome | Real `NSTextInputClient`, real Metal layer |
| Surface | `NSView` host Metal layer của libghostty | IME pixel-precise |
| Storage | SQLite WAL (notes + SSH hosts) | Local-only, atomic, indexable |
| Distribution | Developer-ID signed `.app` zip + (planned) Homebrew | Sandbox App Store incompatible |

## Repo layout

```
herminal/
├── Sources/
│   ├── HerminalCore/         # libghostty C ABI bridge + BellRegistry
│   ├── HerminalDB/           # NotesStore + SSHHostsStore + SSHConfigImporter
│   ├── HerminalAgent/        # process-subtree detection + status + pane mapping
│   └── HerminalApp/          # NSApp, WorkspaceView, panels, Diary
├── App/                       # Info.plist + entitlements
├── Tests/                     # 77+ Swift Testing unit tests
├── Scripts/                   # bootstrap, bundle, verify-*, dogfood, sign, release
├── Vendor/libghostty/         # git submodule (Ghostty v1.3.1)
└── docs/
    ├── research/             # market scan + scoring
    ├── define/herminal.prd.md # PRD source-of-truth
    ├── backlog/              # task list + retro theo từng month
    ├── QA/                   # IME checklist, dogfood checklist + journal
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
| [docs/RELEASE.md](docs/RELEASE.md) | Cách cut signed + notarized release |
| [docs/PATTERNS.md](docs/PATTERNS.md) | Patterns hay lặp trong codebase |
| [docs/define/herminal.prd.md](docs/define/herminal.prd.md) | PRD frame mọi decision |
| [docs/QA/dogfood-checklist.md](docs/QA/dogfood-checklist.md) | Những thứ cần watch khi daily-driver |
| [docs/QA/vietnamese-ime-checklist.md](docs/QA/vietnamese-ime-checklist.md) | 20-phrase Telex/VNI smoke matrix |
| [docs/backlog/](docs/backlog/) | Task list + retro hàng tháng M1 → M9 |

---

Made with 🐈 by Yuuhou Meow team in Việt Nam.
