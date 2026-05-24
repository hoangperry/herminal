import Foundation
import Testing
@testable import HerminalAgent

/// Verifies the CPU-delta heuristic that distinguishes `.running` from
/// `.idle` agents. We can't easily mock `proc_pid_rusage`, so the
/// integration assertion uses a real spawned process: a tight CPU loop
/// vs a `sleep`. The bridge math (first-sighting = unknown, eviction of
/// dead PIDs) is covered by direct calls without spawning.
@Suite("AgentStatusTracker")
struct AgentStatusTrackerTests {
    @Test("first sighting always reports .unknown — no prior sample")
    func firstSightingUnknown() {
        let tracker = AgentStatusTracker()
        let agent = DetectedAgent(id: 12345, kind: .codex, processName: "codex")
        let annotated = tracker.annotate([agent])
        #expect(annotated.first?.status == .unknown)
    }

    @Test("dead PIDs are evicted from the cache between calls")
    func deadPIDsEvicted() {
        let tracker = AgentStatusTracker()
        let alive = DetectedAgent(id: 11111, kind: .codex, processName: "codex")
        let ghost = DetectedAgent(id: 99999, kind: .codex, processName: "codex")
        _ = tracker.annotate([alive, ghost])
        // Re-call with only `alive` — ghost should be evicted internally.
        // We can't observe the cache directly, but a third call with ghost
        // alone again should report .unknown (back to first-sighting).
        _ = tracker.annotate([alive])
        let resurrected = tracker.annotate([ghost])
        #expect(resurrected.first?.status == .unknown)
    }

    @Test("a CPU-busy process is reported .running on the second poll")
    func busyIsRunning() {
        // Use the test process itself — no spawn races, no
        // standardOutput plumbing, just burn CPU between two annotate
        // calls. The PID always exists (getpid()) and proc_pid_rusage
        // sees real work from the inline busy loop.
        let pid = getpid()
        let agent = DetectedAgent(id: pid, kind: .codex, processName: "test")
        let tracker = AgentStatusTracker()
        _ = tracker.annotate([agent])  // Seed

        // Burn ~500ms of CPU. ~10M iterations of integer math comfortably
        // exceeds the 5% threshold (it's effectively 100%).
        let deadline = Date().addingTimeInterval(0.5)
        var acc: UInt64 = 0
        while Date() < deadline {
            for i in 0..<10_000 { acc &+= UInt64(i) }
        }
        // Reference acc so the optimiser can't elide the whole loop.
        #expect(acc > 0)

        let second = tracker.annotate([agent])
        #expect(second.first?.status == .running)
    }

    @Test("an idle process is reported .idle on the second poll")
    func idleIsIdle() async throws {
        // Spawn a real child — `sleep` is the cleanest test subject
        // because it provably burns no CPU. The Swift Testing runner
        // has its own background threads that pollute self-process
        // CPU samples, so we can't use getpid() for the idle case.
        let idle = Process()
        idle.executableURL = URL(fileURLWithPath: "/bin/sleep")
        idle.arguments = ["10"]
        try idle.run()
        defer { idle.terminate() }

        let pid = idle.processIdentifier
        let agent = DetectedAgent(id: pid, kind: .codex, processName: "sleep")
        let tracker = AgentStatusTracker()
        _ = tracker.annotate([agent])
        try await Task.sleep(nanoseconds: 500_000_000)
        let second = tracker.annotate([agent])
        #expect(second.first?.status == .idle)
    }
}
