// WorkspaceTab — one tab. Holds one or more panes (terminal sessions)
// arranged in a recursive split TREE (v0.5).
//
// v0.4.x split along a single axis (all side-by-side or all stacked).
// v0.5 generalises to tmux/iTerm2-style nesting: any pane can split again
// along either axis. The geometry lives in a `LayoutNode` tree; the
// sessions live in a flat array the tree references by id. `panes` and
// `focusedPane` are derived from the tree so the rest of the app — which
// only iterates panes or reads the focused one — is unaffected by the
// model change.

import AppKit
import GhosttyKit

@MainActor
final class WorkspaceTab: Identifiable {
    nonisolated let id = UUID()

    /// Every live session in this tab — the tree's leaves, stored flat for
    /// identity lookups. `panes` returns them in the tree's reading order.
    private var sessions: [TerminalSession]
    /// The split tree. Leaves reference `sessions` by id.
    private(set) var root: LayoutNode
    /// The focused leaf's id. Invariant: always a live session.
    private(set) var focusedPaneID: UUID
    /// When set, this pane is "zoomed" — temporarily filling the whole tab,
    /// the others hidden. Transient view state (not persisted); cleared by
    /// any structural or focus change. (v1.0 pane zoom.)
    private(set) var zoomedPaneID: UUID?

    init(app: ghostty_app_t, command: String? = nil,
         title: String = TerminalSession.defaultTitle,
         workingDirectory: String? = nil) {
        let session = TerminalSession(
            app: app, title: title, command: command, workingDirectory: workingDirectory
        )
        self.sessions = [session]
        self.root = .leaf(session.id)
        self.focusedPaneID = session.id
    }

    /// Rebuilds a tab from a restored `TabSnapshot` (session restore).
    /// Every pane spawns a plain shell in its saved cwd — the snapshot
    /// never carries a command, so ssh/claude panes come back as clean
    /// local shells (see WorkspaceStore header). When the snapshot has a
    /// `layout` tree we rebuild it; pre-v0.5 flat snapshots are folded
    /// into a left-leaning chain along the saved axis.
    init(app: ghostty_app_t, restoring snapshot: TabSnapshot, rerunCommands: Bool = false) {
        let restored = snapshot.panes.map { pane in
            // Conservative default: each pane comes back as a plain shell.
            // Only when the owner opted into "re-run commands on restore"
            // do we replay the saved ssh/claude command (validated first).
            let command = rerunCommands ? Self.safeRerunCommand(pane.command) : nil
            return TerminalSession(app: app, command: command, workingDirectory: pane.cwd)
        }
        let live = restored.isEmpty ? [TerminalSession(app: app)] : restored
        self.sessions = live

        if let tree = snapshot.layout, Self.isValidTree(tree, count: live.count) {
            self.root = Self.buildNode(from: tree, sessions: live)
        } else {
            self.root = Self.flatTree(
                sessions: live,
                vertical: snapshot.isVerticalSplit ?? true,
                ratios: snapshot.paneRatios
            )
        }
        let focus = min(max(snapshot.focusedPaneIndex, 0), live.count - 1)
        self.focusedPaneID = live[focus].id
    }

    // MARK: - Derived views (preserve the pre-v0.5 API)

    /// Panes in reading order (tree in-order traversal of leaves).
    var panes: [TerminalSession] {
        let byID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return root.leaves().compactMap { byID[$0] }
    }

    /// Panes whose PTY is still live. Exited panes may remain in `panes`
    /// temporarily so an at-risk note can still be retried or exported.
    var livePanes: [TerminalSession] {
        panes.filter { !$0.hasExited }
    }

    var focusedPane: TerminalSession {
        sessions.first { $0.id == focusedPaneID } ?? sessions[0]
    }

    /// Index of the focused pane within `panes`. Back-compat for the
    /// dump-state harness; the tree tracks focus by id internally.
    var focusedPaneIndex: Int { panes.firstIndex { $0.id == focusedPaneID } ?? 0 }

    var title: String {
        let base = focusedPane.displayLabel
        return sessions.count > 1 ? "\(base) (\(sessions.count))" : base
    }

    /// The surface for a given leaf id — the recursive layout looks panes
    /// up by id as it walks the tree.
    func surfaceView(for id: UUID) -> HerminalSurfaceView? {
        sessions.first { $0.id == id }?.surfaceView
    }

    // MARK: - Mutations

    /// Splits the focused pane in two along `vertical ? .vertical :
    /// .horizontal`, 50/50, and moves focus to the new pane.
    /// `command` / `title` let the cockpit spawn an agent or lazygit in
    /// the new pane instead of a plain shell.
    func split(app: ghostty_app_t, vertical: Bool,
               command: String? = nil, title: String? = nil) {
        zoomedPaneID = nil  // structure changed — drop any zoom
        // The new pane opens in the same directory as the one being split
        // (OSC 7) — splitting while in ~/proj keeps you in ~/proj.
        let inheritedCwd = focusedPane.surfaceView.currentWorkingDirectory
        let new = TerminalSession(
            app: app,
            title: title ?? TerminalSession.defaultTitle,
            command: command,
            workingDirectory: inheritedCwd
        )
        sessions.append(new)
        let axis: SplitAxis = vertical ? .vertical : .horizontal
        let replacement = LayoutNode.split(SplitInfo(
            id: UUID(), axis: axis, ratio: 0.5,
            first: .leaf(focusedPaneID), second: .leaf(new.id)
        ))
        root = root.replacingLeaf(focusedPaneID, with: replacement)
        focusedPaneID = new.id
    }

    /// Closes the focused pane. Returns true if the tab is now empty.
    @discardableResult
    func closeFocusedPane() -> Bool { remove(focusedPaneID) }

    /// Removes a specific pane (used by the `surfaceDidClose` listener when
    /// a PTY child dies — not necessarily the focused pane).
    func removePane(id: UUID) { _ = remove(id) }

    func focusPane(id: UUID) {
        if sessions.contains(where: { $0.id == id }) {
            focusedPaneID = id
            zoomedPaneID = nil  // moving focus reveals the layout again
        }
    }

    /// Focuses the pane whose original spawn command targets `name`.
    /// This matters when a tmux client lives in a split: selecting only its
    /// tab would leave keyboard focus in an unrelated sibling pane.
    @discardableResult
    func focusPane(spawningTmuxNamed name: String) -> Bool {
        guard let pane = panes.first(where: { pane in
            pane.closeRiskCommand.flatMap(TmuxLaunch.sessionName(fromSpawnCommand:)) == name
        }) else { return false }
        focusPane(id: pane.id)
        return true
    }

    /// Toggles "zoom" on the focused pane: maximize it to fill the tab, or
    /// restore the split layout. No-op for a single-pane tab. (v1.0.)
    func toggleZoom() {
        if zoomedPaneID != nil {
            zoomedPaneID = nil
        } else if sessions.count > 1 {
            zoomedPaneID = focusedPaneID
        }
    }

    var isZoomed: Bool { zoomedPaneID != nil }

    /// Sets the ratio of a split node (driven by a divider drag).
    func adjustRatio(splitID: UUID, to ratio: CGFloat) {
        root = root.adjustingRatio(splitID: splitID, to: ratio)
    }

    /// Current ratio of a split — used to convert a drag delta to the new
    /// absolute ratio.
    func ratio(ofSplit id: UUID) -> CGFloat? { root.ratio(ofSplit: id) }

    @discardableResult
    private func remove(_ id: UUID) -> Bool {
        guard sessions.contains(where: { $0.id == id }) else { return sessions.isEmpty }
        zoomedPaneID = nil  // structure changed — drop any zoom
        // Pick the focus successor (sibling leaf) before we mutate the tree.
        let successor = root.leafToFocusAfterRemoving(id)
        sessions.removeAll { $0.id == id }
        guard let newRoot = root.removingLeaf(id) else {
            return true // that was the last pane → tab empty
        }
        root = newRoot
        if focusedPaneID == id {
            focusedPaneID = successor ?? newRoot.leaves().first ?? focusedPaneID
        }
        return false
    }

    // MARK: - Snapshot

    func snapshot() -> TabSnapshot {
        // A pane whose PTY exited can remain in memory briefly so the owner
        // can retry or export an at-risk note. It is not a restorable
        // terminal session and must never be resurrected as a fresh shell.
        let ordered = livePanes
        let indexByID = Dictionary(
            ordered.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a }
        )
        return TabSnapshot(
            panes: ordered.map {
                PaneSnapshot(
                    cwd: $0.surfaceView.currentWorkingDirectory,
                    command: $0.closeRiskCommand
                )
            },
            focusedPaneIndex: ordered.firstIndex { $0.id == focusedPaneID } ?? 0,
            layout: Self.snapshotNode(root, indexByID: indexByID),
            isVerticalSplit: nil,
            paneRatios: nil
        )
    }

    /// Vets a persisted spawn command before replaying it on restore.
    /// Re-run is already opt-in and `workspace.json` is owner-owned, but a
    /// hand-edited file shouldn't be able to smuggle a second command via
    /// a newline (the spawn runs through the shell), so reject anything
    /// carrying control characters. nil/empty → no command (plain shell).
    static func safeRerunCommand(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        guard !raw.contains(where: { $0.isNewline || $0 == "\0" }) else { return nil }
        return raw
    }

    // MARK: - Tree (de)serialization helpers

    /// Serializes only retained leaf ids. Missing leaves are exited panes;
    /// collapse their parent split so the surviving layout still references
    /// every persisted pane exactly once.
    private static func snapshotNode(
        _ node: LayoutNode,
        indexByID: [UUID: Int]
    ) -> LayoutSnapshot? {
        switch node {
        case let .leaf(id):
            return indexByID[id].map(LayoutSnapshot.leaf)
        case let .split(info):
            let first = snapshotNode(info.first, indexByID: indexByID)
            let second = snapshotNode(info.second, indexByID: indexByID)
            switch (first, second) {
            case let (.some(first), .some(second)):
                return .split(
                    axis: info.axis,
                    ratio: Double(info.ratio),
                    first: first,
                    second: second
                )
            case let (.some(first), .none):
                return first
            case let (.none, .some(second)):
                return second
            case (.none, .none):
                return nil
            }
        }
    }

    private static func isValidTree(_ tree: LayoutSnapshot, count: Int) -> Bool {
        tree.leafIndices().sorted() == Array(0..<count)
    }

    private static func buildNode(from snap: LayoutSnapshot, sessions: [TerminalSession]) -> LayoutNode {
        switch snap {
        case let .leaf(i):
            return .leaf(sessions[i].id)
        case let .split(axis, ratio, first, second):
            let clamped = min(max(CGFloat(ratio), LayoutNode.minRatio), 1 - LayoutNode.minRatio)
            return .split(SplitInfo(
                id: UUID(), axis: axis, ratio: clamped,
                first: buildNode(from: first, sessions: sessions),
                second: buildNode(from: second, sessions: sessions)
            ))
        }
    }

    /// Folds a flat (pre-v0.5) layout into a left-leaning chain along
    /// `axis`, preserving the per-pane proportions from `ratios`.
    private static func flatTree(sessions: [TerminalSession],
                                 vertical: Bool, ratios: [Double]?) -> LayoutNode {
        let axis: SplitAxis = vertical ? .vertical : .horizontal
        let weights: [Double] = {
            if let r = ratios, r.count == sessions.count, r.allSatisfy({ $0 > 0 && $0.isFinite }) {
                return r
            }
            return Array(repeating: 1.0, count: sessions.count)
        }()
        func build(_ start: Int) -> LayoutNode {
            if start >= sessions.count - 1 { return .leaf(sessions[start].id) }
            let remaining = weights[start...].reduce(0, +)
            let ratio = remaining > 0 ? CGFloat(weights[start] / remaining) : 0.5
            let clamped = min(max(ratio, LayoutNode.minRatio), 1 - LayoutNode.minRatio)
            return .split(SplitInfo(
                id: UUID(), axis: axis, ratio: clamped,
                first: .leaf(sessions[start].id), second: build(start + 1)
            ))
        }
        return build(0)
    }
}
