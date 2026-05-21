# [herminal] recent context, 2026-05-22 4:46am GMT+7

No previous sessions found.

View Observations Live @ http://localhost:37777
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
Ripgrep is not available. Falling back to GrepTool.
MCP issues detected. Run /mcp list for status.
Hook system message: # [herminal] recent context, 2026-05-22 4:46am GMT+7

No previous sessions found.

View Observations Live @ http://localhost:37777
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 0s.. Retrying after 5835ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 0s.. Retrying after 5759ms...
Attempt 1 failed: You have exhausted your capacity on this model. Your quota will reset after 0s.. Retrying after 5419ms...
Attempt 2 failed: You have exhausted your capacity on this model. Your quota will reset after 0s.. Retrying after 10238ms...
Building a terminal for macOS in 2026 presents a deceptive fork in the road. On one side, the allure of a **pure Rust** implementation (Alacritty, WezTerm, Zed) promises memory safety and cross-platform "engine" sharing. On the other, the **Swift/AppKit shell** (Ghostty approach) acknowledges that the macOS UI layer is a proprietary walled garden that punishes anyone trying to "fake it" with FFI.

For a terminal specifically targeting Vietnamese users (Telex/VNI), the analysis is brutally simple: **Rust is a high-maintenance tax, Swift is the native subsidy.**

### 1. The IME Nightmare: `NSTextInputClient` is the Final Boss
Vietnamese Telex/VNI relies on **marked text (composition)**. When a user types `h-o-a-s`, the IME needs to "mark" the text and eventually transform it into `hóa`.

*   **Swift/AppKit:** You implement the `NSTextInputClient` protocol. It’s a first-class citizen. The OS handles the candidate window positioning, the underline of the preedit string, and the complex backspacing logic required for tonal marks. It "just works" because the protocol was designed for the AppKit event loop.
*   **Rust (The Winit Struggle):** Rust GUI stacks (like `winit`) treat IME as an "afterthought extension" to the event loop. While `winit` has improved by 2026, it still abstracts IME into generic events (`Ime::Preedit`, `Ime::Commit`). 
    *   **The Problem:** Terminal emulators aren't text editors; they are grid-based cells. Bridging the OS's coordinate-based `firstRectForCharacterRange:` to a terminal's row/column grid via FFI in Rust is a recipe for "jumping" IME windows.
    *   **Real-world failure:** Even in 2026, many Rust terminals still struggle with "ghost characters" or incorrect cursor positioning during Vietnamese tone-mark composition because the Rust-to-ObjC bridge misses subtle timing nuances in the `NSInputContext` lifecycle.

### 2. The "Mac-Assed" Gap: Beyond the Grid
A terminal is more than a renderer. It’s a macOS citizen.

*   **Native Tabs & Window Management:** In Swift, `NSWindow` tabs are "free." You get the native look, the `Cmd+Shift+[` shortcuts, and the "Liquid Glass" (macOS 17 Tahoe) translucency without writing a single shader. In Rust, you have to manually call `addTabbedWindow:ordered:` via FFI, and if Apple changes the internal implementation of `NSWindowTabGroup`, your Rust bridge breaks while Swift apps just recompile.
*   **Accessibility (VoiceOver):** Terminal accessibility is notoriously hard. Swift gives you `NSAccessibility` protocols that are deeply integrated with the OS. Implementing these in Rust requires a massive amount of boilerplate code in `objc2` just to tell VoiceOver where the cursor is.
*   **The Lifecycle Tax:** macOS apps are not "running binaries"; they are "managed objects." Handling "Secure Keyboard Entry" (essential for passwords in terminals) is a single toggle in AppKit. In Rust, you're fighting the OS to ensure your custom event loop doesn't interfere with the TCC (Transparency, Consent, and Control) subsystem.

### 3. Rust↔AppKit Interop: Maturity vs. Ergonomics
By 2026, crates like **`objc2`** and **`icrate`** have made AppKit interop *safe*, but not *pleasant*.

*   **The Verbosity Tax:** What takes 5 lines of Swift takes 50 lines of Rust. You are constantly wrapping pointers in `Retained<T>`, handling `MainThreadOnly` markers, and manually registering classes with the Objective-C runtime.
*   **The "Cidre" Alternative:** While `cidre` provides zero-cost bindings for Metal rendering, it is even more low-level. If you use it for the UI, you are essentially writing Objective-C in Rust syntax, losing the "ergonomic" benefits of Rust while keeping the "complexity" of the Mac APIs.

### 4. The Ghostty Verdict: Why Mitchell Hashimoto was Right
Ghostty’s choice of a **Zig/Rust Core + Swift Shell** is the only way to win in 2026.

*   **The Logic:** Use Rust/Zig for the "Brain" (VT parser, PTY handling, performance). These are platform-agnostic and benefit from the speed.
*   **The Shell:** Use Swift for the "Face." 
    *   **Reason:** You want the **Vietnamese IME** to be handled by the same code that handles it in Notes.app or Safari. 
    *   **Reason:** You want **iCloud sync** for your config, **Native Context Menus**, and **Services** support without maintaining a 10,000-line FFI bridge.

### Final Verdict: Brutal Honesty
If you build the GUI in **Pure Rust**:
*   You will spend **60% of your time** debugging IME positioning and window-lifecycle edge cases.
*   Your Vietnamese users will complain that the "tone marks don't appear until the word is finished" or the candidate window is in the wrong corner of the screen.

If you build a **Swift Shell + Rust Core**:
*   The OS handles the "hard" Mac integration for you.
*   You can focus 100% of your Rust effort on making the terminal engine fast.

**Recommendation:** For a macOS-native terminal with first-class Vietnamese support, **do not build the UI in Rust.** Use a Swift shell and link your Rust engine as a library (`staticlib` or `cdylib`). It isn't just easier; it's the only way to achieve a "pro" feel in 2026.
