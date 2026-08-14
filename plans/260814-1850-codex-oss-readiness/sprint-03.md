# Sprint 3 — Agent interoperability and contributor surface

**Status:** in progress
**Started:** 2026-08-14

## Goal

Introduce a privacy-minimized, vendor-neutral agent event boundary and make the repository easier for outside contributors to enter without broadening Herminal into an orchestrator.

## Deliverables

- `AgentEvent`, confidence levels, and `AgentSignalSource` in HerminalAgent.
- Existing process detection available as a heuristic source.
- Privacy/schema tests and integration documentation.
- Research checkpoint before any structured Codex adapter.
- Contributor fast path, triage policy, and genuinely scoped public issues.
- CI green and parent-plan sync.

## Non-goals

- Prompt/output capture.
- Agent command execution or orchestration.
- Undocumented Codex log scraping.
- A standalone event-protocol repository.

## Progress

- Added the neutral event contract and process source.
- Added identity and privacy-minimization tests.
- Added `docs/AGENT-INTEGRATIONS.md` and verified official Codex hook surfaces.
- Documented why a hook adapter is deferred until secure pane attribution exists.
- Added contributor fast path and public triage policy.
- Opened six genuinely scoped public issues (#2–#7) with contributor labels.
- CI full build and 152 tests pass; live IME remains a manual acceptance gate.

## Exit criteria

- Event model compiles and tests pass.
- Existing dashboard behavior does not regress.
- At least six useful contributor tasks are public and accurately labeled.
- Contributor docs identify a path that does not require building UI/libghostty.
