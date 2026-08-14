# Codex for Open Source application — working draft

> **NOT READY TO SUBMIT.** Herminal has no public v1 release or qualifying
> external beta evidence yet. This document is a claim checklist, not a claim
> that the project has been accepted or meets current program criteria. Recheck
> the official application form and terms immediately before submission.

## Project

- Repository: <https://github.com/hoangperry/herminal>
- License: MIT
- Maintainer: `hoangperry` — repository owner with write access
- Pitch: A local-first native macOS terminal focused on Vietnamese input and
  privacy-minimized visibility into local coding-agent sessions.
- Current public release: `v0.4.2`
- Current development state: `v1.0.0` release candidate on `main`

Herminal combines libghostty with a Swift/AppKit interface, an
`NSTextInputClient` bridge, local SQLite notes and SSH host metadata, and a
process-signal agent dashboard. It targets Vietnamese macOS developers whose
terminal and coding-agent workflows are poorly represented by generic terminal
feature sets.

## Why Codex would support core maintenance

Subject to maintainer review, Codex can assist with:

1. reproducing public compatibility and input bugs and proposing regression
   tests;
2. reviewing PRs against `docs/ARCHITECTURE.md`, `docs/THREAT-MODEL.md`, and
   `docs/MAINTAINER-AI-POLICY.md`;
3. maintaining agent-detection fixtures without collecting terminal content;
4. checking cross-version release docs, checksums, and dependency manifests;
5. triaging public CI failures and dependency updates.

Codex does not approve merges, receive signing credentials, inspect private
terminal content, or publish releases. Those boundaries are documented in the
maintainer AI policy.

## Why security review is relevant

Herminal crosses shell/PTY, process inspection, SSH metadata, clipboard/IME,
local persistence, vendored terminal engine, and signed-update boundaries. The
public [threat model](../THREAT-MODEL.md) and
[security policy](../../SECURITY.md) identify command execution, sensitive
metadata leakage, malicious local files, and supply-chain compromise as real
maintenance concerns. Any request for security tooling should map to findings
on these surfaces, not generic interest in security.

## Public evidence matrix

No row may be marked ready without a dated public source.

| Claim | Required source | Current evidence | Ready? |
|---|---|---|---|
| Maintainer/write access | Repository ownership | Public repository owner | Yes |
| CI health | GitHub Actions run | 189-test run `31828682778` | Yes |
| Security scanning | GitHub Actions run | CodeQL run `31828682659` | Yes |
| Release supply chain | Workflow + owner-gate record | Candidate run `31830331678`; notarization/DMG evidence in `docs/QA/results/release-candidate-2026-08-15.md` | Partial — final clean install pending |
| Public v1 install | Release + DMG/Homebrew/Gatekeeper verification | Missing | No |
| Live Telex/VNI completion | Dated checklist result linked from issue #2 | Missing | No |
| Verified installs | Privacy-safe beta ledger | 0 | No |
| Completed 3-day testers | Opt-in completion records | 0 | No |
| External reports | Externally authored public links | 0 | No |
| External contribution | PR/docs/fixture/repro link | 0 | No |
| Feedback releases | Release notes linked to reports | 0 | No |
| Codex maintenance examples | Issue/PR records using policy template | 0 | No |

The beta ledger is in [`docs/BETA.md`](../BETA.md). Downloads, stars, and bot PRs
do not satisfy tester or contributor counts.

## Six-month use plan

- Months 1–2: issue reproduction, compatibility tests, documentation, and
  human-reviewed PR analysis.
- Months 3–4: privacy-safe agent signal fixtures and remediation of public
  security backlog items.
- Months 5–6: dependency/release maintenance, contributor support, and
  feedback-driven compatibility work.

API credits should be requested only if a public automation is actually planned
and reviewed. Interactive maintainer use alone is not evidence that Herminal
needs an API integration.

## Current limitations to disclose

- Public latest release is still `v0.4.2`.
- v1 distribution is blocked on live Telex/VNI verification and owner-held
  signing/notarization setup.
- Current agent status is heuristic process/CPU/bell signaling; no official
  Codex lifecycle adapter is claimed.
- No verified external adoption or contribution evidence exists yet.
- Herminal is Apple Silicon/macOS focused and maintained primarily by one owner.

## Final red-team gate

Before submission, answer **yes** with a source for each item:

- Can every adoption and impact statement be verified publicly?
- Does the current release install without bypassing Gatekeeper?
- Is Vietnamese completion verified with real Telex and VNI input sources?
- Are at least three Codex maintenance examples public and human-reviewed?
- Is requested security access tied to concrete threat-model work?
- Are private data, credentials, tester identities, and unverifiable estimates
  absent?
- Has the maintainer rechecked the current official program requirements?

If any required answer is no, continue public maintenance instead of submitting
or weakening the truth standard.
