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

    // MARK: - M8/A1 Node-wrapped detection (Q3-002 close-out)

    @Test("isInterpreter flags node/python/bun/deno, rejects unrelated names")
    func interpreterFlag() {
        for name in ["node", "Node", "python", "python3", "bun", "deno"] {
            #expect(AgentKind.isInterpreter(name: name), "expected \(name) to be a wrapper interpreter")
        }
        for name in ["zsh", "bash", "claude", "vim", ""] {
            #expect(!AgentKind.isInterpreter(name: name), "did not expect \(name) to be an interpreter")
        }
    }

    @Test("detect(interpreterArgv:) catches npm-package agent CLIs", arguments: [
        (["node", "/Users/x/.npm/_npx/abc/@anthropic-ai/claude-code/cli.js"], AgentKind.claudeCode),
        (["node", "/usr/local/bin/.bin/claude", "--help"], AgentKind.claudeCode),
        (["node", "/opt/homebrew/lib/node_modules/@openai/codex/dist/cli.js"], AgentKind.codex),
        (["python3", "-m", "aider"], AgentKind.aider),
        (["python", "/Users/x/.local/bin/aider"], AgentKind.aider),
        (["node", "/path/to/claude-code/index.js"], AgentKind.claudeCode),
    ])
    func interpreterArgvDetects(argv: [String], expected: AgentKind) {
        #expect(AgentKind.detect(interpreterArgv: argv) == expected)
    }

    @Test("detect(interpreterArgv:) returns nil for non-agent scripts", arguments: [
        ["node", "/Users/x/my-app/server.js"],
        ["python3", "manage.py", "runserver"],
        ["node"],  // bare interpreter — argv[1] missing
        [],        // empty — never happens in practice but must not crash
    ])
    func interpreterArgvRejects(argv: [String]) {
        #expect(AgentKind.detect(interpreterArgv: argv) == nil)
    }

    @Test("ProcessArgvReader returns the running test's own argv")
    func argvReaderRoundTrip() {
        // The test process always has at least argv[0] (the xctest helper).
        let argv = ProcessArgvReader.argv(forPID: getpid())
        #expect(!argv.isEmpty, "self-process argv must be readable via sysctl")
        // Whatever shape Swift Testing's runner uses, argv[0] should look
        // like an executable path (contains "/" on disk).
        #expect(argv.first?.contains("/") == true,
                "argv[0] should look like a path, got \(argv.first ?? "nil")")
    }

    @Test("ProcessArgvReader returns empty for a non-existent PID")
    func argvReaderHandlesMissingPID() {
        // pid 999999 is well outside the live range on a normal system —
        // the reader must degrade gracefully, not crash.
        let argv = ProcessArgvReader.argv(forPID: 999_999)
        #expect(argv.isEmpty)
    }
}
