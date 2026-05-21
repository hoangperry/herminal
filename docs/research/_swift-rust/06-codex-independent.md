# Swift, Rust, and the Right Architecture for Herminal

Generated: 2026-05-22  
Decision: high-performance macOS terminal for Vietnamese developers  
Current baseline: working Swift + AppKit spike embedding `libghostty` as a C ABI xcframework, Metal rendering, zsh PTY, keyboard input, and Vietnamese IME through `NSTextInputClient`.

## Executive Summary

Do not rewrite Herminal as a pure Rust macOS app.

Rust is an excellent language for terminal cores. It is not automatically a faster product architecture once the VT engine, font handling, and renderer already live in a native component such as `libghostty`. In this project, Swift is not the hot path. Swift is the macOS integration layer: `NSView`, `NSTextInputClient`, window lifecycle, menus, focus, accessibility, and future SwiftUI side panels. Replacing that layer with Rust would mostly replace first-party Apple APIs with Rust-to-Objective-C glue.

The winning architecture for Herminal is the architecture the spike already proves: high-performance terminal engine plus native macOS shell. Keep `libghostty` + Swift/AppKit. Use Rust only if a clearly bounded non-UI subsystem needs it later, such as a background indexer, agent parser, sync daemon, or portable library. Do not make Rust own the AppKit surface unless the product goal changes from "best macOS terminal for Vietnamese developers" to "cross-platform terminal engine and UI."

## 1. Is Rust Measurably Faster Than Swift Here?

Not in the way that matters for this project.

A terminal emulator pipeline is roughly:

1. PTY read/write.
2. VT escape parsing.
3. Grid and scrollback mutation.
4. Unicode width, grapheme, font fallback, ligatures, glyph shaping.
5. Glyph atlas updates.
6. GPU command encoding and presentation.
7. App event loop, key input, IME, menus, tabs, panels.

Rust can beat badly written Swift in steps 2 and 3. That is not Herminal's current situation. Herminal is not parsing terminal output in Swift. The project embeds `libghostty`; Ghostty documents `libghostty` as the shared Zig core providing terminal emulation, font handling, and rendering, with the macOS GUI written in Swift/AppKit/SwiftUI and linked to the C API ([Ghostty about](https://ghostty.org/docs/about)). The local spike follows the same shape: [HerminalSurfaceView.swift](../../../Sources/HerminalApp/HerminalSurfaceView.swift) passes an `NSView` pointer into `ghostty_surface_new`, forwards input/preedit, and lets libghostty own the terminal surface and rendering.

So the question is not "is Rust faster than Swift?" The real question is: "Would replacing the Swift AppKit shell with Rust remove a bottleneck that is currently visible in the terminal hot path?" The honest answer is probably no.

Ghostty itself is careful about terminal performance claims: "fast" can mean startup, scrolling, IO throughput, escape-sequence throughput, framerate, and more ([Ghostty about](https://ghostty.org/docs/about)). Alacritty's own README makes the same point: benchmark results do not capture all aspects of latency, framerate, or frame consistency, and the right answer is to test the user's actual workload ([Alacritty README](https://github.com/alacritty/alacritty)).

For Herminal, the real bottlenecks are likely:

- Draw scheduling and wakeup latency. The current spike drives `ghostty_app_tick` with a steady 60 Hz `Timer` because `wakeup_cb` is a no-op ([AppDelegate.swift](../../../Sources/HerminalApp/AppDelegate.swift)). That can add up to one frame of avoidable latency before Rust vs Swift enters the discussion.
- PTY throughput and backpressure under huge output, such as `cat` on large logs, build output, and noisy agent streams.
- Font shaping, glyph fallback, glyph atlas churn, emoji, ligatures, and Vietnamese text composition. Apple's Core Text exists precisely for low-level layout, font handling, glyph conversion, ligatures, kerning, fallback, metrics, and glyph data ([Apple Core Text](https://developer.apple.com/documentation/CoreText)).
- Main-thread stalls caused by UI panels, resizing, SwiftUI sidebar/dashboard work, or over-eager string/attributed-string bridging.
- IME composition correctness and candidate-window positioning, which are user-visible quality bottlenecks even when raw rendering is fast.

The local performance target should be measured as p95/p99 behavior, not language ideology:

- Time from PTY bytes available to surface invalidation.
- Time from key event to bytes sent to PTY.
- Time from IME preedit update to visible preedit/candidate rect update.
- Frame time during `yes`, large paste, `cat` logs, Neovim redraw, tmux pane split, and Vietnamese Telex/VNI typing.
- Main-thread blocking time while the agent dashboard and notes UI are open.

If those profiles show Swift consuming meaningful time in terminal parsing, grid mutation, or glyph rendering, the architecture is wrong. But the current architecture intentionally avoids that.

## 2. The Cost of Pure Rust on macOS

Pure Rust on macOS is not impossible. It is just expensive in exactly the areas Herminal cannot afford to degrade.

### CoreText: You Do Not Really Escape Apple APIs

"Pure Rust" usually means one of two things:

1. Use a cross-platform Rust text stack: HarfBuzz, Swash, Cosmic Text, Fontdue, WGPU, etc.
2. Keep calling Apple APIs such as Core Text, Core Graphics, Metal, AppKit, and Objective-C runtime APIs through Rust bindings.

Option 1 buys portability but gives up some platform-native behavior and pushes you into owning more font discovery, fallback, shaping, atlas, and rendering edge cases. Option 2 keeps native behavior but stops being meaningfully "pure" at the product boundary. You are now writing AppKit/CoreText code through bindings.

The `objc2` ecosystem is real and useful. Its docs explicitly say Rust can interoperate with Objective-C frameworks such as CoreFoundation, Foundation, AppKit, Metal, UIKit, and WebKit ([objc2 docs](https://docs.rs/objc2/latest/objc2/)). But the examples also show the price: unsafe protocol/class declarations, `Retained<T>`, main-thread markers, selector methods, message sending, and Objective-C lifetime rules. That is a valid systems project. It is not a shortcut for a solo developer trying to ship a polished terminal.

### NSTextInputClient: This Is the Product Risk

Vietnamese input is not a side feature for Herminal. It is one of the product's core reasons to exist. Apple defines `NSTextInputClient` as the set of methods custom text views implement to work with the text input management system, including marked text, selected range, attributed substrings, insertion, and character-coordinate lookup ([Apple NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient)).

Herminal already implements that protocol in Swift in [HerminalSurfaceView.swift](../../../Sources/HerminalApp/HerminalSurfaceView.swift). That means Telex/VNI composition, preedit text, committed text, and candidate-window rectangle mapping are wired directly into AppKit's expected model.

Rust windowing stacks have improved, but they abstract away the exact protocol Herminal cares about. Winit exposes generic IME events and requires the window to explicitly allow IME; its own docs note IME is not allowed by default and that macOS needs IME enabled to receive combined dead-key text input ([winit Window docs](https://docs.rs/winit/latest/winit/window/struct.Window.html), [winit event docs](https://docs.rs/crate/winit/latest/source/src/event.rs)). That is useful. It is not the same as owning a correct `NSTextInputClient` implementation for a terminal grid with precise candidate-window geometry.

WezTerm is a good reality check. It is a mature Rust terminal, but its IME docs still describe IME as platform-dependent and call out history such as earlier macOS key-repeat problems when enabled ([WezTerm use_ime](https://wezterm.org/config/lua/config/use_ime.html)). That is not a knock on WezTerm; it is evidence that IME is not "solved by Rust." It is a platform integration problem.

### AppKit Integration: You Will Rebuild the Native Shell the Hard Way

The cost is not just text input.

A credible macOS terminal has to deal with:

- `NSWindow` lifecycle, focus, restoration, titlebar behavior, fullscreen, tabbing, and Spaces.
- Menu bar commands and standard shortcuts.
- Secure keyboard entry.
- Clipboard, paste confirmation, drag/drop, Quick Look, Services, file proxy icons, and accessibility.
- Retina scale changes, multi-monitor movement, occlusion, resize coalescing, and display refresh behavior.
- Future SwiftUI panels for notes, agent dashboard, settings, SSH manager, and onboarding.

Ghostty's macOS app uses Swift/AppKit/SwiftUI exactly because those features are native platform work. Ghostty's docs emphasize native UI components, platform conventions, Quick Look, force touch, secure input, and window restoration as part of the app value ([Ghostty about](https://ghostty.org/docs/about), [Ghostty features](https://ghostty.org/docs/features)).

If Herminal goes pure Rust, it either:

- Accepts a less native, more custom-drawn macOS feel, or
- Rebuilds the native integration through `objc2`/raw AppKit bindings.

Both are worse than the current position for a macOS-only product.

## 3. What Pure Rust Would Buy Versus Cost

### What Rust Would Buy

Rust would buy real value if Herminal were starting from zero or changing scope:

- A single language for parser, PTY, renderer, config, mux, and UI.
- Strong compile-time ownership for terminal core data structures.
- Easy reuse of Rust terminal ecosystem pieces, such as Alacritty-style terminal crates or WGPU renderer infrastructure.
- Cross-platform ambition: Linux, Windows, maybe web.
- Headless terminal/mux/server components that do not need AppKit.
- A contributor pool that prefers Cargo, crates, fuzzing, and Rust's type system.

The market proves Rust can work. Alacritty is a fast cross-platform OpenGL terminal written overwhelmingly in Rust, though it intentionally leaves features such as tabs and splits to window managers or multiplexers ([Alacritty README](https://github.com/alacritty/alacritty)). WezTerm is implemented in Rust and has a broad feature set including multiplexing ([WezTerm home](https://wezterm.org/index.html), [WezTerm multiplexing](https://wezterm.org/multiplexing.html)). Rio is a Rust, hardware-accelerated terminal explicitly aimed at running across desktops and browsers ([Rio README](https://github.com/raphamorim/rio)). Warp says its modern terminal UX is built with Rust for high performance ([Warp docs](https://docs.warp.dev/)).

Rust is not the problem.

### What Rust Would Cost This Project

For Herminal, pure Rust costs more than it buys:

- You would throw away a working spike that already embeds a high-performance terminal surface, renders through Metal, spawns zsh, and handles Vietnamese IME.
- You would replace a proven libghostty path with either another terminal engine or a Rust wrapper around the same C ABI. Wrapping the same C ABI from Rust does not make it faster.
- You would move macOS-native input and UI work from Swift/AppKit into Rust FFI code. That is not product progress.
- You would risk the project's differentiator: Vietnamese input quality.
- You would spend solo-dev months catching up to the current spike instead of building tabs, splits, agent dashboard, notes, SSH manager, polish, packaging, and daily-driver stability.

There is one real caveat on the current stack: Ghostty states `libghostty` is not yet a standalone stable API, even though it is already used by Ghostty's macOS and Linux GUI applications ([Ghostty about](https://ghostty.org/docs/about)). That is a real dependency risk. But rewriting the macOS shell in Rust does not remove that risk if you still use libghostty. The mitigation is version pinning, build reproducibility, thin wrapper boundaries, and an update budget - not a full rewrite.

## 4. When Rust Is the Right Choice for a Terminal

Rust is the right choice when the terminal's hardest problem is the terminal engine or portability.

Use Rust when:

- You are building the VT parser, grid, scrollback, PTY abstraction, mux, renderer, or protocol layer from scratch.
- Cross-platform support is a primary requirement, not a someday maybe.
- You want one renderer path across macOS/Linux/Windows using WGPU/OpenGL/Vulkan abstractions.
- You are willing to own custom windowing/input behavior and accept native-platform gaps.
- You need long-running daemon, mux, SSH, or agent processes where memory safety and concurrency matter more than AppKit fidelity.
- The team already has deep Rust + macOS FFI experience.

Rust is not the right choice when:

- The project is macOS-only.
- The highest-risk user promise is native Vietnamese IME correctness.
- The terminal hot path is already in a fast native engine.
- The UI roadmap includes native tabs, panels, accessibility, settings, notes, agent dashboards, and polished macOS behavior.
- The developer is solo and has a 7-month MVP clock.

In that case, pure Rust becomes an identity choice, not a product choice.

## 5. Project Comparisons

| Project | Architecture Lesson | Relevance to Herminal |
|---|---|---|
| Ghostty | Zig core, `libghostty`, Swift/AppKit/SwiftUI on macOS, Metal on macOS, native UI as a product goal. | The closest match. Herminal is already following this path. |
| Alacritty | Rust/OpenGL, excellent performance focus, intentionally avoids many app-level features such as built-in tabs/splits. | Good proof that Rust terminals can be fast. Weak proof for a polished macOS-native app with Vietnamese IME and side panels. |
| WezTerm | Rust terminal + multiplexer, broad features, GPU backends including OpenGL/WebGPU and Metal through WebGPU. | Good proof that Rust can power a sophisticated terminal. Also proof that IME and cross-platform behavior remain platform-specific maintenance. |
| Warp | Rust-backed modern terminal/product UX. | Proof that Rust can ship commercially, not proof that a solo macOS-native terminal should replace AppKit with Rust FFI. |
| Rio | Rust/WGPU terminal aimed at desktop and browser reach. | Good if Herminal's mission becomes "run everywhere." Not aligned with the current macOS-only, native-IME mission. |

## Final Recommendation

Keep `libghostty` + Swift/AppKit. Do not go pure Rust.

The current stack is already the right hybrid:

- `libghostty` owns terminal emulation, font/rendering work, and Metal surface behavior.
- Swift/AppKit owns the macOS-native shell, first-responder chain, `NSTextInputClient`, IME candidate geometry, window lifecycle, and future SwiftUI panels.

The brutally honest version: rewriting the working Swift/AppKit shell in Rust would be a detour with no clear measurable performance upside and a large, concrete risk to the one feature Herminal must get right for Vietnamese developers.

The better engineering plan is:

1. Keep Swift out of terminal hot loops.
2. Replace the 60 Hz tick timer with a wakeup-driven or display-linked integration if profiling shows latency.
3. Add instrumentation around PTY read, `ghostty_app_tick`, draw scheduling, `keyDown`, preedit sync, and candidate rectangle lookup.
4. Stress-test Telex/VNI, dead keys, Neovim, tmux, huge output, large paste, and agent-stream workloads before debating language changes.
5. Pin the libghostty build and keep Herminal's wrapper thin enough that a future engine swap remains possible.
6. Consider Rust only for bounded non-UI subsystems where AppKit is irrelevant.

If the product later becomes cross-platform, revisit Rust. For the current product, Rust is not the bottleneck. Native macOS integration is the bottleneck, and Swift/AppKit is the shortest path through it.

## Sources

- [Ghostty docs: About](https://ghostty.org/docs/about) - Native macOS GUI in Swift/AppKit/SwiftUI, shared Zig `libghostty`, C API architecture, performance framing, and API stability note.
- [Ghostty docs: Features](https://ghostty.org/docs/features) - Metal rendering on macOS and platform-native macOS features.
- [Alacritty README](https://github.com/alacritty/alacritty) - Rust/OpenGL terminal, performance caveats, and scope tradeoffs such as no built-in tabs/splits.
- [Alacritty vtebench](https://github.com/alacritty/vtebench) - Benchmark scope caveat: PTY read throughput only, not general terminal performance.
- [WezTerm home](https://wezterm.org/index.html) - Rust terminal emulator and multiplexer.
- [WezTerm front_end docs](https://wezterm.org/config/lua/config/front_end.html) - OpenGL, software, and WebGPU render frontends, including platform GPU backends.
- [WezTerm use_ime docs](https://wezterm.org/config/lua/config/use_ime.html) - IME support as platform-dependent behavior.
- [WezTerm: What is a terminal?](https://wezterm.org/what-is-a-terminal.html) - PTY, shell, terminal emulator, escape parsing, and input encoding model.
- [Rio README](https://github.com/raphamorim/rio) - Rust hardware-accelerated terminal focused on desktop and browser reach.
- [Warp docs](https://docs.warp.dev/) - Rust-backed modern terminal UX and open-source client positioning.
- [Apple Core Text](https://developer.apple.com/documentation/CoreText) - Low-level text layout, font handling, glyph conversion, ligatures, kerning, fallback, metrics, and glyph data.
- [Apple NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient) - Required AppKit protocol surface for custom text input and marked text.
- [Apple Metal view drawing](https://developer.apple.com/documentation/metal/using-metal-to-draw-a-view%27s-contents) - MetalKit view integration with AppKit/UIKit view surfaces.
- [winit Window docs](https://docs.rs/winit/latest/winit/window/struct.Window.html) - IME enablement and macOS text-input notes.
- [winit event docs](https://docs.rs/crate/winit/latest/source/src/event.rs) - Generic IME event model and platform support notes.
- [objc2 docs](https://docs.rs/objc2/latest/objc2/) - Rust Objective-C/AppKit/Metal interop model and safety/verbosity implications.
- [objc2 NSTextInputClient trait](https://docs.rs/objc2-app-kit/latest/objc2_app_kit/trait.NSTextInputClient.html) - Rust binding surface for the AppKit text-input protocol.
- [Herminal README](../../../README.md) - Current product scope: macOS-only, Vietnamese IME, libghostty, Swift/AppKit/Metal.
- [Herminal Surface View](../../../Sources/HerminalApp/HerminalSurfaceView.swift) - Current AppKit, Metal-surface, keyboard, and `NSTextInputClient` spike.
- [Herminal AppDelegate](../../../Sources/HerminalApp/AppDelegate.swift) - Current 60 Hz tick integration.
- [Herminal Package.swift](../../../Package.swift) - Current Swift package, `GhosttyKit.xcframework`, and linked Apple frameworks.
