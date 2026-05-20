// HerminalDB — SQLite WAL storage for notes, sessions, and agent runs.
// Schema: sessions, notes, agent_runs, schema_migrations.
// Local-only, no network. FileVault baseline encryption.

import Foundation

public enum HerminalDB {
    public static let schemaVersion = 1
}
