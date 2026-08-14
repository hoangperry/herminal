---
title: tmux launcher (PRD Must Feature 3 leftover)
status: implemented
owner: hoangperry
created: 2026-08-15
blockedBy: []
blocks: []
define: docs/define/tmux-launcher.md
---

# tmux launcher — implementation plan

**Define (product source of truth):** [`docs/define/tmux-launcher.md`](../../docs/define/tmux-launcher.md)

If this file and the define disagree, **the define wins**. Do not add
broadcast, choose-tree, `tmux -CC`, PTY detach, or agent-in-tmux mapping.

Phases:

| Phase | File | What |
|---|---|---|
| 1 | [phase-01-core.md](phase-01-core.md) | Tests + `TmuxLaunch` (no UI) |
| 2 | [phase-02-ui.md](phase-02-ui.md) | Menu, palette, alerts, `addTab` |
| 3 | [phase-03-docs.md](phase-03-docs.md) | CHANGELOG + shortcuts |

## 1. Why this exists

PRD Must Feature 3 requires: new session, attach existing, attach-or-create
by repo. Tabs/splits and in-PTY tmux already ship. The launcher does not.

Worktrees (`⌘⌥W`) are git checkouts. This is a **named tmux session**
inside a new herminal tab. Different problem.

## 2. Architecture

```
Menu / ⌘⇧P
    → WorkspaceView+Tmux (@objc)
        → TmuxLaunch.resolveBinary()          // or alert, stop
        → TmuxLaunch.sessionName(fromCwd:)    // or alert, stop
        → TmuxLaunch.hasSession / listSessions
        → TmuxLaunch.command(for:name:)       // quoted string
        → WorkspaceView.addTab(command:title:workingDirectory:)
            → libghostty surface, cwd = focused OSC 7
```

tmux **client** dies with the tab. tmux **server** and other sessions
keep running the way tmux already does. Herminal never attaches an
existing PTY.

Do not grow `WorkspaceView.swift` except what the extension can already
call (`addTab`, `focusedWorkingDirectory`).

## 3. `TmuxLaunch` API (implement exactly)

```swift
enum TmuxLaunch {
    enum Action { case newSession, attach, attachOrCreate }

    enum ValidationError: Swift.Error, Equatable {
        case empty, tooLong, invalid
    }

    enum Error: Swift.Error, Equatable {
        case tmuxMissing
        case noWorkingDirectory
        case sessionExists        // New, and name already live
        case noSessions           // Attach…, list empty
        case invalidName
        case tmuxFailed(String)
    }

    static let maxNameLength = 64
    static let binaryCandidates = [
        "/opt/homebrew/bin/tmux",
        "/usr/local/bin/tmux",
        "/usr/bin/tmux",
    ]

    static func validateName(_ name: String) throws
    static func slug(_ raw: String) -> String
    static func sessionName(fromCwd cwd: String) -> String?
    static func resolveBinary(fileManager: FileManager = .default) -> String?
    static func quote(_ value: String) -> String          // same as ssh: ' + ' → '\''
    static func command(action: Action, name: String) throws -> String
    static func parseSessionList(_ stdout: String) -> [String]
    static func listSessions(runner: TmuxRunner = .live) throws -> [String]
    static func hasSession(name: String, runner: TmuxRunner = .live) throws -> Bool
}
```

`TmuxRunner` mirrors `GitRunner`: argv-only `Process`, executable =
resolved binary, 8s timeout, file-backed stdout/stderr (do **not** copy
the old pipe-deadlock version). Tests inject a fake runner.

### Name rules

Allowed after trim: `A–Z a–z 0–9 . _ -`.  
Reject: empty, length > 64, leading `-`, `..`, space, `/`, `'`, `"`,
`$`, `` ` ``, `;`, `|`, `&`, any control char.

`slug`: replace space and `/` with `-`, drop every other illegal
character, then `validateName`. If slug is empty → `sessionName` returns
nil.

`sessionName(fromCwd:)`:

1. If `GitWorktree.resolveContext(cwd:)` succeeds, use
   `(mainRepoRoot as NSString).lastPathComponent`.
2. Else use `(cwd as NSString).lastPathComponent`.
3. Slug + validate. Failure → nil.

### Commands (after validate)

| Action | String passed to `addTab` |
|---|---|
| `.newSession` | `tmux new-session -s` + `quote(name)` |
| `.attach` | `tmux attach-session -t` + `quote(name)` |
| `.attachOrCreate` | `tmux new-session -A -s` + `quote(name)` |

Use the basename `tmux` in the command string (user shell `PATH` at
PTY spawn). Binary resolution is **only** for list/has-session
preflight, so a missing install fails in the GUI instead of a dead pane.

`quote("foo")` → `'foo'`.  
`quote("a'b")` → `'a'\''b'`.

### list / has-session

```
<resolved> list-sessions -F #{session_name}
<resolved> has-session -t =<name>
```

The `=` prefix is exact match (tmux target).

- `list-sessions` exit ≠ 0 and empty stdout → `[]` (no server yet), not an error.
- `has-session` exit 0 → true; anything else → false.
- Missing binary → `Error.tmuxMissing`.

## 4. UI

Window menu, after the agent-cockpit block, before tab 1–9 **or** after
tab 1–9 — pick **after Claude Sessions / before theme** if that groups
better; default: a “tmux” trio after Open Lazygit, separator, then ⌘1–9.

| Title | Selector | Shortcut |
|---|---|---|
| New tmux Session | `newTmuxSession:` | none |
| Attach tmux Session… | `attachTmuxSession:` | none |
| Attach or Create tmux Session | `attachOrCreateTmuxSession:` | none |

Palette: same three, `id` `tmux-new` / `tmux-attach` / `tmux-attach-or-create`,
icon `square.split.2x1` (or `terminal`), no `shortcutDisplay`.

### Action flow

Shared preamble:

1. `resolveBinary()` nil → alert “tmux is not installed.” Stop.
2. Need a name? `focusedWorkingDirectory()` nil → alert “No working
   directory yet.” Stop. Then `sessionName(fromCwd:)` nil → alert
   “Could not make a tmux session name from this folder.” Stop.

**New**

3. `hasSession` true → alert “A tmux session named … already exists.
   Use Attach or Create.” Do not log the name if you can avoid it;
   “session already exists” is enough.
4. `addTab(command: command(new), title: "tmux · \(name)", cwd: cwd)`.

**Attach…**

3. `listSessions()`. Empty → alert “No tmux sessions. Create one first.”
4. NSAlert + `NSPopUpButton` of names. Cancel → stop.
5. Re-validate the chosen name (do not trust the popup blindly).
6. `addTab` attach command.

**Attach or Create**

3. `addTab` attachOrCreate command. No extra prompt.

Diary: `tmux spawn action=new|attach|attachOrCreate` only. No cwd, no name.

Alerts: `NSAlert` informational, title `tmux`, one OK button (or
Create/Cancel on the picker). Copy the worktree dialog layout
(`WorkspaceView+Cockpit.newAgentWorktree`).

## 5. Files

| Path | Change |
|---|---|
| `Sources/HerminalApp/Workspace/TmuxLaunch.swift` | **New.** Pure + runner. |
| `Sources/HerminalApp/Workspace/WorkspaceView+Tmux.swift` | **New.** `@objc` + alerts. |
| `Sources/HerminalApp/AppMenu.swift` | +3 items, no key equivalents. |
| `Sources/HerminalApp/CommandPalette.swift` | +3 `CommandPaletteAction`s. |
| `Tests/HerminalAppTests/TmuxLaunchTests.swift` | **New.** See phase 1. |
| `docs/KEYBOARD-SHORTCUTS.md` | Section under tmux: menu/palette, no keys. |
| `CHANGELOG.md` | Unreleased / Added. |

Do **not** edit `WorkspaceView.swift` unless `quoted` must be shared —
prefer duplicating the two-line quoter on `TmuxLaunch` (already tested
there) so we do not touch SSH code.

## 6. Tests first (phase 1, must fail until core exists)

`TmuxLaunchTests`:

- accept `herminal`, `my-app`, `foo.bar`
- reject `""`, `" "`, `-evil`, `foo bar`, `foo/bar`, `a$(b)`,
  `` a`b ``, `foo;rm`, 65-character string
- `slug("My App") == "My-App"`; `slug("foo/bar") == "foo-bar"`
- `quote("foo") == "'foo'"`; `quote("a'b") == "'a'\\''b'"`
- `command(.newSession, "foo") == "tmux new-session -s 'foo'"`
- `command(.attach, "foo") == "tmux attach-session -t 'foo'"`
- `command(.attachOrCreate, "foo") == "tmux new-session -A -s 'foo'"`
- `parseSessionList("a\nb\n\n") == ["a", "b"]`
- fake runner: `hasSession` true/false from exit code
- `resolveBinary` with a FileManager mock or a temp executable path —
  if mocking FileManager is awkward, test `binaryCandidates` order
  and that an empty candidate list is not used; live resolve is
  dogfood.

No new `verify-*.sh`. Compat matrix already starts tmux.

## 7. Order of work

1. Phase 1 tests → red.
2. `TmuxLaunch` until tests green.
3. Phase 2 UI wiring. Build the app if Xcode is available; otherwise
   rely on unit tests + owner dogfood.
4. Phase 3 docs.
5. Diff review: no broadcast, no `-CC`, no PTY attach, no new shortcuts.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Other agents edit AppMenu / palette / WorkspaceView | Additive rows + new files only |
| `config.command` is shell-parsed | `quote` + tests with `'` |
| tmux only via Homebrew | Fixed candidate list |
| `list-sessions` fails when no server | Treat as empty list |
| Agent inside tmux invisible to dashboard | Accepted in define; do not “fix” |
| Session name collision with `new-session -s` | Preflight `has-session`; New fails closed |

## 9. Done when

Define §7:

- Attach or Create lands in yesterday’s session without typing tmux.
- Injection cases have unit tests.
- Diff has no broadcast / `-CC` / detach.

## Validation log

- 2026-08-15 — cut broadcast, choose-tree, `-CC`, persist-after-quit.
- 2026-08-15 — define written (`docs/define/tmux-launcher.md`).
- 2026-08-15 — plan expanded into API, UI flows, and three phases.
