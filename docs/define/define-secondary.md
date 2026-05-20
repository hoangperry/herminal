# [herminal] recent context, 2026-05-20 4:24pm GMT+7

No previous sessions found.

View Observations Live @ http://localhost:37777
YOLO mode is enabled. All tool calls will be automatically approved.
YOLO mode is enabled. All tool calls will be automatically approved.
Ripgrep is not available. Falling back to GrepTool.
MCP issues detected. Run /mcp list for status.
Hook system message: # [herminal] recent context, 2026-05-20 4:24pm GMT+7

No previous sessions found.

View Observations Live @ http://localhost:37777
The independent risk and persona analysis for **herminal** has been completed. The analysis is based on the technical constraints of a solo 3-month MVP (SwiftUI + libghostty) and the specific needs of Vietnamese AI developers in 2026.

The full report is available at `docs/research/07-persona-risk-analysis.md`.

### A. User Persona Deep-Dive
I have identified three key personas:
1. **Bảo Nguyễn (The Agile Soloist):** A senior frontend engineer needing tight integration between Claude Code streams and task scratchpads. Switch point: reliably typing `tiếng Việt` without terminal flickering.
2. **Linh Trần (The Infrastructure Guardian):** A DevOps lead who lives in `tmux` but needs to monitor multiple background agents. Switch point: 100% local privacy + agent dashboard that respects existing `tmux` habits.
3. **Khoa Đặng (The Academic Innovator):** A CS student running local LLM experiments. Switch point: "Persistent Notes" that attach context directly to experimental shell sessions.

### B. Top 12 Risks (Ranked)
The top risks focus on technical stability and project survival:
- **Rank 1: IME Corruption (Score 20):** Vietnamese input bugs destroy trust. Mitigation: Direct AppKit-layer `NSTextInputClient` implementation and weekly regression suites.
- **Rank 2: libghostty ABI Drift (Score 16):** Upstream changes breaking the Swift bridge. Mitigation: Thin, versioned C-bridge and daily upstream tracking.
- **Rank 3: Solo Developer Burnout (Score 16):** Deep complexity of terminal emulators. Mitigation: Strict 7-feature MoSCoW limit and vertical slicing.

### C. Success Metrics Reality Check
I have proposed **Honest Success Criteria** for a pet project, moving away from generic DAU/MAU targets:
- **Owner Dogfooding:** Primary terminal usage for 30 consecutive days.
- **Vietnamese Trust:** Zero reported IME bugs in 14 days of active use.
- **Performance Parity:** p95 latency under 16ms during heavy agent streaming.
- **Survival Metric:** Reaching Month 4 with a stable build and zero scope creep.

The analysis highlights that while the market is saturated with "AI terminals," a **privacy-first, Vietnamese-optimized native macOS host** for local agents has a distinct, defensible niche.
