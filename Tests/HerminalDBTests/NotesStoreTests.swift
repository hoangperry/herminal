import Foundation
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
}
