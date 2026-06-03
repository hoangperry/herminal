import Foundation
import Testing
@testable import HerminalApp

// The pure split-tree behind recursive panes (v0.5). These pin the model
// operations in isolation — no view, no libghostty.
@Suite("LayoutNode")
struct LayoutNodeTests {
    private let a = UUID(), b = UUID(), c = UUID(), d = UUID()

    private func split(_ axis: SplitAxis, _ ratio: CGFloat,
                       _ first: LayoutNode, _ second: LayoutNode,
                       id: UUID = UUID()) -> LayoutNode {
        .split(SplitInfo(id: id, axis: axis, ratio: ratio, first: first, second: second))
    }

    // MARK: - Queries

    @Test("a lone leaf reports just itself")
    func loneLeaf() {
        let tree = LayoutNode.leaf(a)
        #expect(tree.leaves() == [a])
        #expect(tree.contains(a))
        #expect(!tree.contains(b))
    }

    @Test("leaves() is an in-order (reading-order) traversal")
    func leavesInOrder() {
        // a | (b / c)  → reads a, b, c
        let tree = split(.vertical, 0.5, .leaf(a), split(.horizontal, 0.5, .leaf(b), .leaf(c)))
        #expect(tree.leaves() == [a, b, c])
    }

    // MARK: - Split (replaceLeaf)

    @Test("replacingLeaf turns a pane into a split of itself + the new pane")
    func replaceLeafSplits() {
        let tree = LayoutNode.leaf(a)
        let replaced = tree.replacingLeaf(a, with: split(.vertical, 0.5, .leaf(a), .leaf(b)))
        #expect(replaced.leaves() == [a, b])
    }

    @Test("replacingLeaf only touches the target leaf")
    func replaceLeafTargeted() {
        let tree = split(.vertical, 0.5, .leaf(a), .leaf(b))
        let replaced = tree.replacingLeaf(b, with: split(.horizontal, 0.5, .leaf(b), .leaf(c)))
        #expect(replaced.leaves() == [a, b, c])
        #expect(replaced.contains(a))
    }

    // MARK: - Close (removeLeaf → collapse parent)

    @Test("removing the only leaf empties the tree (nil)")
    func removeLastLeaf() {
        #expect(LayoutNode.leaf(a).removingLeaf(a) == nil)
    }

    @Test("removing a leaf collapses its parent to the sibling")
    func removeCollapsesToSibling() {
        let tree = split(.vertical, 0.5, .leaf(a), .leaf(b))
        #expect(tree.removingLeaf(a) == .leaf(b))
        #expect(tree.removingLeaf(b) == .leaf(a))
    }

    @Test("removing a nested leaf keeps the rest of the tree")
    func removeNested() {
        // a | (b / c)
        let inner = split(.horizontal, 0.5, .leaf(b), .leaf(c), id: UUID())
        let tree = split(.vertical, 0.5, .leaf(a), inner, id: UUID())
        // Remove b → inner collapses to c → a | c
        let afterB = tree.removingLeaf(b)
        #expect(afterB?.leaves() == [a, c])
        // Remove a → whole left side gone → just the inner subtree
        let afterA = tree.removingLeaf(a)
        #expect(afterA?.leaves() == [b, c])
    }

    @Test("removing an absent leaf is a no-op")
    func removeAbsent() {
        let tree = split(.vertical, 0.5, .leaf(a), .leaf(b))
        #expect(tree.removingLeaf(d) == tree)
    }

    // MARK: - Resize (adjustRatio)

    @Test("adjustingRatio sets the targeted split's ratio")
    func adjustTargetsSplit() {
        let sid = UUID()
        let tree = split(.vertical, 0.5, .leaf(a), .leaf(b), id: sid)
        guard case let .split(info) = tree.adjustingRatio(splitID: sid, to: 0.7) else {
            Issue.record("expected a split"); return
        }
        #expect(abs(info.ratio - 0.7) < 1e-9)
    }

    @Test("adjustingRatio clamps to keep both children >= minRatio")
    func adjustClamps() {
        let sid = UUID()
        let tree = split(.vertical, 0.5, .leaf(a), .leaf(b), id: sid)
        guard case let .split(tooBig) = tree.adjustingRatio(splitID: sid, to: 0.99),
              case let .split(tooSmall) = tree.adjustingRatio(splitID: sid, to: -0.5) else {
            Issue.record("expected splits"); return
        }
        #expect(abs(tooBig.ratio - (1 - LayoutNode.minRatio)) < 1e-9)
        #expect(abs(tooSmall.ratio - LayoutNode.minRatio) < 1e-9)
    }

    @Test("adjustingRatio reaches a nested split by id and leaves others")
    func adjustNested() {
        let outer = UUID(), inner = UUID()
        let tree = split(.vertical, 0.5, .leaf(a),
                         split(.horizontal, 0.5, .leaf(b), .leaf(c), id: inner),
                         id: outer)
        let adjusted = tree.adjustingRatio(splitID: inner, to: 0.3)
        guard case let .split(outerInfo) = adjusted,
              case let .split(innerInfo) = outerInfo.second else {
            Issue.record("shape changed"); return
        }
        #expect(abs(outerInfo.ratio - 0.5) < 1e-9)   // untouched
        #expect(abs(innerInfo.ratio - 0.3) < 1e-9)   // adjusted
    }
}
