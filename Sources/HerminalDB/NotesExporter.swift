// NotesExporter — round-trips a note between the store and a .md file.
//
// A note's body is plain markdown text, so export/import is a direct
// file write/read. Database metadata (id, timestamps) stays in SQLite and
// is not round-tripped through the file.

import Foundation

public enum NotesExporter {
    /// Writes a note's body to a markdown file.
    public static func exportMarkdown(_ note: Note, to url: URL) throws {
        try note.body.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reads a markdown file into a new note for the given session.
    public static func importMarkdown(from url: URL, sessionID: UUID) throws -> Note {
        let body = try String(contentsOf: url, encoding: .utf8)
        return Note(sessionID: sessionID, body: body)
    }
}
