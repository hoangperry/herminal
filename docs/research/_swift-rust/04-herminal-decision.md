# [herminal] recent context, 2026-05-22 4:48am GMT+7

No previous sessions found.

View Observations Live @ http://localhost:37777
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
Ripgrep is not available. Falling back to GrepTool.
MCP issues detected. Run /mcp list for status.
Hook system message: # [herminal] recent context, 2026-05-22 4:48am GMT+7

No previous sessions found.

View Observations Live @ http://localhost:37777
### Decision Analysis: 'herminal' — Swift/Zig vs. Pure Rust

Based on the research documents provided and the current state of the 2026 macOS ecosystem, here is the brutally honest analysis for a 7-month solo-dev project.

---

### 1. Sunk Cost vs. Real Cost: The "3-Month Reset"
The **libghostty + Swift** spike is a "cheat code." You have already solved the three hardest parts of a terminal emulator:
1.  **The PTY/VT Engine:** Handled by `libghostty` (Zig/SIMD), which is faster than almost any Rust engine currently available.
2.  **GPU Rendering:** Handled by a Metal view via a proven C ABI.
3.  **The Vietnamese Moat:** You’ve already wired `NSTextInputClient`. 

**The Pure Rust Cost:** Rewriting in Rust means finding a VT crate (likely `alacritty_terminal` or `wezterm-term`) and then spending **2–3 months** just to get back to where you are today. You would be fighting `winit` and `objc2` to re-implement the windowing and IME logic that you currently get for free in Swift. For a 7-month project, a 3-month detour is **suicidal**.

### 2. What would Rust actually BUY?
*   **Performance?** No. The hot path is already Zig. Rust replacing the "GUI shell" would yield zero throughput improvement.
*   **Safety?** Marginal. Swift is also memory-safe. The only unsafe parts are the FFI boundaries, which you'd still have in Rust if you wanted to talk to macOS APIs.
*   **Cross-platform?** Yes—but your PRD explicitly says **"Native macOS Terminal."** If you aren't shipping on Linux/Windows, Rust's cross-platform portability is a feature you're paying for but never using.

### 3. What would Rust COST?
*   **The Vietnamese User Experience:** This is the project's biggest risk. Vietnamese Telex/VNI IME on macOS is a "black box" protocol. In Swift/AppKit, it is a first-class citizen. In Rust, you will be debugging "ghost characters," "jumping candidate windows," and "broken tone-mark composition" for months. 
*   **Native Fidelity:** You lose native "Liquid Glass" translucency, native tabs, and native accessibility (VoiceOver) without massive boilerplate.
*   **Developer Happiness:** You'll spend your time writing FFI glue code instead of building your **Agent Dashboard** and **Per-tab Notes**.

### 4. The Honest Framing: Emotional vs. Strategic
*   **The "Make it in Rust" drive** is usually emotional or resume-driven. It feels like "the right way" because Rust is the darling of systems programming.
*   **The "Swift Shell" strategy** is the professional way. It follows the **Mitchell Hashimoto (Ghostty) Rule**: "Use the best tool for the engine (Zig/Rust), and the best tool for the platform (Swift/AppKit)."

---

### 5. Verdict & Recommendation

**Verdict: KEEP the libghostty + Swift stack. Do NOT rewrite in Rust.**

#### Ranking of Options:
1.  **🥇 libghostty (Zig Core) + Swift/AppKit (Current):** The "Gold Standard" for a high-fidelity macOS terminal. Best performance, best IME, fastest velocity.
2.  **🥈 libghostty + Rust GUI:** A "complexity trap." You keep the engine speed but inherit all the FFI pain of Rust-to-AppKit without any of the native benefits of Swift.
3.  **🥉 Pure Rust (alacritty_terminal + custom GUI):** The "Hard Mode." You'll end up with a terminal that feels like a ported Linux app, with buggy Vietnamese input and a 12-month delivery window.

#### Reasoning for the 7-Month Timeline:
You have **4 months** of "feature time" left after accounting for stabilization. 
*   **In Swift:** You can build a world-class **Agent Dashboard** and **Markdown Notes** sidebar using SwiftUI in 4–6 weeks. 
*   **In Rust:** You will spend those same 4–6 weeks just getting a window to resize without flickering or losing IME focus.

**Final Advice:** Focus your "system programming" energy on extending the **Agent-aware OSC sequences** in the Zig core, and use Swift to build the best UI Vietnamese developers have ever seen. **Don't let "Rust Envy" kill your momentum.**
