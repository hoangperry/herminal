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
import HerminalCrashHandler

public final class Diary: @unchecked Sendable {
    public static let shared = Diary()

    /// Ring buffer size — 200 entries covers roughly the last 5 minutes of
    /// normal use (one entry per significant action).
    private static let ringCapacity = 200

    private let queue = DispatchQueue(label: "com.hoangperry.herminal.diary",
                                      qos: .utility)
    /// `nonisolated(unsafe)`: only mutated/read inside `queue`; the crash
    /// handler uses its own duplicated descriptor and precomputed byte store.
    private nonisolated(unsafe) var fileHandle: FileHandle?
    private nonisolated(unsafe) var ring: [String] = []

    /// Lazily resolved Application Support directory. Falls back to a private
    /// per-user temporary subdirectory so sandboxed test runs still work.
    private static func resolveLogDirectory() -> URL? {
        let fm = FileManager.default
        if let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil, create: true) {
            if let directory = prepareLogDirectory(in: appSupport, name: "herminal") {
                return directory
            }
        }
        return prepareLogDirectory(
            in: fm.temporaryDirectory,
            name: "herminal-\(geteuid())"
        )
    }

    static func prepareLogDirectory(in parentURL: URL, name: String) -> URL? {
        DiaryFileAccess.preparePrivateDirectory(in: parentURL, name: name)
    }

    private init() {
        self.fileHandle = Self.resolveLogDirectory().flatMap { directory in
            Self.openFile(at: directory.appendingPathComponent("diary.log"))
        }
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

    /// Snapshot of recent entries — used by tests and by the Help menu's
    /// privacy-redacted diagnostic copy action.
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
        queue.sync {
            guard let descriptor = fileHandle?.fileDescriptor else { return 0 }
            var fileInfo = stat()
            guard fstat(descriptor, &fileInfo) == 0 else { return 0 }
            return Int64(fileInfo.st_size)
        }
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
        queue.sync {
            try? fileHandle?.synchronize()
            return Self.exportRedacted(
                from: fileHandle,
                fallbackEntries: ring,
                maxLines: maxLines
            )
        }
    }

    /// Reads the persisted tail so a relaunch can still export the previous
    /// session's crash context. The live ring is used only when the file is
    /// unavailable or empty.
    static func exportRedacted(
        from fileHandle: FileHandle?,
        fallbackEntries: [String],
        maxLines: Int
    ) -> String {
        guard maxLines > 0 else { return "" }
        let persistedEntries: [String]? = persistedData(from: fileHandle)
            .flatMap { data in
                guard !data.isEmpty else { return nil }
                return String(decoding: data, as: UTF8.self)
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
            }
        let snapshot = (persistedEntries ?? fallbackEntries).suffix(maxLines)
        return snapshot
            .map(Self.redact)
            .joined(separator: "\n")
    }

    private static func persistedData(from fileHandle: FileHandle?) -> Data? {
        DiaryFileAccess.persistedData(from: fileHandle)
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

    /// Opens the diary path once and performs every validation/truncation step
    /// through that descriptor. Internal so security regressions can exercise
    /// real filesystem semantics without touching the singleton's live log.
    static func openFile(at url: URL) -> FileHandle? {
        DiaryFileAccess.openFile(at: url)
    }

    static func preparedCrashMessage(for signal: Int32) -> String? {
        var length = 0
        guard let message = herminal_crash_message_for_signal(signal, &length) else {
            return nil
        }
        let bytes = UnsafeBufferPointer(
            start: UnsafeRawPointer(message).assumingMemoryBound(to: UInt8.self),
            count: length
        )
        return String(decoding: bytes, as: UTF8.self)
    }

    static func duplicateCrashDescriptor(from descriptor: Int32) -> Int32 {
        herminal_duplicate_crash_descriptor(descriptor)
    }

    // MARK: - Signal handlers (async-signal-safe ONLY)

    private func installCrashHandlers() {
        // Signal handling lives entirely in C so compiler-inserted Swift
        // exclusivity/runtime calls cannot enter the crash path.
        //
        // File mode tightened from 0o644 to 0o600 per security-reviewer M-3
        // — the diary now stores nothing world-readable.
        guard let fileHandle else { return }
        _ = herminal_install_crash_handlers(fileHandle.fileDescriptor)
    }
}
