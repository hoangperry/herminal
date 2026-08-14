import Foundation
import Testing
@testable import HerminalApp

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
                == "tmux attach-session -t 'foo'")
        #expect(try TmuxLaunch.command(action: .attachOrCreate, name: "foo")
                == "tmux new-session -A -s 'foo'")
    }

    @Test("refuses to build a command from an illegal name")
    func rejectsIllegalCommand() {
        #expect(throws: TmuxLaunch.ValidationError.self) {
            try TmuxLaunch.command(action: .newSession, name: "foo;rm")
        }
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

    @Test("binaryCandidates are the Homebrew-then-system list")
    func candidateOrder() {
        #expect(TmuxLaunch.binaryCandidates == [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ])
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
