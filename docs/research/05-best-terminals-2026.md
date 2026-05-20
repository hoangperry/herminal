# Best macOS Terminal Emulators 2026 — Comparison Table

**Project:** herminal
**Date:** 2026-05-20
**Methodology:** Multi-provider discovery (`/octo:discover deep`) — 5 Gemini + 1 Codex GPT-5 secondary research
**Note:** Gemini quota bị exhausted giữa chừng → nguồn chính: Codex `05f-codex-independent.md` + kiến thức tích hợp về landscape 2026.

---

## Executive Ranking (Recommended for Power Developer 2026)

| Rank | Terminal | Score | Short Take |
|---:|---|---:|---|
| 1 | **Ghostty 1.x** | **9.2/10** | Best Mac default — fast, native, modern protocols, no product noise |
| 2 | **Kitty** | 8.6/10 | Most capable terminal-native power environment, keyboard-first |
| 3 | **Warp** | 8.4/10 | Best for AI/agentic workflows — open-sourced client 2026, AGPL |
| 4 | **iTerm2** | 8.2/10 | Mature workhorse, unmatched tmux control mode |
| 5 | **WezTerm** | 8.0/10 | Most configurable cross-platform via Lua |
| 6 | **Wave Terminal** | 7.6/10 | Open-source Warp challenger, BYOK AI, workspace blocks |
| 7 | **Alacritty** | 7.4/10 | Minimalist Rust+OpenGL, perfect for tmux/zellij users |
| 8 | **Rio** | 7.1/10 | Rust+WebGPU upstart, modern but young |
| 9 | **Tabby** | 6.6/10 | SSH/Telnet/serial operator's friend, Electron weight |
| 10 | **Terminal.app** | 5.8/10 | Apple baseline — only for emergencies |
| 11 | **Hyper** | 4.3/10 | Electron+JS hack toy, không serious 2026 |

---

## Master Comparison Table — Side-by-Side

| Tiêu chí | Ghostty | Kitty | Warp | iTerm2 | WezTerm | Wave | Alacritty | Rio | Tabby | Terminal.app | Hyper |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Stack** | Zig+Swift | C+Python | Rust+React | Obj-C | Rust | Go+TS/Electron | Rust | Rust | Electron+TS | Apple proprietary | Electron+TS |
| **Rendering** | Metal | OpenGL | Metal/wgpu | Metal | wgpu | (Electron+GPU) | OpenGL | Metal/Vulkan | (Electron) | Native AppKit | WebGL (xterm.js) |
| **GitHub Stars (approx)** | ~25k | ~25k | ~25k (mới OSS 2026) | ~14k | ~17k | ~14k | ~55k | ~5k | ~60k | n/a | ~43k |
| **License** | **MIT** ★ | GPL-3.0 | AGPL-3 (+ MIT subset) | GPL-2/3 | **MIT** ★ | Apache-2.0 ★ | Apache-2.0 | **MIT** ★ | MIT ★ | Apple proprietary | MIT ★ |
| **macOS native feel** | ★★★★★ | ★★ | ★★★ | ★★★★★ | ★★ | ★★★ | ★★ | ★★ | ★★ | ★★★★★ | ★★ |
| **Performance (subjective)** | ★★★★★ | ★★★★★ | ★★★★ | ★★★ | ★★★★ | ★★★ | ★★★★★ | ★★★★ | ★★ | ★★★ | ★★ |
| **Built-in tabs/splits** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (block model) | ✗ (intentional) | ✓ | ✓ | ✓ | ✓ |
| **AI integration native** | ✗ (agent-friendly) | ✗ | ✓✓✓ (best-in-class) | ✗ | ✗ | ✓✓ (BYOK + Ollama) | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Image protocols** | Kitty graphics | Kitty graphics ★ | partial | iTerm2 inline | Kitty + Sixel | ✓ | ✗ | ✓ | partial | ✗ | partial |
| **Config format** | Plain text (`config`) | conf file | GUI + cloud | GUI + plist | **Lua** | UI + JSON | TOML | TOML | UI + YAML | GUI | JS |
| **Hot-reload config** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| **OSC 133 semantic prompts** | ✓ | ✓ | ✓ (block UI) | ✓ | ✓ | ✓ | partial | partial | ✗ | ✗ | ✗ |
| **Kitty keyboard protocol** | ✓ | ✓ (native) | partial | ✗ | ✓ | partial | partial | ✓ | ✗ | ✗ | ✗ |
| **Ligatures** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| **IME (Vietnamese/CJK)** | ✓ | ✓ | ✓ | ✓✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓✓ | ✓ |
| **tmux integration** | standard | standard + remote ctrl | block-aware | **tmux -CC** ★ | own multiplexer | ✓ | standard | standard | ✓ | standard | standard |
| **SSH manager UI** | ✗ | kittens | partial | partial | domains | ✓ | ✗ | ✗ | ✓✓ ★ | ✗ | ✗ |
| **Plugin system** | ✗ | kittens (Python) | extensions | scripts/triggers | Lua callbacks | extensions | ✗ | ✗ | ✓ (plugins) | ✗ | npm plugins |
| **Learning curve** | Easy | Hard | Easy | Medium | Hard | Easy | Easy | Easy | Medium | Trivial | Trivial |
| **Sane defaults** | ★★★★★ | ★★★ | ★★★★ | ★★★ | ★★ | ★★★★ | ★★★ | ★★★★ | ★★★ | ★★★★ | ★★★ |
| **Funding model** | Donations | Solo (donations) | VC-backed | Solo (donations) | Solo | OSS startup | Community | Community | Solo+sponsors | Apple | Vercel (idle) |
| **Bus factor risk** | Medium (Hashimoto) | High (Goyal solo) | Low (company) | High (Nachman solo) | High (Furlong solo) | Medium | Medium | High (solo) | Medium | n/a | High (idle) |
| **2025-2026 activity** | ★★★★★ active | ★★★★★ very active | ★★★★ OSS 2026 | ★★★ steady | ★★★ steady | ★★★★ active | ★★ slow | ★★★★ active | ★★★ steady | ★ stagnant | ★ idle |

★ = particular strength | ★★★ = above average | ★★★★★ = best-in-class

---

## Phân Nhóm Theo Target User

### 🚀 "Tôi muốn cái nhanh, native, không phiền"
**→ Ghostty 1.x** (9.2/10) — không có lựa chọn nào tốt hơn cho Mac 2026

### 🧠 "Tôi sống trong terminal, muốn nó programmable"
**→ Kitty** (8.6/10) — kittens, remote control, image protocols. Trade-off: GPL-3, UI không native lắm

### 🤖 "Workflow của tôi nặng AI/agent"
**→ Warp** (8.4) hoặc **Wave Terminal** (7.6, open source BYOK)
- Warp: trải nghiệm AI tốt nhất, AGPL client
- Wave: privacy-friendly, dùng Ollama/LM Studio local được

### 🛠️ "Tôi cần tmux control mode + maturity"
**→ iTerm2** (8.2/10) — không ai bằng về tmux -CC integration

### 🔧 "Tôi muốn customize sâu, cross-platform"
**→ WezTerm** (8.0/10) — Lua + multiplexer built-in. Trade-off: stable lag, Lua project of its own

### 🪶 "Tôi dùng tmux/zellij, terminal phải im lặng"
**→ Alacritty** (7.4/10) — không tabs, không splits, just renderer

### 🌐 "Tôi quản lý nhiều SSH/serial/Telnet"
**→ Tabby** (6.6/10) — connection manager + encrypted secrets

### 🎓 "Tôi mới học, dùng máy Mac sạch"
**→ Terminal.app** rồi upgrade lên **Ghostty** khi cảm thấy chật

---

## Performance Snapshot (best-effort, public benchmarks scarce)

| Metric | Best | Notes |
|---|---|---|
| **Input latency** | Alacritty / Ghostty | < 5ms typical; tracked at refterm-style benchmarks |
| **Throughput (cat 1GB)** | Ghostty / Alacritty / Kitty | 100-300 MB/s thực tế (Refterm 1.3 GB/s là goalpost) |
| **Startup time cold** | Alacritty / Terminal.app | < 100ms |
| **Startup time** | Warp / Hyper / Tabby | Electron tax: 500ms-2s |
| **Memory idle** | Alacritty (~30MB) | vs Electron-based ~200-400MB |
| **120Hz ProMotion stability** | Ghostty / Kitty | Most others target 60Hz |

**Caveat:** Hầu hết benchmark công khai đã lỗi thời (2022-2023). Ghostty 1.3+ chưa có benchmark độc lập đầy đủ. Số liệu trên là tổng hợp từ Reddit/HN threads + repo benchmark commits.

---

## AI Integration Landscape 2026

| Terminal | AI Mode | Local LLM | Privacy | Cost |
|---|---|---|---|---|
| **Warp** | Block UI + agent mode, multi-agent orchestration | partial via Oz | Cloud-first (concern) | Free tier + Team paid |
| **Wave Terminal** | BYOK + Ollama/LM Studio | ✓ | ★★★★★ self-host | Free OSS |
| **Ghostty** | None built-in, but agent-friendly OSC | n/a | ★★★★★ local | Free |
| **iTerm2** | None native, có scripts | n/a | ★★★★★ local | Free |
| **Kitty/WezTerm/Alacritty** | None | n/a | ★★★★★ local | Free |
| **Tabby/Hyper** | Community plugins | n/a | depends | Free |

**Takeaway:** Có khoảng trống rõ cho "AI terminal mà privacy-first" — Wave đang chiếm chỗ này nhưng nặng (Electron+Go), UI giống IDE hơn terminal. Cơ hội cho herminal.

---

## Verdict cho herminal (Discovery Phase)

### Thị trường 2026 đã đông
- Ghostty đã chiếm "fast + native + free" — đóng cửa với bất kỳ "terminal nhanh hơn" nào
- Warp + Wave chiếm "AI workspace" — có cạnh tranh nhưng Warp lock-in, Wave nặng
- iTerm2 vẫn giữ "mature + tmux" — không ai cạnh tranh được
- Alacritty/Kitty/WezTerm giữ "power user/keyboard-first"

### Khoảng trống còn để herminal chen vào (theo độ khả thi)
1. **AI terminal privacy-first lightweight** — đối lập Warp + nhẹ hơn Wave (Wave nặng vì Electron)
   - Stack: libghostty engine + Swift GUI + Ollama integration
   - USP: "Local-first AI terminal, native macOS, không cloud"

2. **Design-first terminal** — opinionated UX kiểu Linear/Raycast
   - Stack: libghostty + Swift premium UI
   - USP: "Terminal cho dev có taste, không phải nerd tool"

3. **Agent-host terminal** — tối ưu cho Claude Code, Cursor, Aider
   - Stack: libghostty + Swift + agent IPC protocol
   - USP: "Terminal đầu tiên thiết kế cho human + AI agent đồng làm việc"

### Đường KHÔNG nên đi
- ❌ "Just another fast terminal" — Ghostty đã làm rồi, tốt hơn
- ❌ "Another Electron with theme support" — Hyper failed, Tabby nặng, Wave overweight
- ❌ "Warp clone" — không có $50M+ funding sẽ thua trên product complexity

---

## Unresolved Questions

1. **Differentiation thesis cho herminal là gì?** — bắt buộc phải có câu trả lời trước khi build
2. **Solo project hay team?** — quyết định stack + ambition
3. **AI-first hay design-first hay cả hai?** — quá ambitious nếu chọn cả
4. **OSS để build cộng đồng hay closed để hoàn thiện trải nghiệm?**

---

## Sub-Report Sources

- [05f-codex-independent.md](./05f-codex-independent.md) — **Nguồn chính** (Codex GPT-5, 320k tokens, đầy đủ 11 terminal)
- [05a-performance.md](./05a-performance.md) — _Gemini quota exhausted_
- [05b-features.md](./05b-features.md) — _Gemini quota exhausted_
- [05c-design-ux.md](./05c-design-ux.md) — _Gemini quota exhausted_
- [05d-ai-integration.md](./05d-ai-integration.md) — _Gemini quota exhausted_
- [05e-ecosystem.md](./05e-ecosystem.md) — _Gemini quota exhausted_

### Reference Links

- Ghostty: https://ghostty.org/docs · https://github.com/ghostty-org/ghostty
- Warp OSS announcement: https://www.warp.dev/blog/warp-is-now-open-source
- iTerm2: https://iterm2.com/ · https://github.com/gnachman/iTerm2
- Alacritty: https://github.com/alacritty/alacritty
- WezTerm: https://wezterm.org/ · https://github.com/wezterm/wezterm
- Kitty: https://github.com/kovidgoyal/kitty
- Wave Terminal: https://github.com/wavetermdev/waveterm
- Rio: https://rioterm.com/ · https://github.com/raphamorim/rio
- Tabby: https://tabby.sh/ · https://github.com/Eugeny/tabby
- Hyper: https://github.com/vercel/hyper
