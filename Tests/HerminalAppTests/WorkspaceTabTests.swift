import Foundation
import Testing
@testable import HerminalApp

/// WorkspaceTab pane/split/focus logic over the v0.5 split tree. A dummy
/// app handle is enough: the libghostty surface is only created once the
/// view enters a window, which these tests never do — so the handle is
/// never dereferenced.
@MainActor
@Suite("WorkspaceTab")
struct WorkspaceTabTests {
    private var dummyApp: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(bitPattern: 0xDEAD)!
    }

    /// The root split's info, or nil if the root is a lone leaf.
    private func rootSplit(_ tab: WorkspaceTab) -> SplitInfo? {
        if case let .split(info) = tab.root { return info }
        return nil
    }

    @Test("a new tab has exactly one focused pane and a leaf root")
    func newTabHasOnePane() {
        let tab = WorkspaceTab(app: dummyApp)
        #expect(tab.panes.count == 1)
        #expect(tab.focusedPaneIndex == 0)
        #expect(tab.root == .leaf(tab.panes[0].id))
    }

    @Test("split adds a pane, moves focus to it, and makes the root a split")
    func splitAddsPane() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        #expect(tab.panes.count == 2)
        #expect(tab.focusedPane.id == tab.panes[1].id)
        #expect(rootSplit(tab)?.axis == .vertical)
    }

    @Test("the first split sets the tab axis")
    func firstSplitSetsAxis() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: false)
        #expect(rootSplit(tab)?.axis == .horizontal)
    }

    @Test("splits nest: splitting the focused pane deepens the tree")
    func splitsNest() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)  // A | B, focus B
        tab.split(app: dummyApp, vertical: true)  // A | (B | C), focus C
        #expect(tab.panes.count == 3)
        // Root's second child is itself a split (the nesting).
        if case let .split(second) = rootSplit(tab)?.second {
            #expect(second.axis == .vertical)
        } else {
            Issue.record("expected the root's second child to be a nested split")
        }
    }

    @Test("closeFocusedPane reports empty only when the last pane goes")
    func closeReportsEmpty() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        #expect(tab.closeFocusedPane() == false)
        #expect(tab.panes.count == 1)
        #expect(tab.closeFocusedPane() == true)
    }

    @Test("closing the focused pane focuses its sibling")
    func closeFocusesSibling() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)   // A | B, focus B
        let bID = tab.focusedPane.id
        tab.split(app: dummyApp, vertical: true)   // A | (B | C), focus C
        _ = tab.closeFocusedPane()                 // close C → focus its sibling B
        #expect(tab.panes.count == 2)
        #expect(tab.focusedPane.id == bID)
    }

    @Test("removePane(id:) drops a specific pane and collapses its split")
    func removeByID() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)   // A | B
        let aID = tab.panes[0].id
        tab.removePane(id: aID)
        #expect(tab.panes.count == 1)
        #expect(!tab.panes.contains { $0.id == aID })
        #expect(tab.root == .leaf(tab.panes[0].id))  // collapsed to the sibling
    }

    @Test("focusPane ignores unknown ids")
    func focusPaneBounds() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        let before = tab.focusedPane.id
        tab.focusPane(id: UUID())
        #expect(tab.focusedPane.id == before)
        tab.focusPane(id: tab.panes[0].id)
        #expect(tab.focusedPane.id == tab.panes[0].id)
    }

    @Test("title shows the pane count once a tab is split")
    func titleShowsCount() {
        let tab = WorkspaceTab(app: dummyApp)
        #expect(!tab.title.contains("("))
        tab.split(app: dummyApp, vertical: true)
        #expect(tab.title.contains("(2)"))
    }

    // MARK: - Resize

    @Test("a fresh split is 50/50")
    func freshSplitEven() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        #expect(abs((rootSplit(tab)?.ratio ?? 0) - 0.5) < 1e-9)
    }

    @Test("adjustRatio moves a split and clamps to minRatio")
    func adjustRatioClamps() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        let sid = rootSplit(tab)!.id
        tab.adjustRatio(splitID: sid, to: 0.7)
        #expect(abs((tab.ratio(ofSplit: sid) ?? 0) - 0.7) < 1e-9)
        tab.adjustRatio(splitID: sid, to: 0.99)
        #expect(abs((tab.ratio(ofSplit: sid) ?? 0) - (1 - LayoutNode.minRatio)) < 1e-9)
    }

    // MARK: - Snapshot round-trip

    @Test("snapshot → restore preserves the pane count, focus, and shape")
    func snapshotRoundTrips() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)   // A | B
        tab.split(app: dummyApp, vertical: false)  // A | (B / C)
        let snap = tab.snapshot()
        #expect(snap.panes.count == 3)
        #expect(snap.layout != nil)

        let restored = WorkspaceTab(app: dummyApp, restoring: snap)
        #expect(restored.panes.count == 3)
        #expect(restored.focusedPaneIndex == snap.focusedPaneIndex)
        // The nested child kept its horizontal axis through the round-trip.
        if case let .split(info) = restored.root, case let .split(child) = info.second {
            #expect(child.axis == .horizontal)
        } else {
            Issue.record("restored tree lost its nested split")
        }
    }

    @Test("restore from a pre-v0.5 flat snapshot rebuilds a chain")
    func restoreLegacyFlat() {
        // No `layout` → the legacy axis + ratios drive a flat chain.
        let snap = TabSnapshot(
            panes: [PaneSnapshot(cwd: nil), PaneSnapshot(cwd: nil), PaneSnapshot(cwd: nil)],
            focusedPaneIndex: 1,
            layout: nil,
            isVerticalSplit: false,
            paneRatios: [0.5, 0.25, 0.25]
        )
        let tab = WorkspaceTab(app: dummyApp, restoring: snap)
        #expect(tab.panes.count == 3)
        #expect(tab.focusedPaneIndex == 1)
        #expect(rootSplit(tab)?.axis == .horizontal)
    }

    // MARK: - Tab label sourcing (v0.4.4 live cwd)

    @Test("a tab with a cwd but no program title shows the cwd basename")
    func tabLabelFallsBackToCwd() {
        let tab = WorkspaceTab(app: dummyApp,
                               workingDirectory: "/opt/herminal-fixture/api")
        #expect(tab.title == "api")
    }

    @Test("a program-set title wins over the cwd")
    func explicitTitleWinsOverCwd() {
        let tab = WorkspaceTab(app: dummyApp, command: nil, title: "VIM - main.swift",
                               workingDirectory: "/opt/herminal-fixture/api")
        #expect(tab.title == "VIM - main.swift")
    }

    @Test("a split pane inherits the focused pane's working directory")
    func splitInheritsCwd() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.focusedPane.surfaceView.applyPwd("/opt/herminal-fixture/proj")
        tab.split(app: dummyApp, vertical: true)  // focus moves to the new pane
        #expect(tab.focusedPane.surfaceView.currentWorkingDirectory == "/opt/herminal-fixture/proj")
    }

    // MARK: - Re-run commands on restore (v0.5.4)

    @Test("snapshot records each pane's spawn command")
    func snapshotRecordsCommand() {
        let tab = WorkspaceTab(app: dummyApp, command: "ssh ops@host")
        #expect(tab.snapshot().panes.first?.command == "ssh ops@host")
    }

    @Test("restore replays the command only when re-run is enabled")
    func restoreRerunsCommandWhenEnabled() {
        let snap = TabSnapshot(
            panes: [PaneSnapshot(cwd: nil, command: "claude --resume abc")],
            focusedPaneIndex: 0, layout: nil, isVerticalSplit: true, paneRatios: [1.0])
        let off = WorkspaceTab(app: dummyApp, restoring: snap)  // default: rerun off
        #expect(off.focusedPane.command == nil)
        let on = WorkspaceTab(app: dummyApp, restoring: snap, rerunCommands: true)
        #expect(on.focusedPane.command == "claude --resume abc")
    }

    @Test("safeRerunCommand rejects empties and control-char smuggling")
    func safeRerunCommandValidation() {
        #expect(WorkspaceTab.safeRerunCommand("ssh ops@host") == "ssh ops@host")
        #expect(WorkspaceTab.safeRerunCommand(nil) == nil)
        #expect(WorkspaceTab.safeRerunCommand("") == nil)
        #expect(WorkspaceTab.safeRerunCommand("ssh x\nrm -rf ~") == nil)  // newline smuggle
        #expect(WorkspaceTab.safeRerunCommand("a\u{0}b") == nil)          // NUL
    }

    // MARK: - Pane zoom (v1.0)

    @Test("toggleZoom maximizes the focused pane and restores")
    func toggleZoomLifecycle() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.toggleZoom()                          // single pane → no-op
        #expect(tab.zoomedPaneID == nil)
        tab.split(app: dummyApp, vertical: true)  // 2 panes, focus the new one
        let focused = tab.focusedPane.id
        tab.toggleZoom()
        #expect(tab.zoomedPaneID == focused)
        tab.toggleZoom()
        #expect(tab.zoomedPaneID == nil)
    }

    @Test("zoom clears on focus change and on structural change")
    func zoomClearsOnChange() {
        let tab = WorkspaceTab(app: dummyApp)
        tab.split(app: dummyApp, vertical: true)
        tab.toggleZoom()
        #expect(tab.isZoomed)
        tab.focusPane(id: tab.panes[0].id)        // focus change → unzoom
        #expect(!tab.isZoomed)
        tab.toggleZoom()
        #expect(tab.isZoomed)
        tab.split(app: dummyApp, vertical: false) // structural change → unzoom
        #expect(!tab.isZoomed)
    }
}
