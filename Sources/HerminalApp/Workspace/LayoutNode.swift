// LayoutNode — the binary split tree behind a tab's pane layout.
//
// v0.4.x laid panes out along a SINGLE axis (all side-by-side, or all
// stacked) — a flat array + ratios. v0.5 generalises that to a recursive
// tree, tmux / iTerm2 / Ghostty style: any pane can split again along
// either axis, nesting arbitrarily.
//
// A node is either:
//   • a LEAF — one terminal, referenced by its `TerminalSession.id` (a
//     stable UUID). The tree never owns the session, only points at it,
//     so identity-based lookups elsewhere keep working.
//   • a SPLIT — two child subtrees laid out along `axis`, with `ratio`
//     giving the FIRST child's fraction of the axis (0<ratio<1). Each
//     split carries its own UUID so the view layer can map it 1-1 to a
//     draggable divider.
//
// The type is a pure value tree: every mutation returns a NEW tree
// (immutability — see coding-style). That keeps it trivially testable and
// snapshot-friendly; WorkspaceTab owns the single mutable `root`.

import CoreGraphics
import Foundation

/// Which way a split divides its rect.
enum SplitAxis: String, Codable, Sendable, Equatable {
    /// Children sit side by side, divided by a vertical bar (drag ↔).
    case vertical
    /// Children stack, divided by a horizontal bar (drag ↕). Child
    /// `first` is the TOP one.
    case horizontal
}

/// A split's payload — pulled into a struct so the recursive `LayoutNode`
/// stays readable and the fields can mutate in place during a rebuild.
struct SplitInfo: Equatable, Sendable {
    /// Stable identity, for mapping the split to its divider view.
    let id: UUID
    var axis: SplitAxis
    /// The FIRST child's fraction of the axis extent. Kept in
    /// `[minRatio, 1-minRatio]`.
    var ratio: CGFloat
    var first: LayoutNode
    var second: LayoutNode
}

indirect enum LayoutNode: Equatable, Sendable {
    case leaf(UUID)
    case split(SplitInfo)

    /// A pane can't be dragged smaller than this fraction of its split's
    /// axis — keeps a sliver grabbable and avoids a 0-extent surface
    /// libghostty would reject. (Matches the old flat-model floor.)
    static let minRatio: CGFloat = 0.08

    // MARK: - Queries

    /// All leaf ids, left-to-right / top-to-bottom (in-order traversal) —
    /// the natural reading order, which WorkspaceTab exposes as `panes`.
    func leaves() -> [UUID] {
        switch self {
        case let .leaf(id):
            return [id]
        case let .split(info):
            return info.first.leaves() + info.second.leaves()
        }
    }

    func contains(_ id: UUID) -> Bool {
        switch self {
        case let .leaf(leafID):
            return leafID == id
        case let .split(info):
            return info.first.contains(id) || info.second.contains(id)
        }
    }

    // MARK: - Mutations (return a new tree)

    /// Replaces the leaf `target` with `replacement` (used to split a
    /// pane: the leaf becomes a split of itself + the new pane).
    func replacingLeaf(_ target: UUID, with replacement: LayoutNode) -> LayoutNode {
        switch self {
        case let .leaf(id):
            return id == target ? replacement : self
        case let .split(info):
            var copy = info
            copy.first = info.first.replacingLeaf(target, with: replacement)
            copy.second = info.second.replacingLeaf(target, with: replacement)
            return .split(copy)
        }
    }

    /// Removes leaf `target`, collapsing its parent split so the sibling
    /// subtree takes the parent's place. Returns nil when `target` was the
    /// whole tree (the tab is now empty).
    func removingLeaf(_ target: UUID) -> LayoutNode? {
        switch self {
        case let .leaf(id):
            return id == target ? nil : self
        case let .split(info):
            // If a direct child IS the target leaf, collapse to the sibling.
            if case let .leaf(firstID) = info.first, firstID == target {
                return info.second
            }
            if case let .leaf(secondID) = info.second, secondID == target {
                return info.first
            }
            // Otherwise recurse; a side that collapses to nil can't happen
            // here (only a lone leaf returns nil, handled above), so a
            // recursive nil means that whole subtree vanished — fold up.
            var copy = info
            if let newFirst = info.first.removingLeaf(target) {
                copy.first = newFirst
            } else {
                return info.second
            }
            if let newSecond = info.second.removingLeaf(target) {
                copy.second = newSecond
            } else {
                return copy.first
            }
            return .split(copy)
        }
    }

    /// Sets the ratio of the split identified by `splitID`, clamped so
    /// neither child drops below `minRatio`.
    func adjustingRatio(splitID: UUID, to ratio: CGFloat) -> LayoutNode {
        switch self {
        case .leaf:
            return self
        case let .split(info):
            var copy = info
            if info.id == splitID {
                copy.ratio = min(max(ratio, Self.minRatio), 1 - Self.minRatio)
            } else {
                copy.first = info.first.adjustingRatio(splitID: splitID, to: ratio)
                copy.second = info.second.adjustingRatio(splitID: splitID, to: ratio)
            }
            return .split(copy)
        }
    }
}
