# Research Report: Làm Terminal Emulator cho macOS Có Khó Không?

**Project:** herminal
**Date:** 2026-05-20
**Conducted by:** Yuuhou Meow (phù phù醬)
**Sources:** 4 parallel Gemini-3-flash queries + 3 detailed sub-reports

---

## TL;DR (Brutal Honest)

**Có. Rất khó. Nhưng khả thi nếu chọn đúng chiến lược.**

| Mức độ | Effort | Kết quả |
|--------|--------|---------|
| **MVP demo** (boots zsh, ANSI 16 màu, scrollback đơn giản) | **1-3 tháng** solo, part-time | Đủ để khoe nhưng không ai dùng được hằng ngày |
| **Daily-driver** (256/truecolor, ligature, IME, GPU, tabs, config) | **6-12 tháng** full-time | Có thể tự dùng, cộng đồng nhỏ |
| **Production-grade** (Ghostty/Alacritty parity) | **2-4 năm** | Mitchell Hashimoto mất ~2 năm cho Ghostty 1.0, riêng font rendering chiếm ~70% thời gian |

**Khuyến nghị chính:** Đừng viết từ số 0. **Embed `libghostty` (C ABI từ Ghostty)** hoặc **`alacritty_terminal` crate**, dùng Swift/SwiftUI cho GUI shell. Tiết kiệm 12-18 tháng, focus vào sự khác biệt thực sự.

---

## 1. Tại sao khó — 5 lớp phức tạp xếp chồng

Terminal emulator nhìn thì đơn giản (một cái ô đen chạy chữ), nhưng thực ra là **5 subsystem độc lập** phải vận hành chính xác:

```
┌─────────────────────────────────────────────┐
│  GUI Layer (NSWindow, Metal view, IME)      │ ← AppKit/SwiftUI khó nhất ở IME
├─────────────────────────────────────────────┤
│  Renderer (CoreText → Texture Atlas → GPU)  │ ← Bottleneck performance
├─────────────────────────────────────────────┤
│  Grid/State (scrollback, reflow, selection) │ ← Logic phức tạp nhất
├─────────────────────────────────────────────┤
│  VT/ANSI Parser (escape sequence state m/c) │ ← Có sẵn lib (vte, libvterm)
├─────────────────────────────────────────────┤
│  PTY + Process (forkpty/posix_openpt + shell)│ ← Dễ nhất, ~200 LOC
└─────────────────────────────────────────────┘
```

Mỗi lớp một mình thì viết được, **gắn lại đồng bộ là cơn ác mộng** (vd: SIGWINCH → resize grid → reflow scrollback → invalidate cache → repaint dirty tiles — phải xảy ra trong 8ms ở 120Hz ProMotion).

---

## 2. So sánh các terminal hiện có (số liệu thực tế)

| Terminal | Stack | LOC | Rendering | Ghi chú |
|----------|-------|-----|-----------|---------|
| **Ghostty** | Zig + Swift | ~60k | Metal native | Mitchell Hashimoto, ~25k★, 2 năm dev, hiện là benchmark |
| **Alacritty** | Rust | ~30k | OpenGL | ~55k★, minimal, cross-platform |
| **WezTerm** | Rust | ~180k | wgpu | Wez Furlong, Lua scripting, full-featured |
| **Kitty** | C + Python | ~110k | OpenGL | Kovid Goyal, custom graphics protocol |
| **iTerm2** | Obj-C | ~300k | Metal | 15+ năm dev, đầy đủ nhất trên macOS |
| **Warp** | Rust + React | 200k+ | Metal/wgpu | $50M+ funding, AI-first, custom UI framework |
| **Hyper** | Electron | ~20k | WebGL (xterm.js) | Easy mode, performance kém |

**Điểm quan trọng:** Chỉ Hyper là dưới 50k LOC, nhưng Hyper performance tệ. Anything serious = 30k+ LOC, **không phải project cuối tuần**.

---

## 3. Những thứ KHÓ NHẤT (không ai cảnh báo bạn)

### 3.1 Unicode & Grapheme Clusters
- **UAX #29** segmentation: emoji ZWJ sequences (👨‍👩‍👧‍👦), regional indicators (🇻🇳), skin tones, combining marks
- **East Asian Width problem:** Terminal nghĩ ký tự rộng 2 cột, vim/tmux nghĩ 1 cột → màn hình loạn
- **Grapheme width agreement:** Không có spec chính thức, mỗi terminal hơi khác nhau → vim/tmux/fzf hiển thị sai

### 3.2 VT Escape Sequences — biển bug
- Hàng nghìn sequence (CSI, OSC, DCS, SS3...), spec rải rác (ECMA-48, VT100/220/520, xterm extensions)
- **Modern protocols phải support:**
  - OSC 7 (CWD reporting cho new tab inherit pwd)
  - OSC 8 (hyperlinks)
  - OSC 52 (clipboard)
  - OSC 133 (semantic prompt — jump to prev command)
  - Kitty graphics protocol / Sixel (inline images)
  - Kitty keyboard protocol (CSI u, disambiguate Tab vs Ctrl+I)

### 3.3 Reflow on Resize
Khi user resize cửa sổ ngang, scrollback phải re-wrap **TẤT CẢ** dòng cũ một cách chính xác — đây là một trong những bug gnarly nhất, Alacritty mất nhiều năm mới fix ổn.

### 3.4 IME trên macOS (Japanese/Chinese/Korean/Vietnamese)
- Phải implement `NSTextInputClient` protocol
- **Marked text** (đang gõ, gạch chân) ≠ **inserted text** (đã commit) → không được gửi marked text vào PTY
- Vietnamese telex/VNI cũng cần IME, dễ ăn bug nếu không cẩn thận

### 3.5 Performance Targets
- **Throughput:** Casey Muratori "Refterm" demo 1.3 GB/s. Hầu hết terminal hiện đại chỉ đạt 100-300 MB/s
- **Input latency:** < 5ms để cảm thấy "snappy"; ProMotion 120Hz = 8.3ms/frame budget
- **Bottleneck thường gặp:** Text shaping (CoreText/HarfBuzz call quá nhiều) → giải pháp: cache theo **run** (chuỗi glyph), không cache theo character

---

## 4. macOS-Specific Landmines

| Vấn đề | Mức độ | Giải pháp |
|--------|--------|-----------|
| **Sandbox** | High | App Store không khả thi → distribute via DMG/Homebrew, request Full Disk Access |
| **Login vs interactive shell** | Medium | Luôn spawn `zsh -l` để source .zprofile |
| **Codesigning/Notarization** | Medium | Apple Developer ID ($99/năm) + notarytool |
| **OpenGL deprecated** | High | Bắt buộc dùng Metal hoặc wgpu (translate sang Metal) |
| **Retina/HiDPI** | Medium | NSView `wantsLayer = true`, `layer.contentsScale = backingScaleFactor` |
| **Apple Silicon SIMD** | Low | Tận dụng NEON cho VT parser nếu viết Rust/Zig |
| **macOS 15+ AppKit changes** | Low | Theo dõi release notes, hầu hết backward-compatible |

---

## 5. Foundations có thể "đứng trên vai khổng lồ"

### 5.1 Best skeletons (fork hoặc embed)

| Foundation | Ngôn ngữ | Cách dùng | Phù hợp khi |
|------------|----------|-----------|-------------|
| **`libghostty`** (Ghostty C ABI) | Zig (C-callable) | Embed như framework, viết Swift GUI riêng | **★ Khuyến nghị #1** — engine tốt nhất 2026 |
| **`alacritty_terminal` crate** | Rust | Bridge sang Swift bằng UniFFI/C ABI | Muốn ecosystem Rust thuần |
| **`termwiz` + `wezterm-term`** | Rust | Modular, pick from menu | Cần customization sâu |
| **SwiftTerm** (Miguel de Icaza) | Swift thuần | Drop-in vào AppKit/SwiftUI | Prototype nhanh, không cần GPU |

### 5.2 Layer-by-layer libraries

| Layer | macOS-native | Cross-platform |
|-------|--------------|----------------|
| **PTY** | `forkpty`, `posix_openpt` + `posix_spawn` | `portable-pty` (Rust) |
| **VT parser** | — | `vte` (Rust), `libvterm` (C), `vtparse` (C) |
| **Text shaping** | **CoreText** ★ | HarfBuzz, cosmic-text (Rust) |
| **GPU** | **Metal** ★ | wgpu (Rust, → Metal) |
| **Config format** | — | TOML (Alacritty), Lua (WezTerm/Ghostty) |

★ = lựa chọn tối ưu cho macOS-only project

---

## 6. Decision Framework cho herminal

| Chiến lược | Time-to-MVP | Time-to-prod | Differentiation | Recommended? |
|------------|-------------|--------------|-----------------|--------------|
| **Fork Ghostty** | 2 tuần | 3-6 tháng | Thấp (giống upstream) | Nếu muốn ship nhanh |
| **Embed `libghostty` + Swift GUI** | 1 tháng | 6-9 tháng | **Cao** (UI/UX riêng, engine top-tier) | **★ Khuyến nghị** |
| **Embed `alacritty_terminal` + Swift** | 1.5 tháng | 8-12 tháng | Cao | Nếu thích Rust hơn Zig |
| **SwiftTerm + custom Metal renderer** | 3 tuần | 9-15 tháng | Cao | Nếu muốn Swift-only stack |
| **Viết từ scratch (Swift)** | 2-3 tháng | 24-48 tháng | Tối đa | ❌ Hố đen, đừng làm |
| **Viết từ scratch (Rust+Metal)** | 2 tháng | 24-36 tháng | Tối đa | ❌ Trừ khi mục đích là học |

---

## 7. Khoảng trống thị trường 2026 (góc nhìn positioning)

Landscape hiện tại:
- **Ghostty** đã chiếm vị trí "fast + native + free" (Dec 2024 GA)
- **Warp** chiếm "AI-native + block UI" ($50M funding, có lock-in)
- **iTerm2** chiếm "feature-complete + free" nhưng đang già
- **Alacritty/WezTerm/Kitty** chiếm "power user + cross-platform"

**Khoảng trống khả thi cho herminal:**
1. **Privacy-first AI terminal** — local LLM (Ollama) integration, không cloud → đối lập Warp
2. **Design-first / opinionated UX** — kiểu Linear/Raycast cho terminal, mỹ thuật vượt trội
3. **Workflow niche** — focus một use case (vd: DevOps deploy dashboard, data scientist REPL, hoặc native Vietnamese coder workflow)
4. **Embedded/AI agent host** — terminal được thiết kế cho Claude Code / agent workflows, không phải human-typing-first

**Đừng đi đường:** "Just another fast terminal" — Ghostty đã làm rồi, free, và tốt hơn bất cứ thứ gì bạn build solo trong 2 năm tới.

---

## 8. Compatibility test matrix (bắt buộc test)

| Phần mềm | Test gì |
|----------|---------|
| **vim/neovim** | True color, mouse, alternate screen buffer |
| **tmux** | Nested escape sequences, mouse, true color |
| **fzf** | Alternate screen, full-screen UI, mouse |
| **starship/p10k** | Powerline glyphs, true color, OSC 133 |
| **htop/btop** | Mouse, true color, Unicode block chars |
| **lazygit/lazydocker** | Mouse drag, color, focus |
| **ranger/nnn** | Image preview (Sixel/Kitty graphics) |
| **claude-code / agent CLIs** | OSC sequences, ANSI parsing chính xác |

Nếu vim/tmux không chạy hoàn hảo → terminal không ai dùng được.

---

## 9. Khuyến nghị cụ thể cho herminal

### Stack đề xuất

```
┌─────────────────────────────────────────────┐
│  SwiftUI shell (window, tabs, settings)    │  ← phù phù醬 ưa thích
├─────────────────────────────────────────────┤
│  Custom Metal renderer (MTKView)            │
│  + CoreText shaping + texture atlas         │
├─────────────────────────────────────────────┤
│  libghostty (Zig core, C ABI)              │  ← engine
│  → PTY + VT parsing + grid state            │
└─────────────────────────────────────────────┘
```

### Lộ trình 12 tháng (part-time solo)

| Tháng | Mục tiêu | Deliverable |
|-------|----------|-------------|
| 1 | Spike `libghostty` Swift binding | Boot zsh trong NSTextView, render text |
| 2-3 | Custom Metal renderer + glyph atlas | Render fluid, 120fps cuộn |
| 4-5 | IME + key handling + selection | Gõ tiếng Việt OK, copy/paste |
| 6 | Tabs, splits, config | TOML/JSON config, multi-tab |
| 7-8 | Testing matrix (vim/tmux/fzf/starship) | Daily-driver được |
| 9 | Theme system + font management | Customize visual |
| 10-11 | **Differentiation feature** (AI local? niche workflow?) | Lý do tồn tại |
| 12 | Notarization, DMG, public beta | Ship v0.1 |

---

## 10. Unresolved Questions (cần chủ nhân quyết)

1. **Mục tiêu cuối cùng là gì?** Pet project học hỏi? Sản phẩm ship? Mở source? Thương mại?
2. **Stack preference?** Swift-thuần (chậm hơn, dễ tuyển coder Việt) vs Rust/Zig core + Swift GUI (nhanh, khó hơn)
3. **Differentiation thesis?** Tại sao có người sẽ chọn herminal thay vì Ghostty/Warp? (Phải có câu trả lời rõ trước khi viết dòng code đầu)
4. **Có ổn không nếu fork Ghostty và customize UI?** (Tiết kiệm 12-18 tháng nhưng giới hạn khác biệt)
5. **Bao nhiêu thời gian/tuần dành cho project này?** 5 giờ/tuần và 30 giờ/tuần ra hai roadmap hoàn toàn khác

---

# Special Deep Dive: Best macOS Terminal Emulators 2026 — AI INTEGRATION Perspective

**Date:** 2026-05-20
**Scope:** Evaluation of AI features, Agent-friendliness, and Privacy Models.

## 1. Executive Summary
The terminal emulator landscape in 2026 has bifurcated. We see **AI-Native Platforms** (Warp, Wave) competing against **Agent-Optimized Shells** (Ghostty, cmux). While Warp offers the most integrated "magic" experience, a growing movement of developers prefers high-performance, open-source shells that host external CLI agents (like Claude Code) via semantic protocols (OSC 133/7/99).

## 2. Terminal Analysis

### 2.1 Warp: The Agentic Development Environment (ADE)
Warp has transitioned from a terminal to a full platform.
- **Oz Agent:** A built-in agent that performs multi-step tasks (e.g., "Migrate this repo to Vitest"). It generates plans, executes commands with your approval, and handles errors autonomously.
- **Active AI:** Real-time suggestions based on shell history and exit codes.
- **MCP (Model Context Protocol):** Allows the agent to query local docs, Linear, or Sentry.
- **Privacy:** Requires an account; collects telemetry. The client is open-source, but agent features are cloud-orchestrated.

### 2.2 cmux: The Multi-Agent Command Center (2026 Entrant)
Released in early 2026, cmux is a native Swift app built on the **Ghostty** engine.
- **Agent Orchestration:** Designed for running multiple agents (Claude Code, Aider, etc.) simultaneously.
- **Notification Rings:** Panes glow to signal when an agent needs input.
- **WebKit Sidebar:** A built-in browser that agents can programmatically control to verify UI changes without leaving the terminal.
- **Privacy:** Open-source (GPL), local-first, no account required.

### 2.3 Ghostty: The Performance Host
Created by Mitchell Hashimoto, Ghostty is the 2026 standard for "invisible" performance.
- **Agent Integration:** Zero built-in AI features. It focuses on being the fastest "pipe" for external agents.
- **Claude Code Optimization:** Preferred host for Claude Code due to ultra-low latency (~2ms) and support for the **Kitty Graphics Protocol** for inline images and diffs.
- **Privacy:** Zig-based, zero telemetry, completely open-source.

### 2.4 Wave: The Context-Rich Workspace
Wave focuses on eliminating context-switching by embedding web tools.
- **Contextual AI:** Integrated chat can "see" terminal scrollback, file previews, and web widgets.
- **Durable Sessions:** Sessions persist across network drops, allowing AI agents to finish remote tasks reliably.
- **Privacy:** Open-source, local-first. Supports local models via Ollama.

### 2.5 iTerm2: The Privacy-Focused Modular Classic
iTerm2 maintains its lead for users who want "Opt-in" AI.
- **AI Plugin:** A separate, sandboxed app for security.
- **Ollama Integration:** Easiest setup for local LLMs via OpenAI-compatible endpoints.
- **Codecierge:** A toolbelt assistant that understands session context for error diagnosis.

---

## 3. Privacy & Cost Model Comparison

| Terminal | Privacy Model | Cloud Dependency | Cost Model | AI Data Sovereignty |
| :--- | :--- | :--- | :--- | :--- |
| **Warp** | High Telemetry | Required | $20/mo (Pro) | Low (Cloud Processing) |
| **Wave** | Local-first | Optional | Free | High (Local/BYOK) |
| **cmux** | Local-first | None | Free | High (Local/Open) |
| **Ghostty**| Zero Telemetry | None | Free | Total (Host only) |
| **iTerm2** | Modular/Opt-in | Optional | Free | High (Local Ollama) |

---

## 4. Ranking: AI Maturity vs. Privacy

| Rank | Terminal | AI Maturity | Privacy Score | Cost | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **#1** | **Warp** | ⭐⭐⭐⭐⭐ | 🔴 | $$$ | Best for "Hands-off" AI |
| **#2** | **cmux** | ⭐⭐⭐⭐ | 🟢 | Free | Best for Multi-Agent Work |
| **#3** | **Ghostty**| ⭐ (Host) | ⭐⭐⭐⭐⭐ | Free | Best for Claude Code |
| **#4** | **Wave** | ⭐⭐⭐ | 🟢 | Free | Best for Remote/Web Tasks |
| **#5** | **iTerm2** | ⭐⭐⭐ | ⭐⭐⭐⭐ | Free | Best for Local/Private AI |

---

## 5. Citations & References
- [1] Warp Blog: "Oz: Our Vision for the Agentic Terminal" (Jan 2026).
- [2] zenn.dev: "Why we built cmux on libghostty" (March 2026).
- [3] Ghostty Spec: "OSC 133 Semantic Prompt Adoption" (2025).
- [4] Wave Terminal Docs: "Using Ollama for OMNI-Context Workflows".
- [5] iTerm2 Release Notes v3.7: "Modular AI and Codecierge Security Model".
- [6] Anthropics: "Best Terminal Practices for Claude Code" (GitHub Issue #1465).
