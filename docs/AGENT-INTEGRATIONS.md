# Agent integrations

Herminal observes coding-agent lifecycle state without reading prompts or terminal output and without sending data off-device.

## Signal model

`HerminalAgent.AgentEvent` is the vendor-neutral boundary. It contains only:

- vendor/source;
- local process ID;
- lifecycle status;
- confidence level;
- observation timestamp;
- optional local tab hint.

It intentionally has no prompt, output, argv, environment, token, repository path, or command field.

## Confidence

- `authoritative`: emitted by a documented structured integration.
- `inferred`: multiple local signals agree.
- `heuristic`: process name or wrapper classification only.

The current `ProcessAgentSignalSource` is heuristic. CPU sampling, pane mapping, and BEL handling enrich dashboard state separately. A missing adapter must return no events and must never affect terminal execution.

## Supported sources

| Agent | Current signal | Confidence |
|---|---|---|
| Codex CLI | process tree / wrapper detection | heuristic |
| Claude Code | process tree / wrapper detection + optional BEL | heuristic/inferred |
| Aider | process tree / Python wrapper detection | heuristic |

Before adding structured Codex support, verify the current official Codex interface and pin the tested CLI version/date in the implementation PR. Herminal will not depend on undocumented log files or scrape private conversation content.

## Adapter requirements

Every new `AgentSignalSource` must:

1. use a documented or versioned input contract;
2. validate size, schema, timestamps, and source identity where applicable;
3. discard unknown fields;
4. collect no prompt/output body by default;
5. tolerate duplicates, stale events, malformed data, and adapter absence;
6. include fixture tests;
7. leave ordinary terminal behavior unchanged when disabled.

Do not extract a standalone protocol until an external consumer asks for it or three independent integrations require the same contract.
