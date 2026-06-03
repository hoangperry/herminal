// Diary — telemetry-free crash diary for dogfood.
//
// herminal sends nothing over the network. When something goes wrong in M6
// daily driving the owner needs a local file to look at: what was happening
// right before the bad thing, and (for hard crashes) which signal landed.
//
// Two layers:
// - Ring buffer of the last 200 entries in memory, flushed to disk on a
//   timer and at process exit.
// - Signal handler that writes a final "CRASHED signal=N" line to a pre-
//   opened file descriptor using `write(2)` — that's async-signal-safe,
//   unlike anything that touches Swift strings or Foundation IO.
//
// File: `~/Library/Application Support/herminal/diary.log` (append-only,
// truncated to ~1 MB on startup to keep it readable in Console.app).

import Foundation
import Darwin

public final class Diary: @unchecked Sendable {
    public static let shared = Diary()

    /// Ring buffer size — 200 entries covers roughly the last 5 minutes of
    /// normal use (one entry per significant action).
    private static let ringCapacity = 200

    /// Soft cap on the on-disk file. At every launch we truncate to the
    /// last ~1 MB so the diary stays grep-able and doesn't grow unbounded.
    private static let maxFileBytes = 1_048_576

    private let queue = DispatchQueue(label: "com.hoangperry.herminal.diary",
                                      qos: .utility)
    private let fileURL: URL
    /// `nonisolated(unsafe)`: only mutated/read inside `queue`; the C signal
    /// handler reads `crashFD` (no Swift state) which is set once at init.
    private nonisolated(unsafe) var fileHandle: FileHandle?
    private nonisolated(unsafe) var ring: [String] = []

    /// Lazily resolved Application Support directory. Falls back to /tmp so
    /// the diary still works in sandboxed test runs.
    private static func resolveLogDirectory() -> URL {
        let fm = FileManager.default
        if let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil, create: true) {
            let dir = appSupport.appendingPathComponent("herminal", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        return URL(fileURLWithPath: "/tmp")
    }

    private init() {
        let dir = Self.resolveLogDirectory()
        self.fileURL = dir.appendingPathComponent("diary.log")
        self.fileHandle = Self.openFile(at: fileURL)
        // Schedule a periodic flush so the ring keeps spilling to disk even
        // when nothing crashes — the dogfood owner shouldn't have to quit
        // herminal to see the latest events.
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.scheduleFlush()
        }
        installCrashHandlers()
        log("=== herminal launched pid=\(getpid()) ===", category: "lifecycle")
    }

    /// Append a single event. Safe to call from any thread.
    public func log(_ message: String, category: String = "app") {
        let entry = Self.format(message, category: category)
        queue.async { [weak self] in
            guard let self else { return }
            self.ring.append(entry)
            if self.ring.count > Self.ringCapacity {
                self.ring.removeFirst(self.ring.count - Self.ringCapacity)
            }
            self.append(entry: entry)
        }
        // Also forward to NSLog so Console.app users see the same events
        // unified with libghostty's own log stream. The local diary file
        // keeps full fidelity, but NSLog lands in the system-wide unified
        // log that ANY local process can read (`log stream`), so redact
        // the home-username prefix + surface addresses before it leaves
        // (v0.4.3 security review F3 — keep PII out of the shared log).
        NSLog("%@", Self.redact(entry))
    }

    /// Snapshot of recent entries — used by tests + (eventually) the future
    /// "Help → Show Diary" menu item.
    public func recentEntries() -> [String] {
        queue.sync { ring }
    }

    /// Force-flush the buffer to disk. Called on process exit and before
    /// the periodic re-arm of the flush timer.
    public func flush() {
        queue.sync {
            try? self.fileHandle?.synchronize()
        }
    }

    /// Current on-disk file size. Returns 0 if stat fails (e.g. the file
    /// hasn't been created yet, or in test runs that point at a missing
    /// directory). Cheap — single `stat(2)`, safe to call from the UI
    /// thread.
    public func fileSizeBytes() -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = attrs?[.size] as? NSNumber else { return 0 }
        return size.int64Value
    }

    /// Exports the diary's last `maxLines` entries with PII redacted —
    /// suitable for pasting into a GitHub bug report. The promise from
    /// `SECURITY.md` is that herminal sends nothing over the network on
    /// its own; this method exists so the OWNER can opt-in to sharing
    /// the diary with full visibility of exactly what bytes leave the
    /// machine.
    ///
    /// Redactions:
    /// - User home prefix (`/Users/<name>`) → `/Users/<redacted>`
    /// - libghostty surface addresses (`0x[0-9a-f]+`) → `0x<addr>`
    /// - PIDs are KEPT — they're useful for cross-referencing the
    ///   crash diary's signal handler line with the process tree at
    ///   the time of crash, and they're meaningless to anyone outside
    ///   the machine that produced them.
    public func exportRedacted(maxLines: Int = 200) -> String {
        let snapshot = recentEntries().suffix(maxLines)
        return snapshot
            .map(Self.redact)
            .joined(separator: "\n")
    }

    /// Internal-but-public so the test suite can verify the redaction
    /// rules without touching the live disk file. Stateless.
    public static func redact(_ entry: String) -> String {
        let homePrefix = NSHomeDirectory()
        // 1. Substring replace the user's specific home (e.g.
        //    `/Users/hoangperry`) with `/Users/<redacted>`. Catches
        //    everything below the home too (`/Users/x/Library/...`).
        var redacted = entry
        if !homePrefix.isEmpty, redacted.contains(homePrefix) {
            redacted = redacted.replacingOccurrences(of: homePrefix,
                                                     with: "/Users/<redacted>")
        }
        // 2. Generic `/Users/<anything-but-/>` catch-all for entries
        //    that mention OTHER users' homes (rare, but possible if
        //    the user ran `ls /Users/...` and we logged a derived path).
        if let re = try? NSRegularExpression(
            pattern: #"/Users/[^/\s"']+"#, options: [.caseInsensitive]
        ) {
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = re.stringByReplacingMatches(
                in: redacted, range: range, withTemplate: "/Users/<redacted>")
        }
        // 3. libghostty surface addresses — high-entropy pointer ints
        //    aren't PII but they're noise on the report side.
        if let re = try? NSRegularExpression(
            pattern: #"0x[0-9a-fA-F]{6,}"#, options: []
        ) {
            let range = NSRange(redacted.startIndex..., in: redacted)
            redacted = re.stringByReplacingMatches(
                in: redacted, range: range, withTemplate: "0x<addr>")
        }
        return redacted
    }

    // MARK: - Internal

    private func append(entry: String) {
        guard let handle = fileHandle else { return }
        if let data = (entry + "\n").data(using: .utf8) {
            try? handle.write(contentsOf: data)
        }
    }

    private func scheduleFlush() {
        queue.async { [weak self] in
            try? self?.fileHandle?.synchronize()
            self?.queue.asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.scheduleFlush()
            }
        }
    }

    /// ISO8601DateFormatter allocates a Calendar + locale + ICU structures
    /// on init — about 100 µs each time. log() runs on every state change,
    /// so we cache the formatter for the process lifetime. (M11-A2 fix,
    /// MEDIUM M-1 from code-reviewer.)
    /// `nonisolated(unsafe)`: ISO8601DateFormatter isn't Sendable, but its
    /// `string(from:)` method is documented as thread-safe since macOS 10.10.
    /// We only call that one method, never mutate the formatOptions after
    /// the initializer ran, so the unsafe annotation is sound.
    private nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func format(_ message: String, category: String) -> String {
        let stamp = isoFormatter.string(from: Date())
        return "\(stamp) [\(category)] \(message)"
    }

    private static func openFile(at url: URL) -> FileHandle? {
        let fm = FileManager.default
        // Truncate stale large logs at launch — keeps the tail-N portion the
        // owner cares about. Atomic-ish: read tail, replace file.
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int, size > maxFileBytes {
            if let data = try? Data(contentsOf: url) {
                let tail = data.suffix(maxFileBytes)
                try? tail.write(to: url, options: .atomic)
            }
        }
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return nil }
        try? handle.seekToEnd()
        return handle
    }

    // MARK: - Signal handlers (async-signal-safe ONLY)

    private func installCrashHandlers() {
        // M11-A2 fix (CRITICAL from code-reviewer): the FD + the handler
        // closure used to be `static let` on Diary. Both went through
        // `swift_once` lazy initialisation. A signal that fires from a
        // thread holding the swift_once lock — or before any normal-path
        // code touched the statics — would deadlock the runtime, which
        // is the opposite of async-signal-safe. Moved both to file-scope
        // module-level vars (declared below) so reads from signal context
        // hit raw memory with no runtime path.
        //
        // File mode tightened from 0o644 to 0o600 per security-reviewer M-3
        // — the diary now stores nothing world-readable.
        _diaryCrashFD = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
        guard _diaryCrashFD >= 0 else { return }
        for sig in [SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE] {
            var action = sigaction()
            action.__sigaction_u = unsafeBitCast(
                _diaryCrashHandler,
                to: __sigaction_u.self
            )
            action.sa_flags = 0
            sigemptyset(&action.sa_mask)
            sigaction(sig, &action, nil)
        }
    }
}

// MARK: - Signal-handler globals
//
// File-scope so the signal handler can touch them without traversing
// any swift_once or actor-isolation path. Both are written exactly once
// — `_diaryCrashFD` in `Diary.installCrashHandlers` before sigaction
// registers the handler, `_diaryCrashHandler` at module-load via the
// fact that it has no captures (a @convention(c) closure with no
// captures is materialised eagerly, no swift_once).

nonisolated(unsafe) var _diaryCrashFD: Int32 = -1

/// Async-signal-safe crash recorder. Stays inside `write(2)` + integer
/// formatting so it can't deadlock on a Swift runtime lock or allocate.
let _diaryCrashHandler: @convention(c) (Int32) -> Void = { signal in
    let prefix = "\n=== CRASHED signal=".utf8CString
    let suffix = " ===\n".utf8CString
    var sigBuf = [CChar](repeating: 0, count: 16)
    var n = Int32(signal)
    var idx = sigBuf.count - 1
    // Itoa, base-10, no allocations.
    if n == 0 { sigBuf[idx] = 48; idx -= 1 }
    while n > 0 && idx >= 0 {
        sigBuf[idx] = CChar(48 + (n % 10))
        n /= 10
        idx -= 1
    }
    let fd = _diaryCrashFD
    prefix.withUnsafeBufferPointer { ptr in
        _ = write(fd, ptr.baseAddress, prefix.count - 1)
    }
    sigBuf.withUnsafeBufferPointer { ptr in
        _ = write(fd, ptr.baseAddress! + idx + 1,
                  sigBuf.count - idx - 2)
    }
    suffix.withUnsafeBufferPointer { ptr in
        _ = write(fd, ptr.baseAddress, suffix.count - 1)
    }
    // Re-raise so the OS still produces the crash report.
    signalRaiseDefault(signal)
}

/// Reset the signal to default and re-raise so macOS's crash reporter
/// still gets called after our diary write completes.
private func signalRaiseDefault(_ sig: Int32) {
    var action = sigaction()
    action.__sigaction_u = unsafeBitCast(SIG_DFL, to: __sigaction_u.self)
    sigaction(sig, &action, nil)
    raise(sig)
}
