import Foundation

struct CloseRiskSession: Hashable {
    let id: UUID
    let hasNote: Bool
    let spawnedCommand: String?
    let hasMappedAgent: Bool
    let hasLiveProcess: Bool
}

struct CloseRiskFingerprint: Equatable {
    let sessions: Set<CloseRiskSession>
    let includeNotes: Bool
}

struct CloseRiskWindowDecision: Equatable {
    let approved: Bool
    let approvedFingerprint: CloseRiskFingerprint?
}

enum CloseRiskAction: Equatable {
    case closePane
    case closeTab
    case closeWorkspace
    case quitApplication

    var title: String {
        switch self {
        case .closePane: return "Close Pane"
        case .closeTab: return "Close Tab"
        case .closeWorkspace: return "Close Workspace"
        case .quitApplication: return "Quit Herminal"
        }
    }

    static func windowClose(isLastVisibleWindow: Bool) -> CloseRiskAction {
        isLastVisibleWindow ? .quitApplication : .closeWorkspace
    }
}

struct CloseRiskAlertPresentation: Equatable {
    let messageText: String
    let informativeText: String
    let defaultButtonTitle: String
    let destructiveButtonTitle: String

    init(action: CloseRiskAction, assessment: CloseRiskAssessment) {
        messageText = "\(action.title) with active work?"
        if action == .closeWorkspace {
            informativeText = assessment.informativeText
                + " Herminal will quit after its remaining windows close."
        } else {
            informativeText = assessment.informativeText
        }
        defaultButtonTitle = "Cancel"
        destructiveButtonTitle = action.title
    }
}

struct CloseRiskGate {
    private var approvedFingerprint: CloseRiskFingerprint?

    mutating func recordWindowClose(approvedFingerprint: CloseRiskFingerprint?) {
        self.approvedFingerprint = approvedFingerprint
    }

    mutating func consumeWindowCloseApproval(
        matchingCurrentFingerprint currentFingerprint: CloseRiskFingerprint
    ) -> Bool {
        defer { approvedFingerprint = nil }
        guard let approvedFingerprint else { return false }
        return approvedFingerprint == currentFingerprint
    }

    mutating func clearWindowCloseApproval() {
        approvedFingerprint = nil
    }
}

struct CloseRiskAssessment: Equatable {
    let notedSessionCount: Int
    let liveProcessSessionCount: Int
    let activeAgentSessionCount: Int
    let longLivedCommandSessionCount: Int

    var requiresConfirmation: Bool {
        notedSessionCount > 0
            || liveProcessSessionCount > 0
            || activeAgentSessionCount > 0
            || longLivedCommandSessionCount > 0
    }

    var informativeText: String {
        var details: [String] = []
        if notedSessionCount > 0 {
            details.append(notesWarningText)
        }
        if liveProcessSessionCount > 0 {
            details.append(liveProcessWarningText)
        }
        if activeAgentSessionCount > 0 {
            details.append(agentWarningText)
        }
        if longLivedCommandSessionCount > 0 {
            details.append(longLivedCommandWarningText)
        }
        if activeAgentSessionCount > 0 || longLivedCommandSessionCount > 0 {
            details.append(
                "Herminal cannot yet verify every foreground process in a plain shell."
            )
        }
        return details.joined(separator: " ")
    }

    static func assess(
        _ sessions: [CloseRiskSession],
        includeNotes: Bool
    ) -> CloseRiskAssessment {
        let uniqueSessions = Dictionary(
            sessions.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        ).values
        return CloseRiskAssessment(
            notedSessionCount: includeNotes
                ? uniqueSessions.filter(\.hasNote).count
                : 0,
            liveProcessSessionCount: uniqueSessions.filter(\.hasLiveProcess).count,
            activeAgentSessionCount: uniqueSessions.filter { session in
                !session.hasLiveProcess && session.hasMappedAgent
            }.count,
            longLivedCommandSessionCount: uniqueSessions.filter { session in
                !session.hasLiveProcess
                    && !session.hasMappedAgent
                    && isLongLivedCommand(session.spawnedCommand)
            }.count
        )
    }

    private static func isLongLivedCommand(_ command: String?) -> Bool {
        guard let token = command?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .first else { return false }
        let executable = NSString(string: String(token)).lastPathComponent.lowercased()
        return ["ssh", "tmux", "claude", "codex", "aider"].contains(executable)
    }

    private func sessionPhrase(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }

    private var notesWarningText: String {
        "\(sessionPhrase(notedSessionCount)) \(noteVerb(for: notedSessionCount)) notes "
            + "that may become unavailable after closing. "
            + "Copy or export important text first."
    }

    private var liveProcessWarningText: String {
        if liveProcessSessionCount == 1 {
            return "1 session has a running process that will be terminated."
        }
        return "\(liveProcessSessionCount) sessions have running processes that will be terminated."
    }

    private var agentWarningText: String {
        if activeAgentSessionCount == 1 {
            return "1 session appears to contain an AI agent that may still be active."
        }
        return "\(activeAgentSessionCount) sessions appear to contain AI agents that may still be active."
    }

    private var longLivedCommandWarningText: String {
        if longLivedCommandSessionCount == 1 {
            return "1 session appears to contain an SSH, tmux, or agent command that may still be active."
        }
        return "\(longLivedCommandSessionCount) sessions appear to contain SSH, tmux, or agent commands that may still be active."
    }

    private func noteVerb(for count: Int) -> String {
        count == 1 ? "has" : "have"
    }
}
