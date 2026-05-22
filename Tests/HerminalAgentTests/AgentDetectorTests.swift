import Foundation
import Testing
@testable import HerminalAgent

@Suite("AgentDetector")
struct AgentDetectorTests {
    @Test("detect maps known agent process names", arguments: [
        ("claude", AgentKind.claudeCode),
        ("Claude", AgentKind.claudeCode),
        ("codex", AgentKind.codex),
        ("aider", AgentKind.aider),
    ])
    func detectKnownNames(name: String, expected: AgentKind) {
        #expect(AgentKind.detect(processName: name) == expected)
    }

    @Test("detect returns nil for non-agent process names", arguments: [
        "zsh", "bash", "node", "tmux", "",
    ])
    func detectRejectsOthers(name: String) {
        #expect(AgentKind.detect(processName: name) == nil)
    }

    @Test("detectAgents on a clean subtree does not crash and returns a list")
    func detectAgentsRuns() {
        // The test process has no agent children — expect an empty result,
        // but the call must complete without crashing.
        let agents = AgentDetector.detectAgents(under: getpid())
        #expect(agents.allSatisfy { $0.kind != .unknown })
    }
}
