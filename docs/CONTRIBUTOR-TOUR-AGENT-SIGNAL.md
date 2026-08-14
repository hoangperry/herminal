# Contributor tour: one agent lifecycle signal

This tour follows the current process-derived signal into the sidebar. It
assumes the module boundaries in [`ARCHITECTURE.md`](ARCHITECTURE.md) and focuses
only on the smallest safe change.

## 1. Classify in `HerminalAgent`

[`AgentDetector.detectAgents`](../Sources/HerminalAgent/AgentDetector.swift)
walks Herminal's descendant process tree. A direct executable goes through
`AgentKind.detect(processName:)`; node/python/bun/deno wrappers go through
`AgentKind.detect(interpreterArgv:)`. The result is a `DetectedAgent` with PID,
kind, and an initially unknown lifecycle status.

`ProcessArgvReader` is a privacy boundary: argv is read only to classify known
wrappers. Do not store it in `DetectedAgent`, `AgentEvent`, diagnostics, or UI.
Synthetic examples belong in
[`AgentDetectorTests`](../Tests/HerminalAgentTests/AgentDetectorTests.swift), not
in copied user output.

[`AgentEvent`](../Sources/HerminalAgent/AgentEvent.swift) is the vendor-neutral
contract for future signal sources. It deliberately carries lifecycle metadata,
not prompt/output/argv/environment content. `ProcessAgentSignalSource` exposes
current detection through that contract; the existing dashboard pipeline still
uses `DetectedAgent` while status and pane heuristics are applied.

## 2. Refresh in `WorkspaceView`

[`WorkspaceView.startAgentPolling`](../Sources/HerminalApp/Workspace/WorkspaceView.swift)
schedules a two-second timer. Its closure enters `MainActor` before calling
`refreshAgents()`. Keep process sampling outside SwiftUI views and keep all UI
mutation on this actor boundary.

`refreshAgents()`:

1. detects processes and updates the status-bar count;
2. uses `AgentStatusTracker` to infer running versus idle from CPU deltas;
3. uses `AgentPaneMapper` to infer the tab from process ancestry;
4. promotes eligible agents to `needsInput` after a recent terminal bell;
5. replaces `dashboardHost.rootView` with the resulting list.

A missing process, argv read, pane mapping, or future adapter must degrade to no
signal or lower confidence. It must never interrupt terminal input or shell
execution.

## 3. Render in `AgentDashboardView`

[`AgentDashboardView`](../Sources/HerminalApp/Workspace/AgentDashboardView.swift)
is a value view over `[DetectedAgent]`. `agentRow(_:)` maps kind/status to labels,
colors, accessibility text, and an optional one-based tab hint. It does no
process inspection and owns no polling state.

PIDs are ephemeral operational metadata and are currently displayed. Never add
argv, cwd, workspace names, terminal text, or note content. Follow
[`MAINTAINER-AI-POLICY.md`](MAINTAINER-AI-POLICY.md) and run
`Scripts/check-diagnostics-privacy.py` when logging changes.

## Small-change recipe

To support one documented Codex wrapper shape:

1. add a generic synthetic argv row to `AgentDetectorTests`;
2. make the smallest boundary-safe classifier change in `AgentDetector.swift`;
3. add a malformed lookalike negative fixture;
4. run `swift test --filter HerminalAgentTests`, the diagnostics guard, and the
   full CI suite.

Do not couple `AgentDashboardView` to process APIs or libghostty. If a new source
needs structured lifecycle states, implement `AgentSignalSource` and preserve
normal terminal behavior when it returns no events.
