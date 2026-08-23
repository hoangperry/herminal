---
title: Herminal Codex for Open Source readiness
status: in_progress
owner: hoangperry
created: 2026-08-14
targetWindow: 8 weeks
blockedBy: []
blocks: []
---

# Herminal — Codex for Open Source Readiness Plan

## Progress

| Sprint | Scope | Status |
|---|---|---|
| Sprint 1 | Phase 0: IME Tab blocker + release truth | In progress — public signed/notarized v1 and Homebrew cask are live; blocked only on dated live Telex/VNI and clean-account install evidence |
| Sprint 2 | Phase 1: security and supply-chain hardening | Complete — dated CI/CodeQL evidence recorded in Sprint 2; entitlement audit complete |
| Sprint 3 | Phase 2–3: agent interoperability + contributor surface | Complete — neutral event boundary, official hooks research, contributor fast path, triage policy, and issues #2–#7 |
| Sprint 4 | Phase 4: closed beta and feedback releases | In progress — signed v1 distribution and intake/privacy/evidence infrastructure are ready; recruitment can begin while live IME evidence is completed |
| Sprint 5 | Phase 5–7: launch evidence + application | In progress — maintainer AI policy and truth-gated application skeleton ready; evidence/submission blocked on Sprint 4 |
| Sprint 6 | Existing-feature completion | Complete for automatable scope — issues #3/#5/#6/#7 closed with dated CI/CodeQL evidence; owner gates #2/#13 remain |
| Sprint 7 | Owner-gate automation | Tooling complete — privacy-safe IME recorder, entitlement experiment, and signing readiness preflight ready; owner execution pending |
| Sprint 8 | Agent worktree cockpit | Complete — isolated worktrees, whitelisted agent/lazygit launch, pane focus, off-main bounded git runner; CI + CodeQL green |
| Sprint 9 | Remote release build, local signing | Public v1 shipped — read-only build, local Developer ID/notarization/staple/Gatekeeper, release assets, checksums, deterministic dependency manifest, and audited Homebrew cask complete; clean-account install pending |
| Sprint 10 | Gate verifiers and external evidence | In progress — stop feature work; close #2/#13 with independent evidence, then run a bounded three-day beta; keep #36 optional |

## 1. Objective

Turn Herminal from a technically polished solo project into a credible, actively maintained public OSS project with real external users, public maintenance evidence, a defensible security posture, and a truthful Codex for Open Source application.

Official program fit to demonstrate:

- Applicant is a core maintainer with write access.
- Repository is public and serves a meaningful ecosystem role.
- Codex will support day-to-day coding, triage, review, release automation, and other core OSS maintenance.
- Codex Security has a concrete purpose on a terminal with shell, SSH, hooks, local data, and software-update surfaces.

This plan does **not** assume any star threshold and does not guarantee acceptance.

## 2. Starting baseline (verified 2026-08-14)

Repository: `github.com/hoangperry/herminal`

Strengths:

- Original public MIT project; maintainer has write access.
- Native Swift/AppKit terminal using libghostty.
- Vietnamese IME support, agent dashboard, SSH manager, session notes.
- CI, signed/notarized release machinery, Homebrew cask, security policy.
- 143 unit tests plus dogfood checks documented in the v1 retrospective.
- Clear local-first/no-telemetry positioning.

Gaps and credibility risks:

- Public GitHub baseline is 0 stars, 0 forks, 0 open issues.
- Latest public release is `v0.4.2`; `v1.0.0` exists in code/docs but is not public.
- README says `v1.0.0 stable`, while the public release remains `v0.4.2`.
- `docs/ROADMAP.md` mixes old v0.1 owner gates with later v1 work.
- No external issue, PR, contributor, or tester evidence is visible.
- Agent detection is mostly process/CPU heuristic; Codex integration is not yet a strong public interoperability story.
- **Release-blocking Vietnamese UX bug:** pressing Tab while macOS Vietnamese IME still has underlined marked text drops the Tab instead of committing the preedit and invoking shell completion. This reproduces Ghostty behavior but not iTerm2 behavior and directly contradicts Herminal's Vietnamese-first promise.
- Security policy exists, but a public threat model, automated code scanning, release provenance, and explicit agent-specific trust boundaries are missing.

### Current checkpoint (verified 2026-08-20)

The starting gaps above are retained as historical context. Since then Herminal
has shipped signed/notarized `v1.0.0`, an audited Homebrew cask, CodeQL,
Dependabot, deterministic release provenance, contributor docs, and 52 stars /
2 forks. The latest green main CI/Security evidence is pinned to `10f6b13`.
The active blockers are now human evidence rather than another engineering
wave:

- issue #13: clean-account DMG and Homebrew installation;
- issue #2: complete visual Telex/VNI T1–T7 matrix;
- issue #36: optional CJK compatibility evidence only; not an application gate.
- 0 verified installs, completed three-day testers, external reports, or
  external contributions in the evidence ledger;
- 0 public, human-reviewed Codex maintenance examples.

Execution moves to [Sprint 10](sprint-10.md). Do not submit the application or
resume speculative feature work before its gate-verifier wave completes.

## 3. Success gates

Apply only when all truth/quality gates and most adoption gates are met.

### Mandatory truth and quality gates

- Public docs agree on the currently released version and actual shipped state.
- Vietnamese Telex/VNI composition can be committed with Tab and shell completion runs in the same keystroke, matching the expected iTerm2 workflow; Shift-Tab and non-IME Tab behavior do not regress.
- Latest public release installs through both DMG and Homebrew on a clean Mac.
- CI and release verification are green at the public release commit.
- Public threat model covers terminal, shell, SSH, agent detection, hooks/config, local storage, clipboard/IME, updater, and supply chain.
- Security reporting uses GitHub private vulnerability reporting or another verified private channel.
- No fabricated users, stars, issues, testimonials, downloads, or contribution activity.

### Internal adoption targets (not claimed as OpenAI requirements)

- At least 10 independently verified installations.
- At least 5 testers who use Herminal in a real workflow for 3+ days.
- At least 3 externally authored issues or structured beta reports.
- At least 1 external contribution: code, docs, test fixture, translation, or reproducible bug report.
- At least 2 public post-v1 maintenance releases driven by real feedback.
- A 30-day public activity trail showing triage, review, fixes, and releases.

### Application evidence gate

- Public roadmap and maintainer backlog exist.
- At least 3 concrete examples show how Codex was or will be used for maintenance.
- Requested Codex Security access maps to documented risks and planned remediation workflows.
- Application claims can all be linked to public evidence.

## 4. Scope boundaries

### In scope

- Release truth and documentation consistency.
- Security hardening and supply-chain visibility.
- Reliable Codex/agent observability inside Herminal.
- Contributor onboarding and maintainability.
- Ethical beta recruitment and public feedback loops.
- Evidence collection and application drafting.

### Out of scope until adoption proves demand

- A new `open-agent-events` standalone repository.
- Linux/Windows ports.
- Cloud sync, accounts, analytics, or terminal-content telemetry.
- An in-terminal chatbot.
- Plugin or theme marketplace.
- Features built only to inflate commit count.
- Paid promotion, star exchanges, fake accounts, or generated issues pretending to be community activity.

## 5. Workstreams and dependency graph

```text
P0 Truth audit + public v1 release
├── P1 Security and supply-chain hardening
├── P2 Agent interoperability foundation
└── P3 Contributor/community surface
    └── P4 Closed beta and feedback releases
        ├── P5 Public launch and adoption evidence
        └── P6 Maintainer automation evidence
            └── P7 Application package and submission
```

P1, P2, and P3 can run in parallel after P0. P4 requires the install path and docs from P0/P3. P7 requires measured evidence from P4–P6.

## 6. Phased implementation

## Phase 0 — Vietnamese Tab-completion blocker, truth audit, and public release baseline

**Duration:** 3–5 days  
**Priority:** blocking

### Confirmed diagnosis for the IME blocker

Herminal follows Ghostty's AppKit input path. In `HerminalSurfaceView.keyDown`, a Tab pressed while `markedText` exists is sent to libghostty with `composing = true`. In `Vendor/libghostty/src/input/key_encode.zig`, composing events deliberately return without encoding any non-modifier key. The result is deterministic: `\t` never reaches the shell, so completion cannot run. iTerm2 instead behaves as a transaction: commit the visible preedit, clear composition, then forward Tab.

### Tasks

1. Capture a before-fix manual reproduction with both macOS Vietnamese Telex and VNI in `zsh`, including the exact underlined partial word and expected completion.
2. Add a narrow Herminal-owned policy for Tab/Shift-Tab during active marked text; do not patch vendored Ghostty first:
   - snapshot the latest marked/preedit string;
   - safely end/discard the IME's marked state without losing the snapshot;
   - commit that string exactly once to the PTY;
   - clear libghostty preedit;
   - forward the original Tab/Shift-Tab as a non-composing key event.
3. Guard against duplicate commit callbacks from AppKit and preserve ordinary composition behavior for Enter, Backspace, arrows, candidate selection, Korean/Japanese/Chinese IMEs, and non-IME Tab.
4. Add regression coverage for the pure state-transition policy: marked text + Tab, marked text + Shift-Tab, no marked text + Tab, empty marked text, and duplicate/late IME callback handling. A live system-IME test remains manual because CI cannot reliably drive macOS input sources.
5. Extend `docs/QA/vietnamese-ime-checklist.md` with shell-completion cases for Telex and VNI, plus zsh/bash/fish where available. Record one passing owner run as a dated artifact.
6. Compare `main`, latest tag, GitHub Releases, Homebrew cask, website, README, changelog, roadmap, and retrospective.
7. Decide one truthful release state:
   - publish `v1.0.0` only after the IME blocker and release verification pass; or
   - temporarily change README/status back to the latest public version.
8. Remove stale roadmap language such as old v0.1 release gates that have already been completed.
9. Verify the version in app metadata, release artifact names, Homebrew cask, changelog, and docs.
10. Run the full release gate on a clean checkout.
11. Publish signed/notarized `v1.0.0`, update cask checksum/version, then verify a clean Homebrew install.
12. Create a short public release verification record with commands and outcomes; never expose signing secrets.

### Likely files

- `README.md`, `README.vi.md`
- `CHANGELOG.md`
- `docs/ROADMAP.md`
- `docs/RELEASE.md`
- `docs/backlog/v1.0-retrospective.md`
- `App/Info.plist`
- `.github/workflows/release.yml`
- `Casks/herminal.rb` and/or the external Homebrew tap

### Verification

```bash
swift test
Scripts/dogfood.sh
Scripts/release.sh 1.0.0   # only with owner-held signing/notary credentials
brew uninstall --cask herminal || true
brew install --cask hoangperry/herminal/herminal
codesign --verify --deep --strict /Applications/herminal.app
spctl --assess --type execute --verbose /Applications/herminal.app
```

### Exit criteria

- While a Vietnamese word is visibly underlined, one Tab keystroke commits it exactly once and triggers real shell completion; Shift-Tab and plain Tab still work.
- The expanded Telex/VNI manual matrix has a dated passing record and automated state-transition regressions pass.
- Public GitHub release, Homebrew cask, app version, and docs all show the same version.
- A clean machine can install and launch the release without bypassing Gatekeeper.

## Phase 1 — Security and supply-chain hardening

**Duration:** 1 week  
**Depends on:** Phase 0

### Tasks

1. Add `docs/THREAT-MODEL.md` using assets/trust-boundaries/attack-paths/mitigations/residual-risk structure.
2. Explicitly cover:
   - untrusted repository instructions and agent-generated commands;
   - process argv inspection and accidental secret exposure;
   - shell/PTY command execution;
   - SSH config parsing and command construction;
   - clipboard and IME injection;
   - workspace/session JSON depth and corruption;
   - SQLite file permissions and sensitive notes;
   - test-only environment variables in production;
   - libghostty and SQLite.swift supply chain;
   - release signing, notarization, Homebrew, and future Sparkle updates.
3. Enable GitHub private vulnerability reporting and document the actual reporting route.
4. Add automated dependency/update review appropriate to SwiftPM and the git submodule.
5. Add CodeQL for Swift if supported by the current GitHub runner/toolchain; otherwise document and use a verified Swift-compatible alternative. Do not add a badge for a scanner that is not running.
6. Pin third-party GitHub Actions to reviewed commit SHAs and define an update procedure.
7. Generate checksums and an SBOM or dependency manifest for release artifacts.
8. Add security regression tests for unsafe command construction, malicious SSH config values, oversized/deep JSON, log redaction, and test-env path handling.
9. Review whether raw process arguments can ever reach logs/UI; enforce data minimization.

### Exit criteria

- Threat model is public and reviewed against actual code.
- Security reporting works privately.
- Security checks run in CI or have a documented, reproducible substitute.
- Release assets have verifiable checksums and dependency provenance.

## Phase 2 — Agent interoperability foundation

**Duration:** 1–2 weeks  
**Depends on:** Phase 0

### Goal

Make Codex support a real, useful Herminal capability without turning Herminal into an agent orchestrator.

### Tasks

1. Introduce an internal `AgentEvent` model decoupled from UI and individual vendors:
   - source, session/process identity, workspace, lifecycle state, timestamp;
   - optional event category and safe metadata;
   - no prompt/output body by default.
2. Define an `AgentSignalSource` interface and keep current process/CPU detection as one source.
3. Research the current official Codex integration surfaces before implementation (notifications, hooks, config, process behavior). Record version/date and avoid relying on undocumented behavior.
4. Implement the smallest supported Codex adapter:
   - prefer documented structured events;
   - otherwise retain process + bell/terminal-semantic signals and label confidence honestly.
5. Add source confidence and fallback behavior so a missing/broken adapter never breaks terminal use.
6. Add fixture-driven conformance tests for Codex, Claude Code, and Aider signals.
7. Ensure payload validation, size/depth limits, source authentication where applicable, and redaction.
8. Display vendor, workspace, status, confidence, and last activity; do not display sensitive argv or terminal text.
9. Document the integration contract in `docs/AGENT-INTEGRATIONS.md`.

### Architecture constraint

Keep the event model internal. Extract `open-agent-events` only if at least one external consumer requests it or three independent integrations need the same contract.

### Exit criteria

- A real Codex session is detected and focused reliably in a manual matrix.
- Unit/fixture tests cover valid, malformed, oversized, stale, duplicate, and out-of-order signals.
- Disabling every adapter leaves normal terminal behavior unchanged.

## Phase 3 — Contributor and maintainer surface

**Duration:** 3–5 days  
**Depends on:** Phase 0  
**Can run parallel with:** Phases 1–2

### Tasks

1. Update `CONTRIBUTING.md` with a 15-minute path for docs/tests and a full native-build path.
2. Add a `GOOD_FIRST_ISSUES.md` or GitHub issue list with genuinely scoped tasks.
3. Seed 6–10 real issues from known limitations, each with reproduction/context, acceptance criteria, and expected test level.
4. Label issues accurately: `good first issue`, `help wanted`, `security`, `agent-integration`, `IME`, `docs`.
5. Add a PR checklist covering tests, security/privacy impact, screenshots for UI, and changelog need.
6. Add a maintainer triage policy: response target, duplicate handling, severity, close/stale rules.
7. Create a lightweight architecture tour focused on module boundaries and where contributors should not couple UI to libghostty.
8. Reconcile claimed test counts and prerequisites with current reality.

### Exit criteria

- A contributor can make a docs or fixture PR without building libghostty.
- Every seeded issue represents useful work; none exists merely to inflate activity.
- CI gives fast feedback to external PRs without requiring maintainer secrets.

## Phase 4 — Closed beta and feedback-driven maintenance

**Duration:** 2 weeks  
**Depends on:** Phases 0, 2, 3

### Recruitment

Recruit 10–15 relevant people, aiming for at least 5 completed testers:

- Vietnamese macOS developers using Telex or VNI.
- Developers using Codex/Claude Code/Aider daily.
- At least two tmux/SSH-heavy users.
- At least one Swift/macOS contributor.

Do not ask testers to star the repo. Ask for usage and honest reports.

### Test protocol

1. Install via Homebrew on a clean environment.
2. Use Herminal for one real repository for at least three days.
3. Run Vietnamese IME checklist.
4. Run one Codex or other supported agent session.
5. Exercise tabs, recursive splits, restore, notes, and SSH where relevant.
6. Submit a structured report or issue with macOS version, hardware, workflow, failures, and fallback terminal.
7. Obtain explicit consent before publishing any quote or identity.

### Maintenance loop

- Triage reports within 48 hours.
- Reproduce before fixing.
- Label severity and affected version.
- Ship small patch releases rather than a large feature wave.
- Publish release notes linking resolved issues and thanking contributors.

### Exit criteria

- 5 completed real-workflow beta reports.
- At least 3 externally authored reports/issues.
- Two feedback-driven patch releases or a documented reason fewer were needed.
- No unresolved critical install, data-loss, command-execution, or update issue.

## Phase 5 — Public launch and adoption evidence

**Duration:** 1–2 weeks  
**Depends on:** Phase 4

### Tasks

1. Produce a 60–90 second truthful demo:
   - Vietnamese IME;
   - Codex session detection/focus;
   - multiple panes;
   - local notes;
   - no cloud/account requirement.
2. Publish three technical posts already supported by repo research:
   - macOS process-tree detection pitfalls;
   - mach-time CPU sampling bug;
   - Vietnamese `NSTextInputClient` lessons.
3. Launch to relevant communities, not generic mass promotion:
   - Vietnamese developer groups;
   - Swift/macOS communities;
   - terminal and agent-tool communities where self-promotion is allowed.
4. Add privacy-safe evidence:
   - GitHub release asset download counts;
   - Homebrew analytics if publicly available;
   - opt-in tester registry or anonymized completed-beta count.
5. Maintain an `ADOPTERS.md` only for people/projects that explicitly opt in.
6. Respond publicly and professionally to every issue and PR.

### Exit criteria

- Installation and beta metrics are timestamped and reproducible.
- At least 10 verified installs and 5 completed testers.
- Public maintenance activity continues after launch day.

## Phase 6 — Demonstrate Codex-assisted OSS maintenance

**Duration:** concurrent during Phases 3–5

### Tasks

Document three to five real workflows where Codex materially helps without replacing maintainer judgment:

1. Reproduce and propose tests for externally reported bugs.
2. Review PRs against Herminal architecture/security rules.
3. Update cross-version docs and changelog during releases.
4. Generate candidate compatibility fixtures, then manually validate them.
5. Audit release workflow and supply-chain changes.

For each example record:

- issue/PR link;
- task and human decision boundary;
- validation commands;
- outcome and correction if Codex was wrong;
- approximate time saved, clearly labeled as an estimate.

Never auto-merge based only on an agent review. Never expose private beta data or signing credentials to prompts.

### Exit criteria

- At least 3 public issue/PR examples exist.
- Maintainer policy states what Codex may automate and what remains human-approved.

## Phase 7 — Application package and submission

**Duration:** 2 days  
**Depends on:** Phases 4–6 and success gates

### Deliverables

Create `docs/community/codex-for-oss-application.md` containing:

1. Maintainer identity and write-access role.
2. One-sentence project pitch.
3. Project description and underserved audience.
4. Public usage and maintenance evidence with dates/links.
5. Why the project matters despite its niche size.
6. Six-month Codex maintenance plan.
7. API-credit use cases, only if the project will actually use API automation.
8. Codex Security request mapped to the threat model.
9. Repository, releases, Homebrew, roadmap, security, demo, issue, and contributor links.
10. Explicitly truthful limitations and current scale.

### Suggested six-month use plan

- Months 1–2: issue reproduction, tests, compatibility fixtures, PR review.
- Months 3–4: safe agent integrations and security backlog remediation.
- Months 5–6: release automation, dependency updates, contributor support, documentation.

### Submission gate

Perform a red-team review:

- Can every claim be verified publicly?
- Does the application overstate adoption or importance?
- Is Herminal clearly more than a personal demo?
- Are API credits tied to core OSS work rather than private product usage?
- Is Codex Security justified by actual attack surfaces?
- Are maintainer duties visible over time?

Submit only after all mandatory gates pass. If adoption gates fail, continue maintenance for another 30 days instead of embellishing the application.

## 7. PR sequence

| PR | Scope | Depends on | Risk |
|---|---|---|---|
| PR-1 | Version/release/docs truth reconciliation | none | medium |
| PR-2 | Public v1 release verification fixes | PR-1 | high |
| PR-3 | Threat model + reporting path | PR-1 | low |
| PR-4 | CI security, dependency, provenance hardening | PR-3 | high |
| PR-5 | Internal AgentEvent + AgentSignalSource model | PR-1 | medium |
| PR-6 | Codex adapter spike + fixtures | PR-5 | medium |
| PR-7 | Dashboard confidence/redaction UX | PR-6 | medium |
| PR-8 | Contributor fast path + issue templates/backlog | PR-1 | low |
| PR-9+ | Beta-reported fixes, one concern per PR | PR-2, PR-7, PR-8 | variable |
| PR-final | Application evidence document | beta evidence | low |

Do not combine release, security workflow, and agent architecture changes into one PR.

## 8. Verification matrix

Every implementation PR should run the narrowest relevant checks plus the full gate before release:

```bash
swift test --filter HerminalAgentTests
swift test --filter HerminalDBTests
swift test
Scripts/make-app-bundle.sh
Scripts/dogfood.sh
```

Manual release matrix:

- clean Homebrew install;
- first launch/Gatekeeper;
- Vietnamese Telex and VNI composition, including Tab/Shift-Tab completion while marked text is active;
- Codex detection, status change, focus, exit;
- tmux, SSH, notes persistence, layout restore;
- malicious/corrupt workspace fixture;
- no terminal text, argv secrets, credentials, or user paths in exported diagnostics.

## 9. Metrics dashboard

Track weekly in a public, simple Markdown table; do not add telemetry to the app.

| Metric | Baseline | Apply target |
|---|---:|---:|
| Public latest release | v0.4.2 | v1.x consistent everywhere |
| Verified installs | unknown | 10+ |
| Completed 3-day testers | 0 known | 5+ |
| External reports/issues | 0 | 3+ |
| External contributions | 0 | 1+ |
| Feedback-driven releases | 0 after public v1 | 2+ |
| Critical unresolved security/data-loss bugs | unknown | 0 |
| Public Codex maintenance examples | 0 | 3+ |

## 10. Stop/pivot rules

- If clean installation is unreliable, stop promotion and fix distribution first.
- If testers do not value agent observability, do not extract an event protocol; focus on Vietnamese IME and terminal reliability.
- If fewer than five testers complete the beta, extend recruitment rather than manufacturing activity.
- If a critical shell/update/security issue appears, pause feature work and release a coordinated fix.
- If the application cannot truthfully show external use, apply later or contribute substantially to an established OSS project instead.

## 11. Definition of done

This plan is complete when:

- Herminal has a consistent, publicly installable v1 release.
- Security posture and supply chain are documented and automatically checked where feasible.
- Codex integration is reliable, tested, privacy-preserving, and based on supported interfaces.
- External users have produced real feedback that resulted in visible maintenance work.
- A truthful, evidence-linked Codex for Open Source application has passed red-team review and been submitted.
