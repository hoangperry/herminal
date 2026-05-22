import Foundation
import Testing
@testable import HerminalDB

@Suite("NotesExporter")
struct NotesExporterTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-note-\(UUID().uuidString).md")
    }

    @Test("export then import round-trips the note body")
    func roundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let original = Note(sessionID: UUID(), body: "# Ghi chú\n\n- mục tiếng Việt")
        try NotesExporter.exportMarkdown(original, to: url)

        let session = UUID()
        let imported = try NotesExporter.importMarkdown(from: url, sessionID: session)
        #expect(imported.body == original.body)
        #expect(imported.sessionID == session)
    }

    @Test("exported file is valid UTF-8 markdown on disk")
    func exportedFileContents() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let note = Note(sessionID: UUID(), body: "plain body")
        try NotesExporter.exportMarkdown(note, to: url)

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == "plain body")
    }
}
