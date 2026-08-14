# Sprint 6 — Existing-feature completion

**Status:** in progress
**Scope:** close every code/documentation readiness issue that can be completed
without owner credentials or live keyboard interaction

## Work items

1. Issue #3 — add synthetic Codex direct/package-manager wrapper fixtures,
   malformed/unknown negatives, and classification tests without real argv.
2. Issue #5 — add a source-level diagnostics privacy guard with allowed and
   forbidden fixtures; remove current sensitive metadata logging; run it in CI.
3. Issue #6 — migrate `Package.swift` from `swiftLanguageVersions` to
   `swiftLanguageModes` without changing Swift 6 or macOS 14 requirements.
4. Issue #7 — add a sub-800-word lifecycle-signal architecture tour with real
   source/symbol links, privacy/MainActor boundaries, and fixture-test location.
5. Re-run full CI and CodeQL, review the diff, then close only issues whose
   acceptance criteria have objective evidence.

## Manual-only gates

- Issue #2: real Telex/VNI T1–T7 keyboard run.
- Issue #4: one-at-a-time entitlement removal on signed/notarized-style builds.
- Issue #13: owner-held Developer ID/notary credentials and clean installation.

These gates must remain open. Automation may prepare commands/checklists but
must not fabricate a passing result or weaken release requirements.

## Verification

```bash
Scripts/check-diagnostics-privacy.py
swift package dump-package
swift test --filter HerminalAgentTests
swift test
Scripts/verify-release-guards.sh
actionlint
git diff --check
```

## Exit criteria

- Issues #3, #5, #6, and #7 are closed with commit/CI evidence.
- No diagnostic call logs forbidden raw metadata unless OSLog marks the exact
  interpolation private.
- Codex fixture tests contain only synthetic generic values.
- Full CI is green; manual-only issues remain explicitly blocked and truthful.
