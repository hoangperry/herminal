# Phase 1 — TmuxLaunch + tests

Parent: [plan.md](plan.md) · Define: [docs/define/tmux-launcher.md](../../docs/define/tmux-launcher.md)

## Goal

Pure module compiles and unit tests pass. No AppKit chrome yet.

## Steps

1. Add `Tests/HerminalAppTests/TmuxLaunchTests.swift` with the cases in
   plan §6. It must not compile or must fail until step 2 exists.
2. Add `Sources/HerminalApp/Workspace/TmuxLaunch.swift`:
   - `validateName`, `slug`, `quote`, `command(action:name:)`
   - `parseSessionList`
   - `resolveBinary` over `binaryCandidates`
   - `TmuxRunner` (argv, timeout 8s, file-backed pipes like current
     `GitRunner.live`)
   - `listSessions` / `hasSession` using `-t =<name>`
   - `sessionName(fromCwd:)` via `GitWorktree.resolveContext` then
     basename fallback
3. Run `swift test --filter TmuxLaunch` (or the standalone `swiftc`
   harness if SPM is broken locally).

## Done

Every row in plan §6 is green. No menu items yet.
