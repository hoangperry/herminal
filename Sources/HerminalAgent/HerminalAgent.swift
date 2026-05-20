// HerminalAgent — agent CLI detection heuristics.
// Detects: claude, codex, aider via process name + output patterns.
// Status states: running, idle, needsInput, exitedSuccess, exitedError, unknown.

import Foundation

public enum AgentKind: String, Sendable {
    case claudeCode = "claude"
    case codex = "codex"
    case aider = "aider"
    case unknown
}

public enum AgentStatus: String, Sendable {
    case running
    case idle
    case needsInput
    case exitedSuccess
    case exitedError
    case unknown
}
