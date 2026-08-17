import CoreGraphics
import Testing
@testable import HerminalApp

@Suite("PaneGridSizing")
struct PaneGridSizingTests {
    @Test("whole-cell heights are unchanged")
    func exactHeight() {
        let rect = CGRect(x: 4, y: 6, width: 300, height: 100)
        #expect(PaneGridSizing.snapVertically(rect, cellHeightPixels: 20, scale: 2) == rect)
    }

    @Test("partial rows are removed and the remainder is balanced")
    func balancesRemainder() {
        let rect = CGRect(x: 4, y: 6, width: 300, height: 103)
        let snapped = PaneGridSizing.snapVertically(rect, cellHeightPixels: 20, scale: 2)
        #expect(snapped == CGRect(x: 4, y: 7.5, width: 300, height: 100))
    }

    @Test("snapping is calculated in backing pixels")
    func respectsBackingScale() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 51)
        let snapped = PaneGridSizing.snapVertically(rect, cellHeightPixels: 18, scale: 2)
        #expect(snapped.height == 45)
        #expect(snapped.minY == 3)
    }

    @Test("missing metrics and sub-cell panes remain visible")
    func invalidOrTinyInputs() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 7)
        #expect(PaneGridSizing.snapVertically(rect, cellHeightPixels: 0, scale: 2) == rect)
        #expect(PaneGridSizing.snapVertically(rect, cellHeightPixels: 20, scale: 0) == rect)
        #expect(PaneGridSizing.snapVertically(rect, cellHeightPixels: 20, scale: 2) == rect)
    }
}
