# Contributing to herminal

Thanks for the interest meow~ herminal is a 7-month MVP built by one
developer (with AI pair) — contributions are welcome but the project is
opinionated. Read this first so we don't waste each other's time.

## Scope

herminal is a macOS-only AI-native terminal optimized for Vietnamese
developers running agent CLIs. The PRD at
[`docs/define/herminal.prd.md`](docs/define/herminal.prd.md) is the
source of truth for what's in vs out of scope.

**Out of scope (won't merge):**
- Cross-platform (Linux/Windows) — macOS-only by design
- Cloud sync / accounts / team features
- Plugin marketplace, theming marketplace
- AI chat assistant (the agent dashboard is the surface)
- App Store distribution (sandbox is incompatible)

**In scope (PRs welcome):**
- Bug fixes (include a diary excerpt from
  `~/Library/Application Support/herminal/diary.log`)
- Performance improvements with measurements
- macOS Sequoia / Tahoe compatibility work
- Vietnamese IME edge cases (Telex + VNI)
- Additional agent CLI detection (currently: Claude Code, Codex, Aider)
- libghostty compatibility patches
- Documentation, code comments, test coverage

## Before opening a PR

1. **Open an issue first** for anything beyond a typo fix. The owner
   may have context the codebase doesn't show (deferred design
   decisions, in-flight rewrites).
2. **Run the regression suite** — `Scripts/dogfood-daily.sh` exercises
   every integration path. PRs that break it will be sent back.
3. **Match the existing style** — Swift 6 strict concurrency, no
   suppression of warnings without an inline comment explaining why,
   prefer pure `final class`/`struct` over inheritance, prefer
   `@MainActor` over `DispatchQueue.main.async`.
4. **Tests, tests, tests** — every new public type ships with a unit
   test. If the change exercises a kernel API or libghostty surface,
   add an integration script under `Scripts/verify-*.sh`.

## Development setup

```bash
git clone --recurse-submodules https://github.com/hoangperry/herminal
cd herminal
Scripts/bootstrap.sh    # builds libghostty xcframework
swift build              # builds SPM core libraries
swift test               # runs unit tests
Scripts/make-app-bundle.sh   # assembles .app with ad-hoc signature
```

Prerequisites: macOS 14+ (Apple Silicon), Xcode 26+, Swift 6.2+,
Zig 0.15.2+ (for libghostty), `clang` for the kernel-probe binaries
the integration scripts use.

## Code style

- Swift 6 strict concurrency. `@MainActor` is the default; cross-actor
  hops need explicit `MainActor.assumeIsolated` (or `Task @MainActor`).
- `nonisolated(unsafe)` is allowed for C handles (libghostty pointers,
  file descriptors) — comment why it's safe in this case.
- Files ≤ 800 lines, functions ≤ 50 lines (KISS principle from
  `CLAUDE.md`). If a file balloons past this, split.
- Vietnamese comments are OK in this project where they read more
  naturally than English. Code identifiers stay in English.

## Testing

- Unit tests: Swift Testing (`@Test`, `#expect`), not XCTest, for any
  new file. XCTest is allowed for files that already use it.
- Integration tests: `Scripts/verify-*.sh` for anything that exercises
  the running app, libghostty, the kernel, or shell IO.
- Coverage isn't enforced numerically but every public type should
  have at least one assertion.

## Filing issues

Use the templates under `.github/ISSUE_TEMPLATE/`. The bug template
prompts for:
- The diary excerpt (last ~30 lines of
  `~/Library/Application Support/herminal/diary.log`)
- Which day of dogfood you were on (per the journal under
  `docs/QA/dogfood/`)
- `Scripts/dogfood-daily.sh` output

Anything below P0 (data loss, crash on launch) is unlikely to land
during the MVP build window — it goes on the post-MVP backlog.

## License

By contributing you agree your contributions are licensed under the
MIT License (same as the project — see [`LICENSE`](LICENSE)).
