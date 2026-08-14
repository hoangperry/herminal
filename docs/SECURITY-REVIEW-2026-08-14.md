# Security review — 2026-08-14

## Scope

Terminal/IME input, command spawn and restore, SSH import, diagnostics, workspace persistence, dependencies, CI, and release distribution.

## Closed findings

- Removed raw command, Claude session, SSH user/host, and public error details from diagnostics.
- Bounded file-backed SSH config import to 1 MiB and added a regression test.
- Enabled GitHub private vulnerability reporting and linked it from `SECURITY.md`.
- Added a code-grounded threat model.
- Pinned third-party Actions to reviewed commit SHAs and enabled Dependabot.
- Added verified Zig download/checksum for CI.
- Repaired previously nonfunctional full CI; build and 152 tests pass on run `31812947567`.
- Added CodeQL for independently analyzable DB/agent targets; runs `31812947548` and `31814582462` pass.
- Added release SHA-256/dependency manifests and made missing signing/notary credentials fatal.
- Made the local release driver fail closed, replaced whitespace-sensitive notary JSON parsing, verified post-staple Gatekeeper state, and package the stapled app—not the pre-staple submission ZIP—as the final workflow asset.

## Accepted or deferred risks

- App/Core CodeQL extraction cannot import prebuilt GhosttyKit under CodeQL's DYLD tracer. Full App/Core compilation and tests remain mandatory CI; CodeQL covers HerminalDB and HerminalAgent.
- Hardened-runtime exceptions require signed-build experiments one at a time; tracked publicly in issue #4.
- Live Telex/VNI behavior cannot be automated reliably; tracked in issue #2 and remains a release gate.
- Herminal cannot defend against commands the user intentionally executes or same-user malware reading local files.

## Verdict

No known P0 issue in the reviewed change set. Merge remains gated on latest CI/Security checks and maintainer review. Public v1 additionally requires live IME verification and signed/notarized release verification.
