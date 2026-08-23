import Foundation
import Testing
@testable import HerminalApp
import HerminalDB

@MainActor
@Suite("WorkspaceView.sshCommand")
struct SSHCommandTests {
    @Test("standard port 22 is omitted from the command")
    func defaultPortOmitted() {
        let host = SSHHost(nickname: "n", hostname: "example.com",
                           user: "deploy", port: 22)
        #expect(WorkspaceView.sshCommand(for: host) == "ssh 'deploy'@'example.com'")
    }

    @Test("non-default port adds the -p flag")
    func customPortFlag() {
        let host = SSHHost(nickname: "n", hostname: "host.lan",
                           user: "ops", port: 2222)
        #expect(WorkspaceView.sshCommand(for: host) == "ssh -p 2222 'ops'@'host.lan'")
    }

    @Test("single quotes inside user/host get escaped")
    func escapesEmbeddedQuotes() {
        // Pathological but possible — `'` inside a hostname or user must
        // not break out of the shell quote.
        let host = SSHHost(nickname: "n", hostname: "h'ost",
                           user: "us'er", port: 22)
        #expect(WorkspaceView.sshCommand(for: host) == "ssh 'us'\\''er'@'h'\\''ost'")
    }

    @Test("SSH diary messages keep only structural connection metadata")
    func sshDiaryMessageOmitsIdentityFields() {
        let host = SSHHost(
            nickname: "prod",
            hostname: "internal.example.com",
            user: "deploy",
            port: 2222
        )

        let message = WorkspaceView.sshConnectionDiaryMessage(for: host)

        #expect(message == "ssh connect requested port=2222")
        #expect(!message.contains(host.hostname))
        #expect(!message.contains(host.user))
        #expect(!message.contains(host.nickname))
    }

    @Test("custom tab diary messages omit command payloads and cwd paths")
    func customTabDiaryMessageStaysStructural() {
        let command = "ssh 'deploy'@'internal.example.com'"
        let cwd = "/Users/alice/private/project"

        let message = WorkspaceView.customTabDiaryMessage(
            command: command,
            workingDirectory: cwd
        )

        #expect(message == "addTab customCommand=true cwdSet=true")
        #expect(!message.contains(command))
        #expect(!message.contains(cwd))
        #expect(!message.contains("internal.example.com"))
    }
}
