import Foundation
import Testing
@testable import HerminalAgent

/// `AgentPaneMapper.annotate` pairs detected agents with the tab index
/// hosting their PTY. We can't easily mock `ProcessSnapshot` (it's
/// `final` and reads sysctl on init), so most tests exercise the
/// behaviour through the public seam: the inputs that decide the
/// mapping (sessionStartTimes + the live snapshot of getpid()'s
/// children). Live process tree won't have `login` children when run
/// from `swift test`, so the test process pairing degrades cleanly to
/// "no tab hints" — which is exactly the contract we want to verify
/// for the "no logins" case.
@Suite("AgentPaneMapper")
struct AgentPaneMapperTests {
    @Test("annotate is a no-op when sessionStartTimes is empty")
    func emptySessionsNoOp() {
        let agent = DetectedAgent(id: 12345, kind: .codex, processName: "codex")
        let result = AgentPaneMapper.annotate([agent], sessionStartTimes: [])
        #expect(result == [agent])
    }

    @Test("annotate returns agents unchanged when no login ancestor is found")
    func noLoginAncestorPassesThrough() {
        // Use a real PID that exists but isn't under a login (the test
        // process itself isn't usually launched through /usr/bin/login).
        let agent = DetectedAgent(id: getpid(), kind: .codex, processName: "test")
        let result = AgentPaneMapper.annotate(
            [agent],
            sessionStartTimes: [100, 200, 300]
        )
        // Without a login ancestor, tabHint must remain nil.
        #expect(result.first?.tabHint == nil)
    }

    @Test("annotate preserves agents that are missing from the process snapshot")
    func missingPIDPassesThrough() {
        // PID well above the live range — nearestAncestor returns nil.
        let agent = DetectedAgent(id: 999_999, kind: .claudeCode, processName: "claude")
        let result = AgentPaneMapper.annotate(
            [agent],
            sessionStartTimes: [100, 200]
        )
        #expect(result.first?.tabHint == nil)
    }

    @Test("annotate is identity on empty agent input")
    func emptyAgentsIdentity() {
        let result = AgentPaneMapper.annotate([], sessionStartTimes: [100, 200])
        #expect(result.isEmpty)
    }

    @Test("DetectedAgent.tabHint is nil by default")
    func tabHintDefaultIsNil() {
        let agent = DetectedAgent(id: 1, kind: .codex, processName: "codex")
        #expect(agent.tabHint == nil)
    }

    /// ProcessSnapshot must expose the parent + startTime fields the
    /// mapper relies on. Smoke check using the test process itself —
    /// it MUST have a parent (the test runner) and a non-zero start time.
    @Test("ProcessSnapshot exposes parent + startTime for the self process")
    func snapshotExposesParentAndStart() {
        let snap = ProcessSnapshot()
        let parent = snap.parent(of: getpid())
        #expect(parent != nil, "self process must have a parent in the snapshot")
        #expect(parent! > 0)
        let start = snap.startTime(of: getpid())
        #expect(start > 0, "self process start time should be > 0")
    }

    @Test("ProcessSnapshot.nearestAncestor finds a matching ancestor or returns nil")
    func nearestAncestorBasic() {
        let snap = ProcessSnapshot()
        // Looking for a name that won't exist as our ancestor cleanly
        // exercises the "walked all the way to init" branch.
        let bogus = snap.nearestAncestor(of: getpid(), named: "this-name-cannot-exist-as-comm")
        #expect(bogus == nil)
    }
}
