import Foundation
import Testing
@testable import HerminalApp

// WorkspaceStore.sanitise is the trust boundary for session restore: it
// takes a decoded (possibly hand-edited / corrupt) workspace.json and
// must always return a layout safe to feed the view — ratios that sum to
// 1, indices in range, and cwds that actually exist locally. These tests
// pin that contract, including the v0.4.3 NaN/∞ ratio guard.
@Suite("WorkspaceStore.sanitise")
struct WorkspaceStoreTests {
    private func tab(ratios: [Double], panes: Int,
                     focus: Int = 0, vertical: Bool = true,
                     cwd: String? = nil) -> TabSnapshot {
        TabSnapshot(
            isVerticalSplit: vertical,
            focusedPaneIndex: focus,
            paneRatios: ratios,
            panes: Array(repeating: PaneSnapshot(cwd: cwd), count: panes)
        )
    }

    @Test("clean ratios are normalized and preserved")
    func cleanRatiosKept() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(ratios: [0.25, 0.75], panes: 2)],
                                     activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        let r = out.tabs[0].paneRatios
        #expect(abs(r.reduce(0, +) - 1.0) < 1e-9)
        #expect(abs(r[0] - 0.25) < 1e-9)
    }

    @Test("NaN ratios fall back to an even split")
    func nanRatiosEven() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(ratios: [.nan, 0.5], panes: 2)],
                                     activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].paneRatios == [0.5, 0.5])
    }

    @Test("infinite ratios fall back to an even split")
    func infRatiosEven() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(ratios: [.infinity, 0.5], panes: 2)],
                                     activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].paneRatios == [0.5, 0.5])
    }

    @Test("a ratio/pane count mismatch falls back to an even split")
    func countMismatchEven() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(ratios: [1.0], panes: 2)],
                                     activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].paneRatios == [0.5, 0.5])
    }

    @Test("an out-of-range focus index is clamped")
    func focusClamped() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(ratios: [0.5, 0.5], panes: 2, focus: 99)],
                                     activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].focusedPaneIndex == 1)
    }

    @Test("empty tabs are dropped")
    func emptyTabsDropped() throws {
        let empty = TabSnapshot(isVerticalSplit: true, focusedPaneIndex: 0,
                                paneRatios: [], panes: [])
        let snap = WorkspaceSnapshot(tabs: [empty, tab(ratios: [1.0], panes: 1)],
                                     activeTabIndex: 1)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs.count == 1)
        #expect(out.activeTabIndex == 0) // clamped down to the surviving tab
    }

    @Test("a snapshot with no usable tabs returns nil")
    func allEmptyIsNil() {
        let empty = TabSnapshot(isVerticalSplit: true, focusedPaneIndex: 0,
                                paneRatios: [], panes: [])
        let snap = WorkspaceSnapshot(tabs: [empty], activeTabIndex: 0)
        #expect(WorkspaceStore.sanitise(snap) == nil)
    }

    @Test("the active tab index is clamped into range")
    func activeIndexClamped() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(ratios: [1.0], panes: 1)],
                                     activeTabIndex: 99)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.activeTabIndex == 0)
    }

    @Test("a stale (non-existent) cwd is dropped to nil")
    func staleCwdDropped() throws {
        let snap = WorkspaceSnapshot(
            tabs: [tab(ratios: [1.0], panes: 1, cwd: "/no/such/dir/herminal-test-xyz")],
            activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].panes[0].cwd == nil)
    }

    @Test("an existing directory cwd is preserved")
    func validCwdKept() throws {
        let dir = FileManager.default.temporaryDirectory.path
        let snap = WorkspaceSnapshot(
            tabs: [tab(ratios: [1.0], panes: 1, cwd: dir)],
            activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].panes[0].cwd == dir)
    }
}
