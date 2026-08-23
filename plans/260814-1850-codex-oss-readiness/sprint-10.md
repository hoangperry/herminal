# Sprint 10 — Gate Verifiers and External Evidence

**Status:** in progress
**Priority:** P1 — highest-leverage next move
**Effort:** 2–3 maintainer hours plus 7–14 calendar days
**Depends on:** public `v1.0.0`, issues #2 and #13, contributor-ready QA checklist

## Decision

Stop feature work. Do not submit the Codex for Open Source application yet.
The next bottleneck is independent human evidence, not code quality or release
machinery. PR #33 is already closed as superseded by `#32` / `485c9f9`, so
there is no open PR coordination issue.

Use a two-wave funnel:

1. **Gate-verifier wave:** obtain clean install and full Telex/VNI T1–T7 proof.
2. **Three-day beta wave:** obtain real-workflow reports and one genuine external
   contribution.

Gate verifiers are not automatically counted as completed beta testers. One
person counts once per metric. Stars, downloads, and bot PRs are never treated
as adoption.

## Current checkpoint — 2026-08-20

| Signal | State |
|---|---|
| Main branch snapshot | `0389e22` on 2026-08-20 |
| Public release | `v1.0.0`, signed/notarized/stapled |
| Install paths | DMG + audited Homebrew cask |
| Release provenance | checksums + deterministic dependency manifest |
| CI/security | green at `10f6b13` (CI `32184735881`; Security `32184736405`) |
| Repository interest | 52 stars, 2 forks; supporting signal only |
| Open issues | `#2`, `#13` (blocking); `#36` (optional evidence only) |
| Open PRs | none — `#33` closed as superseded by `#32` / `485c9f9` |
| Clean-account install | Missing — issue #13 |
| Complete live Telex/VNI matrix | Missing — issue #2 |
| Verified installs / 3-day testers | 0 / 0 |
| External reports / contributions | 0 / 0 |

Issue #36 can run in parallel as CJK compatibility evidence. It does not
replace #2 or #13 and it does not gate the application.

## Phase 0 — Repository hygiene and outreach packet

**Timebox:** 30 minutes

1. Record the current `main` SHA, confirm the latest green CI/security evidence,
   and verify the public issue set before outreach. The dated checkpoint above
   used `0389e22` and CI/security evidence pinned to `10f6b13`.
2. Prepare one link packet only:
   - release: <https://github.com/hoangperry/herminal/releases/tag/v1.0.0>
   - IME gate: <https://github.com/hoangperry/herminal/issues/2>
   - clean install gate: <https://github.com/hoangperry/herminal/issues/13>
   - beta expectations: [`docs/BETA.md`](../../docs/BETA.md)
3. Ask for testing, not stars, praise, testimonials, or public identity.

### Success criteria

- No unexplained conflicting PR is presented to prospective contributors.
- A tester can understand the task from public links without private setup help.

## Phase 1 — Gate-verifier wave

**Timebox:** 48 hours

Recruit 3–5 warm, relevant contacts individually. Target at least two completed
verifications; the same person may run both gates but still counts as one person.

### Verifier A — clean install

Use issue #13 acceptance exactly:

- clean macOS account or separate Apple Silicon Mac;
- public DMG checksum verification, normal Gatekeeper prompt, app + PTY launch;
- Homebrew cask install and launch;
- privacy-safe result: date, macOS version, route, pass/fail only.

Close #13 only when both public paths have dated evidence. Any checksum,
Gatekeeper, launch, or PTY failure pauses recruitment and becomes P0/P1 work.

### Verifier B — Vietnamese IME

Use issue #2 and `docs/QA/vietnamese-ime-checklist.md`:

- Apple Telex and VNI;
- T1–T7, including Shift-Tab, US-input Tab, and rapid repetition;
- bounded PREEDIT/COMMIT/DROP/DUP/CURSOR defect classes;
- generated result under `docs/QA/results/` or privacy-safe issue matrix.

Close #2 only when T1/T2/T5/T6/T7 pass with no DROP/DUP. Any DROP/DUP failure
stops beta expansion and requires a tested patch.

### Optional parallel evidence — issue #36

If a reviewer already has the app open, collect a bounded CJK compatibility
note for issue #36 in parallel. Treat it as supporting evidence only; it does
not gate #2/#13 or application readiness.

### Outreach copy

> Herminal v1 is signed and public. I need a 10–15 minute independent macOS
> verification, not a star or testimonial. The test records only version,
> macOS/input source, and pass/fail cases—never terminal history. Would you be
> willing to run either the clean-install check or the Telex/VNI T1–T7 matrix?

### Success criteria

- #13 closed with dated clean-environment evidence.
- #2 closed with dated complete T1–T7 evidence.
- At least one result is externally authored or submitted as a small PR.

## Phase 2 — Three-day beta wave

**Entry gate:** no unresolved install, Gatekeeper, DROP, DUP, data-loss, or
command-execution defect from Phase 1.

**Timebox:** days 2–10

1. Invite 10–15 relevant candidates; optimize for five completions:
   - Vietnamese Telex/VNI users;
   - daily Codex/Claude Code/Aider users;
   - one tmux/SSH-heavy user;
   - one Swift/macOS contributor.
2. Ask each participant to install from a public path and use Herminal on one
   real repository for three days where possible.
3. Route feedback through the beta issue form. Never request repository names,
   prompts, terminal output, tokens, SSH details, or note contents.
4. Triage P0/P1 within 48 hours and other reports within seven days.
5. Reproduce before fixing. Add a regression or bounded manual case for every
   accepted defect.
6. Ship a patch release only when findings justify one. Do not create empty
   releases to satisfy an application metric.
7. Update `docs/BETA.md` only from dated public evidence or a reviewed,
   privacy-preserving opt-in record.

### Success criteria

- 10 independently verified installs.
- 5 completed three-day testers.
- 3 externally authored reports.
- 1 external contribution: result PR, docs, fixture, repro, or code.
- Zero unresolved P0/P1 defects.

## Phase 3 — Maintenance evidence and application gate

**Timebox:** days 7–14, only as real reports arrive

For each genuine report where Codex materially assists maintenance, record:

- public issue/PR link;
- task Codex assisted with;
- human decision boundary;
- validation commands and result;
- corrections made to agent output;
- no private prompts, tester data, terminal content, or credentials.

After the beta window:

1. Refresh the evidence matrix in
   `docs/community/codex-for-oss-application.md`.
2. Count only public, human-reviewed maintenance examples.
3. Red-team the application only when mandatory gates and external evidence are
   non-zero.
4. Submit only when every claim has a dated source. Otherwise schedule another
   evidence window, not another speculative feature sprint.

## Daily operator checklist

| Day | Action | Evidence |
|---|---|---|
| 0 | Send 3–5 gate requests using the latest evidence packet | Links sent; no private data stored |
| 1–2 | Support #2/#13 verifiers; triage failures | Issue comment or result PR |
| 2 | Go/no-go for wider beta | Both critical gates pass; no P0/P1 |
| 2–5 | Invite beta cohort; acknowledge reports | Beta issue links |
| 5–10 | Reproduce and fix accepted defects | Tests, PRs, CI runs |
| 10–14 | Confirm 3-day completions; refresh ledger | Dated evidence rows |
| 14 | Application gate review | Submit / extend / stop decision |

## Stop and pivot rules

- **No gate volunteer after 48 hours:** broaden direct outreach to Vietnamese
  macOS and Swift communities. Do not add features as compensation.
- **Clean install fails:** stop promotion; fix distribution first.
- **IME DROP/DUP fails:** stop promotion; treat as data-loss severity.
- **No beta completion:** extend recruitment; do not infer use from downloads.
- **No actionable bugs:** publish no artificial patch release.
- **No external contribution:** keep #2 and bounded docs/fixture tasks visible;
  do not manufacture activity.

## Not in scope

- New terminal features or UI redesign.
- Official Codex adapter work without user demand.
- Paid promotion, star exchanges, giveaways, or automated outreach.
- Telemetry, email collection, or private tester databases.
- Application submission before evidence gates pass.

## Definition of done

Sprint 10 completes when #2 and #13 have independent dated evidence, the beta
ledger records real external use, accepted defects have visible maintenance
outcomes, and the Codex application can be evaluated from public sources without
inflated claims.
