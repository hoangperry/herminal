# Sprint 1 — Vietnamese IME Tab completion and release truth

**Status:** implementation complete; verification blocked
**Started:** 2026-08-14

## Goal

Remove the Vietnamese-first release blocker where Tab is consumed while Telex/VNI marked text is active, then reconcile public release claims before v1.

## Completed

- Diagnosed the Ghostty/libghostty input path from AppKit callback through Zig key encoding.
- Added Herminal-owned post-IME routing for marked-text commit + Tab replay.
- Preserved the original event on replay, including Shift modifier.
- Added five state-transition regression cases.
- Added Telex/VNI + zsh/bash/fish manual completion matrix.
- Moved the fix into the unreleased v1 changelog.
- Bumped target app build from 22 to 23.
- Corrected README EN/VI: `main` is a v1 release candidate; latest public release is v0.4.2.
- Corrected Homebrew install documentation and synchronized the in-repo cask with public v0.4.2.
- Corrected roadmap, FAQ, and v1 retrospective release claims.
- `git diff --check` passes.

## Verification blocker

Local `swift test --filter IMEBridgeTests` cannot start because this machine only has `/Library/Developer/CommandLineTools`; its SwiftPM executable cannot load `SWBBuildService.framework`. A full Xcode installation is absent.

Required owner/environment actions:

1. Install/select the documented full Xcode toolchain.
2. Run `swift test --filter IMEBridgeTests`, then `swift test`.
3. Build and run the dated live Telex/VNI checklist, especially T1/T2/T5/T6/T7.
4. If green, run the dogfood gate.
5. Only then cut signed/notarized public v1 using owner-held credentials.

Do not claim the IME issue fixed in a public release until the live checklist passes.

## Review notes

The fix deliberately does not manually commit `markedText`. It activates only when AppKit has already ended composition and delivered committed text through `insertText` during the Tab `keyDown`. This avoids guessing at IME state and avoids duplicate commits. The committed text is emitted with keycode 0, then the original Tab event is replayed with `composing=false`, matching Ghostty's upstream approach for post-preedit navigation keys.
