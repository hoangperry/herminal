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
    private struct StoredNoteRow {
        let id: String
        let sessionID: String
        let body: String
        let createdAt: Double
        let updatedAt: Double
    }

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
        guard let row = try canonicalRow(forSession: sessionID) else { return nil }
        return try Self.decode(row)
    }

    /// Inserts or updates a note, treating `session_id` as the logical key.
    /// A fresh caller-supplied UUID must not create a second row for the same
    /// session if a canonical note already exists.
    public func upsert(_ note: Note) throws {
        try db.transaction(.immediate) {
            if let existing = try canonicalRow(forSession: note.sessionID) {
                try db.run(
                    """
                    UPDATE notes
                    SET body = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    note.body,
                    note.updatedAt.timeIntervalSince1970,
                    existing.id
                )
                return
            }

            let insertID = try insertID(for: note)
            try db.run(
                """
                INSERT INTO notes (id, session_id, body, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                insertID,
                note.sessionID.uuidString,
                note.body,
                note.createdAt.timeIntervalSince1970,
                note.updatedAt.timeIntervalSince1970
            )
        }
    }

    public func delete(id: UUID) throws {
        try db.transaction(.immediate) {
            guard
                let sessionID = try db.scalar(
                    "SELECT session_id FROM notes WHERE id = ? LIMIT 1",
                    id.uuidString
                ) as? String
            else {
                return
            }
            try db.run("DELETE FROM notes WHERE session_id = ?", sessionID)
        }
    }

    /// All notes, most recently updated first.
    public func allNotes() throws -> [Note] {
        let rows = try db.prepare(
            """
            SELECT id, session_id, body, created_at, updated_at
            FROM (
                SELECT id, session_id, body, created_at, updated_at,
                       ROW_NUMBER() OVER (
                           PARTITION BY session_id
                           ORDER BY updated_at DESC, created_at DESC, rowid DESC
                       ) AS session_rank
                FROM notes
            )
            WHERE session_rank = 1
            ORDER BY updated_at DESC, created_at DESC, session_id ASC, id ASC
            """
        )
        return try rows.map { try Self.decode(try Self.decodeStoredRow($0)) }
    }

    private func canonicalRow(forSession sessionID: UUID) throws -> StoredNoteRow? {
        let rows = try db.prepare(
            """
            SELECT id, session_id, body, created_at, updated_at
            FROM notes
            WHERE session_id = ?
            ORDER BY updated_at DESC, created_at DESC, rowid DESC
            LIMIT 1
            """,
            sessionID.uuidString
        )
        for row in rows {
            return try Self.decodeStoredRow(row)
        }
        return nil
    }

    private func insertID(for note: Note) throws -> String {
        guard
            let existingSessionID = try db.scalar(
                "SELECT session_id FROM notes WHERE id = ? LIMIT 1",
                note.id.uuidString
            ) as? String
        else {
            return note.id.uuidString
        }

        return existingSessionID == note.sessionID.uuidString
            ? note.id.uuidString
            : UUID().uuidString
    }

    private static func decodeStoredRow(_ row: [Binding?]) throws -> StoredNoteRow {
        guard
            let id = row[0] as? String,
            let sessionID = row[1] as? String,
            let body = row[2] as? String,
            let created = row[3] as? Double,
            let updated = row[4] as? Double
        else {
            throw NotesError.malformedRow
        }
        return StoredNoteRow(
            id: id,
            sessionID: sessionID,
            body: body,
            createdAt: created,
            updatedAt: updated
        )
    }

    private static func decode(_ row: StoredNoteRow) throws -> Note {
        guard
            let id = UUID(uuidString: row.id),
            let sessionID = UUID(uuidString: row.sessionID)
        else {
            throw NotesError.malformedRow
        }
        return Note(
            id: id,
            sessionID: sessionID,
            body: row.body,
            createdAt: Date(timeIntervalSince1970: row.createdAt),
            updatedAt: Date(timeIntervalSince1970: row.updatedAt)
        )
    }
}
