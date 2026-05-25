# Month 12 Retrospective — UI polish + preferences

**Period:** 2026-05-26 (single-session, owner requested
"Enhance UI, preference settings,..." → selected "Both: Preferences
foundation + UI polish batch")
**Sprint goal:** Land a real Settings surface and the four UI polish
touches that have been "obvious once we have Settings" since M8.
**Result:** ✅ All 5 slices shipped behind individual commits. 79/79
tests pass after each slice. App bundle assembles. CHANGELOG updated.
Five files added, six touched.

---

## 1. What Got Done

| Slice | Output | Acceptance |
|---|---|---|
| P1 — Preferences foundation | `Preferences` + `PreferencesView` + `PreferencesWindow` + AppMenu integration | ⌘, opens Settings. Theme picker (Dark/Light/Follow System) flips chrome live. 8 keys defaulted at launch. |
| P2 — Status bar | `StatusBarView` 22 pt strip at window bottom | Live tick p95 / agent count / diary size / theme. Toggleable via `showStatusBar` preference. |
| P3 — First-run welcome | `WelcomeOverlayView` translucent card | Shows once on first launch (`firstRunCompleted == false`), 7 most-used shortcuts. Dismiss = persist. |
| P4 — Close confirmation | NSAlert in `closeTab` + `closeActivePane` | Prompts only when tab being collapsed AND a pane note has non-empty body. Gated by `confirmCloseWithNote` preference. |
| P5 — Window restoration | `WindowState` namespace + `NSWindowDelegate` on AppDelegate | Frame + sidebar visibility + notes visibility persist. Off-screen frames discarded. |

Stats: 5 commits (`c0dbbf5` → `dea56ab`), 79/79 tests, 6 new files,
6 modified files, ~640 net LOC added.

---

## 2. What We Learned

### "Both" was the right call

The owner could have asked for just P1 first and circled back for the
polish later. Doing them in one session worked because P2-P5 ALL depend
on the M12-P1 plumbing — status bar reads `Preferences.showStatusBar`,
welcome reads `firstRunCompleted`, tab confirmation reads
`confirmCloseWithNote`, restoration uses the same UserDefaults pattern.
Splitting across sessions would have meant rebuilding mental model
context twice.

The shape held even at the smaller scale: each slice was its own
commit, so the next time we want to retire one (e.g. if Settings UI
moves to a sheet) we cherry-pick instead of bisecting.

### Swift 6 strict concurrency caught a footgun at compile time

`Preferences.defaults` started life as `static let defaults: [String: Any]`.
Swift 6 strict concurrency flagged it: `[String: Any]` is non-Sendable,
and a global with non-Sendable storage is unsafe even when only read.
The fix (a `defaultsDictionary()` function) is a one-line refactor and
removes any chance of someone treating the dict as mutable later.

Lesson: in Swift 6, "I'll just make it `static let` and move on" is no
longer free. The compiler will surface it the moment you cross actor
boundaries, which is now most callsites.

### NSAlert is still the right primitive for one-shot blocking choices

Tried imagining a SwiftUI sheet for P4, then walked it back. The view
we'd attach to is a libghostty NSView with no SwiftUI environment, and
the prompt is single-button — `addButton(withTitle:)` + `runModal()`
beats wiring `@State` + a `.sheet` modifier + a coordinator.

The same instinct applied to NSWindow restoration: NSWindow.setFrameAutosaveName
would have saved a few lines, but it stores in an opaque defaults
domain we can't compose with the rest of `WindowState`. Doing the
six-line round trip ourselves keeps the persistence layer one file,
one API, one mental model.

### The "centre-on-screen" validation rule for restored frames

First draft of `WindowState.load()` accepted any saved frame. Owner
test would have surfaced it the first time they pulled the laptop off
a second monitor and relaunched. Catching it in design — by requiring
the rect's centre to land inside SOME screen's `visibleFrame` — was
cheaper than a bug report.

This is a small instance of the "trust nothing crossing process
boundaries" rule from `rules/common/security.md`. Application of the
rule extends past obvious validation to "what if the world looks
different from when we saved?"

---

## 3. What Didn't Land

Nothing scoped out; the "Both" expansion held to its 5 slices.

The first-run hint is presented as an overlay, not a modal walkthrough.
That's intentional — interactive product tours feel patronising on a
terminal. But it does mean we're not measuring whether owners actually
read the hint vs. tap it away. No metric for that without telemetry,
which contradicts SECURITY.md's no-network promise. Comfortable with
the trade-off.

---

## 4. Carry-forward for M13+

- **No follow-up debt.** Each slice is self-contained. The TODO list
  this session shows zero pending tasks created.
- **One latent need-to-watch:** Settings has 4 tabs and 8 keys today.
  If we cross ~15 keys it'll stop fitting on one screen. Bridge from
  there: split General into General+About, or move runtime/keyboard
  settings into a separate scene.
- **Test coverage for the new files is implicit** (SwiftUI views aren't
  unit-tested in this project; integration smoke tests would cover
  Settings if we ever build them). Acceptable given the project's
  ratio of UI to tested logic — none of the M12 code branches on data
  beyond reading a preference and rendering a chip.

---

## 5. Commits

| SHA | Slice | LOC |
|---|---|---|
| `c0dbbf5` | M12-P1 — Preferences foundation | +443 / -1 |
| `5131258` | M12-P2 — status bar | +213 / -8 |
| `f2d93f7` | M12-P3 — first-run welcome hint | +139 / -1 |
| `036edec` | M12-P4 — tab close confirmation | +59 / -1 |
| `dea56ab` | M12-P5 — window state restoration | +180 / -5 |

Total: ~1,034 LOC added, ~16 LOC removed, 5 commits, 79/79 tests
green through every step.

---

## 6. Owner sign-off

- All five slices pushed to `main` (commit `dea56ab` is HEAD at time
  of writing).
- v0.1.0 draft release is still pending owner notarization (see
  `docs/NOTARIZE-NEXT.md` — unchanged by M12).
- No backlog items opened this session; M12 closes clean.
