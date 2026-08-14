# Sprint 4 — Closed beta and feedback releases

**Status:** planned
**Depends on:** PR #1 merged, installable signed build, live Telex/VNI gate

## Goal

Obtain real external usage evidence and turn feedback into visible maintenance work without telemetry, fake activity, or requests for stars.

## Entry gates

- CI full build and tests green.
- CodeQL completed or documented as unavailable.
- Telex/VNI T1/T2/T5/T6/T7 pass on a real macOS input source.
- Signed/notarized build installs through DMG and Homebrew.
- No open P0 security/data-loss issue.

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

## Exit criteria

- No unresolved P0/P1 install, input, data-loss, or command-execution defect.
- Evidence table has dates and public links where consent allows.
- Sprint 5 launch/application plan is regenerated from actual beta findings.
