// TerminalSession — one terminal session: a libghostty surface + tab metadata.
// A workspace holds many sessions; each tab maps to one session.

import AppKit
import GhosttyKit

@MainActor
final class TerminalSession: Identifiable {
    /// The label a pane carries until a program sets its own (OSC 0/2)
    /// title. Also the sentinel `displayLabel` uses to decide whether to
    /// fall back to the live cwd.
    static let defaultTitle = "herminal"

    nonisolated let id = UUID()
    let surfaceView: HerminalSurfaceView
    var title: String
    /// The command this pane is currently running (ssh / claude from the
    /// managers), or nil for a plain shell pane. Workspace snapshots no
    /// longer persist this opaque shell string directly.
    let command: String?
    /// Structured metadata for launches herminal can safely reconstruct on
    /// restore. A layout-only restore may keep this descriptor even while the
    /// live pane is currently a plain shell, so a later save can still retain
    /// the allowlisted launch intent.
    let restorableLaunch: RestorableLaunch?
    /// Wall-clock creation time. Used by `AgentPaneMapper` to pair this
    /// session with the libghostty login process spawned alongside it
    /// (Nth-oldest login → Nth-oldest session).
    let createdAt: TimeInterval
    /// A terminal may remain in the layout after its PTY exits so an at-risk
    /// note can still be retried or exported. It must no longer represent
    /// live command or agent work in close-risk decisions.
    private(set) var hasExited = false

    var closeRiskCommand: String? {
        hasExited ? nil : command
    }

    init(app: ghostty_app_t, title: String = TerminalSession.defaultTitle,
         command: String? = nil,
         workingDirectory: String? = nil,
         restorableLaunch: RestorableLaunch? = nil) {
        let normalizedCommand = Self.normalizedSpawnCommand(command)
        self.surfaceView = HerminalSurfaceView(
            app: app, command: normalizedCommand, workingDirectory: workingDirectory
        )
        self.title = title
        self.command = normalizedCommand
        let validatedLaunch = restorableLaunch?.validated
        if let normalizedCommand, validatedLaunch?.spawnCommand != normalizedCommand {
            self.restorableLaunch = nil
        } else {
            self.restorableLaunch = validatedLaunch
        }
        self.createdAt = Date().timeIntervalSince1970
    }

    func markExited() {
        hasExited = true
    }

    /// What the tab strip shows. A program/shell that set its own title
    /// (vim, ssh, a prompt with PROMPT_COMMAND) wins — that's the most
    /// informative label and keeps the OSC 0/2 contract intact. Only when
    /// no title was set do we fall back to the live working directory's
    /// basename, so a bare shell's tab reads `~/proj` instead of a static
    /// "herminal". (v0.4.4 — the full cwd always shows in the status bar.)
    var displayLabel: String {
        if title != TerminalSession.defaultTitle, !title.isEmpty {
            return title
        }
        if let cwd = surfaceView.currentWorkingDirectory {
            return PathLabel.tabLabel(for: cwd)
        }
        return title
    }

    /// Empty-string spawn commands are an internal sentinel meaning
    /// "open a plain shell in this working directory", not a real custom
    /// command. Normalize once here so restore, close-risk, and persisted
    /// snapshots all describe the pane truthfully.
    private static func normalizedSpawnCommand(_ command: String?) -> String? {
        command == "" ? nil : command
    }
}
