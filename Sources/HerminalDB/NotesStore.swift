// NotesStore — SQLite WAL storage for per-session notes.
// Local-only; no network, no sync. FileVault is the at-rest baseline.

import Foundation
import SQLite

/// A note attached to one terminal session.
public struct Note: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sessionID: UUID
    public var body: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        body: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum NotesError: Error, Equatable {
    case malformedRow
}

/// CRUD store for notes. Use from a single isolation domain (the notes UI
/// runs on the main actor; tests drive it synchronously).
public final class NotesStore {
    private let db: Connection

    /// Opens (or creates) a notes database at `location` and runs migrations.
    public init(_ location: Connection.Location = .inMemory) throws {
        db = try Connection(location)
        try db.run("PRAGMA journal_mode = WAL")
        try db.run("PRAGMA foreign_keys = ON")
        try migrate()
    }

    private func migrate() throws {
        try db.run("""
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                body TEXT NOT NULL DEFAULT '',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """)
        try db.run("CREATE INDEX IF NOT EXISTS idx_notes_session ON notes(session_id)")
    }

    /// The note for a session, if one exists.
    public func note(forSession sessionID: UUID) throws -> Note? {
        let rows = try db.prepare(
            """
            SELECT id, session_id, body, created_at, updated_at
            FROM notes WHERE session_id = ? LIMIT 1
            """,
            sessionID.uuidString
        )
        for row in rows {
            return try Self.decode(row)
        }
        return nil
    }

    /// Inserts or updates a note (keyed by `id`).
    public func upsert(_ note: Note) throws {
        try db.run(
            """
            INSERT INTO notes (id, session_id, body, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                body = excluded.body,
                updated_at = excluded.updated_at
            """,
            note.id.uuidString,
            note.sessionID.uuidString,
            note.body,
            note.createdAt.timeIntervalSince1970,
            note.updatedAt.timeIntervalSince1970
        )
    }

    public func delete(id: UUID) throws {
        try db.run("DELETE FROM notes WHERE id = ?", id.uuidString)
    }

    /// All notes, most recently updated first.
    public func allNotes() throws -> [Note] {
        let rows = try db.prepare(
            """
            SELECT id, session_id, body, created_at, updated_at
            FROM notes ORDER BY updated_at DESC
            """
        )
        return try rows.map { try Self.decode($0) }
    }

    private static func decode(_ row: [Binding?]) throws -> Note {
        guard
            let idString = row[0] as? String, let id = UUID(uuidString: idString),
            let sessionString = row[1] as? String, let sessionID = UUID(uuidString: sessionString),
            let body = row[2] as? String,
            let created = row[3] as? Double,
            let updated = row[4] as? Double
        else {
            throw NotesError.malformedRow
        }
        return Note(
            id: id,
            sessionID: sessionID,
            body: body,
            createdAt: Date(timeIntervalSince1970: created),
            updatedAt: Date(timeIntervalSince1970: updated)
        )
    }
}
