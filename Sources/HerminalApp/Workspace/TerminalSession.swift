// TerminalSession — one terminal session: a libghostty surface + tab metadata.
// A workspace holds many sessions; each tab maps to one session.

import AppKit
import GhosttyKit

@MainActor
final class TerminalSession: Identifiable {
    nonisolated let id = UUID()
    let surfaceView: HerminalSurfaceView
    var title: String
    /// Wall-clock creation time. Used by `AgentPaneMapper` to pair this
    /// session with the libghostty login process spawned alongside it
    /// (Nth-oldest login → Nth-oldest session).
    let createdAt: TimeInterval

    init(app: ghostty_app_t, title: String = "herminal",
         command: String? = nil, workingDirectory: String? = nil) {
        self.surfaceView = HerminalSurfaceView(
            app: app, command: command, workingDirectory: workingDirectory
        )
        self.title = title
        self.createdAt = Date().timeIntervalSince1970
    }
}
