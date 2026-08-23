import Foundation
import SQLite
import Testing
@testable import HerminalDB

@Suite("SSHHostsStore")
struct SSHHostsStoreTests {
    private func freshStore() throws -> SSHHostsStore {
        try SSHHostsStore(.inMemory)
    }

    @Test("upsert then fetch round-trips a host")
    func upsertRoundTrips() throws {
        let store = try freshStore()
        // Pin the dates to whole seconds — SQLite stores them as REAL
        // (Double) so the round-trip would otherwise lose sub-microsecond
        // bits and trip strict struct equality.
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let host = SSHHost(nickname: "prod-web", hostname: "10.0.0.5",
                           user: "deploy", port: 2222,
                           createdAt: stamp, updatedAt: stamp)
        try store.upsert(host)
        let fetched = try store.host(forID: host.id)
        #expect(fetched == host)
    }

    @Test("upsert updates an existing host in place")
    func upsertUpdates() throws {
        let store = try freshStore()
        var host = SSHHost(nickname: "old", hostname: "h", user: "u")
        try store.upsert(host)
        host.nickname = "new"
        host.port = 2200
        host.touch()
        try store.upsert(host)
        let fetched = try store.host(forID: host.id)
        #expect(fetched?.nickname == "new")
        #expect(fetched?.port == 2200)
    }

    @Test("allHosts is ordered by most recently updated first")
    func allHostsOrdered() throws {
        let store = try freshStore()
        let first = SSHHost(nickname: "a", hostname: "ha", user: "u",
                            updatedAt: Date(timeIntervalSince1970: 1000))
        let second = SSHHost(nickname: "b", hostname: "hb", user: "u",
                             updatedAt: Date(timeIntervalSince1970: 2000))
        try store.upsert(first)
        try store.upsert(second)
        let listed = try store.allHosts()
        #expect(listed.map(\.nickname) == ["b", "a"])
    }

    @Test("batch upsert persists every imported host")
    func batchUpsertPersistsAll() throws {
        let store = try freshStore()
        let hosts = [
            SSHHost(nickname: "web", hostname: "web.example.com", user: "deploy"),
            SSHHost(nickname: "db", hostname: "db.example.com", user: "admin")
        ]

        try store.upsert(hosts)

        #expect(Set(try store.allHosts().map(\.id)) == Set(hosts.map(\.id)))
    }

    @Test("re-importing the same SSH config does not duplicate saved hosts")
    func repeatedImportDoesNotDuplicateHosts() throws {
        let store = try freshStore()
        let config = """
        Host prod-web
            HostName prod.example.com
            User deploy
            Port 2200

        Host db
            HostName db.example.com
            User admin
        """

        let firstImport = SSHConfigImporter.parse(content: config)
        let secondImport = SSHConfigImporter.parse(content: config)

        try store.upsert(firstImport)
        try store.upsert(secondImport)

        let listed = try store.allHosts()
        #expect(listed.count == 2)
        #expect(Set(listed.map(\.nickname)) == ["db", "prod-web"])
    }

    @Test("re-importing an alias refreshes its saved endpoint")
    func repeatedImportRefreshesExistingHost() throws {
        let store = try freshStore()
        let original = SSHConfigImporter.parse(content: """
        Host prod-web
            HostName old.example.com
            User deploy
        """)
        let updated = SSHConfigImporter.parse(content: """
        Host prod-web
            HostName new.example.com
            User release
            Port 2200
        """)

        try store.upsert(original)
        try store.upsert(updated)

        let listed = try store.allHosts()
        #expect(listed.count == 1)
        #expect(listed.first?.hostname == "new.example.com")
        #expect(listed.first?.user == "release")
        #expect(listed.first?.port == 2200)
    }

    @Test("re-importing preserves connection history")
    func repeatedImportPreservesLastConnectedAt() throws {
        let store = try freshStore()
        let config = """
        Host prod-web
            HostName prod.example.com
            User deploy
        """
        let firstImport = try #require(SSHConfigImporter.parse(content: config).first)
        let stamp = Date(timeIntervalSince1970: 5_000)

        try store.upsert(firstImport)
        try store.touchLastConnected(id: firstImport.id, at: stamp)
        try store.upsert(SSHConfigImporter.parse(content: config))

        let saved = try #require(try store.host(forID: firstImport.id))
        #expect(saved.lastConnectedAt == stamp)
    }

    @Test("delete removes a host")
    func deleteRemoves() throws {
        let store = try freshStore()
        let host = SSHHost(nickname: "x", hostname: "x", user: "x")
        try store.upsert(host)
        try store.delete(id: host.id)
        #expect(try store.host(forID: host.id) == nil)
    }

    @Test("host(forID:) returns nil for an unknown id")
    func unknownIDReturnsNil() throws {
        let store = try freshStore()
        #expect(try store.host(forID: UUID()) == nil)
    }

    @Test("validate rejects empty hostname")
    func validateRejectsEmptyHostname() {
        #expect(throws: SSHHostError.emptyHostname) {
            _ = try SSHHost.validated(nickname: "n", hostname: "  ",
                                      user: "u", port: 22)
        }
    }

    @Test("validate rejects out-of-range port", arguments: [-1, 0, 65536, 100000])
    func validateRejectsBadPort(port: Int) {
        #expect(throws: SSHHostError.invalidPort(port)) {
            _ = try SSHHost.validated(nickname: "n", hostname: "h",
                                      user: "u", port: port)
        }
    }

    @Test("validate accepts a typical host")
    func validateAcceptsTypical() throws {
        let host = try SSHHost.validated(nickname: "web1",
                                         hostname: "web1.example.com",
                                         user: "deploy", port: 22)
        #expect(host.hostname == "web1.example.com")
    }

    @Test("upsert rejects out-of-range ports before persistence", arguments: [-1, 0, 65_536, 100_000])
    func upsertRejectsBadPort(port: Int) throws {
        let store = try freshStore()
        let host = SSHHost(nickname: "bad", hostname: "host.example.com", user: "deploy", port: port)

        #expect(throws: SSHHostError.invalidPort(port)) {
            try store.upsert(host)
        }
        #expect(try store.allHosts().isEmpty)
    }

    @Test("batch upsert stays atomic when one host has an invalid port")
    func batchUpsertRejectsBadPortAtomically() throws {
        let store = try freshStore()
        let good = SSHHost(nickname: "good", hostname: "good.example.com", user: "deploy", port: 22)
        let bad = SSHHost(nickname: "bad", hostname: "bad.example.com", user: "deploy", port: 70_000)

        #expect(throws: SSHHostError.invalidPort(70_000)) {
            try store.upsert([good, bad])
        }
        #expect(try store.allHosts().isEmpty)
    }

    @Test(
        "persisted out-of-range ports fail closed during decode",
        arguments: [Int64(-1), 0, 65_536, 100_000]
    )
    func decodeRejectsBadPort(port: Int64) throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssh-hosts-store-\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let store = try SSHHostsStore(.uri(dbURL.path()))
        let db = try Connection(.uri(dbURL.path()))
        let id = UUID()
        try db.run(
            """
            INSERT INTO ssh_hosts
                (id, nickname, hostname, username, port,
                 created_at, updated_at, last_connected_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            id.uuidString, "n", "h", "u", port, 100.0, 100.0, nil
        )

        #expect(throws: SSHHostError.malformedRow) {
            _ = try store.host(forID: id)
        }
    }

    @Test(
        "valid port endpoints round-trip through persistence",
        arguments: [1, 65_535]
    )
    func portEndpointsRoundTrip(port: Int) throws {
        let store = try freshStore()
        let host = SSHHost(
            nickname: "boundary",
            hostname: "host.example.com",
            user: "deploy",
            port: port
        )
        try store.upsert(host)

        #expect(try store.host(forID: host.id)?.port == port)
    }

    @Test("touchLastConnected stamps the connection time")
    func touchConnectedStamps() throws {
        let store = try freshStore()
        var host = SSHHost(nickname: "x", hostname: "x", user: "x")
        try store.upsert(host)
        #expect(host.lastConnectedAt == nil)
        let stamp = Date(timeIntervalSince1970: 5000)
        try store.touchLastConnected(id: host.id, at: stamp)
        host = try #require(try store.host(forID: host.id))
        #expect(host.lastConnectedAt == stamp)
    }
}
