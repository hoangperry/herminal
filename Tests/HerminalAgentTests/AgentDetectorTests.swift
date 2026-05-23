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

    /// Regression guard for the M4-1 bug: `proc_listchildpids` returns
    /// garbage on macOS Sequoia, so the sysctl-based `ProcessSnapshot`
    /// must actually see real children spawned by the test.
    @Test("dumpSubtree sees a freshly spawned child process")
    func dumpSubtreeSeesChild() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["3"]
        try process.run()
        defer { process.terminate() }
        // Give the kernel time to record the new process — sysctl reads a
        // consistent snapshot, but launchd's accounting can lag a beat.
        Thread.sleep(forTimeInterval: 0.3)

        let tree = AgentDetector.dumpSubtree(of: getpid())
        #expect(!tree.isEmpty, "subtree must not be empty when we just spawned a child")
        let hasSleep = tree.contains { $0.contains("sleep") }
        #expect(hasSleep, "subtree must mention the freshly spawned 'sleep' child — got: \(tree)")
    }
}
