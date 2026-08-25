// AgentLaunch — whitelist of commands the cockpit UI is allowed to
// spawn. FlightDeck's `prefix a` / `prefix g` / `wt` always launch a
// known binary; we do the same so a preference or menu path cannot
// become a free-form shell string.

enum AgentLaunch {
    enum Kind: String, CaseIterable, Identifiable, Codable, Sendable {
        case claude
        case codex
        case aider
        case lazygit
        case shell

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .claude: return "Claude Code"
            case .codex: return "Codex"
            case .aider: return "Aider"
            case .lazygit: return "lazygit"
            case .shell: return "Shell"
            }
        }
    }

    /// nil means "plain shell pane" — libghostty starts the macOS login
    /// shell unless Settings bootstraps a validated override.
    static func command(for kind: Kind) -> String? {
        switch kind {
        case .claude: return "claude"
        case .codex: return "codex"
        case .aider: return "aider"
        case .lazygit: return "lazygit"
        case .shell: return nil
        }
    }
}
