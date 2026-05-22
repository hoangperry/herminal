// AgentDetector — finds agent CLIs running under herminal's process tree.
//
// libghostty does not expose the shell PID per surface, so detection works at
// the app level: walk the process subtree under herminal and match known agent
// process names. This is the "heuristics over protocol" approach (PRD §M3).
//
// Alpha limitation: matches by short process name only. An agent CLI launched
// via a Node wrapper may report as "node" and be missed — see Q3-002.

import Foundation
import Darwin

/// An agent CLI process discovered in herminal's process tree.
public struct DetectedAgent: Sendable, Equatable, Identifiable {
    public let id: pid_t
    public let kind: AgentKind
    public let processName: String

    public var pid: pid_t { id }
}

public enum AgentDetector {
    /// Scans the process subtree under `rootPID` for known agent CLIs.
    public static func detectAgents(under rootPID: pid_t) -> [DetectedAgent] {
        var found: [DetectedAgent] = []
        var visited = Set<pid_t>()
        scan(rootPID, into: &found, visited: &visited)
        return found
    }

    /// Convenience: scan the subtree under the current process.
    public static func detectAgents() -> [DetectedAgent] {
        detectAgents(under: getpid())
    }

    private static func scan(
        _ pid: pid_t,
        into found: inout [DetectedAgent],
        visited: inout Set<pid_t>
    ) {
        guard !visited.contains(pid) else { return }
        visited.insert(pid)
        for child in childPIDs(of: pid) {
            let name = processName(child)
            if let kind = AgentKind.detect(processName: name) {
                found.append(DetectedAgent(id: child, kind: kind, processName: name))
            }
            scan(child, into: &found, visited: &visited)
        }
    }

    /// Direct child PIDs of a process (non-recursive).
    private static func childPIDs(of pid: pid_t) -> [pid_t] {
        // Probe the required buffer size first, then allocate with headroom
        // for processes spawned between the two calls — avoids silently
        // truncating a large process tree at a fixed buffer.
        let probedBytes = proc_listchildpids(pid, nil, 0)
        guard probedBytes > 0 else { return [] }
        let capacity = Int(probedBytes) / MemoryLayout<pid_t>.size + 16
        var pids = [pid_t](repeating: 0, count: capacity)
        let byteSize = Int32(capacity * MemoryLayout<pid_t>.size)
        let bytesWritten = proc_listchildpids(pid, &pids, byteSize)
        guard bytesWritten > 0 else { return [] }
        let count = min(Int(bytesWritten) / MemoryLayout<pid_t>.size, capacity)
        return Array(pids.prefix(count)).filter { $0 > 0 }
    }

    /// Short process name (the BSD `comm` field) for a PID.
    private static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }
}

extension AgentKind {
    /// Maps a process name to a known agent, or nil if it is not an agent CLI.
    public static func detect(processName name: String) -> AgentKind? {
        switch name.lowercased() {
        case "claude": return .claudeCode
        case "codex": return .codex
        case "aider": return .aider
        default: return nil
        }
    }
}
