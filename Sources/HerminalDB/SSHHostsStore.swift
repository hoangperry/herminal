// SSHHostsStore — SQLite WAL storage for SSH connection metadata.
// Local-only; no network, no sync. Mirrors NotesStore's pattern so the
// codebase has one persistent-store idiom. Q4-001 decided on SQLite over
// plist for symmetry + indexing headroom; row count stays small (5–50 hosts
// typical) but the cost of SQLite over plist is essentially nil at this size.

import Foundation
import SQLite

/// One SSH host the user has saved in the connection manager.
/// Secrets (passwords, key paths) live in `~/.ssh/config` or Keychain —
/// herminal only stores user-curated metadata.
public struct SSHHost: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var nickname: String
    public var hostname: String
    public var user: String
    public var port: Int
    public let createdAt: Date
    public var updatedAt: Date
    public var lastConnectedAt: Date?

    public init(
        id: UUID = UUID(),
        nickname: String,
        hostname: String,
        user: String,
        port: Int = 22,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.hostname = hostname
        self.user = user
        self.port = port
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastConnectedAt = lastConnectedAt
    }

    /// Bumps `updatedAt` — call after edits before persisting so the UI's
    /// recent-first ordering reflects the change.
    public mutating func touch(at instant: Date = Date()) {
        updatedAt = instant
    }

    /// Validates user input and returns a fully formed host, throwing if
    /// the input is unusable. The UI layer should call this before upsert.
    public static func validated(
        id: UUID = UUID(),
        nickname: String,
        hostname: String,
        user: String,
        port: Int = 22
    ) throws -> SSHHost {
        let trimmedHost = hostname.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else { throw SSHHostError.emptyHostname }
        guard (1...65535).contains(port) else { throw SSHHostError.invalidPort(port) }
        let trimmedUser = user.trimmingCharacters(in: .whitespaces)
        let trimmedNick = nickname.trimmingCharacters(in: .whitespaces)
        return SSHHost(
            id: id,
            nickname: trimmedNick.isEmpty ? "\(trimmedUser)@\(trimmedHost)" : trimmedNick,
            hostname: trimmedHost,
            user: trimmedUser.isEmpty ? NSUserName() : trimmedUser,
            port: port
        )
    }
}

public enum SSHHostError: Error, Equatable {
    case emptyHostname
    case invalidPort(Int)
    case malformedRow
}

/// CRUD store for SSH hosts. Same isolation contract as NotesStore: use
/// from a single isolation domain.
public final class SSHHostsStore {
    private let db: Connection

    public init(_ location: Connection.Location = .inMemory) throws {
        db = try Connection(location)
        try db.run("PRAGMA journal_mode = WAL")
        try db.run("PRAGMA foreign_keys = ON")
        try migrate()
    }

    private func migrate() throws {
        try db.run("""
            CREATE TABLE IF NOT EXISTS ssh_hosts (
                id TEXT PRIMARY KEY,
                nickname TEXT NOT NULL,
                hostname TEXT NOT NULL,
                username TEXT NOT NULL,
                port INTEGER NOT NULL DEFAULT 22,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                last_connected_at REAL
            )
            """)
        try db.run("CREATE INDEX IF NOT EXISTS idx_ssh_hosts_updated ON ssh_hosts(updated_at DESC)")
    }

    public func upsert(_ host: SSHHost) throws {
        try db.run(
            """
            INSERT INTO ssh_hosts
                (id, nickname, hostname, username, port,
                 created_at, updated_at, last_connected_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                nickname = excluded.nickname,
                hostname = excluded.hostname,
                username = excluded.username,
                port = excluded.port,
                updated_at = excluded.updated_at,
                last_connected_at = excluded.last_connected_at
            """,
            host.id.uuidString,
            host.nickname,
            host.hostname,
            host.user,
            Int64(host.port),
            host.createdAt.timeIntervalSince1970,
            host.updatedAt.timeIntervalSince1970,
            host.lastConnectedAt?.timeIntervalSince1970
        )
    }

    public func delete(id: UUID) throws {
        try db.run("DELETE FROM ssh_hosts WHERE id = ?", id.uuidString)
    }

    public func host(forID id: UUID) throws -> SSHHost? {
        let rows = try db.prepare(
            """
            SELECT id, nickname, hostname, username, port,
                   created_at, updated_at, last_connected_at
            FROM ssh_hosts WHERE id = ? LIMIT 1
            """,
            id.uuidString
        )
        for row in rows { return try Self.decode(row) }
        return nil
    }

    /// Lists all hosts, most recently updated first — matches the sidebar
    /// ordering the UI uses.
    public func allHosts() throws -> [SSHHost] {
        let rows = try db.prepare(
            """
            SELECT id, nickname, hostname, username, port,
                   created_at, updated_at, last_connected_at
            FROM ssh_hosts ORDER BY updated_at DESC
            """
        )
        return try rows.map { try Self.decode($0) }
    }

    /// Stamps a host's last-connected time without bumping `updated_at` —
    /// connection telemetry should not promote the row in the sidebar.
    public func touchLastConnected(id: UUID, at instant: Date = Date()) throws {
        try db.run(
            "UPDATE ssh_hosts SET last_connected_at = ? WHERE id = ?",
            instant.timeIntervalSince1970,
            id.uuidString
        )
    }

    private static func decode(_ row: [Binding?]) throws -> SSHHost {
        guard
            let idString = row[0] as? String, let id = UUID(uuidString: idString),
            let nickname = row[1] as? String,
            let hostname = row[2] as? String,
            let user = row[3] as? String,
            let portRaw = row[4] as? Int64,
            let created = row[5] as? Double,
            let updated = row[6] as? Double
        else {
            throw SSHHostError.malformedRow
        }
        let lastConnected = (row[7] as? Double).map(Date.init(timeIntervalSince1970:))
        return SSHHost(
            id: id,
            nickname: nickname,
            hostname: hostname,
            user: user,
            port: Int(portRaw),
            createdAt: Date(timeIntervalSince1970: created),
            updatedAt: Date(timeIntervalSince1970: updated),
            lastConnectedAt: lastConnected
        )
    }
}
