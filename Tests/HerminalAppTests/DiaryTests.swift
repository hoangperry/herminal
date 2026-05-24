import Foundation
import Testing
@testable import HerminalApp

@Suite("Diary")
struct DiaryTests {
    /// The diary is a singleton because the crash-signal handler can only
    /// hold one open file descriptor — so these tests share the live
    /// instance rather than mock it. We only assert behaviours that don't
    /// race with the periodic flush timer.
    private var diary: Diary { Diary.shared }

    @Test("log appends to the in-memory ring buffer")
    func logAppends() async throws {
        let marker = "diary-test-\(UUID().uuidString)"
        diary.log(marker, category: "test")
        // log() dispatches onto a serial queue — give it a beat so the
        // ring write definitely lands before we read it back.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(diary.recentEntries().contains(where: { $0.contains(marker) }))
    }

    @Test("log entries carry the supplied category")
    func categoryAppearsInEntry() async throws {
        let marker = "cat-test-\(UUID().uuidString)"
        diary.log(marker, category: "ssh")
        try await Task.sleep(nanoseconds: 100_000_000)
        let hit = diary.recentEntries().first { $0.contains(marker) }
        let entry = try #require(hit)
        #expect(entry.contains("[ssh]"))
    }

    @Test("log entries start with an ISO 8601 timestamp")
    func entryHasTimestamp() async throws {
        let marker = "stamp-test-\(UUID().uuidString)"
        diary.log(marker, category: "test")
        try await Task.sleep(nanoseconds: 100_000_000)
        let hit = diary.recentEntries().first { $0.contains(marker) }
        let entry = try #require(hit)
        // ISO 8601 with fractional seconds always begins with a 4-digit
        // year + a `-`. Cheap shape check that survives time-zone drift.
        let year = entry.prefix(4)
        #expect(year.allSatisfy { $0.isNumber })
        #expect(entry[entry.index(entry.startIndex, offsetBy: 4)] == "-")
    }

    @Test("flush completes without blocking forever")
    func flushReturns() async throws {
        diary.log("pre-flush", category: "test")
        // If the queue were to deadlock the test would hang here. We let
        // Swift Testing's default timeout (60s) catch that case.
        diary.flush()
    }

    // MARK: - M9/F redaction

    @Test("redact rewrites the current user's home prefix")
    func redactRewritesOwnHome() {
        let home = NSHomeDirectory()
        let input = "saved note at \(home)/Library/Application Support/herminal/notes.db"
        let out = Diary.redact(input)
        #expect(!out.contains(home))
        #expect(out.contains("/Users/<redacted>"))
    }

    @Test("redact catches other /Users/* paths too")
    func redactCatchesOtherUsers() {
        let input = "diff between /Users/alice/x and /Users/bob/y"
        let out = Diary.redact(input)
        #expect(!out.contains("/Users/alice"))
        #expect(!out.contains("/Users/bob"))
        // Replaced count == 2.
        let count = out.components(separatedBy: "/Users/<redacted>").count - 1
        #expect(count == 2)
    }

    @Test("redact anonymises libghostty surface addresses")
    func redactSurfaceAddresses() {
        let input = "[bell] surface=0x7f9c8e003a40 rang"
        let out = Diary.redact(input)
        #expect(out.contains("0x<addr>"))
        #expect(!out.contains("0x7f9c8e003a40"))
    }

    @Test("redact preserves PIDs — they're useful and not PII")
    func redactKeepsPIDs() {
        let input = "[lifecycle] === herminal launched pid=12345 ==="
        let out = Diary.redact(input)
        #expect(out.contains("pid=12345"))
    }

    @Test("exportRedacted returns recent entries with all rules applied")
    func exportRedactedRunsRules() async throws {
        // Seed a small, deterministic shape — diary singleton shares
        // state across cases so we tolerate older entries by suffix.
        let home = NSHomeDirectory()
        diary.log("note at \(home)/file", category: "test")
        diary.log("[bell] surface=0xfeedbeef rang", category: "test")
        try await Task.sleep(nanoseconds: 100_000_000)
        let out = diary.exportRedacted(maxLines: 200)
        #expect(!out.contains(home))
        #expect(!out.contains("0xfeedbeef"))
        #expect(out.contains("/Users/<redacted>"))
        #expect(out.contains("0x<addr>"))
    }
}
