import CoreGraphics
import Foundation
import Testing
@testable import HerminalApp

// Spatial pane focus movement (v0.5 directional nav). Pure frame geometry,
// AppKit coords (origin bottom-left → "up" is +y).
@Suite("PaneNavigation")
struct PaneNavigationTests {
    private let a = UUID(), b = UUID(), c = UUID()

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    // Two side-by-side columns: A (left) | B (right), full height.
    private var twoColumns: (focusedA: CGRect, focusedB: CGRect, all: [(id: UUID, rect: CGRect)]) {
        let ra = rect(0, 0, 500, 800)
        let rb = rect(500, 0, 500, 800)
        return (ra, rb, [(a, ra), (b, rb)])
    }

    @Test("right moves to the pane on the right; left moves back")
    func horizontalMove() {
        let layout = twoColumns
        #expect(PaneNavigation.nearestPane(from: layout.focusedA,
                candidates: [(b, layout.all[1].rect)], direction: .right) == b)
        #expect(PaneNavigation.nearestPane(from: layout.focusedB,
                candidates: [(a, layout.all[0].rect)], direction: .left) == a)
    }

    @Test("no pane above/below two side-by-side columns")
    func noVerticalNeighbour() {
        let layout = twoColumns
        let others = [(b, layout.all[1].rect)]
        #expect(PaneNavigation.nearestPane(from: layout.focusedA, candidates: others, direction: .up) == nil)
        #expect(PaneNavigation.nearestPane(from: layout.focusedA, candidates: others, direction: .down) == nil)
        #expect(PaneNavigation.nearestPane(from: layout.focusedA, candidates: others, direction: .left) == nil)
    }

    // L-shape: A spans the left full height; the right column is split into
    // B (top) and C (bottom).
    //   A: x 0..500,   y 0..800
    //   B: x 500..1000, y 400..800   (top)
    //   C: x 500..1000, y 0..400     (bottom)
    private var lShape: (rA: CGRect, rB: CGRect, rC: CGRect) {
        (rect(0, 0, 500, 800), rect(500, 400, 500, 400), rect(500, 0, 500, 400))
    }

    @Test("from the top-right pane: left → A, down → C")
    func fromTopRight() {
        let l = lShape
        #expect(PaneNavigation.nearestPane(from: l.rB,
                candidates: [(a, l.rA), (c, l.rC)], direction: .left) == a)
        #expect(PaneNavigation.nearestPane(from: l.rB,
                candidates: [(a, l.rA), (c, l.rC)], direction: .down) == c)
    }

    @Test("from the bottom-right pane: up → B, left → A")
    func fromBottomRight() {
        let l = lShape
        #expect(PaneNavigation.nearestPane(from: l.rC,
                candidates: [(a, l.rA), (b, l.rB)], direction: .up) == b)
        #expect(PaneNavigation.nearestPane(from: l.rC,
                candidates: [(a, l.rA), (b, l.rB)], direction: .left) == a)
    }

    @Test("from the tall left pane, right reaches one of the stacked panes")
    func fromTallLeft() {
        let l = lShape
        let target = PaneNavigation.nearestPane(from: l.rA,
            candidates: [(b, l.rB), (c, l.rC)], direction: .right)
        #expect(target == b || target == c)  // symmetric — either is correct
    }

    @Test("no candidates yields no move")
    func noCandidates() {
        #expect(PaneNavigation.nearestPane(from: rect(0, 0, 100, 100),
                candidates: [], direction: .right) == nil)
    }
}
