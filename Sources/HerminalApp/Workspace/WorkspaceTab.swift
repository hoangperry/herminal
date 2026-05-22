// WorkspaceTab — one tab. Holds one or more panes (terminal sessions)
// arranged along a single split axis.
//
// MVP scope: a tab splits along ONE axis (all panes side-by-side, or all
// stacked). Recursive split trees (tmux-style nesting) are deferred — see
// docs/backlog/month-2.md Q2-002.

import AppKit
import GhosttyKit

@MainActor
final class WorkspaceTab: Identifiable {
    nonisolated let id = UUID()
    private(set) var panes: [TerminalSession]
    /// true → panes sit side-by-side (vertical divider); false → stacked.
    private(set) var isVerticalSplit: Bool
    private(set) var focusedPaneIndex: Int

    init(app: ghostty_app_t) {
        self.panes = [TerminalSession(app: app)]
        self.isVerticalSplit = true
        self.focusedPaneIndex = 0
    }

    var focusedPane: TerminalSession { panes[focusedPaneIndex] }

    var title: String {
        let base = focusedPane.title
        return panes.count > 1 ? "\(base) (\(panes.count))" : base
    }

    /// Splits the focused pane, adding a new pane next to it.
    /// The first split sets the tab's axis; later splits reuse it.
    func split(app: ghostty_app_t, vertical: Bool) {
        if panes.count == 1 { isVerticalSplit = vertical }
        let session = TerminalSession(app: app)
        panes.insert(session, at: focusedPaneIndex + 1)
        focusedPaneIndex += 1
    }

    /// Closes the focused pane. Returns true if the tab is now empty.
    func closeFocusedPane() -> Bool {
        panes.remove(at: focusedPaneIndex)
        if panes.isEmpty { return true }
        focusedPaneIndex = min(focusedPaneIndex, panes.count - 1)
        return false
    }

    func focusPane(at index: Int) {
        guard panes.indices.contains(index) else { return }
        focusedPaneIndex = index
    }
}
