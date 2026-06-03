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
    /// Wall-clock creation time. Used by `AgentPaneMapper` to pair this
    /// session with the libghostty login process spawned alongside it
    /// (Nth-oldest login → Nth-oldest session).
    let createdAt: TimeInterval

    init(app: ghostty_app_t, title: String = TerminalSession.defaultTitle,
         command: String? = nil, workingDirectory: String? = nil) {
        self.surfaceView = HerminalSurfaceView(
            app: app, command: command, workingDirectory: workingDirectory
        )
        self.title = title
        self.createdAt = Date().timeIntervalSince1970
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
}
