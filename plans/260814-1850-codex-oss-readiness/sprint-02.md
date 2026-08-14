# Sprint 2 — Security and supply-chain hardening

**Status:** complete
**Depends on:** Sprint 1 implementation; may proceed while live IME verification is owner-blocked

## Goal

Make Herminal's security posture credible for a terminal that executes shells, opens SSH sessions, observes agent processes, stores local notes, and distributes signed binaries.

## Progress

Completed in first pass:

- Added code-grounded `docs/THREAT-MODEL.md`.
- Enabled and verified GitHub private vulnerability reporting.
- Updated `SECURITY.md` to use the private advisory path.
- Added grouped minor/patch Dependabot updates for GitHub Actions. Swift updates remain manual because Dependabot cannot parse the local GhosttyKit binary target.
- Pinned all third-party Actions in CI, Pages, and Release workflows to reviewed commit SHAs.
- Added a pinned CodeQL Swift workflow (execution still requires CI verification).
- Added release SHA-256 and dependency-manifest generation/upload.

Completed afterward: diagnostics minimization, bounded SSH imports + regression,
verified Zig installation, release hard-fail on missing signing/notary secrets,
full CI (152 tests, run `31812947567`), targeted CodeQL (run `31812947548`),
and `docs/SECURITY-REVIEW-2026-08-14.md`. The entitlement experiment is
correctly deferred as public issue #4 because it requires signed runtime tests.

## Deliverables

1. `docs/THREAT-MODEL.md` grounded in actual code and trust boundaries.
2. GitHub private vulnerability reporting enabled and `SECURITY.md` updated.
3. Dependabot coverage for GitHub Actions plus a documented manual SwiftPM update policy.
4. CodeQL Swift workflow if it works with the supported macOS runner; otherwise a documented replacement.
5. Third-party GitHub Actions pinned to reviewed commit SHAs.
6. Release SHA-256 manifest and SBOM/dependency manifest uploaded with draft releases.
7. Tests/guards for command construction, SSH import bounds, diagnostics redaction, workspace JSON depth, and test-only environment paths.
8. Security review report with unresolved risks and owner gates.

## Order

1. Map assets, boundaries, and existing controls.
2. Write threat model before changing controls.
3. Harden CI/dependencies and release provenance.
4. Add regression guards for confirmed code-level risks only.
5. Run narrow tests and full suite when Xcode is available.
6. Update the parent plan and generate Sprint 3 from evidence.

## Exit criteria

- Every documented mitigation links to code, workflow, or an explicit owner action.
- Private reporting path is verified.
- Security workflows run rather than merely displaying badges.
- Release artifacts can be checked independently.
- No terminal content, process argv secrets, SSH credentials, or signing material is uploaded.
