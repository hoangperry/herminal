# [herminal] Foundations & Shortcuts (2026 Edition)

Building a terminal emulator in 2026 doesn't mean starting from `forkpty`. Modern performance expectations (sub-2ms latency, 120fps rendering) and AI integration require standing on the shoulders of giants.

## 1. Fork-and-Customize: The 80% Skeletons

If you want a working terminal in a weekend, start here.

| Project | Language | Architecture | Best For... |
| :--- | :--- | :--- | :--- |
| **Ghostty** | Zig / Swift | libghostty (C ABI) + Swift GUI | Native macOS feel with absolute maximum performance. |
| **Alacritty** | Rust | `alacritty_terminal` crate | Cross-platform stability and a clean, minimalist Rust foundation. |
| **WezTerm** | Rust | Modular crates (`termwiz`, `wezterm-term`) | Deep customizability and Lua-driven extensibility. |

### Ghostty (The 2026 Alpha)
Ghostty has changed the game by publishing **`libghostty`**. It’s a Zig-based core that handles terminal state, VT parsing, and input processing, exposed via a stable C ABI.
- **I have completed the research on forkable foundations and shortcuts for **herminal**, your macOS terminal emulator project. The findings have been synthesized into a comprehensive guide and a decision framework, now available in your `docs/research/` directory.

### Key Highlights from the Research:

1.  **Top Skeletons (2026):**
    *   **Ghostty:** The clear winner for macOS-native performance. It now exposes `libghostty` (C ABI), allowing you to embed its lightning-fast Zig-based engine into a SwiftUI application.
    *   **Alacritty:** The `alacritty_terminal` Rust crate remains the gold standard for a cross-platform, minimalist, and battle-tested VTE core.
    *   **WezTerm:** Best if you need a modular ecosystem of crates like `portable-pty` (the industry-best PTY manager) and `termwiz`.

2.  **Reusable Libraries by Layer:**
    *   **PTY:** `portable-pty` (Rust) or native `forkpty` wrappers in Swift.
    *   **VT Parsing:** `vte` (Rust/C++) or `libvterm` (C).
    *   **Text Shaping:** `CoreText` is recommended for native macOS feel, though `cosmic-text` (Rust) is a high-performance alternative.
    *   **GPU Rendering:** **Metal** is the mandatory target for 2026. `wgpu` (Rust) is excellent for cross-platform, while `MetalKit` is the fastest path for pure Swift.

3.  **The Swift/SwiftUI Strategy:**
    *   **Viability:** Highly viable for the GUI, but standard text views (`NSTextView`) cannot handle terminal throughput.
    *   **The "Pro Strategy":** Use **SwiftUI** for tabs, windows, and settings, but bridge to a high-performance engine like **libghostty** or **alacritty_terminal** via a custom Metal renderer.

4.  **Decision Framework:**
    *   **Recommendation:** **Embed libghostty + SwiftUI GUI.** This provides the performance of the fastest terminal engine (Zig) with the premium UI/UX of a modern native macOS application.

### Updated Documentation:
*   `docs/research/01-architecture.md`: Refined deep-dive into PTY plumbing and rendering pipelines.
*   `docs/research/02-difficulty.md`: Realistic effort assessment (Solo MVP: 1-3 months; Pro-grade: 2-4 years).
*   `docs/research/03-foundations.md`: The new comprehensive guide to skeletons, libraries, and shortcuts.

You are now equipped with a solid foundation to begin the implementation phase of **herminal**.
026 performance standards.
- **Black Box (macOS/Swift):** A great reference for a clean AppKit/SwiftUI interface.
- **Capsule (Cocoacafe):** Excellent UI/UX patterns for "modern" terminal feel.

### What's Painful in Pure Swift?
- **Performance:** AppKit `NSTextView` or `SwiftUI.Text` cannot handle a high-throughput stream of terminal data. You **must** write a custom renderer using `Metal` or `Layer-backed` views.
- **VT Coverage:** Pure Swift engines often lag behind in supporting complex features like Kitty graphics or Sixel.

**The Pro Strategy:** Use **Swift/SwiftUI** for the UI/Tabs/Configuration and **libghostty** (via C-bridge) or **alacritty_terminal** (via Rust-bridge) for the engine.

---

## 4. Decision Framework: Fork, Embed, or Scratch?

| Strategy | Pros | Cons |
| :--- | :--- | :--- |
| **Fork Ghostty** | 100% features, 100% performance, native Swift GUI already exists. | Harder to differentiate; tied to upstream architectural choices. |
| **Embed libghostty** | Get the best engine, build your own unique UI from scratch. | Requires C/Zig interop; more work than forking. |
| **Embed Alacritty Core** | Strong Rust ecosystem, very stable. | Requires Rust/Swift interop (UniFFI or C-bridge). |
| **Write from Scratch** | Complete control, learn everything. | 6-12 months to reach "production" stability (PTY bugs, unicode edge cases). |

### Recommendation for 'herminal':
**Embed libghostty + SwiftUI GUI.**
This gives you the performance of the fastest terminal engine (Zig) while allowing you to build a premium, AI-first macOS experience using modern Swift tools.
