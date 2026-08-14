# Herminal closed beta

The beta validates whether Herminal works as a real terminal for Vietnamese macOS developers using coding agents. It is not a star campaign.

## Entry status

Engineering gates are green: CI build, 153 tests, and targeted CodeQL. Distribution begins only after the live Telex/VNI marked-text checklist and signed/notarized build pass.

## Current distribution blockers

- Real Telex/VNI marked-text cases still require human keyboard verification via `Scripts/record-vietnamese-ime-gate.sh`.
- Repository Actions secrets are not configured for Developer ID/notarization; `Scripts/check-release-readiness.sh` verifies local prerequisites without printing their values.
- A local Developer ID identity is visible, but non-interactive signing currently returns `errSecInternalComponent`; no notarytool profile is configured. Credential repair stays an owner-only action and no password/key material belongs in the repository.

## Tester commitment

- Install through the supplied signed DMG or Homebrew cask.
- Use Herminal on a real workflow for at least three days where possible.
- Exercise normal shell work, preferred Vietnamese input source, and one supported agent CLI.
- Submit the privacy-safe beta issue form.
- Do not share terminal history, prompts, repository/client names, tokens, SSH details, or note contents.

Stars, testimonials, and public identity are never required. Quotes or adopter attribution require separate explicit consent.

## Maintainer commitment

- Triage P0/P1 reports within 48 hours and others within seven days.
- Reproduce before fixing.
- Add a regression test or manual checklist case.
- Publish small patch releases linked to accepted reports.
- Collect no in-app telemetry.

## Evidence ledger

Counts must link to public evidence or a privacy-preserving opt-in record. One person counts once per metric.

| Date | Evidence | Count | Public link/verification | Notes |
|---|---|---:|---|---|
| 2026-08-14 | CI full suite | 153 tests | GitHub Actions run 31822247206 | Green; includes manifest and diagnostics guards |
| 2026-08-14 | CodeQL | 1 run | GitHub Actions run 31822247125 | DB + Agent targets |
| 2026-08-14 | CI artifact local launch | 1 smoke | PR #1 / CI run 31814582438 | Signature structure verified; version 1.0.0 build 23; launched without immediate crash |
| — | Verified installs | 0 | — | Target 10 |
| — | Completed 3-day testers | 0 | — | Target 5 |
| — | External beta reports | 0 | — | Target 3 |
| — | External contributions | 0 | — | Target 1 |
| — | Feedback-driven releases | 0 | — | Target 2 when justified |

GitHub download counts are supporting evidence, not proof of active use. Never infer completed testers from downloads or stars.
