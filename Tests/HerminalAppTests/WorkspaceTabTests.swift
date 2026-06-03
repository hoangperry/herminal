import Foundation
import Testing
@testable import HerminalApp

/// WorkspaceTab pane/split/focus logic. A dummy app handle is enough: the
/// libghostty surface is only created once the view enters a window, which
/// these tests never do — so the handle is never dereferenced.
@MainActor
@Suite("WorkspaceTab")
struct WorkspaceTabTests {
    private var dummyApp: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(bitPattern: 0xDEAD)!
    }

    @Test("a new tab has exactly one focused pane")
    func newTabHasOnePane() {
        let tab = WorkspaceTab(app: dummyApp)
        #expect(tab.panes.count == 1)
        #expect(tab.focusedPaneIndex == 0)
    }

    @Test("split adds a pane and moves focus to it")
    func splitAddsPane() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        #expect(tab.panes.count == 2)
        #expect(tab.focusedPaneIndex == 1)
    }

    @Test("the first split sets the tab axis")
    func firstSplitSetsAxis() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: false)
        #expect(tab.isVerticalSplit == false)
    }

    @Test("closeFocusedPane reports empty only when the last pane goes")
    func closeReportsEmpty() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // 2 panes
        #expect(tab.closeFocusedPane() == false)
        #expect(tab.panes.count == 1)
        #expect(tab.closeFocusedPane() == true)
    }

    @Test("closeFocusedPane clamps the focus index in range")
    func closeClampsFocus() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // focus index = 1
        _ = tab.closeFocusedPane()
        #expect(tab.focusedPaneIndex == 0)
    }

    @Test("focusPane ignores out-of-range indices")
    func focusPaneBounds() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // 2 panes, focus = 1
        tab.focusPane(at: 99)
        #expect(tab.focusedPaneIndex == 1) // unchanged
        tab.focusPane(at: 0)
        #expect(tab.focusedPaneIndex == 0)
    }

    @Test("title shows the pane count once a tab is split")
    func titleShowsCount() {
        let tab = WorkspaceTab(app: dummyApp)
        #expect(!tab.title.contains("("))
        tab.split(app: dummyApp, vertical: true)
        #expect(tab.title.contains("(2)"))
    }

    // MARK: - paneRatios invariant (v0.3.3 drag-resize)

    /// The contract `WorkspaceTab` promises: `paneRatios.count ==
    /// panes.count`, the ratios sum to ~1.0, and every entry is
    /// ≥ `minRatio`. These guard that across every mutator.

    private func ratiosSumToOne(_ tab: WorkspaceTab, _ sourceLocation: SourceLocation = #_sourceLocation) {
        let sum = tab.paneRatios.reduce(0, +)
        #expect(abs(sum - 1.0) < 1e-9, "ratios must sum to 1, got \(sum)", sourceLocation: sourceLocation)
        #expect(tab.paneRatios.count == tab.panes.count, sourceLocation: sourceLocation)
    }

    @Test("a fresh tab's single pane fills the axis")
    func freshTabFullRatio() {
        let tab = WorkspaceTab(app: dummyApp)
        #expect(tab.paneRatios == [1.0])
    }

    @Test("split halves the focused pane's ratio")
    func splitHalvesRatio() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        #expect(tab.paneRatios == [0.5, 0.5])
        ratiosSumToOne(tab)
    }

    @Test("ratios stay in lock-step with panes across repeated splits")
    func ratiosTrackPanes() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // [0.5, 0.5], focus 1
        tab.split(app: dummyApp, vertical: true) // halve pane 1 → [0.5, 0.25, 0.25]
        #expect(tab.panes.count == 3)
        #expect(tab.paneRatios == [0.5, 0.25, 0.25])
        ratiosSumToOne(tab)
    }

    @Test("adjustDivider shifts the boundary and preserves the sum")
    func adjustDividerShifts() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // [0.5, 0.5]
        tab.adjustDivider(at: 0, byFraction: 0.1)
        #expect(abs(tab.paneRatios[0] - 0.6) < 1e-9)
        #expect(abs(tab.paneRatios[1] - 0.4) < 1e-9)
        ratiosSumToOne(tab)
    }

    @Test("adjustDivider refuses to shrink a pane below minRatio")
    func adjustDividerClamps() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // [0.5, 0.5]
        // +0.5 would drive pane 1 to 0.0 (< minRatio 0.08) → rejected.
        tab.adjustDivider(at: 0, byFraction: 0.5)
        #expect(tab.paneRatios == [0.5, 0.5])
    }

    @Test("closeFocusedPane renormalizes the survivors to sum 1")
    func closeRenormalizes() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // [0.5, 0.5]
        tab.split(app: dummyApp, vertical: true) // [0.5, 0.25, 0.25]
        _ = tab.closeFocusedPane()               // drop one → renormalize
        #expect(tab.panes.count == 2)
        ratiosSumToOne(tab)
    }

    @Test("removePane renormalizes and keeps focus in range")
    func removePaneRenormalizes() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true) // [0.5, 0.5], focus 1
        tab.split(app: dummyApp, vertical: true) // [0.5, 0.25, 0.25], focus 2
        tab.removePane(at: 0)
        #expect(tab.panes.count == 2)
        #expect(tab.focusedPaneIndex < tab.panes.count)
        ratiosSumToOne(tab)
    }

    @Test("a restored tab keeps its snapshot ratios")
    func restoredTabKeepsRatios() {
        let snapshot = TabSnapshot(
            isVerticalSplit: false, focusedPaneIndex: 1,
            paneRatios: [0.3, 0.7],
            panes: [PaneSnapshot(cwd: nil), PaneSnapshot(cwd: nil)]
        )
        let tab = WorkspaceTab(app: dummyApp, restoring: snapshot)
        #expect(tab.paneRatios == [0.3, 0.7])
        #expect(tab.isVerticalSplit == false)
        #expect(tab.focusedPaneIndex == 1)
    }

    @Test("snapshot round-trips the live ratios")
    func snapshotRoundTrips() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        tab.adjustDivider(at: 0, byFraction: 0.1) // [0.6, 0.4]
        let snap = tab.snapshot()
        #expect(snap.paneRatios.count == 2)
        #expect(abs(snap.paneRatios[0] - 0.6) < 1e-9)
        #expect(abs(snap.paneRatios.reduce(0, +) - 1.0) < 1e-9)
    }
}
