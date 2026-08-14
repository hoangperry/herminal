import Foundation
import Testing
@testable import HerminalApp

@Suite("GitWorktree.branch names")
struct GitWorktreeBranchTests {
    @Test("accepts everyday branch names")
    func acceptsEverydayNames() throws {
        try GitWorktree.validateBranchName("main")
        try GitWorktree.validateBranchName("feature/live-cwd")
        try GitWorktree.validateBranchName("fix-123")
        try GitWorktree.validateBranchName("yuuhou.meow")
    }

    @Test("rejects empty, traversal, and metacharacters")
    func rejectsUnsafeNames() {
        let bad = [
            "", " ", "-dash", "has space", "foo..bar", "foo//bar",
            "evil;rm", "foo$(hi)", "foo`hi`", "../escape", "foo~1",
            "foo^2", "foo:bar", "ends.", "foo.lock", "@{u}", "a" + String(repeating: "b", count: 200),
        ]
        for name in bad {
            #expect(throws: GitWorktree.ValidationError.self) {
                try GitWorktree.validateBranchName(name)
            }
        }
    }

    @Test("slug flattens slashes and strips junk")
    func slugsBranch() {
        #expect(GitWorktree.slug("feature/live cwd") == "feature-live-cwd")
        #expect(GitWorktree.slug("fix-123") == "fix-123")
        #expect(GitWorktree.slug("Weird!!!Name") == "WeirdName")
    }

    @Test("sibling worktree path matches FlightDeck layout")
    func siblingPath() {
        let path = GitWorktree.worktreePath(
            mainRepoRoot: "/Users/me/herminal",
            branch: "feature/agent-wt"
        )
        #expect(path == "/Users/me/herminal.worktrees/feature-agent-wt")
    }

    @Test("path comparison ignores /var vs /private/var spelling")
    func pathComparison() {
        let a = GitWorktree.standardized("/var/tmp")
        let b = GitWorktree.standardized("/private/var/tmp")
        #expect(a == b)
        #expect(GitWorktree.pathsEqual("/var/tmp", "/private/var/tmp"))
        #expect(!GitWorktree.pathsEqual("/var/tmp", nil))
    }
}

@Suite("GitWorktree.porcelain")
struct GitWorktreePorcelainTests {
    @Test("parses a main checkout and a linked worktree")
    func parsesPorcelain() {
        let text = """
        worktree /Users/me/herminal
        HEAD 9fceb02d0ae598e95dc970b74767f19372d61af8
        branch refs/heads/main

        worktree /Users/me/herminal.worktrees/feat
        HEAD deadbeefdeadbeefdeadbeefdeadbeefdeadbeef
        branch refs/heads/feat

        worktree /Users/me/herminal.worktrees/tmp
        HEAD cafe0000cafe0000cafe0000cafe0000cafe0000
        detached

        """
        let entries = GitWorktree.parsePorcelain(text)
        #expect(entries.count == 3)
        #expect(entries[0].path == "/Users/me/herminal")
        #expect(entries[0].branch == "main")
        #expect(entries[0].isDetached == false)
        #expect(entries[1].branch == "feat")
        #expect(entries[2].isDetached == true)
        #expect(entries[2].branch == nil)
    }

    @Test("ignores incomplete records")
    func ignoresIncomplete() {
        #expect(GitWorktree.parsePorcelain("HEAD abc\n").isEmpty)
        #expect(GitWorktree.parsePorcelain("").isEmpty)
    }

    @Test("derives the main repo root from git-common-dir")
    func mainRepoRootFromCommonDir() {
        #expect(GitWorktree.mainRepoRoot(fromGitCommonDir: "/Users/me/herminal/.git")
                == "/Users/me/herminal")
        #expect(GitWorktree.mainRepoRoot(fromGitCommonDir: "/Users/me/herminal/.git/")
                == "/Users/me/herminal")
        #expect(GitWorktree.mainRepoRoot(fromGitCommonDir: ".git") == nil)
    }
}

@Suite("GitWorktree.gitdir file")
struct GitWorktreeGitDirTests {
    @Test("parses an absolute gitdir pointer")
    func parsesAbsolute() {
        #expect(
            GitWorktree.parseGitDirFile("gitdir: /tmp/repo/.git/worktrees/feat\n")
            == "/tmp/repo/.git/worktrees/feat"
        )
    }

    @Test("rejects garbage")
    func rejectsGarbage() {
        #expect(GitWorktree.parseGitDirFile("") == nil)
        #expect(GitWorktree.parseGitDirFile("not a gitdir") == nil)
        #expect(GitWorktree.parseGitDirFile("gitdir:") == nil)
    }
}

@Suite("GitWorktree.live")
struct GitWorktreeLiveTests {
    @Test("adds, lists, and removes a sibling worktree")
    func addListRemove() throws {
        try GitWorktreeLive.withTempRepo { repo in
            let created = try GitWorktree.add(branch: "feature/cockpit", cwd: repo)
            #expect(created.hasSuffix("/repo.worktrees/feature-cockpit"))
            #expect(FileManager.default.fileExists(atPath: created))

            let listed = try GitWorktree.list(cwd: repo)
            #expect(listed.contains(where: { $0.branch == "feature/cockpit" }))

            try GitWorktree.remove(path: created)
            #expect(!FileManager.default.fileExists(atPath: created))
        }
    }

    @Test("re-adding an existing worktree is idempotent")
    func addIsIdempotent() throws {
        try GitWorktreeLive.withTempRepo { repo in
            let first = try GitWorktree.add(branch: "same-branch", cwd: repo)
            let second = try GitWorktree.add(branch: "same-branch", cwd: repo)
            #expect(first == second)
        }
    }

    @Test("creating from inside a worktree still siblings the main repo")
    func addFromLinkedWorktree() throws {
        try GitWorktreeLive.withTempRepo { repo in
            let first = try GitWorktree.add(branch: "feature/cockpit", cwd: repo)
            let second = try GitWorktree.add(branch: "other", cwd: first)
            #expect(second.hasSuffix("/repo.worktrees/other"))
            #expect(!second.contains("feature-cockpit.worktrees"))
        }
    }

    @Test("slug collision with a different branch is refused")
    func slugCollision() throws {
        try GitWorktreeLive.withTempRepo { repo in
            _ = try GitWorktree.add(branch: "feature/x", cwd: repo)
            #expect(throws: GitWorktree.Error.pathBusy) {
                try GitWorktree.add(branch: "feature-x", cwd: repo)
            }
        }
    }

    @Test("a leftover non-empty folder is not silently reused as a worktree")
    func leftoverDirectoryIsNotReused() throws {
        try GitWorktreeLive.withTempRepo { repo in
            let dest = GitWorktree.worktreePath(mainRepoRoot: repo, branch: "stale")
            try FileManager.default.createDirectory(atPath: dest, withIntermediateDirectories: true)
            try "junk".write(
                toFile: (dest as NSString).appendingPathComponent("oops"),
                atomically: true, encoding: .utf8
            )
            #expect(throws: GitWorktree.Error.self) {
                try GitWorktree.add(branch: "stale", cwd: repo)
            }
        }
    }

    @Test("refuses a worktree add outside a repo")
    func refusesNonRepo() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("herminal-not-a-repo-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        #expect(throws: GitWorktree.Error.self) {
            try GitWorktree.add(branch: "nope", cwd: tmp.path)
        }
    }
}

@Suite("AgentLaunch")
struct AgentLaunchTests {
    @Test("only the known agent binaries produce a spawn command")
    func whitelist() {
        #expect(AgentLaunch.command(for: .claude) == "claude")
        #expect(AgentLaunch.command(for: .codex) == "codex")
        #expect(AgentLaunch.command(for: .aider) == "aider")
        #expect(AgentLaunch.command(for: .lazygit) == "lazygit")
        #expect(AgentLaunch.command(for: .shell) == nil)
    }

    @Test("rejects anything that is not a known launch kind")
    func rejectsUnknownRaw() {
        #expect(AgentLaunch.Kind(rawValue: "claude") == .claude)
        #expect(AgentLaunch.Kind(rawValue: "/bin/zsh") == nil)
        #expect(AgentLaunch.Kind(rawValue: "claude; rm -rf /") == nil)
    }
}

/// Temp-repo fixture for the live git tests. Isolated so the parse suites
/// never touch the filesystem.
enum GitWorktreeLive {
    static func withTempRepo(_ body: (String) throws -> Void) throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "herminal-wt-\(UUID().uuidString)", isDirectory: true
        )
        let repo = root.appendingPathComponent("repo", isDirectory: true)
        try fm.createDirectory(at: repo, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        func git(_ args: [String]) throws {
            let result = GitRunner.live.run(args, in: repo.path)
            guard result.status == 0 else {
                throw GitWorktree.Error.gitFailed(result.stderr)
            }
        }

        try git(["init", "-b", "main"])
        try git(["config", "user.email", "wt@herminal.test"])
        try git(["config", "user.name", "herminal-test"])
        try "hello\n".write(to: repo.appendingPathComponent("README"), atomically: true, encoding: .utf8)
        try git(["add", "README"])
        try git(["commit", "-m", "init"])
        try body(repo.path)
    }
}
