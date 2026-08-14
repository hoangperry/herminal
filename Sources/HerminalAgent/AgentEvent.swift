import Foundation

/// Vendor-neutral lifecycle observation consumed by Herminal's dashboard.
/// Deliberately excludes prompts, terminal output, argv, and environment data.
public struct AgentEvent: Sendable, Equatable, Identifiable {
    public struct ID: Hashable, Sendable {
        public let source: AgentKind
        public let processID: Int32

        public init(source: AgentKind, processID: Int32) {
            self.source = source
            self.processID = processID
        }
    }

    public let id: ID
    public let source: AgentKind
    public let processID: Int32
    public let status: AgentStatus
    public let confidence: AgentSignalConfidence
    public let observedAt: Date
    public let tabHint: Int?

    public init(
        source: AgentKind,
        processID: Int32,
        status: AgentStatus,
        confidence: AgentSignalConfidence,
        observedAt: Date = Date(),
        tabHint: Int? = nil
    ) {
        self.id = ID(source: source, processID: processID)
        self.source = source
        self.processID = processID
        self.status = status
        self.confidence = confidence
        self.observedAt = observedAt
        self.tabHint = tabHint
    }
}

public enum AgentSignalConfidence: String, Sendable, Hashable {
    /// A documented structured integration emitted the state directly.
    case authoritative
    /// Multiple local signals agree (for example process + CPU + bell).
    case inferred
    /// Process-name or wrapper-argv detection only.
    case heuristic
}

/// A replaceable source of privacy-minimized agent lifecycle observations.
/// Sources must fail closed: an unavailable adapter returns no events and must
/// never interfere with terminal input or process execution.
public protocol AgentSignalSource: Sendable {
    func snapshot(observedAt: Date) -> [AgentEvent]
}

/// Existing process-tree detection exposed through the neutral event contract.
/// This is a heuristic source; future documented Codex integrations can provide
/// authoritative events without changing dashboard consumers.
public struct ProcessAgentSignalSource: AgentSignalSource {
    public let rootProcessID: Int32

    public init(rootProcessID: Int32) {
        self.rootProcessID = rootProcessID
    }

    public func snapshot(observedAt: Date = Date()) -> [AgentEvent] {
        AgentDetector.detectAgents(under: rootProcessID).map { agent in
            AgentEvent(
                source: agent.kind,
                processID: agent.pid,
                status: agent.status,
                confidence: .heuristic,
                observedAt: observedAt,
                tabHint: agent.tabHint
            )
        }
    }
}
