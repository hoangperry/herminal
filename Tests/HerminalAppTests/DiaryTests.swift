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
}
