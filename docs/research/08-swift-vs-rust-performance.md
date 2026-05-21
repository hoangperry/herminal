# Research: Swift vs Rust cho Terminal Performance Cao — herminal

**Project:** herminal
**Date:** 2026-05-22
**Conducted by:** Yuuhou Meow (phù phù醬)
**Câu hỏi:** "Làm terminal performance cao — SwiftUI native vs Rust, cái nào tốt hơn?"

---

## 1. Executive Summary

**Rust KHÔNG làm terminal nhanh hơn Swift trên macOS — vì hiệu năng nằm ở ENGINE, không ở GUI language.** herminal đã embed `libghostty` (engine Zig, SIMD-optimized, nhanh nhất 2026) — engine này xử lý toàn bộ hot path (VT parser, grid, render). Swift hay Rust ở lớp GUI **không chạm hot path**, nên không ảnh hưởng throughput/latency.

**Khuyến nghị dứt khoát: GIỮ `libghostty` (Zig) + Swift/AppKit. KHÔNG viết lại Rust.** Viết lại Rust = mất 2-3 tháng quay về điểm xuất phát, mất CoreText + NSTextInputClient native (IME tiếng Việt), đổi lại 0% hiệu năng. Với MVP 7 tháng, đây là "tự sát".

5/5 nguồn research độc lập đồng thuận tuyệt đối điểm này.

---

## 2. Key Themes

### Theme 1 — Hiệu năng terminal nằm ở Engine, không phải GUI language

Phân rã một terminal: PTY I/O → VT/ANSI parser → grid/scrollback → text shaping → GPU render → GUI event loop. Hot path thực sự là **parser + text-shaping cache**. GPU render (blit glyph atlas) là "trivial" với mọi ngôn ngữ hiện đại. GUI event loop (xử lý ~100 keystroke/giây) là "ergonomics only — negligible". `[Source: research/_swift-rust/03-engine-vs-gui.md]`

→ Vì herminal embed `libghostty` (engine Zig, exposed qua C ABI), Swift code **không bao giờ chạm hot path** — nó chỉ sở hữu `NSView` (Metal) và nhận tín hiệu draw. Chọn Swift hay Rust cho GUI là **quyết định ergonomics, KHÔNG phải performance**. `[Source: 03-engine-vs-gui.md]`

### Theme 2 — Trên macOS-only, Rust KHÔNG nhanh hơn Swift đo được

Benchmark 2026 (M4/M5 Apple Silicon):

| Metric | Ghostty (Zig+Metal) | Alacritty (Rust+OpenGL) | Warp (Rust+wgpu) | iTerm2 (ObjC+Metal) |
|--------|--------|--------|--------|--------|
| Throughput cat 1GB | **~5.1s** | ~6.2s | ~8.4s | ~22.1s |
| Input latency avg | ~13.0ms | **~4.2ms** | ~14.5ms | ~30.0ms |
| Frame time 120Hz | **<1.0ms** | ~1.5ms | ~2.1ms | ~4.5ms |
| Memory idle | ~85MB | **~22MB** | ~180MB | ~290MB |

`[Source: 01-perf-benchmark.md — Gemini, benchmark numbers cần xác minh thêm]`

Quan sát quan trọng:
- **Ghostty (Zig engine) thắng throughput** — nhanh hơn cả Alacritty và Warp (cả hai Rust thuần). Engine nhanh > ngôn ngữ GUI. `[Source: 01]`
- **Swift 6.2** với `Span<T>` + `~Copyable` đạt **95%+ throughput của Rust** trong hot loop — gap ngôn ngữ giờ "thuần học thuật (<5%)". `[Source: 01]`
- **wgpu (Rust) có "abstraction tax"** — translate WGSL→Metal runtime + validation layer → +3-5% CPU overhead. Metal trực tiếp (Swift) gần như zero overhead, dùng được Tile Shaders Apple Silicon. `[Source: 01]`
- **CoreText (Swift, native) FREE + nhanh hơn ~15%** HarfBuzz/swash trên macOS nhờ OS-level glyph cache pre-warmed. `[Source: 01]`

→ Alacritty latency thấp (4.2ms) KHÔNG do Rust — do nó tự vẽ UI, bỏ qua AppKit. Ghostty 13ms latency là do **chọn native AppKit** (tabs, panes). Đây là trade-off UI native, không phải trade-off ngôn ngữ. `[Inference từ 01]`

### Theme 3 — macOS native integration: Rust là "thuế cao", Swift là "trợ cấp"

**IME / NSTextInputClient** — điểm sống còn của herminal (Vietnamese Telex/VNI):
- Swift/AppKit: `NSTextInputClient` là first-class. OS tự lo candidate window, preedit underline, backspace logic cho dấu thanh. `[Source: 02-native-integration.md]`
- Rust (winit): IME là "afterthought" — generic events `Ime::Preedit`/`Ime::Commit`. Terminal là grid-based, bridge `firstRectForCharacterRange:` qua FFI → "jumping IME window", "ghost characters", "dấu thanh không hiện cho tới khi gõ xong từ". Nhiều Rust terminal 2026 vẫn lỗi IME tiếng Việt/CJK. `[Source: 02]`

**Native features khác:** native tabs (`NSWindow` free), accessibility/VoiceOver, Secure Keyboard Entry (password), Liquid Glass translucency macOS 17. Rust phải FFI thủ công — `objc2`/`cidre`: "5 dòng Swift = 50 dòng Rust", wrap `Retained<T>`, `MainThreadOnly` markers. `[Source: 02]`

→ Đây là lý do Mitchell Hashimoto chọn **Swift shell** cho Ghostty dù core là Zig: để IME tiếng Việt được xử lý bởi CHÍNH code mà Notes.app/Safari dùng. `[Source: 02, 03]`

### Theme 4 — herminal: sunk cost thấp, cost-to-rewrite cực cao

herminal **đã có spike chạy được** — libghostty + Swift + Metal render + zsh + NSTextInputClient. Đã giải quyết 3 phần khó nhất của terminal. `[Source: 04-herminal-decision.md]`

Viết lại pure Rust nghĩa là:
- Tìm/dùng VT crate (`alacritty_terminal` / `wezterm-term`) — nhưng các crate này CHẬM HƠN libghostty `[Source: 04]`
- Re-implement GPU render (wgpu — có abstraction tax)
- Re-implement macOS IME từ Rust (khó nhất — "debug ghost characters hàng tháng")
- **2-3 tháng chỉ để quay về điểm hiện tại** → với 7-month MVP là "suicidal" `[Source: 04]`

Rust thay được vai trò nào? Chỉ "GUI shell" — mà GUI shell KHÔNG phải bottleneck. Upside hiệu năng = 0. `[Inference từ 03, 04]`

### Theme 5 — Solo dev 7 tháng: Swift thắng productivity tuyệt đối

- **Learning curve:** Rust = ~40% thời gian fight borrow checker / lifetimes / async-sync bridging. Swift align với platform, fight ít hơn. `[Source: 05-solo-dev.md — ước lượng, Opinion]`
- **Tooling:** Xcode Instruments (Time Profiler, Metal Debugger), codesign/notarize tích hợp. Rust: bundle/codesign thủ công. `[Source: 05]`
- **Hiring VN:** Pool iOS/macOS Swift dev ở Việt Nam **lớn**; Rust GUI là niche (VN Rust tập trung blockchain/backend). Onboard cộng tác viên Swift nhanh hơn nhiều. `[Source: 05]`
- **Iteration:** Xcode Previews iterate UI trong giây; Rust GUI compile chậm. `[Source: 05]`

---

## 3. Key Takeaways

1. **GIỮ stack hiện tại: `libghostty` (Zig) + Swift/AppKit.** Đây là kiến trúc tối ưu 2026 — engine nhanh nhất + UX native. Không đổi.

2. **"Làm bằng Rust" cho herminal là quyết định cảm xúc, không phải kỹ thuật.** Hot path đã là Zig. Rust chỉ thay GUI shell — 0% lợi hiệu năng, mất IME native, mất 2-3 tháng. Nguồn 04 gọi thẳng đây là "Rust Envy".

3. **Performance cao của herminal ĐÃ được đảm bảo bởi libghostty** — Zig, SIMD, throughput nhanh hơn Alacritty/Warp (cả hai Rust thuần). Không cần Rust để "nhanh hơn".

4. **Nếu lo latency:** 13ms của Ghostty đến từ AppKit UI layer, không phải Swift. Tối ưu latency = giảm UI-thread jitter (CVDisplayLink, tránh layout churn), KHÔNG phải đổi ngôn ngữ.

5. **Ranking 3 lựa chọn** `[Source: 04]`:
   - 🥇 **libghostty + Swift/AppKit (hiện tại)** — gold standard macOS terminal
   - 🥈 libghostty + Rust GUI — "complexity trap": giữ engine speed nhưng ăn full FFI pain, mất native benefit
   - 🥉 Pure Rust (alacritty_terminal + custom GUI) — "hard mode", IME tiếng Việt buggy, ~12 tháng

6. **Khi nào Rust LÀ lựa chọn đúng cho terminal?** Khi cần cross-platform (Linux/Windows) và CHƯA có engine. herminal là macOS-only + đã có libghostty → cả 2 điều kiện đều không thỏa. `[Inference]`

7. **Dùng năng lượng "systems programming" đúng chỗ:** mở rộng agent-aware OSC sequences trong Zig core (nếu cần), và dồn Swift vào xây Agent Dashboard + Notes sidebar — đó là differentiator thật của herminal.

---

## 4. Sources & Attribution

| Nguồn | Vai trò | File |
|-------|---------|------|
| Gemini-3-flash #1 | Performance benchmark Swift vs Rust | `_swift-rust/01-perf-benchmark.md` |
| Gemini-3-flash #2 | macOS native integration + IME | `_swift-rust/02-native-integration.md` |
| Gemini-3-flash #3 | Engine vs GUI architecture | `_swift-rust/03-engine-vs-gui.md` |
| Gemini-3-flash #4 | herminal keep-vs-rewrite decision | `_swift-rust/04-herminal-decision.md` |
| Gemini-3-flash #5 | Solo dev ergonomics | `_swift-rust/05-solo-dev.md` |
| Codex GPT-5 | Independent synthesis | `_swift-rust/06-codex-independent.md` — kết luận: "Keep libghostty + Swift/AppKit. Do not go pure Rust." (đồng thuận 6/6) |

**Lưu ý độ tin cậy:**
- Số benchmark cụ thể (5.1s, 13ms, 85MB...) từ Gemini — **cần xác minh** với nguồn gốc (Ghostty benchmark blog, typometer measurements). Coi là chỉ dấu xu hướng, không phải số tuyệt đối.
- Kết luận kiến trúc (engine = performance, GUI = ergonomics) **cross-validated** 5/5 nguồn — độ tin cậy cao.
- Ước lượng "40% thời gian fight Rust", "2-3 tháng rewrite" là **[Opinion/Inference]** — không phải số đo, nhưng nhất quán giữa các nguồn.

---

## 5. Methodology

- **Providers:** 5 Gemini-3-flash queries song song (5 góc nhìn: benchmark, native integration, kiến trúc, quyết định herminal, solo-dev) + 1 Codex GPT-5 (independent synthesis).
- **Intensity:** Deep (6 perspectives).
- **Cross-reference:** **6/6 nguồn độc lập** hội tụ cùng kết luận (giữ libghostty+Swift, không pure Rust) — không có nguồn nào bất đồng. Codex GPT-5 còn chủ động loại bỏ các số benchmark chưa kiểm chứng và kết luận dựa trên "measured bottleneck classes, native input cost, solo-dev delivery risk". Đồng thuận tuyệt đối = độ tin cậy cao cho khuyến nghị.
- **Gaps / cần đào thêm:**
  - Số benchmark cụ thể chưa verify với nguồn gốc primary (Ghostty repo benchmarks, typometer data).
  - Chưa đo TRỰC TIẾP herminal hiện tại — task #12 (latency benchmark) của Month 1 sẽ cho số thật trên máy chủ nhân.
  - Chưa khảo sát sâu trường hợp herminal sau này muốn lên Linux/Windows — nếu đổi ý cross-platform, phân tích này cần làm lại.

---

## Kết luận cho chủ nhân

Câu hỏi "làm bằng Rust có tốt hơn không" — **trả lời: KHÔNG, cho herminal.**

herminal đã đi đúng đường: **libghostty (Zig) lo tốc độ, Swift lo trải nghiệm native**. Đây CHÍNH XÁC là công thức Ghostty — terminal nhanh nhất 2026. Performance cao đã có sẵn nhờ engine Zig; Swift ở lớp GUI không làm chậm gì cả.

Viết lại Rust = vứt spike đang chạy, mất IME tiếng Việt native (USP của herminal), tốn 2-3 tháng, đổi lại 0% hiệu năng. **Đừng làm.**

Việc nên làm tiếp: hoàn thiện #7 (IME), #11, #12 — và đo latency thật (#12) để có số trên máy thật thay vì benchmark internet.
