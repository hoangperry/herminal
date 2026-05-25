# Patterns — recurring shapes in the herminal codebase

If you're touching this codebase for the first time, read this once
before the first PR. Each pattern below shows up in 2+ places already
and earned its repetition the hard way.

---

## 1. `MainActor.assumeIsolated` for Sendable callbacks that always run on main

**When:** A callback typed as `@Sendable` (Timer fire blocks,
`NSAnimationContext.completionHandler`, IO callbacks) needs to touch
`@MainActor`-isolated state but always runs on the main runloop.

**Why:** Swift 6 strict concurrency rejects the bare access — the
compiler can't see that "this callback only ever runs on main" is a
runtime invariant. `MainActor.assumeIsolated` is the explicit
acknowledgement.

```swift
NSAnimationContext.runAnimationGroup({ ctx in
    ctx.duration = HerminalDesign.Motion.normal
    self.needsLayout = true
}, completionHandler: { [weak self] in
    MainActor.assumeIsolated {
        guard let self else { return }
        // safe to touch @MainActor state here
        self.isAnimatingLayout = false
    }
})
```

**Existing hits:** `AppDelegate.applicationDidFinishLaunching` (Timer
tick), `WorkspaceView.animateSidebarChange` (NSAnimationContext),
`WorkspaceView.startAgentPolling` (Timer 2s poll).

**Don't:** wrap a closure that may run off-main. The runtime check
that backs `assumeIsolated` will trap.

---

## 2. `nonisolated(unsafe)` for C handles + signal-handler state

**When:** A property holds a C pointer (libghostty handle, file
descriptor), or is written once from a known-safe place and read from
a nonisolated path (deinit, signal handler).

**Why:** Pointers aren't `Sendable`. nonisolated deinit on NSView
subclasses + C function pointer callbacks can't carry actor isolation.
The `unsafe` is the explicit "I promise the lifecycle is safe."

```swift
final class HerminalSurfaceView: NSView {
    // C handle, freed in deinit (nonisolated).
    private nonisolated(unsafe) var surface: ghostty_surface_t?
    // strdup'd buffer kept alive for surface lifetime.
    private nonisolated(unsafe) let commandBuffer: UnsafeMutablePointer<CChar>?

    deinit {
        if let surface { ghostty_surface_free(surface) }
        if let commandBuffer { free(commandBuffer) }
    }
}

// Diary's crash signal handler:
private nonisolated(unsafe) static var crashFD: Int32 = -1
private nonisolated(unsafe) static let crashHandler: @convention(c) (Int32) -> Void = { _ in
    // signal-safe code only — write(2), no Swift strings, no Foundation
}
```

**Existing hits:** `HerminalSurfaceView.surface` + `commandBuffer`,
`Diary.crashFD` + `crashHandler`, `WorkspaceView.agentPollTimer`,
`GhosttyApp.app` + `config`.

**Don't:** use it for state that's actually shared across actors —
that's `Sendable`'s job. `unsafe` is for "compiler can't prove
this but runtime invariant holds."

---

## 3. `sysctl(KERN_PROC_ALL)` instead of libproc on macOS Sequoia+

**When:** You need the process tree, parent PIDs, or per-PID metadata.

**Why:** `proc_listchildpids` returns garbage on macOS 14+ (probe call
reports a buffer size, fill call returns 0 children even when the
target has live ones). Verified empirically in M4-1. `ps` and `pgrep`
both walk sysctl under the hood — match them.

```swift
var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
var size: Int = 0
sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0)
let buffer = UnsafeMutableRawPointer.allocate(
    byteCount: size, alignment: MemoryLayout<kinfo_proc>.alignment)
defer { buffer.deallocate() }
sysctl(&mib, UInt32(mib.count), buffer, &size, nil, 0)
let table = UnsafeBufferPointer(
    start: buffer.bindMemory(to: kinfo_proc.self,
                             capacity: size / MemoryLayout<kinfo_proc>.stride),
    count: size / MemoryLayout<kinfo_proc>.stride)
// Each kinfo_proc gives kp_proc.p_pid, kp_eproc.e_ppid,
// kp_proc.p_comm, kp_proc.p_starttime.
```

**Existing hits:** `ProcessSnapshot` (the whole point).

**Don't:** trust libproc for process-tree introspection on Sequoia.
`proc_pid_rusage` (single-process CPU read) still works fine — it's
specifically the tree-walk APIs that are broken.

---

## 4. `proc_pid_rusage` returns mach absolute time units, NOT nanoseconds

**When:** Reading per-PID CPU time. Apple's docs scatter both claims.

**Why:** `ri_user_time` / `ri_system_time` are mach absolute time
counters straight from the xnu kernel. On Apple Silicon
`mach_timebase_info` reports 125/3 (≈ 41.67 ns / unit). Treating the
field as nanoseconds under-reports CPU by ~42×.

```swift
private static let machTimebase: mach_timebase_info_data_t = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return info
}()

private static func cpuSeconds(forPID pid: pid_t) -> TimeInterval {
    var info = rusage_info_current()
    let rc = withUnsafeMutablePointer(to: &info) { ptr in
        ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
            proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
        }
    }
    guard rc == 0 else { return 0 }
    let machTotal = info.ri_user_time + info.ri_system_time
    let ns = machTotal * UInt64(machTimebase.numer) / UInt64(machTimebase.denom)
    return TimeInterval(ns) / 1_000_000_000
}
```

**Existing hits:** `AgentStatusTracker.cpuSeconds(forPID:)`.

**Don't:** assume any `ri_*time` field is in nanoseconds. Always
multiply by the timebase ratio.

---

## 5. `HERMINAL_TEST_*` env-var hooks for integration testing

**When:** You need to drive an AppKit / SwiftUI flow from a shell
script without OS-level keyboard / mouse synthesis.

**Why:** osascript-style input synthesis is unreliable (focus stealing,
system IME composition). Env-driven hooks let `Scripts/verify-*.sh`
launch the binary with an explicit instruction set, observe the
side-effect on disk, and exit.

```swift
// AppDelegate sees an env var, fires a scripted action after a delay.
let env = ProcessInfo.processInfo.environment
if let spawnCommand = env["HERMINAL_TEST_SPAWN_COMMAND"] {
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        workspace.addTab(command: spawnCommand, title: "spawn-test")
    }
}
```

```bash
# Shell side asserts the side-effect:
HERMINAL_TEST_SPAWN_COMMAND="touch $MARKER" "$APP_BIN" &
sleep 8
[ -f "$MARKER" ] && echo PASS || echo FAIL
```

**Existing hits:** `HERMINAL_TEST_TEXT` (M4-0 inject), `HERMINAL_TEST_DELAY`
(M8 timing override), `HERMINAL_TEST_AGENT_DUMP` (M4-1),
`HERMINAL_TEST_TREE_DUMP` (M4-1 diagnostic),
`HERMINAL_TEST_SPAWN_COMMAND` (M4-4), `HERMINAL_TEST_SMOKE_PLAN` (M5).

**Don't:** add a hook the production code path also reads. Tag
every test env var with `HERMINAL_TEST_*` so the production path
can never accidentally branch on one.

---

## 6. Single-isolation `final class` stores with raw SQL

**When:** Persisting structured data locally.

**Why:** SQLite WAL gives atomic writes + indexable queries without
the schema-migration complexity of CoreData or the third-party churn
of larger ORMs. Wrapping it in a `final class` constrained to one
isolation domain makes the cross-thread story trivial.

```swift
public final class NotesStore {
    private let db: Connection

    public init(_ location: Connection.Location = .inMemory) throws {
        db = try Connection(location)
        try db.run("PRAGMA journal_mode = WAL")
        try migrate()
    }

    public func upsert(_ note: Note) throws {
        try db.run("INSERT INTO notes (id, body) VALUES (?, ?) ...",
                   note.id.uuidString, note.body)
    }
}
```

**Existing hits:** `NotesStore`, `SSHHostsStore`. `SSHConfigImporter`
parses the same shape but doesn't persist (caller upserts via
`SSHHostsStore`).

**Don't:** share one store instance across actors. Make a fresh one
per isolation domain or pin to `@MainActor`.

---

## 7. Coarse-but-honest > fine-but-misleading

**When:** A feature could ship with partial precision (e.g. "this agent
needs input" without knowing WHICH agent), and faking precision is
tempting.

**Why:** A confidently-wrong UX is worse than an honest "I don't know
yet." Users learn to trust the dashboard by it being right when it
claims something. Promote uncertainty by labelling broadly, then
narrow as data accrues.

```swift
// M8/A2 ships this — `any bell anywhere → all agents promoted to .needsInput`.
let anyBell = surfaceAddresses.contains {
    BellRegistry.shared.hasRecentBell(forSurfaceAddress: $0)
}
let final = anyBell
    ? annotated.map { agent in
        guard agent.status == .idle || agent.status == .running else { return agent }
        return DetectedAgent(..., status: .needsInput)
    }
    : annotated
```

```swift
// M9/A3 ships per-tab attribution — promotion now CARRIES tabHint
// through so the user sees both `needs input` AND the tab number.
let mapped = AgentPaneMapper.annotate(annotated,
                                      sessionStartTimes: sessionStarts)
```

**Existing hits:** `AgentStatusTracker` first-sighting `.unknown`,
`AgentPaneMapper` nil tabHint when pairing fails, M6 dogfood day-1
"AI can't feel friction" entry.

**Don't:** invent a value to avoid showing `.unknown` / nil. The
honest blank is a feature.

---

## When to add to this doc

Add a section when the same pattern shows up in a THIRD place. Two
hits is coincidence; three is convention. Keep examples short — link
to the live code rather than inlining the full file.
