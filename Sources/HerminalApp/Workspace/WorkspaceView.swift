// WorkspaceView — the window's root content view.
// Owns the tabs, hosts the SwiftUI tab strip + agent dashboard (left) + notes
// panel (right), and lays out the active tab's panes (manual split, Q2-002).

import AppKit
import Combine
import SwiftUI
import GhosttyKit
import HerminalCore
import HerminalAgent
import HerminalDB
import os

final class WorkspaceView: NSView {
    /// Hairline gap between panes; the dark container shows through as a divider.
    private static let paneGap: CGFloat = 1
    private static let dashboardWidth: CGFloat = 268
    private static let sshPanelWidth: CGFloat = 280
    private static let claudePanelWidth: CGFloat = 300
    private static let notesWidth: CGFloat = 280

    enum RefreshFocusPolicy: Equatable {
        case activePane
        case tabBar(TabBarView.FocusTarget)

        var focusesActivePane: Bool {
            self == .activePane
        }

        var tabBarTarget: TabBarView.FocusTarget? {
            guard case let .tabBar(target) = self else { return nil }
            return target
        }
    }

    struct TabBarFocusRetention {
        private(set) var target: TabBarView.FocusTarget?
        private(set) var generation = 0

        mutating func beginRebuild(
            requestedTarget: TabBarView.FocusTarget? = nil
        ) -> Int {
            if let requestedTarget {
                target = requestedTarget
            }
            generation += 1
            return generation
        }

        mutating func focusDidChange(
            _ changedTarget: TabBarView.FocusTarget,
            isFocused: Bool,
            generation changedGeneration: Int
        ) {
            guard changedGeneration == generation else { return }
            if isFocused {
                target = changedTarget
            } else if target == changedTarget {
                target = nil
            }
        }

        mutating func clear() {
            target = nil
        }
    }

    nonisolated static func activeTabIndexAfterClosing(
        closedIndex: Int,
        activeIndex: Int,
        remainingCount: Int
    ) -> Int {
        guard remainingCount > 0 else { return 0 }
        if closedIndex < activeIndex {
            return max(activeIndex - 1, 0)
        }
        if closedIndex == activeIndex {
            return min(closedIndex, remainingCount - 1)
        }
        return min(activeIndex, remainingCount - 1)
    }

    enum CloseTabOutcome: Equatable {
        case closeWindow
        case keepWorkspace(activeIndex: Int, focusPolicy: RefreshFocusPolicy)
    }

    nonisolated static func closeTabOutcome(
        closedIndex: Int,
        activeIndex: Int,
        remainingTabIDs: [UUID],
        retainTabBarFocus: Bool
    ) -> CloseTabOutcome {
        guard !remainingTabIDs.isEmpty else { return .closeWindow }
        let nextActiveIndex = activeTabIndexAfterClosing(
            closedIndex: closedIndex,
            activeIndex: activeIndex,
            remainingCount: remainingTabIDs.count
        )
        let focusPolicy: RefreshFocusPolicy = retainTabBarFocus
            ? .tabBar(.tab(remainingTabIDs[nextActiveIndex]))
            : .activePane
        return .keepWorkspace(activeIndex: nextActiveIndex, focusPolicy: focusPolicy)
    }

    @discardableResult
    @MainActor
    static func reuseExistingSearchOverlay(
        hasOverlay: Bool,
        sameTarget: Bool,
        state: SearchOverlayState?
    ) -> Bool {
        guard hasOverlay, sameTarget, let state else { return false }
        state.requestFieldFocus()
        return true
    }

    @MainActor
    static func searchNavigationIsEnabled(
        hasOverlay: Bool,
        state: SearchOverlayState?
    ) -> Bool {
        guard hasOverlay, let state else { return false }
        return SearchOverlayView.matchNavigationIsEnabled(
            needle: state.needle,
            total: state.total
        )
    }

    /// At most one widget occupies the left sidebar — agents, SSH, and the
    /// Claude session browser share the slot so the surface always gets
    /// the maximum content width.
    private enum LeftSidebar {
        case none
        case agents
        case ssh
        case claude
    }

    private let app: ghostty_app_t
    private let notesStore: NotesStore
    private let notesStorageIsDurable: Bool
    private let sshHostsStore: SSHHostsStore
    private let sshHostsStorageIsDurable: Bool
    private let agentStatusTracker = AgentStatusTracker()
    private var tabs: [WorkspaceTab] = []
    private var activeTabIndex = 0

    private let tabHost: NSHostingView<TabBarView>
    private var tabBarFocusRetention = TabBarFocusRetention()
    private let surfaceContainer: NSView
    private let dashboardHost: NSHostingView<AgentDashboardView>
    private let sshPanelHost: NSHostingView<AnyView>
    private let claudePanelHost: NSHostingView<AnyView>
    private let notesHost: NSHostingView<AnyView>
    private let statusBarHost: NSHostingView<StatusBarView>
    /// Draggable handles between split panes — one per gap (count - 1).
    /// Recycled across re-layouts; `refresh()` wipes surfaceContainer's
    /// subviews so layoutPanes re-attaches these on top of the panes.
    /// One divider per split node, keyed by the node's id. (v0.3.3 →
    /// v0.5 recursive tree.)
    private var paneDividers: [UUID: PaneDividerView] = [:]
    /// Each split node's rect from the last layout pass — a divider drag
    /// is a fraction of ITS rect, not the whole container. (v0.5.)
    private var splitFrames: [UUID: NSRect] = [:]
    /// Accent outline over the focused pane, shown only when a tab has
    /// more than one pane. Mouse-transparent. (v0.5.2.)
    private let paneFocusRing = PaneFocusRingView(frame: .zero)
    /// Created lazily on first launch when `firstRunCompleted` is false,
    /// removed (and nil'd) after the user dismisses. Stays nil forever
    /// after that on every subsequent launch. (M12-P3)
    private var welcomeOverlay: NSHostingView<WelcomeOverlayView>?
    /// Active ⌘F search overlay state for the currently bound pane.
    /// While the overlay is visible, repeated ⌘F reuses this state and
    /// returns focus to the query field. Dismissal tears down the state,
    /// host, and binding subscription together.
    private var searchOverlayState: SearchOverlayState?
    private var searchOverlayHost: NSHostingView<SearchOverlayView>?
    /// View whose `searchState` the overlay is bound to — used by the
    /// notification observers to ignore stale events from sibling panes.
    private weak var searchOverlayTarget: HerminalSurfaceView?
    /// Combine subscription propagating SwiftUI text-field updates
    /// into libghostty's `search:<needle>` binding action. Lives only
    /// while the overlay is shown.
    private var searchNeedleSubscription: AnyCancellable?
    private var leftSidebar: LeftSidebar = .none
    private var isNotesVisible = false
    // nonisolated(unsafe): invalidated in the nonisolated deinit.
    private nonisolated(unsafe) var agentPollTimer: Timer?
    /// Cache of `AgentDetector.detectAgents().count`, refreshed on every
    /// agent poll regardless of whether the dashboard sidebar is open —
    /// the status bar needs it even when the panel is closed.
    private var latestAgentCount: Int = 0
    private var latestDisplayedAgents: [DetectedAgent] = []
    private var pendingAgentDashboardFocusRequestID: UUID?
    private var sshImportState = SSHImportState()
    private let sidebarFilterState: SidebarFilterState
    /// Failed autosaves survive SwiftUI host rebuilds (theme changes, tab
    /// refreshes, and focus changes). Successful saves are never cached here.
    private var notesPanelRecoveries: [UUID: NotesPanelRecovery] = [:]
    /// Last `git worktree list` for the focused pane. Refreshed when the
    /// dashboard opens, cwd changes, or the user adds/removes a worktree
    /// — never on the 2s agent poll.
    private var worktreeEntries: [GitWorktree.Entry] = []
    private var worktreesInGitRepo = false
    private var primaryWorktreePath: String?
    /// Discards stale async git results after focus/cwd changes.
    private var worktreeRefreshGeneration = 0
    /// Last `tmux list-sessions`, same cadence as worktrees (open /
    /// cwd / spawn / kill) — never the 2s agent poll. Debounced so OSC 7
    /// storms do not spawn a Process per prompt.
    private var tmuxSessions: [TmuxLaunch.Session] = []
    private var tmuxAvailable = false
    /// Discards stale async `tmux list-sessions` results.
    private var tmuxRefreshGeneration = 0
    /// Discards stale async Claude session scans so an older
    /// focus-bearing refresh cannot land after a newer passive refresh.
    private var claudePanelRefreshGate = ClaudePanelRefreshGate()
    private var lastTmuxRefreshAt: Date?
    /// Gates session-restore persistence. False during init + restore so
    /// the default/launch tab churn doesn't clobber the saved snapshot;
    /// AppDelegate flips it true once the launch decision is made.
    /// (v0.4.1.)
    private var sessionPersistenceEnabled = false

    init(
        app: ghostty_app_t,
        notesStore: NotesStore,
        notesStorageIsDurable: Bool = true,
        sshHostsStore: SSHHostsStore,
        sshHostsStorageIsDurable: Bool = true
    ) {
        self.app = app
        self.notesStore = notesStore
        self.notesStorageIsDurable = notesStorageIsDurable
        self.sshHostsStore = sshHostsStore
        self.sshHostsStorageIsDurable = sshHostsStorageIsDurable
        self.surfaceContainer = NSView(frame: .zero)
        self.tabHost = NSHostingView(rootView: TabBarView(
            tabs: [], activeID: nil,
            onSelect: { _ in }, onClose: { _ in }, onNew: {}
        ))
        let sidebarFilterState = SidebarFilterState()
        self.sidebarFilterState = sidebarFilterState
        self.dashboardHost = NSHostingView(
            rootView: AgentDashboardView(
                agents: [],
                filterState: sidebarFilterState
            )
        )
        self.sshPanelHost = NSHostingView(rootView: AnyView(EmptyView()))
        self.claudePanelHost = NSHostingView(rootView: AnyView(EmptyView()))
        self.notesHost = NSHostingView(rootView: AnyView(EmptyView()))
        // Stub probe — replaced below after `self` is available so we can
        // safely capture `latestAgentCount`. NSHostingView needs a rootView
        // at construction time, so we seed with an empty snapshot.
        self.statusBarHost = NSHostingView(rootView: StatusBarView(probe: { .empty }))
        super.init(frame: NSRect(x: 0, y: 0, width: 900, height: 560))

        // Real probe — captures `self` weakly so the timer in StatusBarView
        // can't keep us alive past window close. The closure runs on the
        // main run loop, matching every other UI read in this view.
        statusBarHost.rootView = StatusBarView(probe: { [weak self] in
            MainActor.assumeIsolated {
                self?.captureStatusSnapshot() ?? .empty
            }
        })

        // The container's dark fill shows between panes as a divider.
        surfaceContainer.wantsLayer = true
        surfaceContainer.layer?.backgroundColor = NSColor(HerminalDesign.Palette.paneGutter).cgColor
        dashboardHost.isHidden = true
        sshPanelHost.isHidden = true
        claudePanelHost.isHidden = true
        notesHost.isHidden = true
        statusBarHost.isHidden = !Preferences.showStatusBar

        addSubview(surfaceContainer)
        addSubview(tabHost)
        addSubview(dashboardHost)
        addSubview(sshPanelHost)
        addSubview(claudePanelHost)
        addSubview(notesHost)
        addSubview(statusBarHost)
        addTab()
        startAgentPolling()
        // M12-P1: live-update path. Settings flips post the notification;
        // we re-read everything that depends on a preference value and
        // repaint. Cheap because the SwiftUI hosts re-evaluate Palette
        // tokens automatically once we rebuild their rootView.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: Preferences.didChangeNotification,
            object: nil
        )
        // libghostty close_surface_cb wakes up here when the shell
        // exits or the PTY child dies. Without this the pane locks
        // onto "Process exited — press Enter to close." (v0.2.3
        // stub-from-spike fix.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(surfaceDidClose(_:)),
            name: GhosttyApp.surfaceDidCloseNotification,
            object: nil
        )
        // Initial renderer metrics and live font-size changes both alter the
        // cell grid. Re-snap every leaf so no pane exposes a partial top row.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(surfaceCellSizeDidChange(_:)),
            name: GhosttyApp.surfaceCellSizeDidChangeNotification,
            object: nil
        )
        // Shell-driven title updates (OSC 0/2 from vim/htop/zsh prompt
        // hooks, or libghostty's `set_tab_title` keybinding). Without
        // this the tab strip stays on the default "herminal" until the
        // app restart — v0.2.4 stub-from-spike fix.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(surfaceTitleDidChange(_:)),
            name: GhosttyApp.surfaceTitleDidChangeNotification,
            object: nil
        )
        // libghostty's MOUSE_SHAPE action: vim mouse mode wants
        // pointing-hand, URL hover wants pointing-hand, default text
        // pane wants I-beam, etc. (v0.2.5 audit pass.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(surfaceMouseShapeDidChange(_:)),
            name: GhosttyApp.surfaceMouseShapeDidChangeNotification,
            object: nil
        )
        // OSC 7 working-directory reports — foundation for the Claude
        // session browser + future session restore. (v0.4-S1a.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(surfacePwdDidChange(_:)),
            name: GhosttyApp.surfacePwdDidChangeNotification,
            object: nil
        )
        // v0.3.2 — search overlay lifecycle. libghostty fires these
        // four actions; we mirror them into AppKit so the overlay's
        // SwiftUI state stays in sync.
        for name: Notification.Name in [
            GhosttyApp.surfaceSearchStartNotification,
            GhosttyApp.surfaceSearchEndNotification,
            GhosttyApp.surfaceSearchTotalNotification,
            GhosttyApp.surfaceSearchSelectedNotification,
        ] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(surfaceSearchEvent(_:)),
                name: name,
                object: nil
            )
        }
    }

    required init?(coder: NSCoder) {
        fatalError("WorkspaceView does not support NSCoder")
    }

    deinit {
        agentPollTimer?.invalidate()
        NotificationCenter.default.removeObserver(
            self,
            name: Preferences.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: GhosttyApp.surfaceDidCloseNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: GhosttyApp.surfaceCellSizeDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: GhosttyApp.surfaceTitleDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: GhosttyApp.surfaceMouseShapeDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: GhosttyApp.surfacePwdDidChangeNotification,
            object: nil
        )
        for name: Notification.Name in [
            GhosttyApp.surfaceSearchStartNotification,
            GhosttyApp.surfaceSearchEndNotification,
            GhosttyApp.surfaceSearchTotalNotification,
            GhosttyApp.surfaceSearchSelectedNotification,
        ] {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
    }

    private var activeTab: WorkspaceTab? {
        tabs.indices.contains(activeTabIndex) ? tabs[activeTabIndex] : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            // trafficLightInset can only be measured once there is a window;
            // the strip was first built with the fallback, so rebuild it now
            // that the real window-control metrics are readable.
            tabHost.rootView = makeTabBar()
            focusActivePane()
            showWelcomeOverlayIfNeeded()
        }
    }

    // MARK: - Layout

    /// True only inside the brief animation window opened by a sidebar
    /// toggle — `layout()` switches to the animator proxy in this case so
    /// the slide is smooth instead of snapping.
    private var isAnimatingLayout = false

    /// Where the tab strip may start without sitting under the close /
    /// minimise / zoom buttons.
    ///
    /// Measured from the window rather than hard-coded: the buttons move
    /// with the system's window-control metrics, and a stale constant here
    /// would either clip a tab or leave a gap. The fallback covers the
    /// pre-window layout pass.
    private var trafficLightInset: CGFloat {
        guard let zoom = window?.standardWindowButton(.zoomButton) else { return 78 }
        return zoom.frame.maxX + HerminalDesign.Spacing.md
    }

    override func layout() {
        super.layout()
        let barHeight = TabBarView.barHeight
        let statusHeight: CGFloat = Preferences.showStatusBar ? StatusBarView.height : 0
        let leftWidth: CGFloat = {
            switch leftSidebar {
            case .none: return 0
            case .agents: return Self.dashboardWidth
            case .ssh: return Self.sshPanelWidth
            case .claude: return Self.claudePanelWidth
            }
        }()
        let rightSidebar = isNotesVisible ? Self.notesWidth : 0

        // Pre-toggle: keep the panel visible during a hide animation so the
        // slide reads as motion rather than a pop. The animator restores
        // `isHidden` at the end of the run (see animateSidebarChange()).
        if !isAnimatingLayout {
            dashboardHost.isHidden = leftSidebar != .agents
            sshPanelHost.isHidden = leftSidebar != .ssh
            claudePanelHost.isHidden = leftSidebar != .claude
            notesHost.isHidden = !isNotesVisible
        }
        statusBarHost.isHidden = !Preferences.showStatusBar

        // Sidebars sit ABOVE the status strip so the strip spans the full
        // width (uniform across content + sidebars, like Xcode's bottom
        // bar), and BELOW the tab strip, which now spans the full width in
        // the titlebar row.
        let sidebarTop = bounds.height - barHeight
        let sidebarBottom: CGFloat = statusHeight
        let sidebarHeight = max(sidebarTop - sidebarBottom, 0)
        let leftTarget = CGRect(x: 0, y: sidebarBottom, width: leftWidth, height: sidebarHeight)
        let notesTarget = CGRect(
            x: bounds.width - rightSidebar, y: sidebarBottom,
            width: rightSidebar, height: sidebarHeight
        )

        if isAnimatingLayout {
            dashboardHost.animator().frame = leftTarget
            sshPanelHost.animator().frame = leftTarget
            claudePanelHost.animator().frame = leftTarget
            notesHost.animator().frame = notesTarget
        } else {
            dashboardHost.frame = leftTarget
            sshPanelHost.frame = leftTarget
            claudePanelHost.frame = leftTarget
            notesHost.frame = notesTarget
        }

        let contentX = leftWidth
        let contentWidth = max(bounds.width - leftWidth - rightSidebar, 0)
        // The tab strip owns the whole titlebar row: its frame spans edge to
        // edge so the row is one continuous surface, and the view keeps its
        // chips clear of the traffic lights via leadingInset. Framing it at
        // the inset instead would leave the window controls sitting on a
        // visibly different patch.
        tabHost.frame = CGRect(
            x: 0, y: bounds.height - barHeight,
            width: bounds.width, height: barHeight
        )
        let surfaceHeight = max(bounds.height - barHeight - statusHeight, 0)
        // The container spans the whole content column and `layoutPanes`
        // insets the pane tree inside it, so its gutter fill paints both the
        // frame around the panes and the seams between splits — one surface,
        // one colour. Insetting the container itself (as this did before)
        // left the outer 6 px showing the window's vibrancy instead, which
        // measured lighter than the panes and read as an outline rather than
        // a recess.
        surfaceContainer.frame = CGRect(
            x: contentX, y: statusHeight,
            width: contentWidth, height: surfaceHeight
        )
        statusBarHost.frame = CGRect(
            x: 0, y: 0, width: bounds.width, height: statusHeight
        )
        welcomeOverlay?.frame = bounds
        // v0.3.2 — search bar floats at the top-right of the active
        // surface area so it doesn't cover the prompt at the bottom of
        // most shells. 14 px margin from edge + intrinsic-content sized.
        if let overlay = searchOverlayHost {
            let intrinsic = overlay.fittingSize
            let width = max(intrinsic.width, 320)
            let height = max(intrinsic.height, 34)
            let margin: CGFloat = 14
            overlay.frame = CGRect(
                x: surfaceContainer.frame.maxX - width - margin,
                y: surfaceContainer.frame.maxY - height - margin,
                width: width, height: height
            )
        }
        layoutPanes()
    }

    /// Lays out the active tab's pane surfaces inside the container,
    /// sized by `tab.paneRatios` along the split axis and separated by a
    /// hairline gap. Draggable divider handles overlay each gap.
    private func layoutPanes() {
        guard let tab = activeTab else {
            syncDividers(specs: [])
            return
        }
        // v0.3 polish: a 6 px inset between the Metal surfaces and the pane
        // chrome — without it the text sits flush against the window edge and
        // the app reads as cheap. Applied to the pane tree rather than to the
        // container so the container's gutter fill shows in the gap.
        let bounds = surfaceContainer.bounds
            .insetBy(dx: HerminalDesign.Geometry.surfaceInset,
                     dy: HerminalDesign.Geometry.surfaceInset)
        guard bounds.width > 0, bounds.height > 0 else { return }

        // Zoomed: the focused pane fills the whole tab, the rest hidden, no
        // dividers and no focus ring (there's only one pane to see). (v1.0.)
        if let zoomID = tab.zoomedPaneID, tab.panes.count > 1,
           let zoomed = tab.surfaceView(for: zoomID) {
            for pane in tab.panes { pane.surfaceView.isHidden = (pane.id != zoomID) }
            zoomed.frame = gridAlignedFrame(bounds, for: zoomed)
            splitFrames = [:]
            syncDividers(specs: [])
            paneFocusRing.isHidden = true
            return
        }
        // Normal layout — make sure everything's visible again (un-zoom).
        for pane in tab.panes { pane.surfaceView.isHidden = false }

        var specs: [DividerSpec] = []
        var rects: [UUID: NSRect] = [:]
        layoutNode(tab.root, in: bounds, tab: tab, dividers: &specs, splitRects: &rects)
        splitFrames = rects
        syncDividers(specs: specs)
        updateFocusRing()
    }

    /// Positions the accent outline over the focused pane, kept topmost so
    /// the border isn't covered. Hidden for a single-pane tab — there's no
    /// ambiguity to resolve. (v0.5.2.)
    private func updateFocusRing() {
        guard let tab = activeTab, tab.panes.count > 1 else {
            paneFocusRing.isHidden = true
            return
        }
        // addSubview re-orders to the front, so the ring stays above the
        // panes + dividers re-added by refresh()/syncDividers.
        surfaceContainer.addSubview(paneFocusRing)
        paneFocusRing.frame = tab.focusedPane.surfaceView.frame
        paneFocusRing.isHidden = false
        paneFocusRing.needsDisplay = true
    }

    /// Geometry for one split's divider, produced by the layout walk.
    private struct DividerSpec {
        let id: UUID
        let isVertical: Bool
        let rect: NSRect
    }

    /// Recursively assigns each leaf surface its frame and records a
    /// divider on every split boundary. `rect` is in surfaceContainer
    /// coordinates (NSView origin is bottom-left). (v0.5.)
    private func layoutNode(_ node: LayoutNode, in rect: NSRect, tab: WorkspaceTab,
                            dividers: inout [DividerSpec], splitRects: inout [UUID: NSRect]) {
        switch node {
        case let .leaf(id):
            if let surface = tab.surfaceView(for: id) {
                surface.frame = gridAlignedFrame(rect, for: surface)
            }
        case let .split(info):
            splitRects[info.id] = rect
            let gap = Self.paneGap
            let hit = PaneDividerView.hitThickness
            if info.axis == .vertical {
                let usable = max(rect.width - gap, 0)
                let firstW = usable * info.ratio
                let firstRect = NSRect(x: rect.minX, y: rect.minY,
                                       width: firstW, height: rect.height)
                let secondRect = NSRect(x: rect.minX + firstW + gap, y: rect.minY,
                                        width: usable - firstW, height: rect.height)
                layoutNode(info.first, in: firstRect, tab: tab,
                           dividers: &dividers, splitRects: &splitRects)
                layoutNode(info.second, in: secondRect, tab: tab,
                           dividers: &dividers, splitRects: &splitRects)
                let centreX = rect.minX + firstW + gap / 2
                dividers.append(DividerSpec(id: info.id, isVertical: true,
                    rect: NSRect(x: centreX - hit / 2, y: rect.minY,
                                 width: hit, height: rect.height)))
            } else {
                // Horizontal: `first` is the TOP child.
                let usable = max(rect.height - gap, 0)
                let firstH = usable * info.ratio
                let firstRect = NSRect(x: rect.minX, y: rect.maxY - firstH,
                                       width: rect.width, height: firstH)
                let secondRect = NSRect(x: rect.minX, y: rect.minY,
                                        width: rect.width, height: usable - firstH)
                layoutNode(info.first, in: firstRect, tab: tab,
                           dividers: &dividers, splitRects: &splitRects)
                layoutNode(info.second, in: secondRect, tab: tab,
                           dividers: &dividers, splitRects: &splitRects)
                let centreY = rect.maxY - firstH - gap / 2
                dividers.append(DividerSpec(id: info.id, isVertical: false,
                    rect: NSRect(x: rect.minX, y: centreY - hit / 2,
                                 width: rect.width, height: hit)))
            }
        }
    }

    /// Removes a fractional terminal row in backing-pixel space and balances
    /// the remainder as chrome gutter. Metrics are per surface because live
    /// font size and backing scale can change independently.
    private func gridAlignedFrame(_ rect: NSRect, for surface: HerminalSurfaceView) -> NSRect {
        guard let cellHeight = surface.cellHeightPixels else { return rect }
        let scale = surface.window?.backingScaleFactor
            ?? window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        return PaneGridSizing.snapVertically(
            rect,
            cellHeightPixels: cellHeight,
            scale: scale
        )
    }

    @objc private func surfaceCellSizeDidChange(_ note: Notification) {
        layoutPanes()
    }

    /// Reconciles live divider views to `specs` — one per split node,
    /// keyed by the split id — positioning each and wiring its drag.
    /// Re-attaches to surfaceContainer after `refresh()` wipes it.
    private func syncDividers(specs: [DividerSpec]) {
        let wanted = Set(specs.map { $0.id })
        for (id, divider) in paneDividers where !wanted.contains(id) {
            divider.removeFromSuperview()
            paneDividers[id] = nil
        }
        for spec in specs {
            let divider = paneDividers[spec.id] ?? {
                let made = PaneDividerView(frame: .zero)
                paneDividers[spec.id] = made
                return made
            }()
            divider.isVertical = spec.isVertical
            divider.ratio = activeTab?.ratio(ofSplit: spec.id) ?? 0.5
            divider.frame = spec.rect
            divider.onDrag = { [weak self] delta in
                self?.resizeSplit(spec.id, byPointDelta: delta, isVertical: spec.isVertical)
            }
            divider.onAdjustment = { [weak self] adjustment in
                self?.adjustSplit(spec.id, adjustment: adjustment)
            }
            if divider.superview !== surfaceContainer {
                surfaceContainer.addSubview(divider)
            }
        }
    }

    /// Translates a divider drag (points along the axis) into a ratio for
    /// the split's OWN rect — not the whole container, which is what makes
    /// nested splits resize correctly — then re-lays out. (v0.5.)
    private func resizeSplit(_ id: UUID, byPointDelta delta: CGFloat, isVertical: Bool) {
        guard let tab = activeTab, let rect = splitFrames[id],
              let current = tab.ratio(ofSplit: id) else { return }
        let extent = max((isVertical ? rect.width : rect.height) - Self.paneGap, 0)
        guard extent > 0 else { return }
        // Vertical: dragging right (+x) grows the first (left) child.
        // Horizontal: dragging down (−y) grows the first (top) child, flip.
        let deltaFraction = (isVertical ? delta : -delta) / extent
        tab.adjustRatio(splitID: id, to: current + deltaFraction)
        layoutPanes()
    }

    /// Moves a focused divider by a stable ratio step, independent of the
    /// window's current size. VoiceOver increment/decrement actions share
    /// this path with keyboard arrows; Return/Space balances the split.
    private func adjustSplit(_ id: UUID, adjustment: PaneDividerView.Adjustment) {
        guard let tab = activeTab, let current = tab.ratio(ofSplit: id) else { return }
        tab.adjustRatio(
            splitID: id,
            to: PaneDividerView.targetRatio(from: current, adjustment: adjustment)
        )
        layoutPanes()
    }

    // MARK: - Tab management

    func addTab() {
        addTab(focusPolicy: .activePane)
    }

    private func addTabFromTabBar() {
        addTab(focusPolicy: .tabBar(.newTab))
    }

    private func addTab(focusPolicy: RefreshFocusPolicy) {
        // Open the new tab in the focused pane's directory (OSC 7), the way
        // Terminal.app / iTerm2 do — `⌘T` from ~/proj lands in ~/proj, not
        // home. nil (no cwd reported yet) falls back to the shell default.
        let inheritedCwd = activeTab?.focusedPane.surfaceView.currentWorkingDirectory
        tabs.append(WorkspaceTab(
            app: app,
            workingDirectory: inheritedCwd
        ))
        activeTabIndex = tabs.count - 1
        Diary.shared.log("addTab — total=\(tabs.count)", category: "tabs")
        refresh(focusPolicy)
        persistWorkspaceIfReady()
    }

    /// Opens a new tab that runs `command` instead of the default shell.
    /// Used by the SSH manager to spawn `ssh user@host` in a fresh pane,
    /// and the Claude session browser to spawn `claude --resume <id>` in
    /// the session's working directory.
    func addTab(command: String, title: String, workingDirectory: String? = nil) {
        tabs.append(WorkspaceTab(
            app: app,
            command: command,
            title: title,
            workingDirectory: workingDirectory
        ))
        activeTabIndex = tabs.count - 1
        // Commands may contain session IDs, hostnames, or user-provided
        // arguments. Record only structural metadata in the local diary.
        Diary.shared.log(
            Self.customTabDiaryMessage(
                command: command,
                workingDirectory: workingDirectory
            ),
            category: "tabs"
        )
        refresh()
        persistWorkspaceIfReady()
    }

    func selectNextTab() {
        guard !tabs.isEmpty else { return }
        activeTabIndex = (activeTabIndex + 1) % tabs.count
        refresh()
    }

    func selectPreviousTab() {
        guard !tabs.isEmpty else { return }
        activeTabIndex = (activeTabIndex - 1 + tabs.count) % tabs.count
        refresh()
    }

    private func selectTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        activeTabIndex = index
        refresh(.tabBar(.tab(id)))
    }

    private func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let sessionIDs = tabs[index].panes.map { $0.id }
        // Confirmation can re-enter the run loop (NSAlert.runModal blocks
        // on the main thread but services menu items + key events).
        // Re-derive the live index by UUID AFTER the modal returns so we
        // don't close the wrong tab if `tabs` mutated underneath us.
        // (M12 review HIGH — security-reviewer finding 1.)
        guard confirmCloseRisk(
            forSessionIDs: sessionIDs,
            action: .closeTab
        ) else { return }
        guard let liveIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        closeTabImmediately(at: liveIndex, retainTabBarFocus: true)
    }

    /// Removes the tab at `index` without prompting — internal helper for
    /// callers that have already done the M12-P4 note-confirmation check
    /// (e.g. `closeActivePane()` after it knows the tab will collapse).
    private func closeTabImmediately(at index: Int, retainTabBarFocus: Bool = false) {
        let previousActiveTabIndex = activeTabIndex
        tabs.remove(at: index)
        let outcome = Self.closeTabOutcome(
            closedIndex: index,
            activeIndex: previousActiveTabIndex,
            remainingTabIDs: tabs.map(\.id),
            retainTabBarFocus: retainTabBarFocus
        )

        switch outcome {
        case .closeWindow:
            // Don't persist an empty workspace — the window is closing.
            // The last non-empty snapshot stays on disk for next launch.
            window?.close()
        case .keepWorkspace(let nextActiveIndex, let focusPolicy):
            activeTabIndex = nextActiveIndex
            refresh(focusPolicy)
            persistWorkspaceIfReady()
        }
    }

    /// Returns true if it's safe to proceed with closing the panes
    /// identified by `sessionIDs`. Notes honor the owner's preference;
    /// mapped live agents and known long-lived launch commands always warn.
    ///
    /// Why NSAlert (not a SwiftUI sheet): the surface we'd attach the
    /// sheet to is the focused libghostty NSView, which doesn't host a
    /// SwiftUI environment. `NSAlert.runModal()` re-enters the main run
    /// loop while it's up — callers MUST re-derive any positional state
    /// (tab indices) after this method returns true.
    private func confirmCloseRisk(
        forSessionIDs sessionIDs: [UUID],
        action: CloseRiskAction
    ) -> Bool {
        let context = closeRiskContext(forSessionIDs: sessionIDs)
        guard context.assessment.requiresConfirmation else { return true }
        return presentCloseRiskAlert(context.assessment, action: action)
    }

    private func presentCloseRiskAlert(
        _ assessment: CloseRiskAssessment,
        action: CloseRiskAction
    ) -> Bool {
        let presentation = CloseRiskAlertPresentation(
            action: action,
            assessment: assessment
        )
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = presentation.messageText
        alert.informativeText = presentation.informativeText
        alert.addButton(withTitle: presentation.defaultButtonTitle)
        let destructiveButton = alert.addButton(
            withTitle: presentation.destructiveButtonTitle
        )
        destructiveButton.hasDestructiveAction = true
        let response = alert.runModal()
        return response == .alertSecondButtonReturn
    }

    func confirmCloseForWindow(action: CloseRiskAction) -> CloseRiskWindowDecision {
        let context = closeRiskContext(
            forSessionIDs: tabs.flatMap { $0.panes.map(\.id) }
        )
        guard context.assessment.requiresConfirmation else {
            return CloseRiskWindowDecision(approved: true, approvedFingerprint: nil)
        }
        let approved = presentCloseRiskAlert(context.assessment, action: action)
        return CloseRiskWindowDecision(
            approved: approved,
            approvedFingerprint: approved ? context.fingerprint : nil
        )
    }

    func closeRiskFingerprint() -> CloseRiskFingerprint {
        closeRiskContext(
            forSessionIDs: tabs.flatMap { $0.panes.map(\.id) }
        ).fingerprint
    }

    private struct CloseRiskContext {
        let sessions: [CloseRiskSession]
        let includeNotes: Bool

        var assessment: CloseRiskAssessment {
            CloseRiskAssessment.assess(sessions, includeNotes: includeNotes)
        }

        var fingerprint: CloseRiskFingerprint {
            CloseRiskFingerprint(sessions: Set(sessions), includeNotes: includeNotes)
        }
    }

    private func closeRiskContext(forSessionIDs sessionIDs: [UUID]) -> CloseRiskContext {
        let targetIDs = Set(sessionIDs)
        let includeNotes = Preferences.confirmCloseWithNote
        guard !targetIDs.isEmpty else {
            return CloseRiskContext(sessions: [], includeNotes: includeNotes)
        }

        let allSessions = tabs.flatMap(\.panes)
        let activeSessions = tabs.flatMap(\.livePanes)
        let mappedAgents = AgentPaneMapper.annotate(
            AgentDetector.detectAgents(),
            sessionStartTimes: activeSessions.map(\.createdAt)
        )
        let mappedAgentSessionIDs = Set<UUID>(mappedAgents.compactMap { agent in
            guard let index = agent.tabHint,
                  activeSessions.indices.contains(index) else { return nil }
            return activeSessions[index].id
        })
        let riskSessions = allSessions
            .filter { targetIDs.contains($0.id) }
            .map { session in
                CloseRiskSession(
                    id: session.id,
                    hasNote: includeNotes && sessionHasNote(session.id),
                    spawnedCommand: session.closeRiskCommand,
                    hasMappedAgent: !session.hasExited
                        && mappedAgentSessionIDs.contains(session.id),
                    hasLiveProcess: !session.hasExited
                        && session.surfaceView.surface.map(
                            ghostty_surface_needs_confirm_quit
                        ) == true
                )
            }
        return CloseRiskContext(sessions: riskSessions, includeNotes: includeNotes)
    }

    private func sessionHasNote(_ sessionID: UUID) -> Bool {
        if let recovery = notesPanelRecoveries[sessionID],
           !recovery.state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        switch loadNoteResult(sessionID) {
        case .success(let note):
            guard let body = note?.body else { return false }
            return !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .failure:
            return true
        }
    }

    // MARK: - Split / pane management

    /// Splits the active pane. If it is the only pane in the tab it also sets
    /// the tab's split axis.
    func splitActivePane(vertical: Bool, command: String? = nil, title: String? = nil) {
        activeTab?.split(app: app, vertical: vertical, command: command, title: title)
        Diary.shared.log(
            "splitActivePane vertical=\(vertical) customCommand=\(command != nil)",
            category: "panes"
        )
        refresh()
        persistWorkspaceIfReady()
    }

    func focusedWorkingDirectory() -> String? {
        activeTab?.focusedPane.surfaceView.currentWorkingDirectory
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabIndex = index
        refresh()
    }

    /// Session names this window already has a spawned tmux client for.
    private var tmuxAttachedHere: Set<String> {
        Set(tabs.flatMap { tab in
            tab.panes.compactMap { pane in
                pane.closeRiskCommand.flatMap(TmuxLaunch.sessionName(fromSpawnCommand:))
            }
        })
    }

    /// Focuses the exact pane in this window that spawned the named session.
    func focusTabSpawningTmux(named name: String) -> Bool {
        for (index, tab) in tabs.enumerated() {
            if tab.focusPane(spawningTmuxNamed: name) {
                activeTabIndex = index
                refresh()
                return true
            }
        }
        return false
    }

    /// `tabHint` from AgentPaneMapper is a flattened live-pane index,
    /// not a tab strip index. Retained exited panes are intentionally skipped.
    func focusSession(flatIndex: Int) {
        var i = 0
        for (tabIndex, tab) in tabs.enumerated() {
            for pane in tab.livePanes {
                if i == flatIndex {
                    activeTabIndex = tabIndex
                    tab.focusPane(id: pane.id)
                    refresh()
                    return
                }
                i += 1
            }
        }
    }

    var tabCount: Int { tabs.count }

    /// Closes the focused pane — or the whole tab if it was the last pane.
    func closeActivePane() {
        guard let tab = activeTab else { return }
        // Always gate on the FOCUSED pane's note, not the whole tab. The
        // earlier shape (gate only when panes.count == 1) silently
        // discarded notes on panes 2..N in multi-pane tabs because
        // closeFocusedPane() returns false when other panes remain, so
        // the post-hoc check at closeTab() never fires for non-final
        // panes. (M12 review HIGH — code-reviewer finding 2.)
        let focusedID = tab.focusedPane.id
        guard confirmCloseRisk(
            forSessionIDs: [focusedID],
            action: .closePane
        ) else { return }
        guard let liveTab = tabs.first(where: { $0.id == tab.id }),
              liveTab.panes.contains(where: { $0.id == focusedID }) else { return }
        liveTab.focusPane(id: focusedID)
        if liveTab.closeFocusedPane() {
            Diary.shared.log("closeActivePane → active tab empty, closing tab", category: "panes")
            guard let index = tabs.firstIndex(where: { $0.id == liveTab.id }) else { return }
            closeTabImmediately(at: index)
        } else {
            Diary.shared.log("closeActivePane remaining=\(liveTab.panes.count)", category: "panes")
            refresh()
            persistWorkspaceIfReady()
        }
    }

    // MARK: - Agent dashboard

    private func startAgentPolling() {
        agentPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshAgents()
            }
        }
    }

    func refreshAgents() {
        // Always refresh the cached count so the status bar (M12-P2) sees
        // the latest agent total even when the dashboard sidebar is closed.
        // The full annotation pipeline only runs when the sidebar is open
        // because it does materially more work (status tracker + pane
        // mapper + bell promotion).
        let raw = AgentDetector.detectAgents()
        latestAgentCount = raw.count
        guard leftSidebar == .agents else { return }
        let annotated = agentStatusTracker.annotate(raw)
        // M8/A2: if ANY surface rang its bell in the last 10s, promote
        // every running/idle agent to .needsInput. Per-surface attribution
        // is the M9/A3 follow-up (below) — but bells fire per-surface and
        // the agent↔pane mapper now tells us which session each agent
        // lives in, so we can scope the promotion when both signals agree.
        // Backstop: when the mapping fails (tabHint nil), fall back to
        // the M8 any-bell-promotes-all behaviour so we never under-flag.
        let bellAddresses = Set(
            surfaceAddresses.filter { BellRegistry.shared.hasRecentBell(forSurfaceAddress: $0) }
        )
        // M9/A3: ask the mapper for tab indices. Session creation order =
        // tab order in the current single-axis layout.
        let sessionStarts = tabs.flatMap { $0.livePanes.map { $0.createdAt } }
        let mapped = AgentPaneMapper.annotate(annotated,
                                              sessionStartTimes: sessionStarts)

        // `tabHint` is a flattened live-pane index. Build the address map in
        // that exact order so a bell in pane 2 of a split tab cannot promote
        // an agent in pane 1 or in the next tab.
        let addressesByPaneIndex = Dictionary(
            uniqueKeysWithValues: tabs
                .flatMap(\.livePanes)
                .enumerated()
                .map { index, pane in
                    (
                        index,
                        Set(pane.surfaceView.surfaceAddress.map { [$0] } ?? [])
                    )
                }
        )
        let final = AgentPaneMapper.promoteOnBell(
            mapped,
            bellAddresses: bellAddresses,
            addressesByTab: addressesByPaneIndex
        )
        latestDisplayedAgents = final
        pendingAgentDashboardFocusRequestID = AgentDashboardView.retainedInitialFocusRequestID(
            pendingAgentDashboardFocusRequestID,
            agents: final,
            query: sidebarFilterState.agentDashboardQuery
        )
        dashboardHost.rootView = makeAgentDashboard(agents: final)
    }

    func refreshTmuxSessions(optimistic name: String? = nil, force: Bool = false) {
        if let name, (try? TmuxLaunch.validateName(name)) != nil,
           !tmuxSessions.contains(where: { $0.name == name }) {
            tmuxSessions.append(
                TmuxLaunch.Session(name: name, windows: 1, attachedClients: 1)
            )
        }

        tmuxAvailable = TmuxLaunch.resolveBinary() != nil
        if !tmuxAvailable {
            tmuxSessions = []
            tmuxRefreshGeneration += 1
            applyTmuxDashboardIfVisible()
            return
        }

        applyTmuxDashboardIfVisible()

        if !force, let last = lastTmuxRefreshAt, Date().timeIntervalSince(last) < 2 {
            return
        }
        lastTmuxRefreshAt = Date()
        tmuxRefreshGeneration += 1
        let generation = tmuxRefreshGeneration
        Task { [weak self] in
            let records = await Task.detached(priority: .utility) {
                let raw = (try? TmuxLaunch.listSessionRecords()) ?? []
                return TmuxLaunch.displayableSessions(raw)
            }.value
            guard let self, generation == self.tmuxRefreshGeneration else { return }
            self.tmuxSessions = TmuxLaunch.sortedForDashboard(records)
            self.applyTmuxDashboardIfVisible()
        }
    }

    private func applyTmuxDashboardIfVisible() {
        guard leftSidebar == .agents else { return }
        dashboardHost.rootView = makeAgentDashboard(agents: latestDisplayedAgents)
    }

    func refreshWorktrees() {
        worktreeRefreshGeneration += 1
        let generation = worktreeRefreshGeneration
        refreshTmuxSessions()
        guard let cwd = focusedWorkingDirectory() else {
            worktreeEntries = []
            worktreesInGitRepo = false
            primaryWorktreePath = nil
            dashboardHost.rootView = makeAgentDashboard(agents: latestDisplayedAgents)
            return
        }

        Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                guard let trees = try? GitWorktree.list(cwd: cwd) else {
                    return Optional<(entries: [GitWorktree.Entry], primary: String?)>.none
                }
                let primary = (try? GitWorktree.resolveContext(cwd: cwd))?.mainRepoRoot
                return (entries: trees, primary: primary)
            }.value
            guard let self, generation == self.worktreeRefreshGeneration else { return }
            if let snapshot {
                self.worktreeEntries = snapshot.entries
                self.worktreesInGitRepo = true
                self.primaryWorktreePath = snapshot.primary
            } else {
                self.worktreeEntries = []
                self.worktreesInGitRepo = false
                self.primaryWorktreePath = nil
            }
            // refreshAgents will replace this again when lifecycle sampling
            // finishes; this immediate render keeps the worktree section fresh.
            self.dashboardHost.rootView = self.makeAgentDashboard(
                agents: self.latestDisplayedAgents
            )
        }
    }

    func makeAgentDashboard(agents: [DetectedAgent]) -> AgentDashboardView {
        return AgentDashboardView(
            agents: agents,
            filterState: sidebarFilterState,
            initialFocusRequestID: pendingAgentDashboardFocusRequestID,
            worktrees: worktreeEntries,
            inGitRepo: worktreesInGitRepo,
            primaryWorktreePath: primaryWorktreePath,
            onInitialFocusConsumed: { [weak self] requestID in
                guard let self else { return }
                self.pendingAgentDashboardFocusRequestID = Self.agentDashboardFocusRequestID(
                    self.pendingAgentDashboardFocusRequestID,
                    afterConsuming: requestID
                )
            },
            onSelectAgent: { [weak self] agent in
                if let hint = agent.tabHint { self?.focusSession(flatIndex: hint) }
            },
            onNewAgent: { [weak self] in self?.newAgentPane(nil) },
            onNewWorktree: { [weak self] in self?.newAgentWorktree(nil) },
            onOpenLazygit: { [weak self] in self?.openLazygit(nil) },
            onOpenWorktree: { [weak self] tree in self?.openWorktree(tree, kind: .shell) },
            onAgentInWorktree: { [weak self] tree in self?.openWorktree(tree, kind: .claude) },
            onRemoveWorktree: { [weak self] tree in self?.confirmRemoveWorktree(tree) },
            tmuxSessions: tmuxSessions,
            tmuxAttachedHere: tmuxAttachedHere,
            tmuxAvailable: tmuxAvailable,
            onAttachTmux: { [weak self] name in self?.attachTmuxNamed(name) },
            onKillTmux: { [weak self] name in self?.confirmKillTmux(name) },
            onAttachOrCreateTmux: tmuxAvailable
                ? { [weak self] in self?.attachOrCreateTmuxSession(nil) }
                : nil,
            onNewNamedTmux: tmuxAvailable
                ? { [weak self] in self?.newTmuxSession(nil) }
                : nil
        )
    }

    nonisolated static func agentDashboardFocusRequestID(
        _ currentRequestID: UUID?,
        afterConsuming consumedRequestID: UUID
    ) -> UUID? {
        currentRequestID == consumedRequestID ? nil : currentRequestID
    }

    /// All libghostty surface addresses across every tab + every pane.
    /// Used by the bell-needs-input promotion in `refreshAgents()`.
    private var surfaceAddresses: [Int] {
        tabs.flatMap { tab in
            tab.panes.compactMap { $0.surfaceView.surfaceAddress }
        }
    }

    // MARK: - Status bar snapshot (M12-P2)

    /// Builds the snapshot StatusBarView consumes once a second. All four
    /// reads are cheap (one O(n log n) sort over ≤600 doubles, one Int,
    /// one stat(2), one enum read) so we don't need to cache anything.
    private func captureStatusSnapshot() -> StatusSnapshot {
        // The focused pane's live cwd (OSC 7) + git branch, both cached on
        // the surface (branch recomputed only on cd) — no filesystem I/O
        // on the 1 Hz tick, just two string reads.
        let surface = activeTab?.focusedPane.surfaceView
        let cwd = surface?.currentWorkingDirectory
        return StatusSnapshot(
            agentCount: latestAgentCount,
            latencyP95: LatencyProbe.shared.snapshotP95Milliseconds(),
            diaryBytes: Diary.shared.fileSizeBytes(),
            themeText: Self.themeDisplayName(),
            cwd: cwd,
            gitBranch: surface?.currentGitBranch
        )
    }

    // MARK: - First-run welcome overlay (M12-P3)

    private func showWelcomeOverlayIfNeeded() {
        guard !Preferences.firstRunCompleted, welcomeOverlay == nil else { return }
        let overlay = NSHostingView(
            rootView: WelcomeOverlayView(onDismiss: { [weak self] in
                MainActor.assumeIsolated {
                    self?.dismissWelcomeOverlay()
                }
            })
        )
        overlay.frame = bounds
        // Drawn last so it sits above sidebars / status bar / surfaces.
        addSubview(overlay)
        welcomeOverlay = overlay
        Diary.shared.log("welcome overlay shown", category: "ui")
    }

    private func dismissWelcomeOverlay() {
        guard let overlay = welcomeOverlay else { return }
        let focusTarget = activeTab?.focusedPane.surfaceView
        // Clear ownership before invoking callbacks so a duplicate action
        // cannot persist onboarding twice while the first dismissal is still
        // unwinding through SwiftUI/AppKit.
        welcomeOverlay = nil
        tabBarFocusRetention.clear()
        guard Self.completeWelcomeOverlayDismissal(
            overlay: overlay,
            window: window,
            returningFocusTo: focusTarget,
            markCompleted: Preferences.markFirstRunCompleted
        ) else { return }
        Diary.shared.log("welcome overlay dismissed", category: "ui")
    }

    /// AppKit boundary shared by production and the responder-chain regression
    /// test. The overlay must still be installed; that makes dismissal
    /// idempotent and prevents a repeated Escape/default-button callback from
    /// consuming one-shot onboarding more than once.
    @discardableResult
    static func completeWelcomeOverlayDismissal(
        overlay: NSView?,
        window: NSWindow?,
        returningFocusTo focusTarget: NSView?,
        markCompleted: () -> Void
    ) -> Bool {
        guard let overlay, overlay.superview != nil else { return false }
        overlay.removeFromSuperview()
        markCompleted()
        if let focusTarget {
            window?.makeFirstResponder(focusTarget)
        }
        return true
    }

    /// Resolves the user-facing theme label, including the "(system)" tag
    /// when the persisted preference is .system so the owner can see what
    /// the appearance is following without opening Settings.
    private static func themeDisplayName() -> String {
        switch Preferences.theme {
        case .dark: return "dark"
        case .light: return "light"
        case .system:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return "\(isDark ? "dark" : "light") (system)"
        }
    }

    // MARK: - Claude sessions panel (v0.4-S1)

    struct ClaudePanelRefreshGate {
        private(set) var latestGeneration = 0

        mutating func beginRefresh() -> Int {
            latestGeneration += 1
            return latestGeneration
        }

        func shouldApply(_ generation: Int) -> Bool {
            generation == latestGeneration
        }
    }

    private func refreshClaudePanel(initialFocusRequestID: UUID? = nil) {
        // Scanning ~/.claude/projects (a dir stat + 16 KB read per project)
        // is filesystem I/O — keep it off the main thread so a user with
        // hundreds of projects doesn't see the sidebar jank on open / theme
        // change / prefs change. Hop back to MainActor to swap the view.
        // (v0.4.3 review HIGH-4.)
        let refreshGeneration = claudePanelRefreshGate.beginRefresh()
        Task { [weak self] in
            let sessions = await Task.detached(priority: .utility) {
                ClaudeSessionStore.recentProjects()
            }.value
            await MainActor.run {
                guard let self else { return }
                guard self.claudePanelRefreshGate.shouldApply(refreshGeneration) else { return }
                self.claudePanelHost.rootView = AnyView(
                    ClaudeSessionsPanel(
                        sessions: sessions,
                        filterState: self.sidebarFilterState,
                        initialFocusRequestID: initialFocusRequestID,
                        onResume: { [weak self] session in self?.resumeClaude(session) },
                        onOpenShell: { [weak self] session in
                            self?.openShell(in: session.cwd, title: session.projectName)
                        },
                        onNewAgentPane: { [weak self] in self?.newAgentPane(nil) },
                        onRefresh: { [weak self] in self?.refreshClaudePanel() }
                    )
                )
            }
        }
    }

    /// Opens a tab that resumes the project's newest Claude conversation
    /// in its real cwd. `claude --resume <id>` reattaches the exact
    /// session; the working directory is set on the libghostty surface
    /// so relative paths in the conversation still resolve.
    private func resumeClaude(_ session: ClaudeProjectSession) {
        Diary.shared.log("resume claude session requested", category: "claude")
        addTab(
            command: "claude --resume \(session.sessionId)",
            title: session.projectName,
            workingDirectory: session.cwd
        )
    }

    /// Opens a plain shell pane already cd'd into `cwd`. With no shell
    /// override this is the macOS login shell; otherwise the validated
    /// override bootstraps after launch.
    private func openShell(in cwd: String, title: String) {
        Diary.shared.log("open project shell requested", category: "claude")
        addTab(command: "", title: title, workingDirectory: cwd)
    }

    // MARK: - SSH hosts panel

    private static let sshLog = Logger(
        subsystem: "com.hoangperry.herminal", category: "ssh"
    )

    private func loadHosts() -> [SSHHost] {
        do {
            return try sshHostsStore.allHosts()
        } catch {
            Self.sshLog.error("hosts load failed: \(error, privacy: .private(mask: .hash))")
            return []
        }
    }

    private func refreshSSHPanel(initialFocusRequestID: UUID? = nil) {
        let hosts = loadHosts()
        sshPanelHost.rootView = AnyView(
            SSHHostsPanel(
                hosts: hosts,
                storageIsDurable: sshHostsStorageIsDurable,
                filterState: sidebarFilterState,
                importFeedback: sshImportState.feedback,
                initialFocusRequestID: initialFocusRequestID,
                onConnect: { [weak self] host in self?.connectSSH(host) },
                onSave: { [weak self] host in self?.saveSSHHost(host) },
                onDelete: { [weak self] id in self?.deleteSSHHost(id: id) },
                onImportConfig: { [weak self] in self?.importSSHConfig(nil) },
                onDismissImportFeedback: { [weak self] in self?.dismissSSHImportFeedback() }
            )
        )
    }

    private func saveSSHHost(_ host: SSHHost) {
        do {
            try sshHostsStore.upsert(host)
            sshImportState.clearAfterManualHostSave()
        } catch {
            Self.sshLog.error("host save failed: \(error, privacy: .private(mask: .hash))")
        }
        refreshSSHPanel(initialFocusRequestID: UUID())
    }

    private func deleteSSHHost(id: UUID) {
        do {
            try sshHostsStore.delete(id: id)
        } catch {
            Self.sshLog.error("host delete failed: \(error, privacy: .private(mask: .hash))")
        }
        refreshSSHPanel()
    }

    private enum SSHConfigReadResult: Sendable {
        case hosts([SSHHost])
        case configMissing(path: String)
        case fileTooLarge(bytes: Int)
        case failed
    }

    /// M9/B: read and parse `~/.ssh/config` off the UI actor, then import
    /// every concrete Host block in one transaction. The same typed feedback
    /// reaches the panel whether the action started there, in the menu, or in
    /// the command palette.
    @objc func importSSHConfig(_ sender: Any?) {
        guard sshImportState.begin() else { return }

        revealSSHPanelForImport()

        Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Self.readSSHConfig()
            }.value
            self?.finishSSHConfigImport(result)
        }
    }

    private nonisolated static func readSSHConfig() -> SSHConfigReadResult {
        do {
            return .hosts(try SSHConfigImporter.parseHosts())
        } catch SSHConfigImporter.ImportError.fileMissing(let path) {
            return .configMissing(path: path)
        } catch SSHConfigImporter.ImportError.fileTooLarge(_, let bytes) {
            return .fileTooLarge(bytes: bytes)
        } catch {
            return .failed
        }
    }

    private func finishSSHConfigImport(_ result: SSHConfigReadResult) {
        switch result {
        case .hosts(let imported):
            do {
                try sshHostsStore.upsert(imported)
                sshImportState.complete(with: .result(importedCount: imported.count))
                Diary.shared.log("imported \(imported.count) ssh hosts from ~/.ssh/config",
                                 category: "ssh")
            } catch {
                sshImportState.complete(with: .failed)
                Diary.shared.log("ssh config import failed", category: "ssh")
                Self.sshLog.error(
                    "ssh config persistence failed: \(error, privacy: .private(mask: .hash))"
                )
            }
        case .configMissing(let path):
            sshImportState.complete(with: .configMissing)
            Diary.shared.log("ssh config not found", category: "ssh")
            Self.sshLog.info("ssh config not found at \(path, privacy: .private(mask: .hash))")
        case .fileTooLarge(let bytes):
            sshImportState.complete(with: .fileTooLarge)
            Diary.shared.log("ssh config is too large", category: "ssh")
            Self.sshLog.info("ssh config exceeds import limit bytes=\(bytes)")
        case .failed:
            sshImportState.complete(with: .failed)
            Diary.shared.log("ssh config import failed", category: "ssh")
            Self.sshLog.error("ssh config read failed")
        }

        if leftSidebar == .ssh {
            refreshSSHPanel()
            announceSSHImportFeedback(sshImportState.feedback)
        }
    }

    private func revealSSHPanelForImport() {
        let wasVisible = leftSidebar == .ssh
        leftSidebar = .ssh
        refreshSSHPanel()
        announceSSHImportFeedback(sshImportState.feedback)
        if !wasVisible {
            animateSidebarChange()
        }
    }

    private func announceSSHImportFeedback(_ feedback: SSHImportFeedback?) {
        guard let feedback else { return }
        let priority: NSAccessibilityPriorityLevel = feedback.isImporting ? .low : .medium
        NSAccessibility.post(
            element: sshPanelHost,
            notification: .announcementRequested,
            userInfo: [
                .announcement: feedback
                    .content(storageIsDurable: sshHostsStorageIsDurable)
                    .accessibilityLabel,
                .priority: priority.rawValue
            ]
        )
    }

    private func dismissSSHImportFeedback() {
        sshImportState.dismiss()
        if leftSidebar == .ssh {
            refreshSSHPanel()
        }
    }

    /// Opens a new tab that spawns `ssh` into the saved host, stamps the
    /// last-connected time, and refreshes the panel so the recency badge
    /// updates immediately.
    private func connectSSH(_ host: SSHHost) {
        let command = Self.sshCommand(for: host)
        Self.sshLog.info("opening ssh tab on port \(host.port)")
        Diary.shared.log(Self.sshConnectionDiaryMessage(for: host), category: "ssh")
        addTab(command: command, title: host.nickname)
        do {
            try sshHostsStore.touchLastConnected(id: host.id)
        } catch {
            Self.sshLog.error("last-connected stamp failed: \(error, privacy: .private(mask: .hash))")
            Diary.shared.log("ssh last-connected stamp failed", category: "ssh")
        }
        refreshSSHPanel()
    }

    /// Builds the shell command that libghostty will exec in the new pane.
    /// User/host get single-quoted to defang any wild characters in saved
    /// metadata (we're feeding this to /bin/sh -c via libghostty).
    /// Internal for direct testing — quoting logic is the kind of thing
    /// that's painful to get wrong and easy to regress.
    static func sshCommand(for host: SSHHost) -> String {
        let target = "\(quoted(host.user))@\(quoted(host.hostname))"
        if host.port == 22 {
            return "ssh \(target)"
        }
        return "ssh -p \(host.port) \(target)"
    }

    static func sshConnectionDiaryMessage(for host: SSHHost) -> String {
        "ssh connect requested port=\(host.port)"
    }

    static func customTabDiaryMessage(
        command: String,
        workingDirectory: String?
    ) -> String {
        "addTab customCommand=\(!command.isEmpty) cwdSet=\(workingDirectory != nil)"
    }

    /// Single-quote a shell argument, escaping any embedded single quotes.
    private static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    // MARK: - Notes

    private static let notesLog = Logger(
        subsystem: "com.hoangperry.herminal", category: "notes"
    )

    /// Loads a session's note and preserves the distinction between "missing"
    /// and "storage failed" so the UI can lock instead of overwriting unknown
    /// content with a blank draft.
    private func loadNoteResult(_ sessionID: UUID) -> Result<Note?, Error> {
        do {
            return .success(try notesStore.note(forSession: sessionID))
        } catch {
            Self.notesLog.error("note load failed: \(error, privacy: .private(mask: .hash))")
            return .failure(error)
        }
    }

    /// Persists a note and reports whether the configured store accepted it.
    /// The panel separately explains whether that store is durable or transient.
    private func persistNote(_ note: Note) -> Bool {
        let writeSucceeded: Bool
        do {
            try notesStore.upsert(note)
            writeSucceeded = true
        } catch {
            Self.notesLog.error("note save failed: \(error, privacy: .private(mask: .hash))")
            writeSucceeded = false
        }
        return NotesStoragePolicy.canReportSaveSuccess(writeSucceeded: writeSucceeded)
    }

    /// Loads the active session's note into the notes panel.
    private func updateNotesPanel() {
        guard isNotesVisible, let session = activeTab?.focusedPane else { return }
        let sessionID = session.id
        let title = activeTab?.title ?? "herminal"
        let recovery = notesPanelRecoveries[sessionID]
        switch loadNoteResult(sessionID) {
        case .success(let loadedNote):
            let now = Date()
            installNotesPanel(
                title: title,
                sessionID: sessionID,
                noteID: recovery?.noteID ?? loadedNote?.id ?? UUID(),
                createdAt: recovery?.createdAt ?? loadedNote?.createdAt ?? now,
                initialState: Self.preferredNotesPanelState(
                    loadedNote: loadedNote,
                    recovery: recovery
                )
            )
        case .failure where recovery != nil:
            let now = Date()
            installNotesPanel(
                title: title,
                sessionID: sessionID,
                noteID: recovery?.noteID ?? UUID(),
                createdAt: recovery?.createdAt ?? now,
                initialState: recovery?.state ?? .loadFailed
            )
        case .failure:
            notesHost.rootView = AnyView(
                NotesPanelView(
                    sessionTitle: title,
                    initialState: .loadFailed,
                    storageIsDurable: notesStorageIsDurable,
                    onReload: { [weak self] in self?.updateNotesPanel() }
                ) { _ in
                    false
                }
                .id(sessionID)
            )
        }
    }

    static func preferredNotesPanelState(
        loadedNote: Note?,
        recovery: NotesPanelRecovery?
    ) -> NotesPanelView.AutosaveState {
        recovery?.state ?? NotesPanelView.AutosaveState(draft: loadedNote?.body ?? "")
    }

    private func installNotesPanel(
        title: String,
        sessionID: UUID,
        noteID: UUID,
        createdAt: Date,
        initialState: NotesPanelView.AutosaveState
    ) {
        notesHost.rootView = AnyView(
            NotesPanelView(
                sessionTitle: title,
                initialState: initialState,
                storageIsDurable: notesStorageIsDurable,
                onReload: { [weak self] in self?.updateNotesPanel() },
                onSaveFailure: { [weak self] in self?.announceNoteSaveFailure() },
                onStateChange: { [weak self] state in
                    self?.retainNotesPanelRecovery(
                        state,
                        sessionID: sessionID,
                        noteID: noteID,
                        createdAt: createdAt
                    )
                }
            ) { [weak self] newText in
                self?.saveNote(
                    id: noteID,
                    sessionID: sessionID,
                    createdAt: createdAt,
                    body: newText
                ) ?? false
            }
            .id(sessionID)
        )
    }

    private func retainNotesPanelRecovery(
        _ state: NotesPanelView.AutosaveState,
        sessionID: UUID,
        noteID: UUID,
        createdAt: Date
    ) {
        notesPanelRecoveries[sessionID] = NotesPanelRecovery.retainingAtRisk(
            state,
            storageIsDurable: notesStorageIsDurable,
            noteID: noteID,
            createdAt: createdAt
        )
    }

    private func pruneNotesPanelRecoveries() {
        let liveSessionIDs = Set(tabs.flatMap { $0.panes.map(\.id) })
        notesPanelRecoveries = notesPanelRecoveries.filter { liveSessionIDs.contains($0.key) }
    }

    private func saveNote(id: UUID, sessionID: UUID, createdAt: Date, body: String) -> Bool {
        let note = Note(
            id: id,
            sessionID: sessionID,
            body: body,
            createdAt: createdAt,
            updatedAt: Date()
        )
        return persistNote(note)
    }

    private func announceNoteSaveFailure() {
        NSAccessibility.post(
            element: notesHost,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "Note save failed. Retry is available in the notes footer.",
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    // MARK: - Menu actions

    @objc func newTab(_ sender: Any?) { addTab() }
    @objc func closeTab(_ sender: Any?) { closeActivePane() }
    @objc func nextTab(_ sender: Any?) { selectNextTab() }
    @objc func previousTab(_ sender: Any?) { selectPreviousTab() }

    @objc func increaseFontSize(_ sender: Any?) { applyFontAction("increase_font_size:1") }
    @objc func decreaseFontSize(_ sender: Any?) { applyFontAction("decrease_font_size:1") }
    @objc func resetFontSize(_ sender: Any?) { applyFontAction("reset_font_size") }

    /// Maximize / restore the focused pane (no-op for a single-pane tab).
    /// Re-lays out + re-focuses; the tree is untouched. (v1.0 pane zoom.)
    @objc func toggleZoomPane(_ sender: Any?) {
        activeTab?.toggleZoom()
        layoutPanes()
        focusActivePane()
    }

    /// Live font-size adjust via libghostty's own binding actions, applied
    /// to every surface (including inactive tabs — intentional, so the
    /// whole window scales together; libghostty applies the action per
    /// surface regardless of view-hierarchy membership). The Settings
    /// slider still sets the default for new panes. (v1.0.)
    private func applyFontAction(_ action: String) {
        for tab in tabs {
            for pane in tab.panes {
                pane.surfaceView.runBindingActionForHarness(action)
            }
        }
        // CELL_SIZE normally triggers the observer above. This immediate pass
        // also covers libghostty builds that update metrics synchronously but
        // omit the informational action callback.
        layoutPanes()
    }
    @objc func splitPaneVertical(_ sender: Any?) { splitActivePane(vertical: true) }
    @objc func splitPaneHorizontal(_ sender: Any?) { splitActivePane(vertical: false) }

    @objc func focusPaneLeft(_ sender: Any?) { moveFocus(.left) }
    @objc func focusPaneRight(_ sender: Any?) { moveFocus(.right) }
    @objc func focusPaneUp(_ sender: Any?) { moveFocus(.up) }
    @objc func focusPaneDown(_ sender: Any?) { moveFocus(.down) }

    /// Moves focus to the pane spatially `direction` of the focused one,
    /// using the laid-out frames (so it's correct for any nesting). No-op
    /// when there's no pane on that side. (v0.5.1 directional nav.)
    func moveFocus(_ direction: PaneDirection) {
        guard let tab = activeTab, tab.panes.count > 1 else { return }
        // While zoomed only one pane is visible, so the others carry stale
        // frames and spatial nav can't read real geometry. Treat the first
        // arrow as "exit zoom" (iTerm convention) — restore the split, keep
        // focus; subsequent arrows then navigate normally. (v1.0 review.)
        if tab.isZoomed {
            tab.focusPane(id: tab.focusedPaneID)  // clears zoom, focus unchanged
            layoutPanes()                          // bring the split layout back
            focusActivePane()
            return
        }
        let focused = tab.focusedPane
        let candidates = tab.panes
            .filter { $0.id != focused.id }
            .map { (id: $0.id, rect: $0.surfaceView.frame) }
        guard let targetID = PaneNavigation.nearestPane(
            from: focused.surfaceView.frame, candidates: candidates, direction: direction
        ) else { return }
        tab.focusPane(id: targetID)
        focusActivePane()
        updateFocusRing()                // move the outline to the new pane
        tabHost.rootView = makeTabBar()  // focused pane's title may differ
        persistWorkspaceIfReady()
    }

    @objc func toggleAgentDashboard(_ sender: Any?) {
        leftSidebar = (leftSidebar == .agents) ? .none : .agents
        if leftSidebar == .agents {
            pendingAgentDashboardFocusRequestID = UUID()
            refreshAgents()
            refreshWorktrees()
        } else {
            pendingAgentDashboardFocusRequestID = nil
        }
        persistSidebarState()
        animateSidebarChange()
    }

    func revealAgentDashboard() {
        if leftSidebar != .agents {
            leftSidebar = .agents
            persistSidebarState()
            animateSidebarChange()
        }
        refreshWorktrees()
        refreshAgents()
    }

    @objc func toggleSSHHosts(_ sender: Any?) {
        leftSidebar = (leftSidebar == .ssh) ? .none : .ssh
        if leftSidebar == .ssh { refreshSSHPanel(initialFocusRequestID: UUID()) }
        persistSidebarState()
        animateSidebarChange()
    }

    @objc func toggleClaudeSessions(_ sender: Any?) {
        leftSidebar = (leftSidebar == .claude) ? .none : .claude
        if leftSidebar == .claude { refreshClaudePanel(initialFocusRequestID: UUID()) }
        persistSidebarState()
        animateSidebarChange()
    }

    @objc func toggleNotes(_ sender: Any?) {
        isNotesVisible.toggle()
        if isNotesVisible { updateNotesPanel() }
        persistSidebarState()
        animateSidebarChange()
    }

    /// Re-apply the workspace-level sidebar state from the last session.
    /// AppDelegate calls this BEFORE the window is shown so the first
    /// layout already reserves space for whatever the owner had open.
    /// (M12-P5)
    func applyRestoredSidebarState(_ snapshot: WindowState.Snapshot) {
        switch snapshot.leftSidebar {
        case .none: leftSidebar = .none
        case .agents: leftSidebar = .agents
        case .ssh: leftSidebar = .ssh
        case .claude: leftSidebar = .claude
        }
        isNotesVisible = snapshot.notesVisible
        if leftSidebar == .agents {
            refreshWorktrees()
            refreshAgents()
        }
        if leftSidebar == .ssh { refreshSSHPanel() }
        if leftSidebar == .claude { refreshClaudePanel() }
        if isNotesVisible { updateNotesPanel() }
        needsLayout = true
    }

    private func persistSidebarState() {
        let mapped: WindowState.LeftSidebar = {
            switch leftSidebar {
            case .none: return .none
            case .agents: return .agents
            case .ssh: return .ssh
            case .claude: return .claude
            }
        }()
        WindowState.saveSidebar(left: mapped, notesVisible: isNotesVisible)
    }

    // MARK: - Session restore (v0.4.1)

    /// Replaces the current tabs with those from a restored snapshot.
    /// Called by AppDelegate at launch (before the window is shown) when
    /// the restore preference is on and a snapshot exists. Returns true
    /// if at least one tab was restored.
    @discardableResult
    func restoreWorkspace(_ snapshot: WorkspaceSnapshot) -> Bool {
        guard !snapshot.tabs.isEmpty else { return false }
        let rerun = Preferences.rerunCommandsOnRestore
        tabs = snapshot.tabs.map {
            WorkspaceTab(
                app: app,
                restoring: $0,
                rerunCommands: rerun
            )
        }
        activeTabIndex = min(max(snapshot.activeTabIndex, 0), tabs.count - 1)
        Diary.shared.log("restored \(tabs.count) tab(s) from snapshot", category: "session")
        refresh()
        return true
    }

    /// Snapshots the whole workspace for persistence.
    func snapshotWorkspace() -> WorkspaceSnapshot {
        WorkspaceSnapshot.compacting(
            tabs: tabs.map { $0.snapshot() },
            activeTabIndex: activeTabIndex
        )
    }

    /// Turns on persistence + writes an immediate snapshot. AppDelegate
    /// calls this once the launch restore decision is made, so the
    /// default/launch tab churn before it doesn't overwrite the saved
    /// session prematurely.
    func enableSessionPersistence() {
        sessionPersistenceEnabled = true
        // Only write the immediate snapshot when restore is actually on.
        // With restore off, AppDelegate has just cleared the saved file —
        // an unconditional persist here would re-create it from the default
        // launch tab and silently undo that opt-out. Later real mutations
        // still persist via persistWorkspaceIfReady. (v0.4.3 review.)
        if Preferences.restoreSessionOnLaunch {
            persistWorkspace()
        }
    }

    /// Writes the current workspace to disk. Always safe to call (used by
    /// AppDelegate.applicationWillTerminate); the `IfReady` variant is for
    /// the structural mutators so they no-op during init/restore.
    func persistWorkspace() {
        WorkspaceStore.save(snapshotWorkspace())
    }

    private func persistWorkspaceIfReady() {
        guard sessionPersistenceEnabled else { return }
        persistWorkspace()
    }

    /// M9/C-light: flip between dark and light theme. SwiftUI re-evaluates
    /// the `@MainActor` Palette tokens because their backing var changed;
    /// we still need to nudge the AppKit chrome (window background +
    /// surface container) explicitly because those colours were resolved
    /// at init time.
    /// Listener for `Preferences.didChangeNotification` — re-applies the
    /// persisted theme (handles both manual flips and the `.system`
    /// follow-the-appearance case) and repaints all SwiftUI hosts so
    /// design tokens re-evaluate. (M12-P1)
    /// libghostty PTY child for some surface just exited. Walk every
    /// tab / pane and remove the matching one. If that empties the
    /// tab, close the tab too. Posted from
    /// `GhosttyApp.closeSurface` on the main thread (libghostty's
    /// callback runs during our 60 Hz `ghostty_app_tick`).
    /// (v0.2.3 stub-from-spike fix.)
    /// Shell wrote OSC 0/2 (or libghostty fired `set_tab_title`).
    /// Find the session whose surfaceView matches the notification
    /// sender and update its title, then rebuild the tab strip.
    /// (v0.2.4 stub-from-spike fix.)
    @objc func surfaceTitleDidChange(_ note: Notification) {
        guard let view = note.object as? HerminalSurfaceView,
              let title = note.userInfo?[GhosttyApp.surfaceTitleKey] as? String else { return }
        for tab in tabs {
            guard let pane = tab.panes.first(where: { $0.surfaceView === view }) else { continue }
            // Empty strings from the wire mean "restore default" —
            // libghostty's OSC 0 with empty payload follows that
            // convention. Fall back to a stable label rather than
            // letting the tab title go blank.
            pane.title = title.isEmpty ? TerminalSession.defaultTitle : title
            tabHost.rootView = makeTabBar()
            return
        }
    }

    // MARK: - Scrollback search overlay (v0.3.2)

    /// AppMenu's File menu (⌘F) hits this entry point. libghostty
    /// owns the actual scanning; we just trigger `start_search` and
    /// then react to the START_SEARCH action that libghostty posts back
    /// (which is what actually opens the overlay).
    @objc func findInScrollback(_ sender: Any?) {
        activeTab?.focusedPane.surfaceView.runBindingActionForHarness("start_search")
    }

    /// ⌘G / ⌘⇧G next/prev match navigation. The bindings are routed
    /// here from AppMenu items. Only fires when the active search has a match.
    @objc func findNext(_ sender: Any?) {
        guard Self.searchNavigationIsEnabled(
            hasOverlay: searchOverlayHost != nil,
            state: searchOverlayState
        ) else { return }
        searchOverlayTarget?.runBindingActionForHarness("navigate_search:next")
    }

    @objc func findPrevious(_ sender: Any?) {
        guard Self.searchNavigationIsEnabled(
            hasOverlay: searchOverlayHost != nil,
            state: searchOverlayState
        ) else { return }
        searchOverlayTarget?.runBindingActionForHarness("navigate_search:previous")
    }

    @objc func surfaceSearchEvent(_ note: Notification) {
        guard let view = note.object as? HerminalSurfaceView else { return }
        switch note.name {
        case GhosttyApp.surfaceSearchStartNotification:
            let initialNeedle = note.userInfo?[GhosttyApp.surfaceSearchValueKey] as? String ?? ""
            presentSearchOverlay(targeting: view, initialNeedle: initialNeedle)
        case GhosttyApp.surfaceSearchEndNotification:
            // Only dismiss if the END event refers to the pane we're
            // currently displaying — guards against stale events from a
            // sibling pane that was closed in the background.
            if view === searchOverlayTarget {
                dismissSearchOverlay(sendEnd: false)
            }
        case GhosttyApp.surfaceSearchTotalNotification:
            guard view === searchOverlayTarget else { return }
            let raw = note.userInfo?[GhosttyApp.surfaceSearchValueKey] as? Int ?? -1
            searchOverlayState?.total = raw >= 0 ? raw : nil
        case GhosttyApp.surfaceSearchSelectedNotification:
            guard view === searchOverlayTarget else { return }
            let raw = note.userInfo?[GhosttyApp.surfaceSearchValueKey] as? Int ?? -1
            searchOverlayState?.selected = raw >= 0 ? raw : nil
        default:
            break
        }
    }

    private func presentSearchOverlay(targeting view: HerminalSurfaceView,
                                      initialNeedle: String) {
        // If the same overlay is already up, just refocus its text
        // field — match Safari's ⌘F-when-already-open behaviour.
        if Self.reuseExistingSearchOverlay(
            hasOverlay: searchOverlayHost != nil,
            sameTarget: searchOverlayTarget === view,
            state: searchOverlayState
        ) {
            return
        }
        // Different pane → tear down the old overlay first so the
        // listener bookkeeping stays clean.
        if searchOverlayHost != nil { dismissSearchOverlay(sendEnd: true) }

        let state = SearchOverlayState()
        state.needle = initialNeedle
        searchOverlayState = state
        searchOverlayTarget = view

        // Whenever the needle text changes, fire the
        // `search:<needle>` binding action. libghostty re-runs the
        // scan + posts SEARCH_TOTAL back. The cancellable is stored
        // on the view (not on the state) so the GC ties the
        // subscription's lifetime to the overlay's.
        let cancellable = state.$needle.sink { [weak self, weak view] needle in
            guard let view, let _ = self else { return }
            // libghostty's binding-action grammar is line/colon-delimited;
            // strip control chars so a pasted needle can't smuggle a second
            // action (e.g. a newline + `close_surface`). v0.4.3 review F2.
            let safe = needle.filter { !$0.isNewline && $0 != "\0" }
            view.runBindingActionForHarness("search:\(safe)")
        }
        searchNeedleSubscription = cancellable

        let overlay = NSHostingView(
            rootView: SearchOverlayView(
                state: state,
                onNext: { [weak self] in self?.findNext(nil) },
                onPrevious: { [weak self] in self?.findPrevious(nil) },
                onDismiss: { [weak self] in self?.dismissSearchOverlay(sendEnd: true) }
            )
        )
        overlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlay)
        searchOverlayHost = overlay
        needsLayout = true
    }

    private func dismissSearchOverlay(sendEnd: Bool) {
        if sendEnd, let view = searchOverlayTarget {
            view.runBindingActionForHarness("end_search")
        }
        searchNeedleSubscription?.cancel()
        searchNeedleSubscription = nil
        searchOverlayHost?.removeFromSuperview()
        searchOverlayHost = nil
        searchOverlayState = nil
        searchOverlayTarget = nil
        focusActivePane()
    }

    /// libghostty asked for a specific cursor shape over this
    /// surface. Forward to the matching HerminalSurfaceView; the view
    /// invalidates its cursor rect so AppKit re-resolves on next
    /// hover. (v0.2.5.)
    @objc func surfaceMouseShapeDidChange(_ note: Notification) {
        guard let view = note.object as? HerminalSurfaceView,
              let raw = note.userInfo?[GhosttyApp.surfaceMouseShapeKey] as? Int else { return }
        view.applyMouseShape(raw)
    }

    /// OSC 7 cwd report — forward to the matching pane so it tracks its
    /// live working directory. (v0.4-S1a foundation.)
    @objc func surfacePwdDidChange(_ note: Notification) {
        guard let view = note.object as? HerminalSurfaceView,
              let pwd = note.userInfo?[GhosttyApp.surfacePwdKey] as? String else { return }
        view.applyPwd(pwd)
        // The cwd feeds the tab label (when no program title is set) and
        // the status-bar path chip. Rebuild the tab strip so the label
        // tracks `cd` immediately; the status bar picks it up on its next
        // 1 Hz tick. (v0.4.4 live-cwd surfacing.)
        tabHost.rootView = makeTabBar()
        if leftSidebar == .agents {
            refreshWorktrees()
            refreshAgents()
        }
    }

    @objc func surfaceDidClose(_ note: Notification) {
        guard let view = note.object as? HerminalSurfaceView else { return }
        if view === searchOverlayTarget {
            dismissSearchOverlay(sendEnd: false)
        }
        // Locate the pane by identity.
        for (tabIndex, tab) in tabs.enumerated() {
            guard let pane = tab.panes.first(where: { $0.surfaceView === view }) else { continue }
            if NotesStoragePolicy.shouldRetainClosedSurface(
                recovery: notesPanelRecoveries[pane.id]
            ) {
                pane.markExited()
                activeTabIndex = tabIndex
                tab.focusPane(id: pane.id)
                let wasNotesVisible = isNotesVisible
                isNotesVisible = true
                refresh()
                persistSidebarState()
                if !wasNotesVisible { animateSidebarChange() }
                NSAccessibility.post(
                    element: notesHost,
                    notification: .announcementRequested,
                    userInfo: [
                        .announcement: NotesStoragePolicy.closedSurfaceRetentionAnnouncement,
                        .priority: NSAccessibilityPriorityLevel.high.rawValue
                    ]
                )
                return
            }
            // Drop the pane. If it was the last pane in the tab, the
            // whole tab disappears. Skip the note-confirm prompt — the
            // shell exited on its own, prompting the user "are you
            // sure?" right after they typed `exit` would be silly.
            tab.removePane(id: pane.id)
            Diary.shared.log("surfaceDidClose tab=\(tabIndex)", category: "panes")
            if tab.panes.isEmpty {
                closeTabImmediately(at: tabIndex)
            } else {
                refresh()
            }
            return
        }
    }

    @objc func preferencesDidChange() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        HerminalDesign.currentTheme = HerminalDesign.resolvedTheme(
            preference: Preferences.theme,
            systemIsDark: isDark
        )
        repaintChrome()
    }

    /// Pushes a fresh rootView into every SwiftUI host so design tokens
    /// re-evaluate against the current theme. AppKit-resolved colours
    /// (window background, surface container) also get refreshed.
    private func repaintChrome() {
        window?.backgroundColor = NSColor(HerminalDesign.Palette.surfaceBase)
        // Keep AppKit's own drawing — vibrancy material, titlebar text — on
        // the same theme as the palette. See HerminalDesign.nsAppearance.
        window?.appearance = HerminalDesign.nsAppearance
        surfaceContainer.layer?.backgroundColor = NSColor(HerminalDesign.Palette.paneGutter).cgColor
        tabHost.rootView = makeTabBar()
        if leftSidebar == .agents { refreshAgents() }
        if leftSidebar == .ssh { refreshSSHPanel() }
        if leftSidebar == .claude { refreshClaudePanel() }
        if isNotesVisible { updateNotesPanel() }
        // Rebuild the status bar so its background/text re-resolve against
        // the new theme tokens and so the visibility flag picks up the
        // latest showStatusBar preference. The probe closure is identical
        // so the timer keeps ticking.
        statusBarHost.rootView = StatusBarView(probe: { [weak self] in
            MainActor.assumeIsolated {
                self?.captureStatusSnapshot() ?? .empty
            }
        })
        statusBarHost.isHidden = !Preferences.showStatusBar
        needsLayout = true
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(selectTabByNumber(_:)) {
            if menuItem.tag == 9 { return tabCount > 0 }
            return menuItem.tag >= 1 && menuItem.tag <= tabCount
        }
        if menuItem.action == #selector(findNext(_:))
            || menuItem.action == #selector(findPrevious(_:)) {
            return Self.searchNavigationIsEnabled(
                hasOverlay: searchOverlayHost != nil,
                state: searchOverlayState
            )
        }
        if menuItem.action == #selector(toggleStatusBar(_:)) {
            menuItem.title = Self.statusBarMenuTitle(isVisible: Preferences.showStatusBar)
        }
        return true
    }

    nonisolated static func statusBarMenuTitle(isVisible: Bool) -> String {
        isVisible ? "Hide Status Bar" : "Show Status Bar"
    }

    @objc func toggleStatusBar(_ sender: Any?) {
        let isVisible = Preferences.toggleStatusBarVisibility()
        Diary.shared.log("\(isVisible ? "showed" : "hid") status bar", category: "ui")
    }

    @objc func toggleTheme(_ sender: Any?) {
        HerminalDesign.currentTheme = HerminalDesign.currentTheme == .dark ? .light : .dark
        // Refresh AppKit-resolved colours.
        window?.backgroundColor = NSColor(HerminalDesign.Palette.surfaceBase)
        surfaceContainer.layer?.backgroundColor = NSColor(HerminalDesign.Palette.paneGutter).cgColor
        // Rebuild all SwiftUI hosts so they pick up the new colour values.
        tabHost.rootView = makeTabBar()
        if leftSidebar == .agents { refreshAgents() }
        if leftSidebar == .ssh { refreshSSHPanel() }
        if leftSidebar == .claude { refreshClaudePanel() }
        if isNotesVisible { updateNotesPanel() }
        // Reset the dashboard if visible so the new palette lands now,
        // not on the next 2s poll.
        if leftSidebar == .agents {
            dashboardHost.rootView = makeAgentDashboard(agents: latestDisplayedAgents)
            refreshAgents()
        }
        Diary.shared.log("toggled to \(HerminalDesign.currentTheme.rawValue) theme",
                         category: "ui")
        needsLayout = true
    }

    /// Slides the sidebars to their new geometry instead of snapping. The
    /// `isHidden` flags are deferred until the slide finishes so panels
    /// don't pop out at the start of a hide.
    nonisolated static func shouldAnimateSidebarChange(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    private func animateSidebarChange() {
        guard Self.shouldAnimateSidebarChange(
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        ) else {
            isAnimatingLayout = false
            dashboardHost.isHidden = leftSidebar != .agents
            sshPanelHost.isHidden = leftSidebar != .ssh
            claudePanelHost.isHidden = leftSidebar != .claude
            notesHost.isHidden = !isNotesVisible
            needsLayout = true
            layoutSubtreeIfNeeded()
            return
        }

        // Make sure all panels are visible during the animation; the
        // completion handler restores the correct hidden state.
        dashboardHost.isHidden = false
        sshPanelHost.isHidden = false
        claudePanelHost.isHidden = false
        notesHost.isHidden = false
        isAnimatingLayout = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = HerminalDesign.Motion.normal
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.needsLayout = true
            self.layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self] in
            // The completion handler is Sendable; jump back to the main
            // actor before touching @MainActor-isolated state.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isAnimatingLayout = false
                self.dashboardHost.isHidden = self.leftSidebar != .agents
                self.sshPanelHost.isHidden = self.leftSidebar != .ssh
                self.claudePanelHost.isHidden = self.leftSidebar != .claude
                self.notesHost.isHidden = !self.isNotesVisible
            }
        })
    }

    @objc func exportNote(_ sender: Any?) {
        guard let session = activeTab?.focusedPane else { return }
        let note: Note
        if let recovery = notesPanelRecoveries[session.id] {
            note = Note(
                id: recovery.noteID ?? UUID(),
                sessionID: session.id,
                body: recovery.state.draft,
                createdAt: recovery.createdAt ?? Date(),
                updatedAt: Date()
            )
        } else {
            switch loadNoteResult(session.id) {
            case .success(let loadedNote):
                note = loadedNote ?? Note(sessionID: session.id)
            case .failure:
                return
            }
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "herminal-note.md"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try NotesExporter.exportMarkdown(note, to: url)
        } catch {
            Self.notesLog.error("note export failed: \(error, privacy: .private(mask: .hash))")
        }
    }

    @objc func importNote(_ sender: Any?) {
        guard let session = activeTab?.focusedPane else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let imported: Note
        do {
            imported = try NotesExporter.importMarkdown(from: url, sessionID: session.id)
        } catch {
            Self.notesLog.error("note import failed: \(error, privacy: .private(mask: .hash))")
            return
        }
        // Keep the existing note's identity; replace its body.
        let note: Note
        switch loadNoteResult(session.id) {
        case .success(let existingNote):
            note = existingNote ?? imported
        case .failure:
            return
        }
        let mergedNote = Note(
            id: note.id,
            sessionID: note.sessionID,
            body: imported.body,
            createdAt: note.createdAt,
            updatedAt: Date()
        )
        if persistNote(mergedNote) {
            var savedState = NotesPanelView.AutosaveState(draft: imported.body)
            savedState.saveDidSucceed()
            notesPanelRecoveries[session.id] = NotesPanelRecovery.retainingAtRisk(
                savedState,
                storageIsDurable: notesStorageIsDurable,
                noteID: mergedNote.id,
                createdAt: mergedNote.createdAt
            )
        } else {
            var failedState = NotesPanelView.AutosaveState(draft: imported.body)
            failedState.saveDidFail()
            notesPanelRecoveries[session.id] = NotesPanelRecovery.retainingAtRisk(
                failedState,
                storageIsDurable: notesStorageIsDurable,
                noteID: mergedNote.id,
                createdAt: mergedNote.createdAt
            )
            announceNoteSaveFailure()
        }
        if isNotesVisible { updateNotesPanel() }
    }

    // MARK: - Refresh

    private func refresh(_ focusPolicy: RefreshFocusPolicy = .activePane) {
        pruneNotesPanelRecoveries()
        surfaceContainer.subviews.forEach { $0.removeFromSuperview() }
        if let tab = activeTab {
            for pane in tab.panes {
                surfaceContainer.addSubview(pane.surfaceView)
            }
        }
        layoutPanes()
        if focusPolicy.focusesActivePane {
            focusActivePane()
        }
        tabHost.rootView = makeTabBar(initialFocusTarget: focusPolicy.tabBarTarget)
        updateNotesPanel()
        needsLayout = true
    }

    private func focusActivePane() {
        tabBarFocusRetention.clear()
        window?.makeFirstResponder(activeTab?.focusedPane.surfaceView)
    }

    /// Test-harness entry point: send raw text to the active pane's surface
    /// without going through the keyboard.
    func injectTextIntoActivePane(_ text: String) {
        activeTab?.focusedPane.surfaceView.injectText(text)
    }

    /// Test-harness entry point: trigger a libghostty binding action
    /// (e.g. `copy_to_clipboard`, `select_all`, `paste_from_clipboard`)
    /// on the active pane's surface. Used by the regression-guard
    /// clipboard smoke so we can verify the round-trip without
    /// synthesizing mouse events at exact pixel coordinates.
    /// (v0.2.2 follow-up — bake the lesson.)
    func triggerBindingActionOnActivePane(_ action: String) {
        activeTab?.focusedPane.surfaceView.runBindingActionForHarness(action)
    }

    /// True iff the active pane's surface currently has a selection
    /// libghostty would copy. Harness-only — production code reads
    /// this via NSUserInterfaceValidations.
    func activePaneHasSelection() -> Bool {
        activeTab?.focusedPane.surfaceView.hasSelectionForHarness() ?? false
    }

    /// Test-harness diagnostic: snapshots the workspace's interactive state
    /// as plain text — used by `Scripts/verify-smoke-m1-m3.sh` to assert
    /// menu actions and sidebar toggles actually take effect.
    func dumpState() -> String {
        let sidebar: String = {
            switch leftSidebar {
            case .none: return "none"
            case .agents: return "agents"
            case .ssh: return "ssh"
            case .claude: return "claude"
            }
        }()
        let paneCounts = tabs.map { String($0.panes.count) }.joined(separator: ",")
        // Report the root split's axis; a lone-leaf tab has no axis, so
        // keep the pre-v0.5 default ("vertical") the smoke harness expects.
        let axis: String = {
            guard let root = activeTab?.root else { return "n/a" }
            if case let .split(info) = root {
                return info.axis == .vertical ? "vertical" : "horizontal"
            }
            return "vertical"
        }()
        let focused = activeTab?.focusedPaneIndex ?? -1
        return """
        tabs=\(tabs.count)
        active_tab=\(activeTabIndex)
        active_title=\(activeTab?.title ?? "<none>")
        panes_per_tab=\(paneCounts)
        active_split_axis=\(axis)
        focused_pane=\(focused)
        left_sidebar=\(sidebar)
        notes_visible=\(isNotesVisible)
        """
    }

    private func makeTabBar(
        initialFocusTarget: TabBarView.FocusTarget? = nil
    ) -> TabBarView {
        let generation = tabBarFocusRetention.beginRebuild(
            requestedTarget: initialFocusTarget
        )
        return TabBarView(
            tabs: tabs.map { TabBarView.Tab(id: $0.id, title: $0.title) },
            activeID: activeTab?.id,
            leadingInset: trafficLightInset,
            initialFocusTarget: tabBarFocusRetention.target,
            onFocusChange: { [weak self] target, isFocused in
                self?.tabBarFocusRetention.focusDidChange(
                    target,
                    isFocused: isFocused,
                    generation: generation
                )
            },
            onSelect: { [weak self] id in self?.selectTab(id: id) },
            onClose: { [weak self] id in self?.closeTab(id: id) },
            onNew: { [weak self] in self?.addTabFromTabBar() }
        )
    }
}
