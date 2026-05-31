# 09 — Polish audit: why herminal feels "không đã"

**Date:** 2026-05-27
**Trigger:** Owner feedback after dogfooding v0.2.5 — "xài vẫn không đã bằng các terminal hiện tại."
**Method:** 3 parallel Gemini-3-flash-preview researches against the live v0.2.5 codebase. Brutal-honest framing.
**Cost:** ~12 minutes wall time. No human reviewer.

---

## TL;DR

**The diagnosis is consistent across all three audits:** herminal has a Ferrari engine (libghostty Metal) bolted into a plastic chassis (default AppKit chrome with linear easing curves, no vibrancy, no scrollback search, no command palette, no margin between text and window edge). The core engine is competitive with Ghostty — but every layer above it screams "wrapper-around-a-library", not "premium product."

**The fix is a focused 14-day polish wave, not feature drip.** Solo dev + AI pair should ship one big v0.3.0 that addresses the GUI gaps in priority order. Adding more features (Notes search, Sparkle, font picker) before fixing the polish gap will compound the "đồ chơi" perception.

**Landing page has parallel issues.** ASCII art reads as student script in 2026. Comparison table reads as self-serving. The "promises we won't do" list is defensive copy padding. Hero needs a real video loop showing the Vietnamese IME + agent dashboard pulse, not text + ASCII.

---

## Table of contents

1. [Root-cause diagnosis](#1-root-cause-diagnosis-the-real-reason)
2. [App polish — top 10 ranked](#2-app-polish--top-10-by-impactdays-effort)
3. [Landing page — top 5 ranked](#3-landing-page--top-5-by-impacteffort)
4. [Recommended 14-day plan](#4-recommended-14-day-plan)
5. [What NOT to do](#5-what-not-to-do-warnings-from-the-audit)
6. [Citations](#6-citations--references)
7. [Open questions](#7-open-questions)

---

## 1. Root-cause diagnosis — the real reason

> "Herminal hiện tại đang có 'vibe' của một ứng dụng Linux port sang Mac hoặc một Electron app cấu hình thấp."
> — Audit 3 (polish layer)

> "Herminal giống như cái máy Ferrari nhưng ghế ngồi bằng nhựa chợ rẫy."
> — Audit 1 (UX gaps)

Owner đã invest 5 ngày v0.2.1 → v0.2.5 vào fix stub-from-spike (clipboard, mouse events, close_surface, SET_TITLE, MOUSE_SHAPE, OPEN_URL). All necessary. None of them touch the **GUI feel layer**.

The gap is not "missing features" — herminal already beats most terminals on agent dashboard, notes, IME, SSH. The gap is **the surface every user touches every second**:

| Layer | Current state | What "đã" terminals do |
|---|---|---|
| **Window background** | Solid `surfaceBase` color (`oklch(15% 0.012 270)`) | `NSVisualEffectView` with `.fullScreenUI` material + 10-15% bg opacity |
| **Animation curves** | `.easeOut`, `HerminalDesign.Motion.normal = 0.22s` | `.interpolatingSpring(stiffness: 300, damping: 28)` |
| **Text padding** | Text sits flush against pane edge | 5-10 px content inset (Ghostty default) |
| **Tab bar** | Default AppKit `NSHostingView` rendering | Slim borderless tabs with inactive opacity (Arc / Ghostty) |
| **Cursor scroll** | Per-cell jumps | Pixel-interpolated smooth move |
| **Caret blink** | Free-running phase | Resets to solid on every keypress |
| **Selection** | Default `NSColor.selectedTextBackgroundColor` (opaque) | Custom alpha-blended overlay (0.3 alpha) |
| **Right-click** | Nothing | Copy / Paste / Search Google / Lookup |

Each line above is something Ghostty / iTerm2 / Warp picked up in their first 6 months. Herminal still hasn't, 12 months in, because the bug-fix backlog (M1 → M13) ate the polish budget.

---

## 2. App polish — top 10 by impact/days effort

Ranking formula: `priority = visible_impact (1-10) / man_days_effort`. Solo dev + Claude Opus pair velocity.

| # | Item | Impact | Effort (days) | Priority | Concrete change |
|---|---|---|---|---|---|
| **1** | `NSVisualEffectView` background | 9 | 0.5 | **18** | Wrap `WorkspaceView` in `NSVisualEffectView(material: .fullScreenUI)`. Drop alpha on `surfaceBase` to 0.85. One file: `AppDelegate.makeWindow`. |
| **2** | Content padding (5-10 px) | 7 | 0.3 | **23** | `WorkspaceView.layout()` shrinks `surfaceContainer` by inset. One file. |
| **3** | Scrollback search (⌘F) | 10 | 4 | **2.5** | New `SearchOverlayView` SwiftUI + `ghostty_surface_*search*` binding actions. Tracks match count, ⌘G / ⌘⇧G nav. Without this, herminal is "đồ chơi, không phải công cụ." |
| **4** | Caret blink phase reset | 7 | 0.5 | **14** | On `keyDown`, force libghostty cursor to solid + reset timer. Need to check if `ghostty_surface_cursor_reset` exists; if not, render-side hint. |
| **5** | Spring animation curves | 6 | 1 | **6** | Replace `.easeOut` in `WorkspaceView.animateSidebarChange` + `TabBarView` transitions. Use `.spring(response: 0.3, dampingFraction: 0.7)`. |
| **6** | Right-click context menu | 6 | 1 | **6** | Override `menu(for event:)` on `HerminalSurfaceView`. Items: Copy, Paste, Open Selection in Browser, Look Up, Search with Google. Wire via existing `runBindingAction`. |
| **7** | Command palette (⌘⇧P) | 8 | 2 | **4** | Floating `NSPanel` over key window. Index: tabs, sessions, ssh hosts, agent processes, menu actions. Same look as Raycast root. |
| **8** | Drag-resize splits | 7 | 2 | **3.5** | `NSSplitViewController` replacing manual layout in `WorkspaceTab.panes`. Loses single-axis-MVP simplicity; gains ultrawide users. |
| **9** | Triple-click select line | 6 | 1 | **6** | `mouseDown` checks `event.clickCount`; 2 → word, 3 → line. libghostty has `ghostty_surface_mouse_button` taking modifier flags — pass triple-click hint. |
| **10** | Hotkey/Quake window (⌥Space) | 8 | 1.5 | **5.3** | Global `NSEvent.addGlobalMonitorForEvents`. Slide-down `NSPanel` window. iTerm2's gateway-drug feature. |

**Quick wins (≤ 0.5 day each, ship in one day):**
- Items 1, 2, 4 above
- Custom selection color with alpha (15 min)
- Tab bar inactive opacity 60% (15 min)
- Window padding around traffic lights (30 min)

These five items alone — half a day total — would already shift perception meaningfully.

---

## 3. Landing page — top 5 by impact/effort

Site shipped at https://hoang.tech/herminal/ uses ASCII art for the agent dashboard preview. Audit 2 verdict: "AI-native mà dùng ASCII art khiến tool trông giống script học sinh hơn là premium engineering tool."

| # | Upgrade | Impact | Effort | Notes |
|---|---|---|---|---|
| **1** | Hero video loop (5-10 s) | 9 | 2 | Record actual terminal: claude code running → BEL fires → dashboard pulses red → owner types reply. `ScreenStudio` or QuickTime + ffmpeg. Replace ASCII art block at hero entirely. |
| **2** | Side-by-side IME demo | 8 | 1 | Loop 1: regular terminal in vim, telex breaks ("tieesng" not composing). Loop 2: same in herminal, composes cleanly. The single most-Vietnamese-targeted moment. |
| **3** | `brew install` line above-the-fold | 7 | 0.1 | Add to hero CTA strip. Right now download URL is 700 px down. |
| **4** | Replace comparison table with manifesto | 6 | 0.5 | The current table reads self-serving. Replace with a 3-line philosophy block: "local-first / native / no-account". Lose 4 rows of marketing copy. |
| **5** | Shorten "promises we won't do" block | 5 | 0.3 | Currently 7 bullets, paragraph each. Compress to a single 3-line italic block. Less defensive. |

**What's already good (don't touch):**
- Mono headlines + accent color (matches in-app dark theme — strong identity)
- 800 px breakpoint (responsive without bloating)
- No analytics / newsletter / form (matches the no-telemetry promise — keep this)
- Sitemap + favicon + nojekyll (operational polish)

**What stays deferred:**
- Bilingual EN/VI toggle (`?lang=vi` URL param + localStorage)
- Live changelog feed (read from CHANGELOG.md via JS fetch)
- GitHub-stars / latest-release badges in hero
- Interactive web terminal preview (xterm.js wrapper) — high effort, low ROI for v0.3

---

## 4. Recommended 14-day plan

**Branch:** `polish-wave-v0.3`. Single PR, merged when v0.3.0 ships.
**Pattern:** App slice in the morning, website slice in the afternoon — keeps both moving and prevents either from rotting.

### Days 1-3 — Foundation (visible change Day 1)

- D1 morning: `NSVisualEffectView` + content padding + selection alpha + tab inactive opacity
- D1 afternoon: Hero video record + edit + replace ASCII art at hero
- D2 morning: Spring animations across sidebar, tab strip, splits
- D2 afternoon: Side-by-side IME demo video + embed
- D3 morning: Caret blink phase reset + right-click context menu
- D3 afternoon: brew install in hero CTA; trim manifesto + promises block

**End of D3:** Re-deploy site. Self-screenshot the new app. Already feels different.

### Days 4-7 — Scrollback search (the headline feature)

- D4: SearchOverlayView SwiftUI scaffolding + ⌘F binding
- D5: libghostty bridge — read selection match positions, paint highlight overlays
- D6: Match count UI + ⌘G / ⌘⇧G next/prev navigation + regex toggle
- D7: Programmable regression test (`Scripts/verify-search.sh`) + dogfood-checklist entry + manual smoke

### Days 8-10 — Command palette + triple-click + drag-resize

- D8: Command palette UI scaffold (modeled on Raycast root)
- D9: Action index (tabs, sessions, ssh hosts, palette commands) + fuzzy filter
- D10: Triple-click line select + drag-resize splits

### Days 11-12 — Hotkey window + verification

- D11: Global hotkey monitor + slide-down `NSPanel`
- D12: Full regression sweep (clipboard, title, search, palette, mouse, scroll); update docs/QA/dogfood-checklist.md

### Days 13-14 — Ship

- D13: v0.3.0 bump, CHANGELOG, sign + notarize + release
- D14: Marketing push: Twitter/X thread, Show HN, Reddit r/vietnam_devs + r/programming, update README hero, announce on website

**End state target:** v0.3.0 shipped. Site refreshed with video hero. Owner says "đã."

---

## 5. What NOT to do — warnings from the audit

1. **Don't add new product features in this wave.** Notes search, Sparkle, font family picker — all valid, all defer. The owner's "không đã" feedback is about polish, not breadth. Adding features now makes the perception problem worse, not better.

2. **Don't replace AppKit with SwiftUI for the workspace shell.** The audit didn't suggest it but it's a tempting rewrite. AppKit + libghostty is the right stack — the issue is *defaults*, not the framework. SwiftUI port = 3 months of regressions.

3. **Don't ship per-feature.** Five separate releases shipping each polish item separately = five micro-announcements with diminishing returns. One v0.3.0 with all of them = a story worth telling on Show HN.

4. **Don't keep ASCII art on the landing page.** Vietnamese / dev / AI-native audience in 2026 expects video. Audit 2: "Đừng 'hạ thấp' libghostty Metal renderer bằng ASCII art."

5. **Don't rely on the existing comparison table.** Devs assume any table the project author wrote will favor the project. The data isn't wrong — it's just unconvincing. A 3-line philosophy block beats a 5-row comparison.

6. **Don't skip the regression-guards.** Every polish change needs the same `verify-*.sh` treatment as v0.2.1-v0.2.5. The lesson from the audit window: stubs hide for 12 months without programmable checks.

---

## 6. Citations & references

### From the audit researches

- **Mitchell Hashimoto on Ghostty's renderer:** "Performance is a feature, but correctness is the requirement." (Cited by Audit 1.)
- **Linear.app product philosophy:** "The difference between a tool and a toy is the attention to edge cases." (Cited by Audit 1 + 3.)
- **Ghostty source:** `src/renderer/metal/renderer.m` — pixel-interpolated cell positioning when scrolling. (Cited by Audit 3.)

### Landing page references (Audit 2)

1. **ghostty.org** — The minimalism benchmark. How to sell performance without ornament.
2. **raycast.com** — Card-based feature messaging + command-palette aesthetic.
3. **linear.app** — Grid / typography / gradient to convey "precision tool."

### Internal references (this repo)

- Existing colour ladder: `Sources/HerminalApp/Design/DesignTokens.swift`
- Animation tokens: `HerminalDesign.Motion.normal = 0.22s` (replace target)
- libghostty C ABI: `Vendor/libghostty/macos/GhosttyKit.xcframework/macos-arm64/Headers/ghostty.h`
- Window construction: `Sources/HerminalApp/AppDelegate.swift:209` (`makeWindow`)
- Sidebar animation: `Sources/HerminalApp/Workspace/WorkspaceView.swift` (`animateSidebarChange`)
- Active landing page: `docs/site/index.html` + `style.css`
- Marketing source: `docs/launch/landing-page.md`

---

## 7. Open questions

1. ~~**libghostty search API surface.**~~ **RESOLVED (v0.3.2).** libghostty exposes the full search lifecycle via binding-action strings (`start_search`, `search:<needle>`, `navigate_search:next|previous`, `end_search`) plus four action callbacks (START_SEARCH / END_SEARCH / SEARCH_TOTAL / SEARCH_SELECTED). No scrollback walking, no upstream patch. Wired in `GhosttyApp.handleAction` + `SearchOverlayView`.

2. ~~**Caret blink phase reset.**~~ **RESOLVED — NEGATIVE (v0.3.3 spike).** libghostty exposes no cursor/blink API to the host (`grep -i "cursor|blink|caret"` on the XCFramework header finds only `GHOSTTY_ACTION_COLOR_KIND_CURSOR`). The blink is purely render-side. Reset-on-keypress would require an upstream libghostty patch — deferred, not attempted.

3. ~~**`NSVisualEffectView` + Metal layer interaction.**~~ **RESOLVED (v0.3.0).** Wrapping the parent `WorkspaceView` in `NSVisualEffectView(.underWindowBackground, .behindWindow)` with `window.isOpaque = false` + clear background works cleanly — vibrancy renders behind libghostty's Metal-backed children, no compositing artefacts observed in dogfood.

4. **Video hero format.** _(STILL OPEN — owner action.)_ WebM vs MP4 — Safari handles both but autoplay rules differ. `<video muted loop playsinline autoplay>` works for both; pick the smaller asset. Owner needs to record the actual interaction (Claude Code → BEL → dashboard pulse) — phù phù醬 can't synthesize this. Site still ships the ASCII-art hero (landing-page upgrade #1 not yet done).

5. **Bilingual content strategy.** _(STILL OPEN — deferred.)_ Audit 2 recommended `?lang=vi` query param + localStorage. Owner has not signalled urgency — defer to v0.4 unless Vietnamese OSS press picks up the launch.

---

## 8. Polish wave outcome (2026-05-30)

All four app-polish slices shipped, notarized, released:

| Slice | Version | Items | Status |
|---|---|---|---|
| 1 | v0.3.0 | Vibrancy, content padding, spring animations, right-click menu | ✅ |
| 2 | v0.3.1 | Command palette (⌘⇧P), global hotkey (⌥Space) | ✅ |
| 3 | v0.3.2 | Scrollback search (⌘F) — the headline finding | ✅ |
| 4 | v0.3.3 | Drag-resize splits | ✅ |

**App-side audit findings: closed.** The two top-2 root causes (no
vibrancy, no padding) and the headline finding (no search) are all
shipped. Caret blink is the only app item that couldn't be done — and
that's a libghostty limitation, not a herminal one.

**Landing-page findings: still open.** The site upgrades (video hero
replacing ASCII art, side-by-side IME demo, brew-install above the
fold, manifesto replacing the comparison table) were NOT part of the
app polish wave and remain owner-driven — they need a screen
recording the owner has to capture.

---

*Generated 2026-05-27. Polish wave landed 2026-05-30.*
