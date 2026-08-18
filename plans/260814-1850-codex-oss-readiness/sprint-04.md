# Sprint 4 — Closed beta and feedback releases

**Status:** in progress — signed v1 is public; Sprint 10 gate-verifier recruitment is the next move
**Depends on:** Sprint 10 Phase 1 before broad three-day beta recruitment

## Goal

Obtain real external usage evidence and turn feedback into visible maintenance work without telemetry, fake activity, or requests for stars.

## Entry gates

The narrow gate-verifier wave may start now using the signed public release.
Broad three-day beta recruitment starts only after:

- CI and CodeQL are green;
- Telex/VNI T1/T2/T5/T6/T7 pass on a real macOS input source;
- a clean account verifies both public DMG and Homebrew installation;
- no P0/P1 security, install, data-loss, or command-execution issue is open.

## Tasks

1. Publish a beta intake form that asks only workflow, macOS/hardware, shell,
   input source, agent CLI, install result, and consent for follow-up.
2. Recruit 10–15 relevant testers; do not request stars or public praise.
3. Require at least five testers to use Herminal on a real repository for 3+ days.
4. Collect reports through GitHub issues or a privacy-reviewed structured form.
5. Triage within 48 hours using `docs/TRIAGE.md`.
6. Reproduce before fixing and add a regression guard for every accepted bug.
7. Ship small patch releases linked to feedback; avoid a speculative feature wave.
8. Track only public release download counts, opt-in tester completion, issues,
   contributions, and patch releases—no in-app telemetry.

## Evidence targets

- 10 independently verified installs.
- 5 completed three-day testers.
- 3 externally authored reports/issues.
- 1 external contribution of code, docs, fixture, translation, or repro.
- 2 feedback-driven patch releases when findings justify them.

## Progress

- Added privacy-safe beta issue form and labels.
- Added `docs/BETA.md` with tester/maintainer commitments and evidence ledger.
- Recorded green CI (220 tests) and CodeQL evidence.
- Published signed/notarized/stapled `v1.0.0`, audited Homebrew cask, checksums,
  and deterministic dependency provenance.
- Made issues #2/#13 and the IME checklist contributor-ready.
- Added [Sprint 10](sprint-10.md) to break the gate/recruitment deadlock with a
  verifier-first wave.

## Exit criteria

- No unresolved P0/P1 install, input, data-loss, or command-execution defect.
- Evidence table has dates and public links where consent allows.
- Sprint 5 launch/application plan is regenerated from actual beta findings.
