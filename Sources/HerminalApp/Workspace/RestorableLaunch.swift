import Foundation

/// Structured, allowlisted launch metadata persisted in workspace snapshots.
/// Restore replays only these descriptors; raw shell strings are never
/// reconstructed from `workspace.json`.
enum RestorableLaunch: Sendable, Equatable {
    case agent(AgentLaunch.Kind)
    case ssh(user: String, host: String, port: Int)
    case claudeResume(sessionID: String)
    case tmux(action: TmuxLaunch.Action, name: String)
}

extension RestorableLaunch {
    private static let maxSSHFieldByteCount = 255
    private static let maxSpawnCommandByteCount = 2_048

    var validated: RestorableLaunch? {
        switch self {
        case let .agent(kind):
            guard kind != .shell, AgentLaunch.command(for: kind) != nil else { return nil }
            return .agent(kind)
        case let .ssh(user, host, port):
            guard let trimmedUser = Self.validatedSSHUser(user),
                  let trimmedHost = Self.validatedSSHHost(host),
                  (1...65_535).contains(port)
            else { return nil }
            return .ssh(user: trimmedUser, host: trimmedHost, port: port)
        case let .claudeResume(sessionID):
            let trimmedID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard ClaudeSessionStore.isValidSessionID(trimmedID) else { return nil }
            return .claudeResume(sessionID: trimmedID)
        case let .tmux(action, name):
            guard let command = try? TmuxLaunch.command(action: action, name: name),
                  let canonicalName = TmuxLaunch.sessionName(fromSpawnCommand: command)
            else { return nil }
            return .tmux(action: action, name: canonicalName)
        }
    }

    var spawnCommand: String? {
        guard let launch = validated else { return nil }
        let command: String?
        switch launch {
        case let .agent(kind):
            command = AgentLaunch.command(for: kind)
        case let .ssh(user, host, port):
            if port == 22 {
                command = "ssh -l \(Self.quoted(user)) -- \(Self.quoted(host))"
            } else {
                command = "ssh -p \(port) -l \(Self.quoted(user)) -- \(Self.quoted(host))"
            }
        case let .claudeResume(sessionID):
            command = "claude --resume \(sessionID)"
        case let .tmux(action, name):
            command = try? TmuxLaunch.command(action: action, name: name)
        }

        guard let command,
              command.utf8.count <= Self.maxSpawnCommandByteCount
        else { return nil }
        return command
    }

    private static func validatedSSHUser(_ value: String) -> String? {
        validatedSSHField(value)
    }

    private static func validatedSSHHost(_ value: String) -> String? {
        validatedSSHField(value)
    }

    private static func validatedSSHField(_ value: String) -> String? {
        guard !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= maxSSHFieldByteCount,
              !trimmed.hasPrefix("-"),
              !trimmed.contains("@"),
              !trimmed.contains(where: \.isWhitespace)
        else { return nil }
        return trimmed
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}

extension RestorableLaunch: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case agent
        case user
        case host
        case port
        case sessionID
        case action
        case name
    }

    private enum Kind: String, Codable {
        case agent
        case ssh
        case claudeResume
        case tmux
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .agent:
            let kind = try container.decode(AgentLaunch.Kind.self, forKey: .agent)
            self = .agent(kind)
        case .ssh:
            self = .ssh(
                user: try container.decode(String.self, forKey: .user),
                host: try container.decode(String.self, forKey: .host),
                port: try container.decode(Int.self, forKey: .port)
            )
        case .claudeResume:
            self = .claudeResume(
                sessionID: try container.decode(String.self, forKey: .sessionID)
            )
        case .tmux:
            self = .tmux(
                action: try container.decode(TmuxLaunch.Action.self, forKey: .action),
                name: try container.decode(String.self, forKey: .name)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .agent(kind):
            try container.encode(Kind.agent, forKey: .kind)
            try container.encode(kind, forKey: .agent)
        case let .ssh(user, host, port):
            try container.encode(Kind.ssh, forKey: .kind)
            try container.encode(user, forKey: .user)
            try container.encode(host, forKey: .host)
            try container.encode(port, forKey: .port)
        case let .claudeResume(sessionID):
            try container.encode(Kind.claudeResume, forKey: .kind)
            try container.encode(sessionID, forKey: .sessionID)
        case let .tmux(action, name):
            try container.encode(Kind.tmux, forKey: .kind)
            try container.encode(action, forKey: .action)
            try container.encode(name, forKey: .name)
        }
    }
}
