import Foundation
import SQLite
import Testing
@testable import HerminalDB

@Suite("NotesStore")
struct NotesStoreTests {
    @Test("upsert then fetch round-trips a note")
    func upsertAndFetch() throws {
        let store = try NotesStore()
        let session = UUID()
        let note = Note(sessionID: session, body: "ghi chú tiếng Việt")
        try store.upsert(note)

        let fetched = try store.note(forSession: session)
        #expect(fetched?.id == note.id)
        #expect(fetched?.body == "ghi chú tiếng Việt")
    }

    @Test("upsert updates the body of an existing note")
    func upsertUpdatesBody() throws {
        let store = try NotesStore()
        let session = UUID()
        var note = Note(sessionID: session, body: "first")
        try store.upsert(note)

        note.body = "second"
        note.updatedAt = Date()
        try store.upsert(note)

        let fetched = try store.note(forSession: session)
        #expect(fetched?.body == "second")
        let all = try store.allNotes()
        #expect(all.count == 1) // updated, not duplicated
    }

    @Test("note(forSession:) returns nil for an unknown session")
    func missingSessionReturnsNil() throws {
        let store = try NotesStore()
        #expect(try store.note(forSession: UUID()) == nil)
    }

    @Test("delete removes a note")
    func deleteRemovesNote() throws {
        let store = try NotesStore()
        let note = Note(sessionID: UUID(), body: "temp")
        try store.upsert(note)
        try store.delete(id: note.id)
        #expect(try store.allNotes().isEmpty)
    }

    @Test("allNotes is ordered by most recently updated")
    func allNotesOrdering() throws {
        let store = try NotesStore()
        let old = Note(
            sessionID: UUID(), body: "old",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let recent = Note(
            sessionID: UUID(), body: "recent",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        try store.upsert(old)
        try store.upsert(recent)

        let all = try store.allNotes()
        #expect(all.first?.body == "recent")
        #expect(all.last?.body == "old")
    }

    @Test("upsert keeps one logical note per session and preserves the canonical id")
    func upsertPreservesCanonicalRowForSession() throws {
        let store = try NotesStore()
        let sessionID = UUID()
        let canonicalID = UUID()
        let duplicateID = UUID()

        try store.upsert(
            Note(
                id: canonicalID,
                sessionID: sessionID,
                body: "first body",
                createdAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 200)
            )
        )

        try store.upsert(
            Note(
                id: duplicateID,
                sessionID: sessionID,
                body: "updated body",
                createdAt: Date(timeIntervalSince1970: 300),
                updatedAt: Date(timeIntervalSince1970: 400)
            )
        )

        let fetched = try #require(try store.note(forSession: sessionID))
        let all = try store.allNotes().filter { $0.sessionID == sessionID }

        #expect(all.count == 1)
        #expect(fetched.id == canonicalID)
        #expect(fetched.body == "updated body")
    }

    @Test("legacy duplicate rows for one session read back deterministically")
    func duplicateSessionRowsReadBackCanonicalNote() throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notes-store-\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let store = try NotesStore(.uri(dbURL.path()))
        let db = try Connection(.uri(dbURL.path()))
        let sessionID = UUID()
        let staleID = UUID()
        let canonicalID = UUID()

        try db.run(
            """
            INSERT INTO notes (id, session_id, body, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            staleID.uuidString,
            sessionID.uuidString,
            "stale body",
            100.0,
            200.0
        )
        try db.run(
            """
            INSERT INTO notes (id, session_id, body, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            canonicalID.uuidString,
            sessionID.uuidString,
            "canonical body",
            100.0,
            300.0
        )

        let fetched = try #require(try store.note(forSession: sessionID))
        let all = try store.allNotes()

        #expect(fetched.id == canonicalID)
        #expect(fetched.body == "canonical body")
        #expect(all.count == 1)
        #expect(all.first?.id == canonicalID)
        #expect(all.first?.body == "canonical body")
    }

    @Test("deleting the canonical id removes a duplicate session logically")
    func deleteCanonicalIDRemovesLogicalSession() throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notes-store-\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: dbURL) }

        let store = try NotesStore(.uri(dbURL.path()))
        let db = try Connection(.uri(dbURL.path()))
        let sessionID = UUID()
        let staleID = UUID()
        let canonicalID = UUID()

        try db.run(
            """
            INSERT INTO notes (id, session_id, body, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            staleID.uuidString,
            sessionID.uuidString,
            "stale body",
            100.0,
            200.0
        )
        try db.run(
            """
            INSERT INTO notes (id, session_id, body, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            canonicalID.uuidString,
            sessionID.uuidString,
            "canonical body",
            100.0,
            300.0
        )

        try store.delete(id: canonicalID)

        #expect(try store.note(forSession: sessionID) == nil)
        let logicalRows = try store.allNotes().filter { $0.sessionID == sessionID }
        #expect(logicalRows.isEmpty)
    }
}
