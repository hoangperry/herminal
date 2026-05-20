# Architectural Deep-Dive: Native macOS Terminal Emulator (2025-2026)

Building a high-performance, native macOS terminal emulator requires balancing low-level Unix system primitives with modern Apple-specific graphics and text frameworks.

---

### 1. Open-Source Baselines & Technical Stack
The "Great Terminal Race" of 2024-2026 has shifted from CPU-bound legacy apps to GPU-accelerated, multi-threaded engines.

| Terminal | Language/Stack | LOC (Approx) | Rendering Backend | Key Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| **Ghostty** | Zig + Swift | 60k | Metal | `libev`, CoreText, SIMD-optimized parser. |
| **Alacritty** | Rust | 30k | OpenGL | `winit`, `alacritty_terminal` crate. |
| **WezTerm** | Rust | 180k | WebGPU (wgpu) | Lua (scripting), HarfBuzz, SSH/TLS domains. |
| **Kitty** | C + Python | 110k | OpenGL | HarfBuzz, custom graphics protocol. |
| **iTerm2** | Objective-C | 300k | Metal | AppKit, Python API, `tmux -CC`. |
| **Warp** | Rust + React | 200k+ | Metal / WGPU | Custom Rust UI framework, Cloud/AI engine. |
| **Hyper** | Electron | 20k | WebGL (xterm.js) | Chromium, Node.js, React. |

---

### 2. Core Subsystems & macOS Plumbing
The PTY (Pseudo-Terminal) is the interface between the GUI process and the shell.

*   **PTY Master/Slave:** The emulator owns the **Master FD** (reads shell output, writes keystrokes). The shell (Slave) sees a standard character device (e.g., `/dev/ttys001`).
*   **APIs:**
    *   **`forkpty` (BSD):** One-call solution that forks, creates a PTY, and attaches the slave to `stdin/out/err`. Simple but can be unstable with certain Cocoa frameworks.
    *   **`posix_openpt` + `posix_spawn`:** The modern macOS standard. Manually open master, grant/unlock slave, and use `posix_spawn` to execute the shell. Safer for multi-threaded GUI apps.
*   **Shell Spawning:** Always spawn as a **login shell** (e.g., `zsh -l`) to ensure `.zprofile` / `.zshrc` are sourced, matching macOS desktop behavior.
*   **Signal Handling:**
    *   **`SIGWINCH`:** Mandatory signal sent to the child process via `ioctl(master_fd, TIOCSWINSZ, ...)` whenever the window resizes.
    *   **`SIGHUP`:** Sent to the shell when the terminal window closes.

---

### 3. VT/ANSI Escape Sequence Parsing
Parsers convert the stream of bytes from the PTY into state changes (colors, cursor moves, buffer updates).

*   **`alacritty_terminal` (Rust):** High-throughput, SIMD-optimized. The gold standard for raw speed (e.g., `cat`ing 1GB logs).
*   **`libvterm` (C):** Abstract state machine used by Neovim. Correct, predictable, and `malloc`-free during runtime.
*   **`vte` (C++):** Engine for GNOME Terminal. Uses "frame skipping" to prioritize UI responsiveness over raw throughput.
*   **`vtparse` (C):** Low-level DEC-compatible state machine implementation. Minimal and fast, but handles zero terminal state (no buffers).

---

### 4. Text Rendering Pipeline: The macOS "Gold Standard"
Modern terminals separate **Shaping** from **Drawing**.

*   **The Producer: CoreText.** Use Apple's native engine for font discovery and shaping. It handles ligatures (`==>`), emojis, and complex scripts (Arabic/Indic) that raw character-cell parsers miss.
*   **The Consumer: Metal.** OpenGL is deprecated on macOS and runs via translation. Native Metal provides direct access to Apple Silicon’s Unified Memory, reducing draw-call latency.
*   **The Bridge: Glyph Cache (Texture Atlas).**
    *   CPU (CoreText) rasterizes a character/run into a bitmap once.
    *   Bitmap is uploaded to a GPU texture.
    *   GPU (Metal) "blits" rectangles from that texture to the screen.
*   **Run vs. Character Caching:**
    *   **Character Caching:** Fast, but breaks ligatures.
    *   **Run Caching (Ghostty/Kitty/WezTerm):** Shapes full sequences. Essential for modern dev fonts (Fira Code, JetBrains Mono).

---

### 5. Input Handling & IME
Handling keyboard input on macOS is non-trivial due to the Input Method Editor (IME).

*   **`NSTextInputClient` Protocol:** Your view must implement this to support Japanese/Chinese/Korean input.
    *   **Marked Text:** Temporary composition state (underlined text in the terminal) that is **not** sent to the PTY yet.
    *   **Inserted Text:** The final committed string sent to the PTY.
*   **Kitty Keyboard Protocol:** A modern standard (`CSI u`) that disambiguates legacy keys (e.g., distinguishing `Tab` from `Ctrl+I`) and reports key-up events.
*   **Modifier Management:**
    *   **Option key:** Can be used as `Meta` (Alt) or for special character input (e.g., `Option+e` → `´`). Terminals must provide a toggle.
    *   **Command key:** Native macOS shortcuts (Cmd+C/V) must be intercepted before being sent to the PTY.

### Reference Links
*   [Ghostty Architecture](https://ghostty.org/)
*   [Alacritty Terminal Engine](https://github.com/alacritty/alacritty)
*   [Kitty Keyboard Protocol Spec](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
*   [Apple CoreText Documentation](https://developer.apple.com/documentation/coretext)
*   [Metal Programming Guide](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/)
