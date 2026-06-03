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
    /// Fractional extent of each pane along the split axis. Sums to 1.0
    /// and stays in lock-step with `panes`. Even-split is the default;
    /// divider drag (v0.3.3) mutates this. Invariant: count ==
    /// panes.count, every element ≥ `Self.minRatio`.
    private(set) var paneRatios: [CGFloat]

    /// A pane can't be dragged smaller than this fraction of the axis —
    /// keeps a sliver always grabbable and avoids a 0-extent Metal
    /// surface that libghostty would reject.
    static let minRatio: CGFloat = 0.08

    init(app: ghostty_app_t, command: String? = nil, title: String = "herminal",
         workingDirectory: String? = nil) {
        self.panes = [TerminalSession(
            app: app, title: title, command: command, workingDirectory: workingDirectory
        )]
        self.isVerticalSplit = true
        self.focusedPaneIndex = 0
        self.paneRatios = [1.0]
    }

    /// Rebuilds a tab from a restored `TabSnapshot` (v0.4.1 session
    /// restore). Every pane spawns a plain shell in its saved cwd — the
    /// snapshot never carries a command, so ssh/claude panes come back
    /// as clean local shells (see WorkspaceStore header). The snapshot is
    /// already sanitised (≥1 pane, ratios normalised, focus in range).
    init(app: ghostty_app_t, restoring snapshot: TabSnapshot) {
        let restoredPanes = snapshot.panes.map { pane in
            TerminalSession(app: app, command: nil, workingDirectory: pane.cwd)
        }
        self.panes = restoredPanes
        self.isVerticalSplit = snapshot.isVerticalSplit
        self.focusedPaneIndex = min(max(snapshot.focusedPaneIndex, 0), max(restoredPanes.count - 1, 0))
        self.paneRatios = snapshot.paneRatios.map { CGFloat($0) }
    }

    /// Captures this tab's restorable state. Pane cwds come from the live
    /// OSC 7 tracking on each surface. (v0.4.1.)
    func snapshot() -> TabSnapshot {
        TabSnapshot(
            isVerticalSplit: isVerticalSplit,
            focusedPaneIndex: focusedPaneIndex,
            paneRatios: paneRatios.map { Double($0) },
            panes: panes.map { PaneSnapshot(cwd: $0.surfaceView.currentWorkingDirectory) }
        )
    }

    var focusedPane: TerminalSession { panes[focusedPaneIndex] }

    var title: String {
        let base = focusedPane.displayLabel
        return panes.count > 1 ? "\(base) (\(panes.count))" : base
    }

    /// Splits the focused pane, adding a new pane next to it.
    /// The first split sets the tab's axis; later splits reuse it.
    /// The focused pane's ratio is halved and the new pane takes the
    /// other half, so the split is visually 50/50 of whatever the
    /// focused pane currently occupies.
    func split(app: ghostty_app_t, vertical: Bool) {
        if panes.count == 1 { isVerticalSplit = vertical }
        let session = TerminalSession(app: app)
        panes.insert(session, at: focusedPaneIndex + 1)
        let half = paneRatios[focusedPaneIndex] / 2
        paneRatios[focusedPaneIndex] = half
        paneRatios.insert(half, at: focusedPaneIndex + 1)
        focusedPaneIndex += 1
    }

    /// Closes the focused pane. Returns true if the tab is now empty.
    func closeFocusedPane() -> Bool {
        panes.remove(at: focusedPaneIndex)
        paneRatios.remove(at: focusedPaneIndex)
        if panes.isEmpty { return true }
        normalizeRatios()
        focusedPaneIndex = min(focusedPaneIndex, panes.count - 1)
        return false
    }

    /// Remove the pane at a specific index. Used by the
    /// `surfaceDidClose` listener when libghostty tells us a PTY child
    /// died — the pane to remove may not be the focused one.
    func removePane(at index: Int) {
        guard panes.indices.contains(index) else { return }
        panes.remove(at: index)
        paneRatios.remove(at: index)
        if !panes.isEmpty { normalizeRatios() }
        focusedPaneIndex = panes.isEmpty ? 0 : min(focusedPaneIndex, panes.count - 1)
    }

    func focusPane(at index: Int) {
        guard panes.indices.contains(index) else { return }
        focusedPaneIndex = index
    }

    /// Move the divider between pane `index` and `index + 1` by
    /// `fraction` of the total axis extent. Positive grows the
    /// lower-index pane. Clamped so neither neighbour shrinks below
    /// `minRatio`. (v0.3.3 drag-resize.)
    func adjustDivider(at index: Int, byFraction fraction: CGFloat) {
        guard paneRatios.indices.contains(index),
              paneRatios.indices.contains(index + 1) else { return }
        let left = paneRatios[index] + fraction
        let right = paneRatios[index + 1] - fraction
        guard left >= Self.minRatio, right >= Self.minRatio else { return }
        paneRatios[index] = left
        paneRatios[index + 1] = right
    }

    /// Rescale `paneRatios` so they sum to 1.0 — called after a remove
    /// redistributes the closed pane's share across the survivors.
    private func normalizeRatios() {
        let sum = paneRatios.reduce(0, +)
        guard sum > 0 else {
            let even = 1.0 / CGFloat(max(paneRatios.count, 1))
            paneRatios = Array(repeating: even, count: paneRatios.count)
            return
        }
        paneRatios = paneRatios.map { $0 / sum }
    }
}
