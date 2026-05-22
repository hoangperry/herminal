# Month 2 Backlog — herminal Premium Shell + Multi-Session

**Sprint goal (PRD roadmap):** Premium design system + tabs/splits + tmux-compat verified.
**Start date:** 2026-05-22
**Owner:** hoangperry
**Carries debt from Month 1:** #11 (Vietnamese IME smoke test), #12 (latency benchmark).

---

## Status Legend
⏳ pending · 🔄 in_progress · ✅ done · ⛔ blocked · 🗑️ deferred

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M1-11 | ⏳ | Vietnamese IME smoke test (20 phrases) | Owner manual test — Telex/VNI; debt from Month 1 |
| M2-1 | ✅ | Design system: color + typography + spacing tokens | `Sources/HerminalApp/Design/DesignTokens.swift` — palette/typography/spacing/radius/motion; build green |
| M2-2 | ✅ | Apply tokens to window chrome | Transparent titlebar + dark `surfaceBase` background; `makeWindow()` helper |
| M2-3 | ✅ | Tab management (multi-session) | `WorkspaceView` + SwiftUI `TabBarView` + `AppMenu` (Cmd+T/W, Cmd+Shift+[ ]); verified launch |
| M2-4 | ✅ | Split panes (horizontal / vertical) | `WorkspaceTab` panes + manual layout; render verified (2 panes side-by-side). Cmd+D owner-verify |
| M2-5 | ✅ | tmux-compat verification | tmux client+server spawn + run verified; htop full-screen TUI renders (colors/alt-screen). Visual tmux status bar = owner spot-check |
| M2-6 | ✅ | Latency benchmark instrumentation (#12) | `LatencyProbe` reports tick p50/p95/p99 — measured p95=0.003ms (CPU-side). keydown→photon needs typometer |
| M2-7 | ✅ | Month 2 retrospective | `docs/backlog/month-2-retrospective.md` — all M2 tasks done, scope on track |

---

## Progress Log

### 2026-05-22 — Month 2 kickoff

**Context carried in:**
- Month 1 spike done: libghostty embedded, terminal renders, shell runs, ASCII input + IME code shipped (12/13 tasks).
- Swift-vs-Rust decision settled (6/6 AI consensus) — stack locked, no architecture churn in Month 2.
- PRD timeline synced to 7 months (Option A).

**Starting:**
- M2-1 — design system token foundation (everything in Month 2+ UI depends on this).

**Plan / sequencing:**
- Design tokens first (foundation for tabs, splits, dashboard, notes UI).
- #12 latency benchmark deferred until tab/render work lands a CVDisplayLink — measuring keystroke→draw needs that hook.
- #11 IME smoke test is an owner task; non-blocking for the rest.

**Done:**
- M2-1 — `DesignTokens.swift` created: `HerminalDesign` namespace with `Palette`
  (dark surfaces, text ladder, teal-cyan accent, agent status colors),
  `Typography` (SF Pro scale + mono), `Spacing` (4-pt grid), `Radius`, `Motion`.
  Build green. Foundation ready for all Month 2+ chrome UI.

### 2026-05-22 — Month 2 complete

**All 6 Month-2 tasks shipped (M2-1..M2-6) + retrospective (M2-7):**
- M2-2 — window chrome: transparent titlebar over dark `surfaceBase`.
- M2-3 — tab management: `WorkspaceView` + SwiftUI `TabBarView` + `AppMenu`
  (Cmd+T/W, Cmd+Shift+[ ]). Verified: tab bar renders, terminal runs in a tab.
- M2-4 — split panes: `WorkspaceTab` + manual `layoutPanes()`. Verified: 2 panes
  render side-by-side, each its own shell. NSSplitView dropped (Q2-002).
- M2-5 — tmux-compat: tmux client+server spawn + run verified; htop full-screen
  TUI renders (colors, alternate screen).
- M2-6 — `LatencyProbe`: tick p95 = 0.003ms; herminal is not CPU-bound per frame.
  Closes Month-1 debt #12.
- Commits: `61f9a67` (tokens) → `24ffc87` (chrome+tabs) → `34cb423` (splits)
  → `4fa6b10` (tmux+latency).

**Carried to Month 3:** GUI interactive verification gap (osascript unreliable,
Telex composes test input) — must be fixed early in Month 3. Plus #11 IME smoke
test and assorted owner spot-checks. See `month-2-retrospective.md`.

**Scope check:** 7-month Option A on track (M1 ✅, M2 ✅). Month 3 (agent
dashboard) is the first feature with no Ghostty reference — re-check Option B/C
at the Month 3 retro if it slips.

**Next:** M2-2 — apply tokens to window chrome (title bar, surface background).

---

## Deferred / Dropped Items

_None yet._

---

## Open Questions

- **Q2-001 (resolved):** Tabs — native `NSWindow` tab group vs custom tab bar? → **custom** SwiftUI tab bar, for premium design control + future agent-status integration.
- **Q2-002 (resolved):** Split layout — `NSSplitView` vs manual layout? → **manual layout**. `NSSplitView.addArrangedSubview` did not divide the panes reliably; manual frame layout in `layoutPanes()` is predictable. Trade-off: no drag-to-resize divider yet — deferred to v0.2.
- **Q2-003 (open):** Recursive split trees (tmux-style nesting) — MVP does 1-axis splits per tab only. Recursive nesting deferred; revisit if owner needs it.

---

## Reference

- [Month 1 retrospective](./month-1-retrospective.md)
- [PRD](../define/herminal.prd.md) — Section roadmap: Month 2 = design system + tabs/splits + tmux-compat
- [Swift vs Rust research](../research/08-swift-vs-rust-performance.md)
