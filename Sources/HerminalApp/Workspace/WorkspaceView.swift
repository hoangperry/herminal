// WorkspaceView — the window's root content view.
// Owns the tabs, hosts the SwiftUI tab strip + agent dashboard (left) + notes
// panel (right), and lays out the active tab's panes (manual split, Q2-002).

import AppKit
import SwiftUI
import GhosttyKit
import HerminalAgent
import HerminalDB
import os

final class WorkspaceView: NSView {
    /// Hairline gap between panes; the dark container shows through as a divider.
    private static let paneGap: CGFloat = 1
    private static let dashboardWidth: CGFloat = 220
    private static let sshPanelWidth: CGFloat = 280
    private static let notesWidth: CGFloat = 280

    /// At most one widget occupies the left sidebar — agents and SSH share
    /// the slot so the surface always gets the maximum content width.
    private enum LeftSidebar {
        case none
        case agents
        case ssh
    }

    private let app: ghostty_app_t
    private let notesStore: NotesStore
    private let sshHostsStore: SSHHostsStore
    private var tabs: [WorkspaceTab] = []
    private var activeTabIndex = 0

    private let tabHost: NSHostingView<TabBarView>
    private let surfaceContainer: NSView
    private let dashboardHost: NSHostingView<AgentDashboardView>
    private let sshPanelHost: NSHostingView<AnyView>
    private let notesHost: NSHostingView<AnyView>
    private var leftSidebar: LeftSidebar = .none
    private var isNotesVisible = false
    // nonisolated(unsafe): invalidated in the nonisolated deinit.
    private nonisolated(unsafe) var agentPollTimer: Timer?

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
        self.notesHost = NSHostingView(rootView: AnyView(EmptyView()))
        super.init(frame: NSRect(x: 0, y: 0, width: 900, height: 560))

        // The container's dark fill shows between panes as a divider.
        surfaceContainer.wantsLayer = true
        surfaceContainer.layer?.backgroundColor = NSColor(HerminalDesign.Palette.border).cgColor
        dashboardHost.isHidden = true
        sshPanelHost.isHidden = true
        notesHost.isHidden = true

        addSubview(surfaceContainer)
        addSubview(tabHost)
        addSubview(dashboardHost)
        addSubview(sshPanelHost)
        addSubview(notesHost)
        addTab()
        startAgentPolling()
    }

    required init?(coder: NSCoder) {
        fatalError("WorkspaceView does not support NSCoder")
    }

    deinit {
        agentPollTimer?.invalidate()
    }

    private var activeTab: WorkspaceTab? {
        tabs.indices.contains(activeTabIndex) ? tabs[activeTabIndex] : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { focusActivePane() }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        let barHeight = TabBarView.barHeight
        let leftWidth: CGFloat = {
            switch leftSidebar {
            case .none: return 0
            case .agents: return Self.dashboardWidth
            case .ssh: return Self.sshPanelWidth
            }
        }()
        let rightSidebar = isNotesVisible ? Self.notesWidth : 0

        dashboardHost.frame = CGRect(x: 0, y: 0, width: leftWidth, height: bounds.height)
        dashboardHost.isHidden = leftSidebar != .agents

        sshPanelHost.frame = CGRect(x: 0, y: 0, width: leftWidth, height: bounds.height)
        sshPanelHost.isHidden = leftSidebar != .ssh

        notesHost.frame = CGRect(
            x: bounds.width - rightSidebar, y: 0,
            width: rightSidebar, height: bounds.height
        )
        notesHost.isHidden = !isNotesVisible

        let contentX = leftWidth
        let contentWidth = max(bounds.width - leftWidth - rightSidebar, 0)
        tabHost.frame = CGRect(
            x: contentX, y: bounds.height - barHeight,
            width: contentWidth, height: barHeight
        )
        surfaceContainer.frame = CGRect(
            x: contentX, y: 0,
            width: contentWidth, height: max(bounds.height - barHeight, 0)
        )
        layoutPanes()
    }

    /// Lays out the active tab's pane surfaces inside the container — evenly
    /// split along the tab's axis, separated by a hairline gap.
    private func layoutPanes() {
        guard let tab = activeTab else { return }
        let bounds = surfaceContainer.bounds
        let panes = tab.panes
        let count = panes.count
        guard count > 0 else { return }

        if count == 1 {
            panes[0].surfaceView.frame = bounds
            return
        }

        let gap = Self.paneGap
        if tab.isVerticalSplit {
            // Side by side, left to right.
            let paneWidth = (bounds.width - gap * CGFloat(count - 1)) / CGFloat(count)
            for (index, pane) in panes.enumerated() {
                pane.surfaceView.frame = CGRect(
                    x: CGFloat(index) * (paneWidth + gap), y: 0,
                    width: paneWidth, height: bounds.height
                )
            }
        } else {
            // Stacked; pane 0 sits at the top (NSView origin is bottom-left).
            let paneHeight = (bounds.height - gap * CGFloat(count - 1)) / CGFloat(count)
            for (index, pane) in panes.enumerated() {
                pane.surfaceView.frame = CGRect(
                    x: 0,
                    y: bounds.height - CGFloat(index + 1) * paneHeight - CGFloat(index) * gap,
                    width: bounds.width, height: paneHeight
                )
            }
        }
    }

    // MARK: - Tab management

    func addTab() {
        tabs.append(WorkspaceTab(app: app))
        activeTabIndex = tabs.count - 1
        refresh()
    }

    /// Opens a new tab that runs `command` instead of the default shell.
    /// Used by the SSH manager to spawn `ssh user@host` in a fresh pane.
    func addTab(command: String, title: String) {
        tabs.append(WorkspaceTab(app: app, command: command, title: title))
        activeTabIndex = tabs.count - 1
        refresh()
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
        tabs.remove(at: index)
        if tabs.isEmpty {
            window?.close()
            return
        }
        activeTabIndex = min(activeTabIndex, tabs.count - 1)
        refresh()
    }

    // MARK: - Split / pane management

    /// Splits the active pane. If it is the only pane in the tab it also sets
    /// the tab's split axis.
    func splitActivePane(vertical: Bool) {
        activeTab?.split(app: app, vertical: vertical)
        refresh()
    }

    /// Closes the focused pane — or the whole tab if it was the last pane.
    func closeActivePane() {
        guard let tab = activeTab else { return }
        if tab.closeFocusedPane() {
            closeTab(id: tab.id)
        } else {
            refresh()
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
        guard leftSidebar == .agents else { return }
        dashboardHost.rootView = AgentDashboardView(agents: AgentDetector.detectAgents())
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

    /// Opens a new tab that spawns `ssh` into the saved host, stamps the
    /// last-connected time, and refreshes the panel so the recency badge
    /// updates immediately.
    private func connectSSH(_ host: SSHHost) {
        let command = Self.sshCommand(for: host)
        Self.sshLog.info("opening ssh tab: \(command, privacy: .public)")
        addTab(command: command, title: host.nickname)
        do {
            try sshHostsStore.touchLastConnected(id: host.id)
        } catch {
            Self.sshLog.error("last-connected stamp failed: \(error, privacy: .public)")
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
    @objc func splitPaneVertical(_ sender: Any?) { splitActivePane(vertical: true) }
    @objc func splitPaneHorizontal(_ sender: Any?) { splitActivePane(vertical: false) }

    @objc func toggleAgentDashboard(_ sender: Any?) {
        leftSidebar = (leftSidebar == .agents) ? .none : .agents
        if leftSidebar == .agents { refreshAgents() }
        needsLayout = true
    }

    @objc func toggleSSHHosts(_ sender: Any?) {
        leftSidebar = (leftSidebar == .ssh) ? .none : .ssh
        if leftSidebar == .ssh { refreshSSHPanel() }
        needsLayout = true
    }

    @objc func toggleNotes(_ sender: Any?) {
        isNotesVisible.toggle()
        if isNotesVisible { updateNotesPanel() }
        needsLayout = true
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
