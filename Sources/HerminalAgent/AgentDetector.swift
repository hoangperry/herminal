// AgentDetector — finds agent CLIs running under herminal's process tree.
//
// libghostty does not expose the shell PID per surface, so detection works at
// the app level: walk the process subtree under herminal and match known agent
// process names. This is the "heuristics over protocol" approach (PRD §M3).
//
// Alpha limitation: matches by short process name only. An agent CLI launched
// via a Node wrapper may report as "node" and be missed — see Q3-002.
//
// macOS Sequoia note: `proc_listchildpids` returns garbage on this OS (probe
// reports bytes, fill returns 0) — verified empirically. We use the
// `sysctl(KERN_PROC_ALL)` snapshot instead, the same path `ps` and `pgrep` use.

import Foundation
import Darwin
import Darwin.sys.sysctl

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
        let snapshot = ProcessSnapshot()
        var found: [DetectedAgent] = []
        var visited = Set<pid_t>()
        scan(rootPID, snapshot: snapshot, into: &found, visited: &visited)
        return found
    }

    /// Convenience: scan the subtree under the current process.
    public static func detectAgents() -> [DetectedAgent] {
        detectAgents(under: getpid())
    }

    /// Diagnostic — returns "pid <comm>" lines for every descendant of
    /// `rootPID`. Used only by the GUI test harness when
    /// `HERMINAL_TEST_TREE_DUMP` is set; not on the hot path.
    public static func dumpSubtree(of rootPID: pid_t) -> [String] {
        let snapshot = ProcessSnapshot()
        var lines: [String] = []
        var visited = Set<pid_t>()
        collect(rootPID, depth: 0, snapshot: snapshot, into: &lines, visited: &visited)
        return lines
    }

    private static func collect(
        _ pid: pid_t,
        depth: Int,
        snapshot: ProcessSnapshot,
        into lines: inout [String],
        visited: inout Set<pid_t>
    ) {
        guard !visited.contains(pid) else { return }
        visited.insert(pid)
        for child in snapshot.children(of: pid) {
            let name = snapshot.name(of: child)
            lines.append("\(String(repeating: "  ", count: depth))\(child) \(name)")
            collect(child, depth: depth + 1, snapshot: snapshot, into: &lines, visited: &visited)
        }
    }

    private static func scan(
        _ pid: pid_t,
        snapshot: ProcessSnapshot,
        into found: inout [DetectedAgent],
        visited: inout Set<pid_t>
    ) {
        guard !visited.contains(pid) else { return }
        visited.insert(pid)
        for child in snapshot.children(of: pid) {
            let name = snapshot.name(of: child)
            if let kind = AgentKind.detect(processName: name) {
                found.append(DetectedAgent(id: child, kind: kind, processName: name))
            }
            scan(child, snapshot: snapshot, into: &found, visited: &visited)
        }
    }
}

/// One-shot snapshot of the system process table via `sysctl(KERN_PROC_ALL)`.
/// Built once per detection cycle and queried in O(1) for child lookup.
/// (`proc_listchildpids` returns broken data on macOS 14+; ps/pgrep use this
/// same sysctl path under the hood.)
final class ProcessSnapshot {
    private struct Entry {
        let pid: pid_t
        let ppid: pid_t
        let name: String
    }

    private let childrenByPPID: [pid_t: [pid_t]]
    private let namesByPID: [pid_t: String]

    init() {
        let entries = ProcessSnapshot.readKernelProcessTable()
        var children: [pid_t: [pid_t]] = [:]
        var names: [pid_t: String] = [:]
        for entry in entries {
            children[entry.ppid, default: []].append(entry.pid)
            names[entry.pid] = entry.name
        }
        self.childrenByPPID = children
        self.namesByPID = names
    }

    func children(of pid: pid_t) -> [pid_t] {
        childrenByPPID[pid] ?? []
    }

    func name(of pid: pid_t) -> String {
        namesByPID[pid] ?? ""
    }

    private static func readKernelProcessTable() -> [Entry] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0
        // First pass: probe required buffer size.
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
            return []
        }
        // Allocate aligned storage as raw bytes — kinfo_proc has internal
        // pointers and a strict layout, so we work in bytes and reinterpret.
        let capacity = size
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: capacity, alignment: MemoryLayout<kinfo_proc>.alignment)
        defer { buffer.deallocate() }
        guard sysctl(&mib, UInt32(mib.count), buffer, &size, nil, 0) == 0 else {
            return []
        }
        let count = size / MemoryLayout<kinfo_proc>.stride
        let bound = buffer.bindMemory(to: kinfo_proc.self, capacity: count)
        let table = UnsafeBufferPointer(start: bound, count: count)
        return table.compactMap { proc in
            let pid = proc.kp_proc.p_pid
            let ppid = proc.kp_eproc.e_ppid
            guard pid > 0 else { return nil }
            let name = withUnsafePointer(to: proc.kp_proc.p_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self,
                                      capacity: MemoryLayout.size(ofValue: proc.kp_proc.p_comm)) {
                    String(cString: $0)
                }
            }
            return Entry(pid: pid, ppid: ppid, name: name)
        }
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
