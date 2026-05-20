# Terminal Đáp Ứng Yêu Cầu Chủ Nhân (2026-05-20)

## Yêu cầu của chủ nhân (5 tiêu chí)

1. **Tối ưu cho Claude Code** — agent CLI workflow, OSC sequences, streaming tokens không lag
2. **Tiếng Việt hiệu quả** — IME Telex/VNI, dấu thanh ấ/ề/ư/đ đầy đủ, copy/paste giữ dấu
3. **Quản lý tmux + multi-session** — tmux -CC control mode hoặc multiplexer tương đương
4. **Quản lý nhiều agent đang hoạt động** — dashboard view, status indicators, side-by-side
5. **Note riêng cho từng terminal** — persistent scratchpad attached to tab/session

---

## Scoring Matrix (0-10 mỗi tiêu chí)

| Terminal | Claude Code | VN IME | tmux/Multi | Agent Dashboard | Notes | **Tổng** |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 🥇 **Warp** | 10 | 8 | 5 | **10** | **10** | **43** |
| 🥈 **iTerm2** | 7 | **10** | **10** | 6 | 8 | **41** |
| 🥉 **Wave Terminal** | 9 | 7 | 6 | 9 | 9 | **40** |
| **Tabby** | 6 | 7 | 8 | 7 | 7 | 35 |
| **WezTerm** | 8 | 7 | 9 | 5 | 4 | 33 |
| **Ghostty 1.x** | **10** | 9 | 7 | 4 | 2 | 32 |
| **Kitty** | 8 | 6 | 8 | 5 | 3 | 30 |
| **Alacritty** | 7 | 5 | 4 | 2 | 1 | 19 |

---

## Verdict ngắn gọn theo trade-off

### 🥇 Warp — Best All-Around (43/50)
- ✓ **Oz Agent** orchestration native, blocks UI lý tưởng cho agent
- ✓ **Warp Drive Notebooks** = persistent notes mạnh nhất hiện tại
- ✗ Cloud-dependent (privacy risk), AGPL client
- ✗ Block UI đôi khi clash với tmux truyền thống
- ✗ Vietnamese IME OK nhưng có thể buggy với Telex composition

### 🥈 iTerm2 — Best Privacy + tmux (41/50)
- ✓ **tmux -CC control mode** — không ai bằng
- ✓ Vietnamese IME hoàn hảo (AppKit-native candidate window)
- ✓ Mature, stable, offline
- ✗ Không có AI built-in
- ✗ Notes chỉ ở mức "badges/triggers", không phải scratchpad thật
- ✗ Agent dashboard không có

### 🥉 Wave Terminal — Best Visual AI OSS (40/50)
- ✓ Block-based workspace render markdown, AI status widgets
- ✓ BYOK AI (Claude/GPT/Gemini) + Ollama local
- ✓ Apache-2.0 OSS, file preview/editor blocks
- ✗ Electron nặng (~300MB RAM idle)
- ✗ tmux integration yếu (replace nhiều hơn collaborate)
- ✗ Vietnamese IME qua Electron không bằng native

### Ghostty 1.x — Best Performance, thiếu UI cho yêu cầu này (32/50)
- ✓ Fastest + native + OSC 133 perfect cho Claude Code
- ✓ Vietnamese IME ngon (NSTextInputClient native)
- ✗ Không có agent dashboard (by design)
- ✗ Không có notes (by design)

---

## 🎯 Recommendation Hiện Tại (dùng tạm trong khi build herminal)

### Setup A: Privacy-first + maturity
```
iTerm2 (main) + tmux -CC + Claude Code CLI
+ Obsidian/Bear cho notes (sidecar)
+ Ghostty (secondary cho heavy agent streaming sessions)
```
**Best cho:** Người tin tmux, không muốn cloud AI, cần Vietnamese IME tốt nhất

### Setup B: AI-first, chấp nhận cloud
```
Warp (main) — Oz agents + Drive notebooks built-in
+ Tab dedicated cho Claude Code
+ Vietnamese: kiểm tra Telex hoạt động trong Warp's input editor
```
**Best cho:** Workflow AI-heavy, không e ngại cloud sync

### Setup C: OSS + Visual + BYOK
```
Wave Terminal (main) — blocks + local Ollama + notebooks
+ Tab/block riêng cho mỗi agent
+ Per-block notes built-in
```
**Best cho:** Muốn OSS + privacy + AI dashboard, chấp nhận Electron weight

---

## 🚀 Gap Analysis = SPEC cho herminal

**Không terminal nào trong 2026 kết hợp đủ 5 yêu cầu của chủ nhân.** Đây là 4 khoảng trống cụ thể:

### Gap 1: Native + Agent Hybrid
- Ghostty fast nhưng "dumb" (không UI cho agents)
- Warp smart nhưng non-native (custom Rust UI, cloud)
- **Thiếu:** Native Swift/Metal terminal có Warp-like agent dashboard + iTerm2-level IME

### Gap 2: Context-Aware Multiplexing cho AI
- tmux opaque với AI agents — không có protocol để agent "see" và "manage" pane cụ thể
- Agents phải scrape screen buffer (tốn token)
- **Thiếu:** Protocol AI-aware để agent biết structure của panes/sessions

### Gap 3: Vietnamese-Aware Agent Buffers
- AI agents (Claude Code) mặc định English formatting
- Không có protocol terminal nói với agent: "User đang gõ Telex, đừng interrupt với partial token streams phá composition buffer"
- **Thiếu:** IME-state protocol giữa terminal ↔ agent

### Gap 4: Local-First Persistent Notes
- Warp Notebooks cloud-synced = privacy risk
- iTerm2 không có notes
- Wave có nhưng Electron-heavy
- **Thiếu:** Local-first notes cryptographically linked tới shell PID / Git branch, sidebar không Electron

---

## 💡 herminal Positioning (rút ra từ gaps)

**"The AI-native macOS terminal for Vietnamese developers"**

- 🎯 **Target user:** Vietnamese developer dùng Claude Code/Cursor/Aider hằng ngày, cần tiếng Việt + tmux + multi-agent
- 🛠️ **Stack đề xuất:** libghostty engine (performance, Claude Code OSC) + Swift/SwiftUI GUI (native IME, dashboard) + local notes DB (SQLite/file)
- ✨ **USP:**
  1. **Native Vietnamese-first IME** (Telex/VNI built-in, agent IME-state protocol)
  2. **Agent panel** — sidebar/dashboard cho concurrent agents với status
  3. **Per-tab notes** — local-first, encrypted, attached to session/branch
  4. **tmux -CC native integration** (Pro version)
  5. **Claude Code optimized** — agent-aware OSC handling, không lag streaming

**Đối thủ trực tiếp:** Warp (nhưng herminal native + privacy-first + Vietnamese)
**Đối thủ gián tiếp:** iTerm2 + Obsidian + tmux + Ollama stack

---

## ⚠️ Risks cần đối mặt

1. **Time-to-market** — Warp đã có 4 năm head start trên AI UX
2. **Vietnamese market size** — niche, có scale enough không?
3. **Cạnh tranh với Ghostty** — Mitchell Hashimoto có thể add notes/agent features trong 6-12 tháng
4. **Apple platform risk** — macOS-only giới hạn TAM
5. **Solo bus factor** — không có team backup

---

## Khuyến nghị tiếp theo

1. **Trong 1-2 tuần tới:** Dùng **Setup A (iTerm2 + tmux + Claude Code)** để có baseline Vietnamese + tmux + privacy
2. **Trong 1 tháng:** Spike technical với libghostty + Swift để verify khả thi
3. **Trong 3 tháng:** Build MVP với 5 core features (agent dashboard, notes, IME, tmux -CC, Claude Code OSC)
4. **Trong 6 tháng:** Beta riêng cho 10-20 Vietnamese dev bạn bè

---

## Source

- Gemini-3-flash deep research, 2026-05-20
- Codex GPT-5 secondary research (05f-codex-independent.md)
- Cross-validated với Ghostty 1.3 release notes, Warp OSS 2026 announcement, Wave docs
