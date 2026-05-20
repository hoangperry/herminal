# [herminal] Difficulty Assessment: Building a Production-Grade macOS Terminal

Building a terminal emulator is deceptively simple to start (a PTY and a text view) but exponentially difficult to finish. This document outlines the realistic effort, technical hurdles, and platform-specific landmines involved in building "herminal."

## 1. Realistic Effort Breakdown

### Solo Developer Timeline
*   **MVP (1-3 Months):** Can boot a shell (`zsh`/`bash`), handle basic ANSI colors (16 colors), implement a simple fixed-size scrollback, and basic input.
*   **"Usable" Beta (6-12 Months):** Support for 256/truecolor, basic font configuration, mouse support, `SIGWINCH` handling (resizing), and basic optimization to avoid UI lag during high-throughput (e.g., `cat`ing a large file).
*   **"Pro" Grade (2-4 Years):** This is where Ghostty, Alacritty, and Kitty live. Requires custom GPU rendering, advanced text shaping (ligatures/emojis), full Unicode compliance, performance parity with the fastest engines, and complex protocol support (Sixel, Kitty Graphics).

### The "Mitchell Hashimoto" Metric
Mitchell Hashimoto (creator of Ghostty) spent nearly **3 years** building the engine before public release, with a heavy focus on font rendering and text shaping. It is often estimated that **70% of terminal development** is handling edge cases in font rendering and text shaping.

---

## 2. Technical "Hard Problems"

### Unicode & Width Agreement
*   **Grapheme Clusters:** Terminal cells are typically 1x1, but Unicode characters can be multiple code points (e.g., emojis with skin tone modifiers).
*   **Width Agreement:** The terminal and the CLI application (e.g., `vim`, `fzf`) MUST agree on how wide a character is. If they disagree (Unicode 11 vs 15), the UI breaks (ghost characters, broken borders).
*   **UAX #29:** Implementing the Unicode Text Segmentation algorithm correctly is mandatory for modern text handling.

### Protocol Sprawl
*   **Sixel / Kitty Graphics:** Users expect images in the terminal.
*   **Osc 133 (Semantic Prompts):** Allowing the terminal to understand where a prompt starts and ends (via OSC 133) for features like "jump to previous command" or "copy output of last command."
*   **Reflow on Resize:** Re-wrapping text lines correctly when the window width changes is notoriously bug-prone and requires a sophisticated memory model for the scrollback.

---

## 3. macOS-Specific Landmines

### Sandboxing & Permissions
*   **Sandbox Inheritance:** If `herminal` is sandboxed (App Store requirement), child processes (shells) inherit the sandbox. This prevents the shell from accessing the user's files, compilers, or network tools.
*   **Full Disk Access:** Most developers distribute outside the App Store (DMG/Homebrew) to avoid these restrictions and request "Full Disk Access" instead.
*   **Login vs. Interactive Shells:** Handling the nuances of `PATH` and environment variables between login shells (`zsh -l`) and non-login interactive shells.

### Rendering with Metal
*   **Metal vs. CoreText:** You cannot render fonts directly with Metal. You must pre-render glyphs into a **Texture Atlas** (using CoreText/HarfBuzz) and then draw quads on the GPU.
*   **MoltenVK/Metal Headaches:** If using cross-platform libraries like Vulkan, the translation layer to Metal (MoltenVK) can introduce performance overhead or unexpected bugs on different macOS versions.
*   **Synchronization:** Ensuring the PTY buffer thread and the Metal render thread are synchronized to avoid "tearing" or "flickering."
*   **Retina/HiDPI:** Handling the different pixel densities and ensuring subpixel antialiasing looks sharp on modern Mac displays.

---

## 4. Performance Bottlenecks

### Throughput & Latency
*   **Throughput Target:** Casey Muratori's **Refterm** demonstrated that 1.3 GB/s (over 1 billion chars/sec) is possible on a single thread. Most terminals struggle at a fraction of this.
*   **Input Latency:** The "feel" of a terminal depends on sub-millisecond input latency. This requires a highly optimized event loop (e.g., `kqueue` on macOS) and avoiding unnecessary allocations in the hot path.

### The Scrollback Memory Model
*   **Circular Buffers:** Using a circular buffer with **virtual memory mapping** (mapping the same physical block multiple times) can eliminate wrap-around checks in the inner loop.
*   **Backpressure:** If the shell outputs data faster than the renderer can process it, the terminal must handle backpressure to avoid memory exhaustion without freezing the UI.

### Rendering Efficiency
*   **60/120fps Rendering:** At 120Hz (ProMotion), the renderer has ~8ms to process all incoming PTY data and draw the entire grid.
*   **Tile-Based Rendering:** Treating the screen as a grid of tiles and only updating changed tiles to save GPU power and battery life.
