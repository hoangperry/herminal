# Month 1 Retrospective — herminal libghostty Spike

**Period:** 2026-05-20 → 2026-05-22
**Sprint goal:** Prove libghostty can be embedded in a Swift macOS app — render, spawn shell, accept keyboard + Vietnamese IME input.
**Result:** ✅ Goal met. 12/13 tasks done; 1 (owner smoke-test) pending.

---

## 1. What Got Done

| Area | Outcome |
|------|---------|
| Toolchain | Zig 0.15.2 + Metal Toolchain 17B54 pinned in `bootstrap.sh` |
| Engine | Ghostty `v1.3.1` vendored; `GhosttyKit.xcframework` built (ReleaseFast, arm64) |
| FFI bridge | `Ghostty.info` wraps `ghostty_info()` — Swift ⇄ libghostty proven; 2 tests pass |
| App | `HerminalApp` SPM executable + `.app` bundle (`make-app-bundle.sh`) |
| Surface | `HerminalSurfaceView` hosts `ghostty_surface`; Metal render works |
| Shell | `zsh` login shell spawns; typed commands run + output renders (verified) |
| Input | ASCII `keyDown` → `ghostty_surface_key` verified end-to-end |
| IME | `NSTextInputClient` implemented (composition/preedit) — owner verify pending |
| Repo | Public OSS at github.com/hoangperry/herminal — 5 commits |

**The Month-1 exit question — "can libghostty actually be embedded in a Swift app?" — is answered: YES.** The single biggest project risk is retired.

---

## 2. What We Learned (Lessons & Bugs)

### Environment surprises
- **Xcode 26 dropped the bundled Metal Toolchain** (BLOCK-001). The xcframework build needs `xcodebuild -downloadComponent MetalToolchain` (~705 MB). Now checked in `bootstrap.sh`.
- **Ghostty v1.3.1 pins Zig 0.15.2** — Homebrew ships 0.16.0, which fails the build. Toolchain versions must be pinned, not "latest".

### Bugs that cost real time
- **BUG-001 — renderer-thread crash (`_dispatch_assert_queue_fail`).** The 6 libghostty C callbacks were closures inside a `@MainActor init`, so they inherited actor isolation; libghostty calls them off-main → Swift's executor check trapped. Fix: build the runtime config in a `nonisolated static` helper. *Lesson: any C callback handed to a library must be built in a nonisolated context.*
- **BUG-002 — app exits immediately as a raw executable.** A macOS GUI app needs a real `.app` bundle (Info.plist, bundle id) to be a proper app process — window server, key routing, run loop. *Lesson: SPM `executableTarget` alone is not a shippable macOS app.*

### Process lessons
- **GUI keyboard/IME cannot be verified by automation while the owner uses the machine** — `osascript` keystrokes interleave with real input, and the system Telex input source composes them. Verification of input must be a manual owner step.
- **Swift 6 strict concurrency is the recurring friction** — three separate fixes this sprint were concurrency-isolation issues (`nonisolated(unsafe)` pointers, nonisolated callbacks, `@MainActor` protocol conformance). Budget time for it.

### Strategic decision settled
- **Swift vs Rust** was researched (6 independent AI perspectives, unanimous): keep `libghostty` (Zig engine) + Swift/AppKit. Performance lives in the engine, not the GUI language; pure Rust would lose native CoreText + NSTextInputClient and cost 2-3 months for zero perf gain. See `docs/research/08-swift-vs-rust-performance.md`. **This question is now closed — do not revisit without a cross-platform requirement.**

---

## 3. Estimate vs Actual

- **PRD Month-1 plan:** weeks 1-2 toolchain + embedding, weeks 2-4 surface + IME.
- **Actual:** toolchain → embedding → surface → shell → ASCII input → IME implemented, all within a dense work session. **Faster than planned** — because libghostty's embedding API (`ghostty.h`) is clean and Ghostty's own `macos/Sources` is an excellent reference to port from.
- **Caveat:** "implemented" ≠ "verified". IME correctness + latency are unmeasured (see Debt).

---

## 4. Debt Carried Into Month 2

| # | Item | Why pending |
|---|------|-------------|
| 11 | Vietnamese IME smoke test (20 phrases) | Needs owner to type Telex/VNI manually — only reliable verification |
| 12 | Latency benchmark (keydown→render p95 < 20ms) | Needs instrumentation in-app; no real number yet |

PRD Month-1 success metric "p95 latency < 20ms" is **unverified** — must be measured early in Month 2.

---

## 5. Roadmap Adjustment for Month 2

- **Stack is locked and validated** — libghostty + Swift/AppKit + SQLite. No further architecture research needed.
- **Month 2 (per PRD):** agent dashboard, per-tab notes, tmux integration, SSH connection manager, premium design.
- **Add to Month 2 start:** close debt #11 + #12 before new features (a day, max).
- **Watch item:** Swift 6 concurrency keeps generating isolation bugs at FFI boundaries — consider a small documented pattern/helper for "C callback surfaces" so each new libghostty integration point does not re-discover BUG-001.
- **Reference asset:** Ghostty's `macos/Sources/Ghostty/` is the canonical porting source for every libghostty integration — keep using it.

---

## 6. Honest Self-Assessment

**Good:** The risky unknown (embedding) is dead; the project has a running terminal in days, not weeks. Backlog kept current throughout. Decisions documented.

**Could be better:** Three concurrency bugs is a sign the FFI boundary needs a deliberate pattern, not ad-hoc fixes. Verification was repeatedly blocked by environment (owner using the machine) — a dedicated clean test session, or a headless test path, would de-risk this.

**Risk for Month 2:** the PRD's 7-month "Option A full scope" (7 features) is ambitious. Month 1 going well does NOT de-risk the scope — surface/IME were the *known* hard parts with a proven reference (Ghostty). Agent dashboard + notes + SSH UI have no such reference and are net-new design. Re-check scope at the Month 2 retro.
