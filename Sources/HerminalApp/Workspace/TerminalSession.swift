// TerminalSession — one terminal session: a libghostty surface + tab metadata.
// A workspace holds many sessions; each tab maps to one session.

import AppKit
import GhosttyKit

@MainActor
final class TerminalSession: Identifiable {
    nonisolated let id = UUID()
    let surfaceView: HerminalSurfaceView
    var title: String

    init(app: ghostty_app_t, title: String = "herminal") {
        self.surfaceView = HerminalSurfaceView(app: app)
        self.title = title
    }
}
