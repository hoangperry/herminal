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

## Codex hooks research checkpoint

Verified against OpenAI's official Codex Hooks and configuration references on
2026-08-14. Codex exposes opt-in lifecycle command hooks behind `features.hooks`
from `hooks.json` or inline `[hooks]` configuration. Relevant documented events
include `SessionStart`, `Stop`, and `SessionEnd`; every hook receives JSON on
stdin with `session_id`, `transcript_path`, `cwd`, and `hook_event_name`.

Herminal must **not** read `transcript_path`, copy the transcript, persist raw
`session_id`, or treat project-local hooks as trusted automatically. A future
adapter should be an explicitly installed command hook that maps only the event
name to a bounded local lifecycle signal. The current hook schema does not
provide a documented PTY/pane identity, so process detection remains necessary
for tab attribution. Until that mapping and authentication boundary are
resolved, process observation stays the production source and the hooks adapter
remains a researched design—not a half-secure implementation.

References:

- <https://developers.openai.com/codex/hooks>
- <https://developers.openai.com/codex/config-reference>

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
