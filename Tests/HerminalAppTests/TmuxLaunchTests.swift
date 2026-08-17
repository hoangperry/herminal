import Foundation
import Testing
@testable import HerminalApp

/// Captures runner argv from a `@Sendable` TmuxRunner without a Swift 6 warning.
private final class ArgCapture: @unchecked Sendable {
    var value: [String] = []
}

@Suite("TmuxLaunch.names")
struct TmuxLaunchNameTests {
    @Test("accepts everyday session names")
    func acceptsEveryday() throws {
        try TmuxLaunch.validateName("herminal")
        try TmuxLaunch.validateName("my-app")
        try TmuxLaunch.validateName("foo.bar")
    }

    @Test("rejects empty, traversal, and metacharacters")
    func rejectsUnsafe() {
        let bad = [
            "", " ", "-evil", "foo bar", "foo/bar", "a$(b)",
            "a`b", "foo;rm", String(repeating: "a", count: 65),
        ]
        for name in bad {
            #expect(throws: TmuxLaunch.ValidationError.self) {
                try TmuxLaunch.validateName(name)
            }
        }
    }

    @Test("slug flattens spaces and slashes")
    func slugs() {
        #expect(TmuxLaunch.slug("My App") == "My-App")
        #expect(TmuxLaunch.slug("foo/bar") == "foo-bar")
    }
}

@Suite("TmuxLaunch.command")
struct TmuxLaunchCommandTests {
    @Test("quotes a plain name")
    func quotesPlain() {
        #expect(TmuxLaunch.quote("foo") == "'foo'")
    }

    @Test("escapes an embedded single quote")
    func quotesEmbedded() {
        #expect(TmuxLaunch.quote("a'b") == "'a'\\''b'")
    }

    @Test("builds the three spawn strings")
    func buildsCommands() throws {
        #expect(try TmuxLaunch.command(action: .newSession, name: "foo")
                == "tmux new-session -s 'foo'")
        #expect(try TmuxLaunch.command(action: .attach, name: "foo")
                == "tmux attach-session -t '=foo'")
        #expect(try TmuxLaunch.command(action: .attachOrCreate, name: "foo")
                == "tmux new-session -A -s 'foo'")
    }

    @Test("refuses to build a command from an illegal name")
    func rejectsIllegalCommand() {
        #expect(throws: TmuxLaunch.ValidationError.self) {
            try TmuxLaunch.command(action: .newSession, name: "foo;rm")
        }
    }

    @Test("sessionName recovers the name from each spawn string")
    func sessionNameFromSpawnCommand() throws {
        let newCmd = try TmuxLaunch.command(action: .newSession, name: "foo")
        let attach = try TmuxLaunch.command(action: .attach, name: "foo")
        let either = try TmuxLaunch.command(action: .attachOrCreate, name: "foo")
        #expect(TmuxLaunch.sessionName(fromSpawnCommand: newCmd) == "foo")
        #expect(TmuxLaunch.sessionName(fromSpawnCommand: attach) == "foo")
        #expect(TmuxLaunch.sessionName(fromSpawnCommand: either) == "foo")
        #expect(TmuxLaunch.sessionName(fromSpawnCommand: "zsh") == nil)
        #expect(TmuxLaunch.sessionName(fromSpawnCommand: "tmux attach-session -t 'foo;rm'") == nil)
    }
}

@Suite("TmuxLaunch.list")
struct TmuxLaunchListTests {
    @Test("drops blank lines")
    func parseList() {
        #expect(TmuxLaunch.parseSessionList("a\nb\n\n") == ["a", "b"])
        #expect(TmuxLaunch.parseSessionList("") == [])
    }

    @Test("hasSession follows the runner exit code")
    func hasSessionFromRunner() throws {
        let present = TmuxRunner { _, _, _ in (0, "", "") }
        let missing = TmuxRunner { _, _, _ in (1, "", "") }
        #expect(try TmuxLaunch.hasSession(name: "foo", binary: "/bin/tmux", runner: present))
        #expect(try TmuxLaunch.hasSession(name: "foo", binary: "/bin/tmux", runner: missing) == false)
    }

    @Test("listSessions is empty when tmux has no server")
    func emptyWhenNoServer() throws {
        let runner = TmuxRunner { _, _, _ in (1, "", "no server") }
        #expect(try TmuxLaunch.listSessions(binary: "/bin/tmux", runner: runner) == [])
    }

    @Test("listSessions parses stdout")
    func listsNames() throws {
        let runner = TmuxRunner { _, _, _ in (0, "api\nweb\n", "") }
        #expect(try TmuxLaunch.listSessions(binary: "/bin/tmux", runner: runner) == ["api", "web"])
    }

    @Test("displayableSessions drops names that would fail validateName")
    func displayableSessions() {
        #expect(TmuxLaunch.displayableSessions(["api", "foo;rm", "web", "a b"]) == ["api", "web"])
    }

    @Test("parseSessionRecords reads name, windows, and attached clients")
    func parseSessionRecords() {
        let rows = TmuxLaunch.parseSessionRecords("api\t2\t1\nweb\t1\t0\n\n")
        #expect(rows == [
            TmuxLaunch.Session(name: "api", windows: 2, attachedClients: 1),
            TmuxLaunch.Session(name: "web", windows: 1, attachedClients: 0),
        ])
    }

    @Test("parseSessionRecords falls back when columns are missing")
    func parseSessionRecordsPlainNames() {
        let rows = TmuxLaunch.parseSessionRecords("api\nweb\n")
        #expect(rows.map(\.name) == ["api", "web"])
        #expect(rows.map(\.windows) == [1, 1])
        #expect(rows.map(\.attachedClients) == [0, 0])
    }

    @Test("listSessionRecords uses the tab-separated format")
    func listSessionRecordsArgs() throws {
        let seen = ArgCapture()
        let runner = TmuxRunner { args, _, _ in
            seen.value = args
            return (0, "api\t3\t2\n", "")
        }
        let rows = try TmuxLaunch.listSessionRecords(binary: "/bin/tmux", runner: runner)
        #expect(seen.value == [
            "list-sessions", "-F", "#{session_name}\t#{session_windows}\t#{session_attached}",
        ])
        #expect(rows == [TmuxLaunch.Session(name: "api", windows: 3, attachedClients: 2)])
    }

    @Test("displayableSessions drops illegal records")
    func displayableRecords() {
        let rows = [
            TmuxLaunch.Session(name: "api", windows: 1, attachedClients: 0),
            TmuxLaunch.Session(name: "foo;rm", windows: 1, attachedClients: 0),
        ]
        #expect(TmuxLaunch.displayableSessions(rows).map(\.name) == ["api"])
    }

    @Test("binaryCandidates are the Homebrew-then-system list")
    func candidateOrder() {
        #expect(TmuxLaunch.binaryCandidates == [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ])
    }
}

@Suite("TmuxLaunch.kill")
struct TmuxLaunchKillTests {
    @Test("killSession sends kill-session -t =name")
    func killSessionArgs() throws {
        let seen = ArgCapture()
        let runner = TmuxRunner { args, _, _ in
            seen.value = args
            return (0, "", "")
        }
        try TmuxLaunch.killSession(name: "foo", binary: "/bin/tmux", runner: runner)
        #expect(seen.value == ["kill-session", "-t", "=foo"])
    }

    @Test("killSession trims before building argv")
    func killSessionTrims() throws {
        let seen = ArgCapture()
        let runner = TmuxRunner { args, _, _ in
            seen.value = args
            return (0, "", "")
        }
        try TmuxLaunch.killSession(name: " foo ", binary: "/bin/tmux", runner: runner)
        #expect(seen.value == ["kill-session", "-t", "=foo"])
    }

    @Test("killSession rejects an illegal name without calling tmux")
    func killRejectsBadName() {
        let runner = TmuxRunner { _, _, _ in
            Issue.record("runner should not run")
            return (0, "", "")
        }
        #expect(throws: TmuxLaunch.ValidationError.self) {
            try TmuxLaunch.killSession(name: "foo;rm", binary: "/bin/tmux", runner: runner)
        }
    }

    @Test("killSession throws when tmux exits nonzero")
    func killSessionFailed() {
        let runner = TmuxRunner { _, _, _ in (1, "", "can't find session") }
        #expect(throws: TmuxLaunch.Error.tmuxFailed("kill-session failed")) {
            try TmuxLaunch.killSession(name: "foo", binary: "/bin/tmux", runner: runner)
        }
    }
}

@Suite("TmuxRunner.process")
struct TmuxRunnerProcessTests {
    @Test("force-kills a subprocess that ignores graceful timeout signals")
    func killsStubbornProcess() {
        let started = Date()
        let runner = TmuxRunner.process(timeout: 0.1)
        let result = runner.run(
            ["-c", "trap '' TERM INT; while :; do :; done"],
            binary: "/bin/sh",
            in: "/"
        )

        #expect(result.status == 124)
        #expect(Date().timeIntervalSince(started) < 2)
        #expect(result.stderr == "tmux timed out")
    }

    @Test("captures at most one MiB of subprocess output")
    func capsOutput() {
        let runner = TmuxRunner.process(timeout: 3)
        let result = runner.run(
            ["-c", "yes 1234567890 | head -n 200000"],
            binary: "/bin/sh",
            in: "/"
        )

        #expect(result.status == 0)
        #expect(result.stdout.utf8.count <= 1_048_576)
    }
}
