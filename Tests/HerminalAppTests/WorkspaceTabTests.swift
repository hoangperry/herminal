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
}
