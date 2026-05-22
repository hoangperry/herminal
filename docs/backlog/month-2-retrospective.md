# Month 2 Retrospective — herminal Premium Shell + Multi-Session

**Period:** 2026-05-22
**Sprint goal (PRD roadmap):** Premium design system + tabs/splits + tmux-compat verified.
**Result:** ✅ Goal met. All 6 Month-2 tasks (M2-1..M2-6) done; retrospective is M2-7.

---

## 1. What Got Done

| # | Task | Outcome |
|---|------|---------|
| M2-1 | Design system tokens | `DesignTokens.swift` — `HerminalDesign` palette/typography/spacing/radius/motion |
| M2-2 | Window chrome | Transparent titlebar over dark `surfaceBase`; `makeWindow()` helper |
| M2-3 | Tab management | `WorkspaceView` + SwiftUI `TabBarView` + `AppMenu`; Cmd+T/W, Cmd+Shift+[ ] |
| M2-4 | Split panes | `WorkspaceTab` panes + manual `layoutPanes()`; Cmd+D / Cmd+Shift+D |
| M2-5 | tmux-compat | tmux client+server verified running; htop full-screen TUI renders |
| M2-6 | Latency probe | `LatencyProbe` — tick p95 = 0.003ms (not CPU-bound per frame) |

Also retired the Month-1 debt #12 (latency benchmark) via `LatencyProbe`.

**Month-2 roadmap goal — "premium design system + tabs/splits + tmux-compat" — is met.**

---

## 2. What We Learned (Lessons & Bugs)

### Architecture decisions
- **Q2-001 — custom SwiftUI tab bar over native NSWindow tabs.** Chosen for premium
  design control and future agent-status integration. SwiftUI for chrome, AppKit
  for the terminal surface, is a clean split and matches the PRD stack.
- **Q2-002 — NSSplitView dropped for manual layout.** `NSSplitView.addArrangedSubview`
  did not divide the pane surfaces reliably (render showed one pane). A manual
  `layoutPanes()` (even split + hairline gap) is predictable. Trade-off: no
  drag-to-resize divider yet — deferred to v0.2.
- **Q2-003 — recursive split trees deferred.** MVP does single-axis splits per tab.

### Swift 6 concurrency (recurring, as flagged in Month 1)
- `TerminalSession` had to be `@MainActor` (it holds an NSView). Its `id` is
  `nonisolated` so it stays `Identifiable` across contexts. One more isolation
  fix — consistent with the Month-1 lesson that the FFI/AppKit boundary keeps
  generating these.

### Process lesson — GUI verification is still blocked
- Automated GUI testing remains unreliable: `osascript` keystrokes go to whichever
  app is frontmost (often iTerm2, since Claude Code runs there), and the system
  Telex input source composes osascript text ("herm" → "hèm"). So Cmd+D, Cmd+T,
  IME, and the tmux status bar could not be self-verified.
- What WAS verified deterministically: render (screenshots of split panes), process
  trees (tmux client+server, child shells), build + unit tests, and pre-set state
  (temporary in-code splits / commands).
- **This is now a known structural gap** — see Roadmap Adjustment.

### No crashes this sprint
Unlike Month 1 (two crashes), Month 2 shipped without a single crash — the
concurrency patterns established in Month 1 held up.

---

## 3. Estimate vs Actual

- **PRD Month-2 plan:** premium design system + tabs/splits + tmux-compat.
- **Actual:** all delivered, plus Month-1 latency debt closed. Faster than a
  calendar month — one dense session.
- **Caveat (same as Month 1):** "delivered" means code shipped, builds green, and
  render verified — NOT that every interactive path (Cmd+D, Cmd+T, IME, tmux
  mouse/copy mode) was exercised. Interactive verification is owner-pending.

---

## 4. Debt Carried Into Month 3

| Item | Why pending |
|------|-------------|
| #11 Vietnamese IME smoke test | Owner manual test — Telex/VNI; carried from Month 1 |
| Cmd+D / Cmd+T / Cmd+W interactive verify | osascript can't reliably drive herminal's GUI |
| tmux status bar + mouse/copy mode visual check | Owner spot-check (window was occluded in tests) |
| Drag-to-resize split divider (Q2-002) | Deferred to v0.2 |
| Recursive split trees (Q2-003) | Deferred; revisit if owner needs nesting |
| True keydown→photon latency | Needs typometer / external tool |

---

## 5. Roadmap Adjustment for Month 3

- **Month 3 (per PRD):** Multi-agent dashboard alpha + notes SQLite + basic export.
- **Critical structural fix first:** the GUI-verification gap must be addressed.
  Options: (a) a scheduled owner test session at each month boundary, (b) an
  in-app debug/test mode that scripts input internally (no osascript), or
  (c) XCUITest. Pick one early in Month 3 — three months of "owner-pending"
  verification is accumulating risk.
- **Reference availability shifts now.** Month 1-2 leaned on Ghostty's `macos/Sources`
  as a porting reference. Month 3's agent dashboard + notes have NO such reference —
  they are net-new herminal design. Expect slower, more iterative work.

### Scope re-check (PRD burnout mitigation #4)
- 7-month Option A: Month 1 ✅, Month 2 ✅ — on track against the roadmap.
- **Not recommending a downgrade to Option B/C yet** — but Month 3 is the real
  test. Tabs/splits were *known-hard-with-reference*; the agent dashboard is
  *unknown-hard-without-reference*. If Month 3 slips, re-open Option B/C at the
  Month 3 retro.

---

## 6. Honest Self-Assessment

**Good:** Month-2 roadmap fully delivered, zero crashes, clean architecture
(SwiftUI chrome + AppKit surface), backlog kept current, decisions documented
(Q2-001/002/003). The app now genuinely looks like a product — dark premium
chrome, tabs, splits.

**Could be better:** Verification debt is compounding. Four "owner-pending"
interactive items now span two months. Code that builds and renders is not the
same as code that *works in the user's hands* — and herminal still has not been
driven by a human for a single real session. That must change in Month 3.

**Risk for Month 3:** the agent dashboard is the first feature with no Ghostty
reference and the first that defines herminal's actual differentiator. It will
be slower than Month 2. Plan accordingly; do not assume Month 2's pace carries.
