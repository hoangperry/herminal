import Foundation
import Testing
@testable import HerminalApp

// WorkspaceStore.sanitise is the trust boundary for session restore: it
// takes a decoded (possibly hand-edited / corrupt / old-format)
// workspace.json and must return something safe to feed the view — panes
// with cwds that exist locally, in-range indices, and a layout tree that
// references exactly the surviving panes (else it's dropped to the flat
// fallback). Normalization of ratios happens at restore (flatTree /
// LayoutNode), not here.
@Suite("WorkspaceStore.sanitise")
struct WorkspaceStoreTests {
    private func tab(panes: Int, focus: Int = 0,
                     layout: LayoutSnapshot? = nil,
                     vertical: Bool? = nil, ratios: [Double]? = nil,
                     cwd: String? = nil,
                     command: String? = nil,
                     launch: RestorableLaunch? = nil) -> TabSnapshot {
        TabSnapshot(
            panes: Array(
                repeating: PaneSnapshot(cwd: cwd, command: command, launch: launch),
                count: panes
            ),
            focusedPaneIndex: focus,
            layout: layout,
            isVerticalSplit: vertical,
            paneRatios: ratios
        )
    }

    // MARK: - Structural sanity

    @Test("empty tabs are dropped and the active index re-clamped")
    func emptyTabsDropped() throws {
        let empty = TabSnapshot(panes: [], focusedPaneIndex: 0, layout: nil,
                                isVerticalSplit: nil, paneRatios: nil)
        let snap = WorkspaceSnapshot(tabs: [empty, tab(panes: 1)], activeTabIndex: 1)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs.count == 1)
        #expect(out.activeTabIndex == 0)
    }

    @Test("sanitise preserves the active retained tab across earlier empty tabs")
    func sanitiseRemapsActiveTab() throws {
        let empty = TabSnapshot(panes: [], focusedPaneIndex: 0, layout: nil,
                                isVerticalSplit: nil, paneRatios: nil)
        let snap = WorkspaceSnapshot(
            tabs: [empty, tab(panes: 1), empty, tab(panes: 1)],
            activeTabIndex: 1
        )

        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs.count == 2)
        #expect(out.activeTabIndex == 0)
    }

    @Test("a snapshot with no usable tabs returns nil")
    func allEmptyIsNil() {
        let empty = TabSnapshot(panes: [], focusedPaneIndex: 0, layout: nil,
                                isVerticalSplit: nil, paneRatios: nil)
        #expect(WorkspaceStore.sanitise(WorkspaceSnapshot(tabs: [empty], activeTabIndex: 0)) == nil)
    }

    @Test("snapshot compaction drops empty tabs and keeps the nearest active tab")
    func compactionDropsEmptyTabs() {
        let empty = TabSnapshot(panes: [], focusedPaneIndex: 0, layout: nil,
                                isVerticalSplit: nil, paneRatios: nil)
        let snapshot = WorkspaceSnapshot.compacting(
            tabs: [tab(panes: 1), empty, tab(panes: 1)],
            activeTabIndex: 1
        )

        #expect(snapshot.tabs.count == 2)
        #expect(snapshot.activeTabIndex == 1)
    }

    @Test("an out-of-range focus index is clamped")
    func focusClamped() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(panes: 2, focus: 99)], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].focusedPaneIndex == 1)
    }

    @Test("the active tab index is clamped into range")
    func activeIndexClamped() throws {
        let snap = WorkspaceSnapshot(tabs: [tab(panes: 1)], activeTabIndex: 99)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.activeTabIndex == 0)
    }

    // MARK: - cwd validation

    @Test("a stale (non-existent) cwd is dropped to nil")
    func staleCwdDropped() throws {
        let snap = WorkspaceSnapshot(
            tabs: [tab(panes: 1, cwd: "/no/such/dir/herminal-test-xyz")], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].panes[0].cwd == nil)
    }

    @Test("an existing directory cwd is preserved")
    func validCwdKept() throws {
        let dir = FileManager.default.temporaryDirectory.path
        let snap = WorkspaceSnapshot(tabs: [tab(panes: 1, cwd: dir)], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].panes[0].cwd == dir)
    }

    // MARK: - Legacy flat ratios

    @Test("NaN legacy ratios are dropped (→ even split on restore)")
    func nanRatiosDropped() throws {
        let snap = WorkspaceSnapshot(
            tabs: [tab(panes: 2, vertical: true, ratios: [.nan, 0.5])], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].paneRatios == nil)
    }

    @Test("count-mismatched legacy ratios are dropped")
    func mismatchedRatiosDropped() throws {
        let snap = WorkspaceSnapshot(
            tabs: [tab(panes: 2, vertical: true, ratios: [1.0])], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].paneRatios == nil)
    }

    @Test("valid legacy ratios pass through")
    func validRatiosKept() throws {
        let snap = WorkspaceSnapshot(
            tabs: [tab(panes: 2, vertical: true, ratios: [0.3, 0.7])], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].paneRatios == [0.3, 0.7])
    }

    // MARK: - Layout tree validation

    @Test("a layout tree covering the panes exactly survives")
    func validTreeKept() throws {
        let tree = LayoutSnapshot.split(axis: .vertical, ratio: 0.5, first: .leaf(0), second: .leaf(1))
        let snap = WorkspaceSnapshot(tabs: [tab(panes: 2, layout: tree)], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].layout == tree)
    }

    @Test("a layout tree with out-of-range indices is dropped")
    func invalidTreeDropped() throws {
        // References pane 5 that doesn't exist → can't rebuild → drop to nil.
        let tree = LayoutSnapshot.split(axis: .vertical, ratio: 0.5, first: .leaf(0), second: .leaf(5))
        let snap = WorkspaceSnapshot(tabs: [tab(panes: 2, layout: tree)], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].layout == nil)
    }

    @Test("a layout tree that misses a pane is dropped")
    func incompleteTreeDropped() throws {
        // 3 panes but the tree only references 0 and 1 → drop.
        let tree = LayoutSnapshot.split(axis: .vertical, ratio: 0.5, first: .leaf(0), second: .leaf(1))
        let snap = WorkspaceSnapshot(tabs: [tab(panes: 3, layout: tree)], activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].layout == nil)
    }

    @Test("legacy raw commands are stripped during sanitise")
    func rawCommandIsStripped() throws {
        let snap = WorkspaceSnapshot(
            tabs: [TabSnapshot(panes: [PaneSnapshot(cwd: nil, command: "ssh ops@host")],
                               focusedPaneIndex: 0, layout: nil,
                               isVerticalSplit: true, paneRatios: nil)],
            activeTabIndex: 0)
        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].panes[0].command == nil)
        #expect(out.tabs[0].panes[0].launch == nil)
    }

    @Test("validated structured launches survive sanitise")
    func launchSurvivesSanitise() throws {
        let launch = RestorableLaunch.ssh(user: "ops", host: "internal.example.com", port: 2222)
        let snap = WorkspaceSnapshot(
            tabs: [TabSnapshot(
                panes: [PaneSnapshot(cwd: nil, command: "ssh ops@host", launch: launch)],
                focusedPaneIndex: 0,
                layout: nil,
                isVerticalSplit: true,
                paneRatios: nil
            )],
            activeTabIndex: 0
        )

        let out = try #require(WorkspaceStore.sanitise(snap))
        #expect(out.tabs[0].panes[0].command == nil)
        #expect(out.tabs[0].panes[0].launch == launch)
    }

    @Test("encoding scrubs legacy commands and invalid launch descriptors")
    func encodingScrubsUnsafeReplayMetadata() throws {
        let pane = PaneSnapshot(
            cwd: nil,
            command: "touch /tmp/herminal-restore-pwned",
            launch: .ssh(user: "", host: "internal.example.com", port: 22)
        )

        let data = try JSONEncoder().encode(pane)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["command"] == nil)
        #expect(object["launch"] == nil)
    }

    @Test("legacy command JSON remains decode-only and is stripped at the trust boundary")
    func legacyCommandJSONIsDecodeOnly() throws {
        let data = Data(#"{"cwd":null,"command":"ssh ops@legacy-host"}"#.utf8)
        let decoded = try JSONDecoder().decode(PaneSnapshot.self, from: data)
        #expect(decoded.command == "ssh ops@legacy-host")

        let snapshot = WorkspaceSnapshot(
            tabs: [TabSnapshot(
                panes: [decoded],
                focusedPaneIndex: 0,
                layout: nil,
                isVerticalSplit: true,
                paneRatios: nil
            )],
            activeTabIndex: 0
        )
        let sanitised = try #require(WorkspaceStore.sanitise(snapshot))

        #expect(sanitised.tabs[0].panes[0].command == nil)
        #expect(sanitised.tabs[0].panes[0].launch == nil)
    }
}
