import Foundation
import Testing
@testable import HerminalDB

@Suite("SSHConfigImporter")
struct SSHConfigImporterTests {
    @Test("parses a single Host block with HostName + User + Port")
    func singleHost() {
        let config = """
        Host prod-web
            HostName 10.0.0.5
            User deploy
            Port 2222
        """
        let hosts = SSHConfigImporter.parse(content: config)
        #expect(hosts.count == 1)
        let host = hosts[0]
        #expect(host.nickname == "prod-web")
        #expect(host.hostname == "10.0.0.5")
        #expect(host.user == "deploy")
        #expect(host.port == 2222)
    }

    @Test("parses multiple Host blocks separated by blank lines + comments")
    func multipleHosts() {
        let config = """
        # office staging
        Host staging
            HostName staging.lan
            User dev

        # production
        Host prod
            HostName prod.example.com
            User ops
            Port 2200
        """
        let hosts = SSHConfigImporter.parse(content: config)
        #expect(hosts.count == 2)
        #expect(hosts.map(\.nickname).sorted() == ["prod", "staging"])
    }

    @Test("skips wildcard Host blocks (Host *, Host *.example.com)")
    func skipsWildcards() {
        let config = """
        Host *
            User defaultuser
            Port 22

        Host *.internal
            User internaluser

        Host real-host
            HostName real.example.com
        """
        let hosts = SSHConfigImporter.parse(content: config)
        #expect(hosts.count == 1)
        #expect(hosts.first?.nickname == "real-host")
    }

    @Test("multi-target Host lines emit one row per concrete target")
    func multiTargetHost() {
        let config = """
        Host a b c
            HostName shared.example.com
            User shared
            Port 2200
        """
        let hosts = SSHConfigImporter.parse(content: config)
        #expect(hosts.count == 3)
        // The first target gets the block's directives; the rest get
        // defaults — faithful to OpenSSH's "every match applies the
        // same rules at connect time" semantics without per-target
        // overrides we'd otherwise need to invent.
        let first = try? #require(hosts.first { $0.nickname == "a" })
        #expect(first?.hostname == "shared.example.com")
        #expect(first?.user == "shared")
        #expect(first?.port == 2200)
        let bare = try? #require(hosts.first { $0.nickname == "b" })
        #expect(bare?.hostname == "b")
    }

    @Test("defaults hostname to the nickname when HostName is missing")
    func hostnameDefault() {
        let config = """
        Host simple
            User me
        """
        let hosts = SSHConfigImporter.parse(content: config)
        #expect(hosts.first?.hostname == "simple")
        #expect(hosts.first?.port == 22)
    }

    @Test("ignores trailing inline comments")
    func ignoresInlineComments() {
        let config = """
        Host h1   # primary box
            HostName 10.0.0.1     # internal IP
            Port 22
        """
        let hosts = SSHConfigImporter.parse(content: config)
        #expect(hosts.first?.nickname == "h1")
        #expect(hosts.first?.hostname == "10.0.0.1")
    }

    @Test("ignores unknown directives without breaking the block")
    func ignoresUnknownDirectives() {
        let config = """
        Host h1
            HostName 10.0.0.1
            IdentityFile ~/.ssh/id_ed25519
            ProxyJump bastion
            User ops
        """
        let hosts = SSHConfigImporter.parse(content: config)
        #expect(hosts.first?.user == "ops")
        #expect(hosts.first?.hostname == "10.0.0.1")
    }

    @Test("parseHosts throws .fileMissing when the path doesn't exist")
    func fileMissingThrows() {
        #expect(throws: SSHConfigImporter.ImportError.fileMissing(
            path: "/tmp/this-does-not-exist-herminal-test"
        )) {
            _ = try SSHConfigImporter.parseHosts(
                at: "/tmp/this-does-not-exist-herminal-test"
            )
        }
    }
}
