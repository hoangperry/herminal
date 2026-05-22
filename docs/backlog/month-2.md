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
| M2-2 | ⏳ | Apply tokens to window chrome | Title bar, surface background, premium styling |
| M2-3 | ⏳ | Tab management (multi-session) | Multiple terminal surfaces in one window |
| M2-4 | ⏳ | Split panes (horizontal / vertical) | Split a window into multiple surfaces |
| M2-5 | ⏳ | tmux-compat verification | Run tmux inside herminal; verify rendering/mouse/colors |
| M2-6 | ⏳ | Latency benchmark instrumentation (#12) | Measure keystroke→draw; needs CVDisplayLink hook |
| M2-7 | ⏳ | Month 2 retrospective | Review, re-check scope (Option B/C re-open?) |

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

**Next:** M2-2 — apply tokens to window chrome (title bar, surface background).

---

## Deferred / Dropped Items

_None yet._

---

## Open Questions

- **Q2-001:** Tabs — native `NSWindow` tab group vs custom tab bar? Native gives free macOS integration but less design control; custom fits the premium Raycast/Linear bar. To decide at M2-3.

---

## Reference

- [Month 1 retrospective](./month-1-retrospective.md)
- [PRD](../define/herminal.prd.md) — Section roadmap: Month 2 = design system + tabs/splits + tmux-compat
- [Swift vs Rust research](../research/08-swift-vs-rust-performance.md)
