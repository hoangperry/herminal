import Foundation
import Testing
@testable import HerminalApp

// GitInfo.parseHead turns a `.git/HEAD` payload into a branch label. Pure,
// so it tests without a repo. (The filesystem walk in `branch(forDirectory:)`
// is exercised live during dogfood — these pin the parsing contract.)
@Suite("GitInfo.parseHead")
struct GitInfoTests {
    @Test("a symbolic ref yields the branch name")
    func symbolicRef() {
        #expect(GitInfo.parseHead("ref: refs/heads/main\n") == "main")
        #expect(GitInfo.parseHead("ref: refs/heads/feature/live-cwd\n") == "feature/live-cwd")
    }

    @Test("a bare object id is reported as detached")
    func detachedHead() {
        #expect(GitInfo.parseHead("9fceb02d0ae598e95dc970b74767f19372d61af8\n") == "detached")
    }

    @Test("trailing whitespace is trimmed")
    func trimsWhitespace() {
        #expect(GitInfo.parseHead("ref: refs/heads/dev   \n\n") == "dev")
    }

    @Test("garbage or empty payloads yield nil")
    func rejectsGarbage() {
        #expect(GitInfo.parseHead("") == nil)
        #expect(GitInfo.parseHead("not a head file") == nil)
        #expect(GitInfo.parseHead("ref: refs/heads/") == nil)
    }
}

@Suite("GitInfo.worktree gitdir")
struct GitInfoWorktreeTests {
    @Test("follows a .git file to the linked worktree HEAD")
    func followsGitDirFile() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "herminal-gitinfo-\(UUID().uuidString)", isDirectory: true
        )
        let worktree = root.appendingPathComponent("checkout", isDirectory: true)
        let gitDir = root.appendingPathComponent("gitdir", isDirectory: true)
        try fm.createDirectory(at: worktree, withIntermediateDirectories: true)
        try fm.createDirectory(at: gitDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try "gitdir: \(gitDir.path)\n".write(
            to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8
        )
        try "ref: refs/heads/feature/wt\n".write(
            to: gitDir.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8
        )

        #expect(GitInfo.branch(forDirectory: worktree.path, fileManager: fm) == "feature/wt")
    }

    @Test("resolves a relative gitdir against the worktree root")
    func followsRelativeGitDir() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "herminal-gitinfo-rel-\(UUID().uuidString)", isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try fm.createDirectory(at: root.appendingPathComponent(".git/worktrees/feat"),
                               withIntermediateDirectories: true)
        try "gitdir: .git/worktrees/feat\n".write(
            to: root.appendingPathComponent(".git-file-placeholder"), atomically: true, encoding: .utf8
        )
        // Put the pointer at `<root>/.git` as a file, and HEAD in the relative dir.
        // FileManager can't have both a .git file and .git dir — use a nested checkout.
        let checkout = root.appendingPathComponent("wt", isDirectory: true)
        try fm.createDirectory(at: checkout, withIntermediateDirectories: true)
        try "gitdir: ../.git/worktrees/feat\n".write(
            to: checkout.appendingPathComponent(".git"), atomically: true, encoding: .utf8
        )
        try "ref: refs/heads/rel-branch\n".write(
            to: root.appendingPathComponent(".git/worktrees/feat/HEAD"),
            atomically: true, encoding: .utf8
        )

        #expect(GitInfo.branch(forDirectory: checkout.path, fileManager: fm) == "rel-branch")
    }
}
