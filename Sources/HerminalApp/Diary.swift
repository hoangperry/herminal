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
        // unified with libghostty's own log stream.
        NSLog("%@", entry)
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

    private static func format(_ message: String, category: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: Date())
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

    /// FD opened to the diary file at process start; the signal handler
    /// writes raw bytes through this without touching Swift state.
    private nonisolated(unsafe) static var crashFD: Int32 = -1

    private func installCrashHandlers() {
        Diary.crashFD = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
        guard Diary.crashFD >= 0 else { return }
        for sig in [SIGSEGV, SIGBUS, SIGABRT, SIGILL, SIGFPE] {
            var action = sigaction()
            action.__sigaction_u = unsafeBitCast(
                Diary.crashHandler as (@convention(c) (Int32) -> Void),
                to: __sigaction_u.self
            )
            action.sa_flags = 0
            sigemptyset(&action.sa_mask)
            sigaction(sig, &action, nil)
        }
    }

    /// Async-signal-safe crash recorder. Stays inside `write(2)` + integer
    /// formatting so it can't deadlock on a Swift runtime lock or allocate.
    /// `nonisolated(unsafe)`: a C function pointer can't carry actor
    /// isolation, and the body touches only `crashFD` (assigned once at
    /// init) plus stack-local integer state.
    private nonisolated(unsafe) static let crashHandler: @convention(c) (Int32) -> Void = { signal in
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
        let fd = Diary.crashFD
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
}

/// Reset the signal to default and re-raise so macOS's crash reporter
/// still gets called after our diary write completes.
private func signalRaiseDefault(_ sig: Int32) {
    var action = sigaction()
    action.__sigaction_u = unsafeBitCast(SIG_DFL, to: __sigaction_u.self)
    sigaction(sig, &action, nil)
    raise(sig)
}
