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
    /// Activity inferred from CPU sampling between two `AgentStatusTracker`
    /// calls. `.unknown` when only one sample exists (first sighting).
    public let status: AgentStatus

    public var pid: pid_t { id }

    public init(id: pid_t, kind: AgentKind, processName: String,
                status: AgentStatus = .unknown) {
        self.id = id
        self.kind = kind
        self.processName = processName
        self.status = status
    }
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
            // Primary path: short name matches a known agent CLI directly.
            // Fallback for wrapper interpreters (node/python/bun/deno):
            // the kernel records `p_comm=node` for `npx @anthropic-ai/claude`,
            // so we have to peek at argv to find the actual agent name.
            // argv reads are skipped for everything that already matched on
            // p_comm because they're more expensive (one sysctl per PID).
            let kind: AgentKind? = {
                if let direct = AgentKind.detect(processName: name) {
                    return direct
                }
                if AgentKind.isInterpreter(name: name) {
                    let argv = ProcessArgvReader.argv(forPID: child)
                    return AgentKind.detect(interpreterArgv: argv)
                }
                return nil
            }()
            if let kind {
                let displayName = AgentKind.isInterpreter(name: name)
                    ? "\(kind.rawValue) (\(name))"
                    : name
                found.append(DetectedAgent(id: child, kind: kind,
                                           processName: displayName, status: .unknown))
            }
            scan(child, snapshot: snapshot, into: &found, visited: &visited)
        }
    }
}

/// Reads process argv via `sysctl(KERN_PROCARGS2)`. Used by
/// `AgentDetector` to disambiguate wrapper interpreters (node, python)
/// from their script arguments. Static utility — no state.
public enum ProcessArgvReader {
    /// Returns the argv array for `pid` (excluding the executable path
    /// prefix), or an empty array if the kernel refuses (process gone,
    /// permission denied, kernel buffer parse failed).
    public static func argv(forPID pid: pid_t) -> [String] {
        // KERN_PROCARGS2 buffer layout:
        //   int32 argc
        //   char  exec_path[]              (null-terminated, then padding)
        //   char  argv[0][]                (null-terminated)
        //   char  argv[1][]
        //   ...
        //   char  envvar[i][]
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        if sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) != 0 || size == 0 {
            return []
        }
        var buffer = [UInt8](repeating: 0, count: size)
        if sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) != 0 {
            return []
        }
        guard size >= MemoryLayout<Int32>.size else { return [] }
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc > 0 else { return [] }
        var pos = MemoryLayout<Int32>.size

        // Step over the exec_path string, then over the padding nulls
        // that align the start of argv[0].
        while pos < size && buffer[pos] != 0 { pos += 1 }
        while pos < size && buffer[pos] == 0 { pos += 1 }

        var args: [String] = []
        var current: [UInt8] = []
        while pos < size && args.count < Int(argc) {
            if buffer[pos] == 0 {
                if let s = String(bytes: current, encoding: .utf8), !s.isEmpty {
                    args.append(s)
                }
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(buffer[pos])
            }
            pos += 1
        }
        return args
    }
}

/// Differentiates "running" from "idle" agents by sampling per-PID CPU
/// usage between calls. The agent dashboard polls every 2s; this tracker
/// remembers the previous sample and infers status from the delta.
///
/// Threshold rationale: a Claude/Codex/Aider session that's actively
/// processing a request burns at least one core (1.0s/s) — even at 5% of
/// one core (0.05s/s of CPU per second of wall time) we mark it
/// `.running`. An idle TUI loop polling stdin sits well below that.
public final class AgentStatusTracker: @unchecked Sendable {
    private struct Sample {
        let cpuSeconds: TimeInterval
        let wallTime: TimeInterval
    }

    private let threshold: Double
    private var samples: [pid_t: Sample] = [:]
    private let lock = NSLock()

    public init(threshold: Double = 0.05) {
        self.threshold = threshold
    }

    /// Enriches each `DetectedAgent` with a freshly inferred `status`.
    /// First sighting always returns `.unknown` — we need two samples to
    /// compute a delta. The caller (dashboard) lives with that for one
    /// poll cycle; the badge flips on the second tick.
    public func annotate(_ agents: [DetectedAgent]) -> [DetectedAgent] {
        let now = Date().timeIntervalSince1970
        lock.lock()
        defer { lock.unlock() }
        var alive: Set<pid_t> = []
        let result = agents.map { agent -> DetectedAgent in
            alive.insert(agent.pid)
            let cpu = Self.cpuSeconds(forPID: agent.pid)
            defer { samples[agent.pid] = Sample(cpuSeconds: cpu, wallTime: now) }
            guard let previous = samples[agent.pid] else {
                return agent  // First sighting → .unknown carries through
            }
            let cpuDelta = cpu - previous.cpuSeconds
            let wallDelta = now - previous.wallTime
            guard wallDelta > 0 else { return agent }
            let status: AgentStatus = (cpuDelta / wallDelta) >= threshold
                ? .running : .idle
            return DetectedAgent(id: agent.pid, kind: agent.kind,
                                 processName: agent.processName, status: status)
        }
        // Evict samples for PIDs that no longer exist so the cache doesn't
        // grow without bound across many short-lived agent invocations.
        samples = samples.filter { alive.contains($0.key) }
        return result
    }

    /// Total user+system CPU time for a PID, in seconds. Returns 0 if the
    /// process is gone or `proc_pid_rusage` declines (sandbox, perms).
    private static func cpuSeconds(forPID pid: pid_t) -> TimeInterval {
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPtr in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, reboundPtr)
            }
        }
        guard result == 0 else { return 0 }
        // `ri_user_time` + `ri_system_time` are MACH ABSOLUTE TIME UNITS,
        // not nanoseconds — verified empirically (Apple Silicon reports
        // 1 mach unit = 125/3 ≈ 41.67 ns; treating the field as ns
        // under-reported CPU by a factor of ~42 and made every agent
        // look idle). Convert via the cached timebase ratio.
        let machTotal = info.ri_user_time + info.ri_system_time
        let ns = machTotal * UInt64(machTimebase.numer) / UInt64(machTimebase.denom)
        return TimeInterval(ns) / 1_000_000_000
    }

    /// Mach timebase ratio for converting `mach_absolute_time` units to
    /// nanoseconds. Read once at first access — the ratio is constant
    /// for the lifetime of the process.
    private static let machTimebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
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

    /// True when the process name is a script interpreter that might be
    /// hosting an agent CLI (`node @anthropic-ai/claude-code/cli.js`,
    /// `python -m aider`, ...). Used by `AgentDetector` to decide
    /// whether to spend a sysctl on argv inspection.
    public static func isInterpreter(name: String) -> Bool {
        switch name.lowercased() {
        case "node", "python", "python3", "bun", "deno":
            return true
        default:
            return false
        }
    }

    /// Inspects an interpreter's argv (e.g. `["node",
    /// "/path/.bin/claude", ...]`) for a recognisable agent CLI. Looks at:
    ///   1. Basename of any argv element — catches `.bin/claude`,
    ///      `cli.js` under a known package directory, plain `claude`.
    ///   2. Substring match against the full argv (lowercased) for the
    ///      known npm package names (`@anthropic-ai/claude-code`,
    ///      `@openai/codex`).
    public static func detect(interpreterArgv argv: [String]) -> AgentKind? {
        guard !argv.isEmpty else { return nil }
        // 2. Package-name substring is the highest-confidence signal.
        let joined = argv.joined(separator: " ").lowercased()
        if joined.contains("@anthropic-ai/claude") || joined.contains("claude-code") {
            return .claudeCode
        }
        if joined.contains("@openai/codex") {
            return .codex
        }
        if joined.contains("aider-chat") || joined.contains("/aider/") {
            return .aider
        }
        // 1. Basename match. Skip argv[0] — it's the interpreter itself.
        for arg in argv.dropFirst() {
            // Trim option flags so `-m aider` and `--script /x/aider.js`
            // resolve to the same payload.
            let trimmed = arg.split(separator: "/").last.map(String.init) ?? arg
            switch trimmed.lowercased() {
            case "claude", "claude.js", "claude-cli": return .claudeCode
            case "codex", "codex.js", "codex-cli": return .codex
            case "aider", "aider.py": return .aider
            default: continue
            }
        }
        return nil
    }
}
