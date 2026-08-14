import Foundation
import Testing
@testable import HerminalAgent

@Suite("AgentEvent")
struct AgentEventTests {
    @Test("identity is stable for source and process")
    func stableIdentity() {
        let first = AgentEvent(
            source: .codex,
            processID: 42,
            status: .running,
            confidence: .heuristic,
            observedAt: Date(timeIntervalSince1970: 1)
        )
        let second = AgentEvent(
            source: .codex,
            processID: 42,
            status: .idle,
            confidence: .inferred,
            observedAt: Date(timeIntervalSince1970: 2)
        )
        #expect(first.id == second.id)
    }

    @Test("different vendors cannot collide on a reused PID")
    func vendorSeparatesIdentity() {
        let codex = AgentEvent(source: .codex, processID: 42,
                               status: .unknown, confidence: .heuristic)
        let claude = AgentEvent(source: .claudeCode, processID: 42,
                                status: .unknown, confidence: .heuristic)
        #expect(codex.id != claude.id)
    }

    @Test("event schema contains no prompt, output, argv, or environment fields")
    func privacyMinimizedSchema() {
        let event = AgentEvent(source: .aider, processID: 7,
                               status: .running, confidence: .heuristic)
        let labels = Set(Mirror(reflecting: event).children.compactMap(\.label))
        #expect(labels.isDisjoint(with: ["prompt", "output", "argv", "environment", "command"]))
    }
}
