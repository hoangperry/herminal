// WorkspaceView — the window's root content view.
// Owns the terminal sessions, hosts the SwiftUI tab strip, and shows the
// active session's surface. One window = one workspace = many tabs.

import AppKit
import SwiftUI
import GhosttyKit

final class WorkspaceView: NSView {
    private let app: ghostty_app_t
    private var sessions: [TerminalSession] = []
    private var activeIndex = 0

    private let tabHost: NSHostingView<TabBarView>
    private let surfaceContainer: NSView

    init(app: ghostty_app_t) {
        self.app = app
        self.surfaceContainer = NSView(frame: .zero)
        self.tabHost = NSHostingView(rootView: TabBarView(
            tabs: [], activeID: nil,
            onSelect: { _ in }, onClose: { _ in }, onNew: {}
        ))
        super.init(frame: NSRect(x: 0, y: 0, width: 900, height: 560))

        addSubview(surfaceContainer)
        addSubview(tabHost)
        addSession()
    }

    required init?(coder: NSCoder) {
        fatalError("WorkspaceView does not support NSCoder")
    }

    private var activeSession: TerminalSession? {
        sessions.indices.contains(activeIndex) ? sessions[activeIndex] : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(activeSession?.surfaceView)
        }
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        let barHeight = TabBarView.barHeight
        tabHost.frame = CGRect(
            x: 0, y: bounds.height - barHeight,
            width: bounds.width, height: barHeight
        )
        surfaceContainer.frame = CGRect(
            x: 0, y: 0,
            width: bounds.width, height: max(bounds.height - barHeight, 0)
        )
        activeSession?.surfaceView.frame = surfaceContainer.bounds
    }

    // MARK: - Session management

    func addSession() {
        sessions.append(TerminalSession(app: app))
        activeIndex = sessions.count - 1
        refresh()
    }

    func closeActiveSession() {
        guard let active = activeSession else { return }
        closeSession(id: active.id)
    }

    func selectNextSession() {
        guard !sessions.isEmpty else { return }
        activeIndex = (activeIndex + 1) % sessions.count
        refresh()
    }

    func selectPreviousSession() {
        guard !sessions.isEmpty else { return }
        activeIndex = (activeIndex - 1 + sessions.count) % sessions.count
        refresh()
    }

    private func selectSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        activeIndex = index
        refresh()
    }

    private func closeSession(id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions.remove(at: index)
        if sessions.isEmpty {
            window?.close()
            return
        }
        activeIndex = min(activeIndex, sessions.count - 1)
        refresh()
    }

    // MARK: - Menu actions

    @objc func newTab(_ sender: Any?) { addSession() }
    @objc func closeTab(_ sender: Any?) { closeActiveSession() }
    @objc func nextTab(_ sender: Any?) { selectNextSession() }
    @objc func previousTab(_ sender: Any?) { selectPreviousSession() }

    // MARK: - Refresh

    private func refresh() {
        // Swap the visible surface to the active session.
        surfaceContainer.subviews.forEach { $0.removeFromSuperview() }
        if let active = activeSession {
            active.surfaceView.frame = surfaceContainer.bounds
            active.surfaceView.autoresizingMask = [.width, .height]
            surfaceContainer.addSubview(active.surfaceView)
            window?.makeFirstResponder(active.surfaceView)
        }
        // Rebuild the tab strip from current sessions.
        tabHost.rootView = makeTabBar()
        needsLayout = true
    }

    private func makeTabBar() -> TabBarView {
        TabBarView(
            tabs: sessions.map { TabBarView.Tab(id: $0.id, title: $0.title) },
            activeID: activeSession?.id,
            onSelect: { [weak self] id in self?.selectSession(id: id) },
            onClose: { [weak self] id in self?.closeSession(id: id) },
            onNew: { [weak self] in self?.addSession() }
        )
    }
}
