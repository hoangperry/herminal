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
