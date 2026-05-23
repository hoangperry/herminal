import Foundation
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
