import Foundation
import Testing
@testable import HerminalApp

// Regression guard for the v0.4.3 security review (finding F1): the
// Claude session id is a transcript FILENAME stem that gets interpolated
// into the `claude --resume <id>` command libghostty runs via the shell.
// A local process can plant any filename under ~/.claude/projects/*/, so
// only a canonical UUID may pass — anything carrying shell metacharacters
// (or merely the wrong shape) must be rejected before it reaches a tab.
@Suite("ClaudeSessionStore.isValidSessionID")
struct ClaudeSessionStoreTests {
    @Test("a canonical Claude Code UUID is accepted")
    func acceptsRealUUID() {
        #expect(ClaudeSessionStore.isValidSessionID("94ff3b58-f352-4896-8cdf-609011564475"))
    }

    @Test("a freshly generated UUID is accepted")
    func acceptsGeneratedUUID() {
        #expect(ClaudeSessionStore.isValidSessionID(UUID().uuidString.lowercased()))
        #expect(ClaudeSessionStore.isValidSessionID(UUID().uuidString))
    }

    @Test("filenames carrying shell metacharacters are rejected",
          arguments: [
            "x; rm -rf ~ #",
            "$(reboot)",
            "`id`",
            "a && open /Applications/Calculator.app",
            "foo|bar",
            "a b c",
            "../../etc/passwd",
            "00000000-0000-0000-0000-000000000000--flag",
          ])
    func rejectsShellInjection(stem: String) {
        #expect(!ClaudeSessionStore.isValidSessionID(stem))
    }

    @Test("non-UUID shapes are rejected",
          arguments: ["", "not-a-uuid", "12345", "deadbeef",
                      "94ff3b58f3524896 8cdf609011564475"])
    func rejectsWrongShape(stem: String) {
        #expect(!ClaudeSessionStore.isValidSessionID(stem))
    }
}
