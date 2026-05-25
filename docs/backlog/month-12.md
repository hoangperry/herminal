# Month 12 — UI polish + preferences foundation

**Period:** 2026-05-26 (single-session, owner requested
"Enhance UI, preference settings,...")
**Sprint goal:** Land a real Settings surface + the small quality-of-life
UI touches that have been "obvious once we have Settings" since M8.

## Scope picked

When the owner asked for "both" via AskUserQuestion, we expanded into
five parallel polish slices:

1. **P1 — Preferences foundation.** Single `Preferences` enum +
   SwiftUI Settings scene + AppKit live-update bridge.
2. **P2 — Status bar.** 22 pt strip at the window bottom showing live
   tick p95 / agent count / diary size / theme.
3. **P3 — First-run welcome hint.** One-shot overlay listing the 7
   most-used shortcuts. Dismiss = `markFirstRunCompleted()`.
4. **P4 — Tab close confirmation.** NSAlert when closing a tab whose
   panes hold a non-empty note. Gated by the M12-P1 preference.
5. **P5 — Window state restoration.** Frame + sidebar visibility +
   notes-pane visibility persist across launches. Off-screen frames
   fall back to default geometry.

## Commits

| SHA | Slice |
|---|---|
| `c0dbbf5` | M12-P1 — Preferences foundation |
| `5131258` | M12-P2 — status bar |
| `f2d93f7` | M12-P3 — first-run welcome hint |
| `036edec` | M12-P4 — tab close confirmation when notes exist |
| `dea56ab` | M12-P5 — window state restoration |

5 commits, 79/79 tests pass through every slice, app bundle assembles
clean after every slice. Each slice was its own commit so the cherry
of pulling out a regression (or backing out a single slice) stays
trivial.

## Files added

- `Sources/HerminalApp/Preferences.swift` — UserDefaults wrapper
- `Sources/HerminalApp/PreferencesView.swift` — SwiftUI 4-tab Settings
- `Sources/HerminalApp/PreferencesWindow.swift` — AppKit host
- `Sources/HerminalApp/Workspace/StatusBarView.swift`
- `Sources/HerminalApp/Workspace/WelcomeOverlayView.swift`
- `Sources/HerminalApp/WindowState.swift`

## Files touched

- `Sources/HerminalApp/AppMenu.swift` — added Settings… (⌘,)
- `Sources/HerminalApp/AppDelegate.swift` — Preferences.registerDefaults
  + applyPersistedTheme + openPreferences action + NSWindowDelegate
  conformance + saved-frame plumbing
- `Sources/HerminalApp/Workspace/WorkspaceView.swift` — preference
  notification observer + repaintChrome + status bar host + welcome
  overlay + note-confirm gating + applyRestoredSidebarState +
  persistSidebarState
- `Sources/HerminalApp/Diary.swift` — fileSizeBytes() accessor
- `Sources/HerminalApp/LatencyProbe.swift` — snapshotP95Milliseconds()
- `CHANGELOG.md` — five new bullets under [Unreleased]
