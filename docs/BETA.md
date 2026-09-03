# Herminal closed beta

The beta validates whether Herminal works as a real terminal for Vietnamese macOS developers using coding agents. It is not a star campaign.

## Entry status

Engineering gates are green and signed, notarized `v1.0.0` artifacts are public. Beta recruitment can begin through the direct DMG while the live Telex/VNI evidence and final Homebrew/clean-install checks are completed.

## Current distribution follow-ups

- Real Telex/VNI marked-text cases still require human keyboard verification via `Scripts/record-vietnamese-ime-gate.sh`.
- The public Homebrew tap now targets `v1.0.0` and passes online cask audit.
- A clean-account install should still confirm both Homebrew and the published DMG without exposing local paths, credentials, or terminal content.

## Tester commitment

- Install through the supplied signed DMG or Homebrew cask.
- Use Herminal on a real workflow for at least three days where possible.
- Exercise normal shell work, preferred Vietnamese input source, and one supported agent CLI.
- In herminal, choose **Help > Open Beta Feedback Form…** and submit the privacy-safe beta issue form.
- Do not share terminal history, prompts, process arguments, tokens, SSH configuration, hostnames, repository names, or note contents; use placeholders in reproductions.

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
| 2026-08-17 | CI full suite | 216 tests | GitHub Actions run 32021988126 | Green on post-v1 `main` |
| 2026-08-17 | CodeQL | 1 run | GitHub Actions run 32021988108 | Green on post-v1 `main` |
| 2026-08-17 | Public v1 release | 1 release | [`v1.0.0`](https://github.com/hoangperry/herminal/releases/tag/v1.0.0) | Signed, notarized, stapled DMG + ZIP + SHA256SUMS published |
| 2026-08-17 | Homebrew v1 cask | 1 tap | [`hoangperry/homebrew-herminal`](https://github.com/hoangperry/homebrew-herminal) | v1.0.0 URL/checksum verified by online cask audit |
| 2026-08-15 | Release candidate | 1 run | GitHub Actions run 31830331678 + local owner gate | Checksums, Developer ID, notarization, staple, Gatekeeper, signed DMG passed before publication |
| 2026-08-14 | CI artifact local launch | 1 smoke | PR #1 / CI run 31814582438 | Signature structure verified; version 1.0.0 build 23; launched without immediate crash |
| — | Verified installs | 0 | — | Target 10 |
| — | Completed 3-day testers | 0 | — | Target 5 |
| — | External beta reports | 0 | — | Target 3 |
| — | External contributions | 0 | — | Target 1 |
| — | Feedback-driven releases | 0 | — | Target 2 when justified |

GitHub download counts are supporting evidence, not proof of active use. Never infer completed testers from downloads or stars.
