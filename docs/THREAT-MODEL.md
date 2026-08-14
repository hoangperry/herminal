# Herminal threat model

**Status:** living document
**Last reviewed:** 2026-08-14

Herminal is a local, non-sandboxed macOS terminal. It intentionally launches the user's shell and arbitrary user-selected commands. Its security goal is not to make untrusted shell commands safe; it is to avoid adding unintended execution, disclosure, persistence, or update paths around normal terminal use.

## Security properties

Herminal must:

- never execute a command merely because untrusted text was displayed;
- preserve the distinction between IME preedit and committed PTY input;
- never log terminal contents, shell arguments, credentials, or note bodies;
- treat workspace, SSH config, and local database files as untrusted input;
- require explicit user intent for destructive UI actions and command replay;
- accept distributed binaries only through Developer ID, notarization, and verifiable release artifacts;
- remain usable when agent detection, metadata parsing, or update checks fail.

Herminal does not protect users from commands they intentionally run, malicious shell startup files, compromised macOS accounts, or vulnerabilities inside upstream libghostty.

## Assets

| Asset | Sensitivity | Storage/use |
|---|---|---|
| Shell/PTY input and output | High | Memory and terminal renderer; must not enter diagnostics |
| Process arguments/environment | High | Read locally for agent detection; may contain tokens |
| SSH host metadata | Medium | Local SQLite; no private key material should be copied |
| Session notes | High | Local SQLite and explicit Markdown exports |
| Workspace layout and replay commands | High | Local JSON; replay is opt-in |
| Clipboard and IME composition | High | AppKit/libghostty input boundary |
| Signing/notary/Sparkle keys | Critical | Owner keychain or CI secrets only |
| Release artifacts and checksums | Integrity-critical | GitHub Releases/Homebrew |
| Crash diary | Medium | Local lifecycle metadata, redacted on export |

## Trust boundaries

1. **Keyboard/IME → `HerminalSurfaceView` → libghostty → PTY.** Marked text is not committed input. Control keys must not be silently dropped or duplicated when composition ends.
2. **Repository/shell output → terminal renderer.** Displayed bytes are untrusted and must not trigger host actions except intentionally supported terminal protocols with explicit policy.
3. **Local files → decoders/parsers.** Workspace JSON, SSH config, SQLite files, and imported Markdown can be malformed or attacker-controlled.
4. **Process table → agent dashboard.** Process names and argv are untrusted and potentially secret-bearing.
5. **Herminal UI → command spawn.** SSH connections, session resumes, restored commands, and agent/worktree launches cross into arbitrary code execution. Worktree branch names are validated and git is invoked as argv (never a shell string). Spawned agent commands are a fixed whitelist (`claude` / `codex` / `aider` / `lazygit`).
6. **Source/dependencies → CI → signed artifact → GitHub/Homebrew → user.** A compromise anywhere in this chain can ship executable code.
7. **Test harness environment → production binary.** `HERMINAL_TEST_*` controls must not become an arbitrary production write/execute interface.

## Threats and controls

### T1 — Unintended command execution from displayed or composed text

**Paths:** IME callbacks, paste, OSC sequences, clickable URLs, agent output.

**Controls:**

- `NSTextInputClient` keeps marked text in libghostty preedit until commit.
- Tab-after-preedit handling emits committed text once, then replays the control key separately.
- Harness text injection is gated by AppDelegate test-mode controls.
- Clipboard paste follows libghostty's paste path and bracketed-paste behavior.
- URL actions require an explicit user interaction.

**Residual risk:** terminal escape-sequence handling is largely upstream libghostty code. Track upstream security releases and keep the submodule pinned to a reviewed commit.

### T2 — Command injection through SSH or restored sessions

**Paths:** imported SSH aliases/hostnames/users, persisted spawn commands, hand-edited workspace JSON.

**Controls:**

- SSH config import ignores `ProxyCommand`, `Match`, wildcard-only targets, and private key content.
- UI command construction must reject control characters and shell metacharacter ambiguity or avoid shell parsing entirely.
- Restored command replay is opt-in and persisted commands are validated before spawn.
- Layout-only restore remains the default.

**Required follow-up:** maintain regression tests for newline/control-character input and verify SSH spawn uses an argument-safe boundary.

### T3 — Secret exposure through agent detection or diagnostics

**Paths:** `KERN_PROCARGS2`, logs, crash diary, bug-report exports.

**Controls:**

- Agent detection reads argv only for known interpreter processes and uses it only for local classification.
- UI shows vendor/display classification, not raw argv.
- Diary records category-tagged lifecycle events, not terminal content.
- `Diary.exportRedacted()` rewrites user paths and surface addresses.

**Required follow-up:** regression-test that raw argv and environment values never reach Diary or exported diagnostics. Avoid adding prompt/output snippets to agent events.

### T4 — Local data disclosure or corruption

**Paths:** notes/SSH SQLite databases, workspace JSON, Markdown export.

**Controls:**

- Data remains local; there is no account, sync, analytics, or upload service.
- SQLite uses WAL and parameterized APIs.
- Workspace decoding has an explicit nesting-depth guard and sanitization.
- Note export is user initiated.
- FileVault/macOS account protection is the encryption baseline.

**Residual risk:** a process running as the same macOS user can read local files. Herminal does not claim application-level encryption.

### T5 — Test hooks abused in production

**Paths:** `HERMINAL_TEST_*` environment variables and GUI harness actions.

**Controls:**

- Trigger paths are centrally gated in AppDelegate.
- Test inputs must use bounded formats and fixed/validated paths.
- Release verification must ensure test mode is inactive without explicit harness setup.

**Required follow-up:** enumerate every `HERMINAL_TEST_*` variable in one document/test and reject arbitrary output paths.

### T6 — Malicious or corrupted workspace causes denial of service

**Paths:** deeply nested or oversized JSON, invalid pane ratios, stale process metadata.

**Controls:**

- `JSONDepthGuard` checks nesting before decoding.
- Workspace sanitization bounds layout values and unsafe replay commands.
- Corrupt state should fall back to a clean workspace instead of boot-looping.

**Residual risk:** size bounds and fuzz/property tests should evolve with the file format.

### T7 — Dependency or CI supply-chain compromise

**Paths:** SQLite.swift, libghostty submodule, GitHub Actions, Homebrew/Zig tool installation.

**Controls:**

- `Package.resolved` pins Swift dependencies.
- libghostty is a git submodule pinned to a commit.
- CI builds from source and release signing uses ephemeral keychain material.
- Release jobs have only `contents: write` permission.

**Required follow-up:**

- Dependabot for grouped minor/patch Action updates;
- maintainer review of `Package.resolved` updates (Swift Dependabot cannot parse the local GhosttyKit binary target);
- pin Actions to reviewed commit SHAs;
- document libghostty update/review procedure;
- generate dependency manifest/SBOM and checksums for every release;
- avoid unpinned build tools in release jobs.

### T8 — Compromised release or update channel

**Paths:** GitHub Actions secrets, Developer ID certificate, notary credentials, GitHub release replacement, Homebrew checksum, future Sparkle key.

**Controls:**

- Developer ID signing, hardened runtime, notarization, and stapling.
- Certificate imported into an ephemeral CI keychain and removed with the runner.
- Releases are drafted before public publication.
- Homebrew verifies SHA-256.
- Sparkle remains disabled until EdDSA signing is designed and tested.

**Required follow-up:** upload SHA-256 manifest and provenance/SBOM; protect release environments with owner approval; never allow an ad-hoc build to become a public stable release.

### T9 — Over-broad hardened-runtime exceptions

Herminal currently requests unsigned executable memory, JIT, DYLD environment variables, and disabled library validation for libghostty/shell integration. These increase impact if the app process is compromised.

**Control:** exceptions are explicit in `App/herminal.entitlements` and the app is not presented as sandboxed.

**Required follow-up:** validate each entitlement against the current libghostty build and remove any exception that is no longer necessary.

## Security review checklist

Every PR touching input, command spawn, persistence, diagnostics, dependencies, or release automation must answer:

1. What untrusted data enters?
2. Can it execute, write a path, open a URL, or persist?
3. Could it contain terminal text, argv, credentials, or notes?
4. Is behavior bounded under malformed/oversized input?
5. What test fails before the fix and passes afterward?
6. Does the release or permission model change?

## Incident response

Follow `SECURITY.md`. Do not open a public issue before coordinated disclosure. For a suspected release compromise, immediately unpublish affected artifacts, revoke/rotate exposed credentials, document affected hashes and versions, publish a clean signed replacement, and notify users through GitHub Releases and the Homebrew tap.

## Review cadence

Review this document for every public minor release and whenever Herminal adds a new network path, agent integration, updater, command source, entitlement, or persistent data type.
