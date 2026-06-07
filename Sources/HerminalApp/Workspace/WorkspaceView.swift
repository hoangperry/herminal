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
    private static let dashboardWidth: CGFloat = 220
    private static let sshPanelWidth: CGFloat = 280
    private static let claudePanelWidth: CGFloat = 300
    private static let notesWidth: CGFloat = 280

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
    private let sshHostsStore: SSHHostsStore
    private let agentStatusTracker = AgentStatusTracker()
    private var tabs: [WorkspaceTab] = []
    private var activeTabIndex = 0

    private let tabHost: NSHostingView<TabBarView>
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
    /// Per-pane ⌘F search overlay state. Lives across show/hide so a
    /// re-open restores the last needle (matches Safari + Chrome
    /// muscle memory). The host is nil'd when search ends. (v0.3.2.)
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
    /// Gates session-restore persistence. False during init + restore so
    /// the default/launch tab churn doesn't clobber the saved snapshot;
    /// AppDelegate flips it true once the launch decision is made.
    /// (v0.4.1.)
    private var sessionPersistenceEnabled = false

    init(app: ghostty_app_t, notesStore: NotesStore, sshHostsStore: SSHHostsStore) {
        self.app = app
        self.notesStore = notesStore
        self.sshHostsStore = sshHostsStore
        self.surfaceContainer = NSView(frame: .zero)
        self.tabHost = NSHostingView(rootView: TabBarView(
            tabs: [], activeID: nil,
            onSelect: { _ in }, onClose: { _ in }, onNew: {}
        ))
        self.dashboardHost = NSHostingView(rootView: AgentDashboardView(agents: []))
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
        surfaceContainer.layer?.backgroundColor = NSColor(HerminalDesign.Palette.border).cgColor
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
            focusActivePane()
            showWelcomeOverlayIfNeeded()
        }
    }

    // MARK: - Layout

    /// True only inside the brief animation window opened by a sidebar
    /// toggle — `layout()` switches to the animator proxy in this case so
    /// the slide is smooth instead of snapping.
    private var isAnimatingLayout = false

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

        // Sidebars + status bar share the full window height — sidebars
        // sit ABOVE the status strip so the strip spans the full width
        // (uniform across content + sidebars, like Xcode's bottom bar).
        let sidebarTop = bounds.height
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
        tabHost.frame = CGRect(
            x: contentX, y: bounds.height - barHeight,
            width: contentWidth, height: barHeight
        )
        let surfaceHeight = max(bounds.height - barHeight - statusHeight, 0)
        // v0.3 polish: 6 px inset between the libghostty Metal surface
        // and the pane chrome. Without it the text sits flush against
        // the window edge and the app reads as cheap. Inset is applied
        // here (not inside the surface itself) so the divider colour of
        // `surfaceContainer.layer.backgroundColor` shows through and
        // doubles as the visual frame.
        let inset = HerminalDesign.Geometry.surfaceInset
        surfaceContainer.frame = CGRect(
            x: contentX + inset,
            y: statusHeight + inset,
            width: max(contentWidth - inset * 2, 0),
            height: max(surfaceHeight - inset * 2, 0)
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
        let bounds = surfaceContainer.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
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
            tab.surfaceView(for: id)?.frame = rect
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
            divider.frame = spec.rect
            divider.onDrag = { [weak self] delta in
                self?.resizeSplit(spec.id, byPointDelta: delta, isVertical: spec.isVertical)
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

    // MARK: - Tab management

    func addTab() {
        // Open the new tab in the focused pane's directory (OSC 7), the way
        // Terminal.app / iTerm2 do — `⌘T` from ~/proj lands in ~/proj, not
        // home. nil (no cwd reported yet) falls back to the shell default.
        let inheritedCwd = activeTab?.focusedPane.surfaceView.currentWorkingDirectory
        tabs.append(WorkspaceTab(app: app, workingDirectory: inheritedCwd))
        activeTabIndex = tabs.count - 1
        Diary.shared.log("addTab — total=\(tabs.count)", category: "tabs")
        refresh()
        persistWorkspaceIfReady()
    }

    /// Opens a new tab that runs `command` instead of the default shell.
    /// Used by the SSH manager to spawn `ssh user@host` in a fresh pane,
    /// and the Claude session browser to spawn `claude --resume <id>` in
    /// the session's working directory.
    func addTab(command: String, title: String, workingDirectory: String? = nil) {
        tabs.append(WorkspaceTab(
            app: app, command: command, title: title, workingDirectory: workingDirectory
        ))
        activeTabIndex = tabs.count - 1
        Diary.shared.log("addTab command=\(command) title=\(title) cwd=\(workingDirectory ?? "-")", category: "tabs")
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
        refresh()
    }

    private func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let sessionIDs = tabs[index].panes.map { $0.id }
        // Confirmation can re-enter the run loop (NSAlert.runModal blocks
        // on the main thread but services menu items + key events).
        // Re-derive the live index by UUID AFTER the modal returns so we
        // don't close the wrong tab if `tabs` mutated underneath us.
        // (M12 review HIGH — security-reviewer finding 1.)
        guard confirmCloseIfNoteExists(forSessionIDs: sessionIDs) else { return }
        guard let liveIndex = tabs.firstIndex(where: { $0.id == id }) else { return }
        closeTabImmediately(at: liveIndex)
    }

    /// Removes the tab at `index` without prompting — internal helper for
    /// callers that have already done the M12-P4 note-confirmation check
    /// (e.g. `closeActivePane()` after it knows the tab will collapse).
    private func closeTabImmediately(at index: Int) {
        tabs.remove(at: index)
        if tabs.isEmpty {
            // Don't persist an empty workspace — the window is closing.
            // The last non-empty snapshot stays on disk for next launch.
            window?.close()
            return
        }
        activeTabIndex = min(activeTabIndex, tabs.count - 1)
        refresh()
        persistWorkspaceIfReady()
    }

    /// Returns true if it's safe to proceed with closing the panes
    /// identified by `sessionIDs`. Shows a blocking NSAlert when (a) the
    /// user has the confirmation preference enabled AND (b) at least
    /// one of those sessions has a non-empty note body. (M12-P4 +
    /// M12-review HIGH fix — signature now takes IDs instead of a whole
    /// `WorkspaceTab` so single-pane closes inside a multi-pane tab
    /// also benefit from the safety check.)
    ///
    /// Why NSAlert (not a SwiftUI sheet): the surface we'd attach the
    /// sheet to is the focused libghostty NSView, which doesn't host a
    /// SwiftUI environment. `NSAlert.runModal()` re-enters the main run
    /// loop while it's up — callers MUST re-derive any positional state
    /// (tab indices) after this method returns true.
    private func confirmCloseIfNoteExists(forSessionIDs sessionIDs: [UUID]) -> Bool {
        guard Preferences.confirmCloseWithNote else { return true }
        let hasNote = sessionIDs.contains { sessionID in
            guard let body = loadNote(sessionID)?.body else { return false }
            return !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard hasNote else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close pane with notes?"
        alert.informativeText = "This pane has notes attached. Closing it does not delete them from disk, but you won't see them in the UI again — the session ID is single-use."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }

    // MARK: - Split / pane management

    /// Splits the active pane. If it is the only pane in the tab it also sets
    /// the tab's split axis.
    func splitActivePane(vertical: Bool) {
        activeTab?.split(app: app, vertical: vertical)
        Diary.shared.log("splitActivePane vertical=\(vertical)", category: "panes")
        refresh()
        persistWorkspaceIfReady()
    }

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
        guard confirmCloseIfNoteExists(forSessionIDs: [focusedID]) else { return }
        if tab.closeFocusedPane() {
            Diary.shared.log("closeActivePane → tab \(tab.id) empty, closing tab", category: "panes")
            guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
            closeTabImmediately(at: index)
        } else {
            Diary.shared.log("closeActivePane remaining=\(tab.panes.count)", category: "panes")
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

    private func refreshAgents() {
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
        let anyBell = !bellAddresses.isEmpty

        // M9/A3: ask the mapper for tab indices. Session creation order =
        // tab order in the current single-axis layout.
        let sessionStarts = tabs.flatMap { $0.panes.map { $0.createdAt } }
        let mapped = AgentPaneMapper.annotate(annotated,
                                              sessionStartTimes: sessionStarts)

        let final: [DetectedAgent] = mapped.map { agent in
            guard anyBell else { return agent }
            guard agent.status == .idle || agent.status == .running else { return agent }
            return DetectedAgent(
                id: agent.pid, kind: agent.kind,
                processName: agent.processName,
                status: .needsInput,
                tabHint: agent.tabHint
            )
        }
        dashboardHost.rootView = AgentDashboardView(agents: final)
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
        let cwd = surface?.currentWorkingDirectory.map { PathLabel.abbreviateHome($0) }
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
        overlay.removeFromSuperview()
        welcomeOverlay = nil
        Preferences.markFirstRunCompleted()
        Diary.shared.log("welcome overlay dismissed", category: "ui")
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

    private func refreshClaudePanel() {
        // Scanning ~/.claude/projects (a dir stat + 16 KB read per project)
        // is filesystem I/O — keep it off the main thread so a user with
        // hundreds of projects doesn't see the sidebar jank on open / theme
        // change / prefs change. Hop back to MainActor to swap the view.
        // (v0.4.3 review HIGH-4.)
        Task { [weak self] in
            let sessions = await Task.detached(priority: .utility) {
                ClaudeSessionStore.recentProjects()
            }.value
            guard let self else { return }
            self.claudePanelHost.rootView = AnyView(
                ClaudeSessionsPanel(
                    sessions: sessions,
                    onResume: { [weak self] session in self?.resumeClaude(session) },
                    onOpenShell: { [weak self] session in self?.openShell(in: session.cwd, title: session.projectName) },
                    onRefresh: { [weak self] in self?.refreshClaudePanel() }
                )
            )
        }
    }

    /// Opens a tab that resumes the project's newest Claude conversation
    /// in its real cwd. `claude --resume <id>` reattaches the exact
    /// session; the working directory is set on the libghostty surface
    /// so relative paths in the conversation still resolve.
    private func resumeClaude(_ session: ClaudeProjectSession) {
        Diary.shared.log("resume claude \(session.projectName) session=\(session.sessionId)", category: "claude")
        addTab(
            command: "claude --resume \(session.sessionId)",
            title: session.projectName,
            workingDirectory: session.cwd
        )
    }

    /// Opens a plain login shell already cd'd into `cwd`.
    private func openShell(in cwd: String, title: String) {
        Diary.shared.log("open shell in \(cwd)", category: "claude")
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
            Self.sshLog.error("hosts load failed: \(error, privacy: .public)")
            return []
        }
    }

    private func refreshSSHPanel() {
        let hosts = loadHosts()
        sshPanelHost.rootView = AnyView(
            SSHHostsPanel(
                hosts: hosts,
                onConnect: { [weak self] host in self?.connectSSH(host) },
                onSave: { [weak self] host in self?.saveSSHHost(host) },
                onDelete: { [weak self] id in self?.deleteSSHHost(id: id) }
            )
        )
    }

    private func saveSSHHost(_ host: SSHHost) {
        do {
            try sshHostsStore.upsert(host)
        } catch {
            Self.sshLog.error("host save failed: \(error, privacy: .public)")
        }
        refreshSSHPanel()
    }

    private func deleteSSHHost(id: UUID) {
        do {
            try sshHostsStore.delete(id: id)
        } catch {
            Self.sshLog.error("host delete failed: \(error, privacy: .public)")
        }
        refreshSSHPanel()
    }

    /// M9/B: pull every concrete Host block from `~/.ssh/config` and
    /// upsert them as SSHHost rows. Conflicts with existing rows are
    /// resolved by generating fresh UUIDs (additive merge — no row
    /// is silently rewritten). Errors land in the diary; success
    /// updates the count and refreshes the panel.
    @objc func importSSHConfig(_ sender: Any?) {
        do {
            let imported = try SSHConfigImporter.parseHosts()
            for host in imported {
                try sshHostsStore.upsert(host)
            }
            Diary.shared.log("imported \(imported.count) ssh hosts from ~/.ssh/config",
                             category: "ssh")
            // Pop the panel open so the user sees the result immediately.
            if leftSidebar != .ssh {
                leftSidebar = .ssh
                animateSidebarChange()
            } else {
                refreshSSHPanel()
            }
        } catch SSHConfigImporter.ImportError.fileMissing(let path) {
            Diary.shared.log("ssh config not found at \(path)", category: "ssh")
            Self.sshLog.info("ssh config not found at \(path, privacy: .public)")
        } catch {
            Diary.shared.log("ssh config import failed: \(error)", category: "ssh")
            Self.sshLog.error("ssh config import failed: \(error, privacy: .public)")
        }
    }

    /// Opens a new tab that spawns `ssh` into the saved host, stamps the
    /// last-connected time, and refreshes the panel so the recency badge
    /// updates immediately.
    private func connectSSH(_ host: SSHHost) {
        let command = Self.sshCommand(for: host)
        Self.sshLog.info("opening ssh tab: \(command, privacy: .public)")
        Diary.shared.log("ssh connect \(host.nickname) (\(host.user)@\(host.hostname):\(host.port))",
                         category: "ssh")
        addTab(command: command, title: host.nickname)
        do {
            try sshHostsStore.touchLastConnected(id: host.id)
        } catch {
            Self.sshLog.error("last-connected stamp failed: \(error, privacy: .public)")
            Diary.shared.log("ssh last-connected stamp failed: \(error)", category: "ssh")
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

    /// Single-quote a shell argument, escaping any embedded single quotes.
    private static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    // MARK: - Notes

    private static let notesLog = Logger(
        subsystem: "com.hoangperry.herminal", category: "notes"
    )

    /// Loads a session's note, logging (not swallowing) any storage error.
    private func loadNote(_ sessionID: UUID) -> Note? {
        do {
            return try notesStore.note(forSession: sessionID)
        } catch {
            Self.notesLog.error("note load failed: \(error, privacy: .public)")
            return nil
        }
    }

    /// Persists a note, logging any storage error.
    private func persistNote(_ note: Note) {
        do {
            try notesStore.upsert(note)
        } catch {
            Self.notesLog.error("note save failed: \(error, privacy: .public)")
        }
    }

    /// Loads the active session's note into the notes panel.
    private func updateNotesPanel() {
        guard isNotesVisible, let session = activeTab?.focusedPane else { return }
        let sessionID = session.id
        let body = loadNote(sessionID)?.body ?? ""
        let title = activeTab?.title ?? "herminal"
        notesHost.rootView = AnyView(
            NotesPanelView(sessionTitle: title, initialText: body) { [weak self] newText in
                self?.saveNote(sessionID: sessionID, body: newText)
            }
            .id(sessionID)
        )
    }

    private func saveNote(sessionID: UUID, body: String) {
        var note = loadNote(sessionID) ?? Note(sessionID: sessionID)
        note.body = body
        note.updatedAt = Date()
        persistNote(note)
    }

    // MARK: - Menu actions

    @objc func newTab(_ sender: Any?) { addTab() }
    @objc func closeTab(_ sender: Any?) { closeActivePane() }
    @objc func nextTab(_ sender: Any?) { selectNextTab() }
    @objc func previousTab(_ sender: Any?) { selectPreviousTab() }

    @objc func increaseFontSize(_ sender: Any?) { applyFontAction("increase_font_size:1") }
    @objc func decreaseFontSize(_ sender: Any?) { applyFontAction("decrease_font_size:1") }
    @objc func resetFontSize(_ sender: Any?) { applyFontAction("reset_font_size") }

    /// Live font-size adjust via libghostty's own binding actions, applied
    /// to every surface so the whole window scales together (the Settings
    /// slider sets the default for new panes). (v1.0.)
    private func applyFontAction(_ action: String) {
        for tab in tabs {
            for pane in tab.panes {
                pane.surfaceView.runBindingActionForHarness(action)
            }
        }
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
        if leftSidebar == .agents { refreshAgents() }
        persistSidebarState()
        animateSidebarChange()
    }

    @objc func toggleSSHHosts(_ sender: Any?) {
        leftSidebar = (leftSidebar == .ssh) ? .none : .ssh
        if leftSidebar == .ssh { refreshSSHPanel() }
        persistSidebarState()
        animateSidebarChange()
    }

    @objc func toggleClaudeSessions(_ sender: Any?) {
        leftSidebar = (leftSidebar == .claude) ? .none : .claude
        if leftSidebar == .claude { refreshClaudePanel() }
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
        if leftSidebar == .agents { refreshAgents() }
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
        tabs = snapshot.tabs.map { WorkspaceTab(app: app, restoring: $0, rerunCommands: rerun) }
        activeTabIndex = min(max(snapshot.activeTabIndex, 0), tabs.count - 1)
        Diary.shared.log("restored \(tabs.count) tab(s) from snapshot", category: "session")
        refresh()
        return true
    }

    /// Snapshots the whole workspace for persistence.
    func snapshotWorkspace() -> WorkspaceSnapshot {
        WorkspaceSnapshot(
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
    /// here from AppMenu items. Only fires when an overlay is up.
    @objc func findNext(_ sender: Any?) {
        guard searchOverlayHost != nil else { return }
        activeTab?.focusedPane.surfaceView.runBindingActionForHarness("navigate_search:next")
    }

    @objc func findPrevious(_ sender: Any?) {
        guard searchOverlayHost != nil else { return }
        activeTab?.focusedPane.surfaceView.runBindingActionForHarness("navigate_search:previous")
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
        if let existing = searchOverlayHost, searchOverlayTarget === view {
            existing.window?.makeFirstResponder(existing)
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
    }

    @objc func surfaceDidClose(_ note: Notification) {
        guard let view = note.object as? HerminalSurfaceView else { return }
        // Locate the pane by identity.
        for (tabIndex, tab) in tabs.enumerated() {
            guard let pane = tab.panes.first(where: { $0.surfaceView === view }) else { continue }
            // Drop the pane. If it was the last pane in the tab, the
            // whole tab disappears. Skip the note-confirm prompt — the
            // shell exited on its own, prompting the user "are you
            // sure?" right after they typed `exit` would be silly.
            tab.removePane(id: pane.id)
            Diary.shared.log("surfaceDidClose tab=\(tabIndex) pane=\(pane.id)", category: "panes")
            if tab.panes.isEmpty {
                closeTabImmediately(at: tabIndex)
            } else {
                refresh()
            }
            return
        }
    }

    @objc func preferencesDidChange() {
        switch Preferences.theme {
        case .dark: HerminalDesign.currentTheme = .dark
        case .light: HerminalDesign.currentTheme = .light
        case .system:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            HerminalDesign.currentTheme = isDark ? .dark : .light
        }
        repaintChrome()
    }

    /// Pushes a fresh rootView into every SwiftUI host so design tokens
    /// re-evaluate against the current theme. AppKit-resolved colours
    /// (window background, surface container) also get refreshed.
    private func repaintChrome() {
        window?.backgroundColor = NSColor(HerminalDesign.Palette.surfaceBase)
        surfaceContainer.layer?.backgroundColor = NSColor(HerminalDesign.Palette.border).cgColor
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

    @objc func toggleTheme(_ sender: Any?) {
        HerminalDesign.currentTheme = HerminalDesign.currentTheme == .dark ? .light : .dark
        // Refresh AppKit-resolved colours.
        window?.backgroundColor = NSColor(HerminalDesign.Palette.surfaceBase)
        surfaceContainer.layer?.backgroundColor = NSColor(HerminalDesign.Palette.border).cgColor
        // Rebuild all SwiftUI hosts so they pick up the new colour values.
        tabHost.rootView = makeTabBar()
        if leftSidebar == .agents { refreshAgents() }
        if leftSidebar == .ssh { refreshSSHPanel() }
        if leftSidebar == .claude { refreshClaudePanel() }
        if isNotesVisible { updateNotesPanel() }
        // Reset the dashboard if visible so the new palette lands now,
        // not on the next 2s poll.
        if leftSidebar == .agents {
            dashboardHost.rootView = AgentDashboardView(agents: [])
            refreshAgents()
        }
        Diary.shared.log("toggled to \(HerminalDesign.currentTheme.rawValue) theme",
                         category: "ui")
        needsLayout = true
    }

    /// Slides the sidebars to their new geometry instead of snapping. The
    /// `isHidden` flags are deferred until the slide finishes so panels
    /// don't pop out at the start of a hide.
    private func animateSidebarChange() {
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
        let note = loadNote(session.id) ?? Note(sessionID: session.id)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "herminal-note.md"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try NotesExporter.exportMarkdown(note, to: url)
        } catch {
            Self.notesLog.error("note export failed: \(error, privacy: .public)")
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
            Self.notesLog.error("note import failed: \(error, privacy: .public)")
            return
        }
        // Keep the existing note's identity; replace its body.
        var note = loadNote(session.id) ?? imported
        note.body = imported.body
        note.updatedAt = Date()
        persistNote(note)
        if isNotesVisible { updateNotesPanel() }
    }

    // MARK: - Refresh

    private func refresh() {
        surfaceContainer.subviews.forEach { $0.removeFromSuperview() }
        if let tab = activeTab {
            for pane in tab.panes {
                surfaceContainer.addSubview(pane.surfaceView)
            }
        }
        layoutPanes()
        focusActivePane()
        tabHost.rootView = makeTabBar()
        updateNotesPanel()
        needsLayout = true
    }

    private func focusActivePane() {
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

    private func makeTabBar() -> TabBarView {
        TabBarView(
            tabs: tabs.map { TabBarView.Tab(id: $0.id, title: $0.title) },
            activeID: activeTab?.id,
            onSelect: { [weak self] id in self?.selectTab(id: id) },
            onClose: { [weak self] id in self?.closeTab(id: id) },
            onNew: { [weak self] in self?.addTab() }
        )
    }
}
