// CommandPalette — ⌘⇧P fuzzy launcher over the workspace.
//
// Same shape as Raycast / Linear / VS Code: a floating panel with a
// search field at top and a result list below. Each row is an
// `Action` that, when chosen, dispatches a selector up the responder
// chain — so the palette can fire ANY menu action without us
// re-implementing each handler.
//
// Why an NSPanel (not a SwiftUI sheet): we need the window to float
// above the terminal surface, accept first-responder for the search
// field, and dismiss on Esc / loss of focus. NSPanel.becomesKeyOnlyIfNeeded
// is the right primitive; a SwiftUI .sheet would block the terminal
// underneath instead of overlaying.

import AppKit
import SwiftUI

@MainActor
enum CommandPalette {
    private static var panel: NSPanel?

    /// Toggles the palette. Closing happens on Esc, loss of focus, or
    /// after an action runs.
    static func toggle() {
        if let existing = panel, existing.isVisible {
            close()
            return
        }
        show()
    }

    static func show() {
        // Always rebuild a fresh panel: reusing the cached one keeps its
        // SwiftUI @State (the typed query + selection cursor) across opens,
        // and `hidesOnDeactivate` orders the panel out without routing
        // through close(), so a stale needle would survive the next ⌘⇧P.
        // Tearing down + rebuilding guarantees an empty field every time
        // and frees the hosting view between opens. (v0.4.3 review MED.)
        close()
        let palette = makePanel()
        panel = palette

        // Centre over the current key window — falls back to screen
        // centre when no window has focus (e.g. the user hits the
        // shortcut from the menu bar).
        if let host = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && $0.title == "herminal" }) {
            let hostFrame = host.frame
            let paletteSize = palette.frame.size
            let originX = hostFrame.midX - paletteSize.width / 2
            // Sit it 1/4 from the top so it doesn't cover the bottom
            // of the terminal — matches Spotlight / Raycast convention.
            let originY = hostFrame.maxY - paletteSize.height - hostFrame.height * 0.18
            palette.setFrameOrigin(NSPoint(x: originX, y: originY))
        } else {
            palette.center()
        }
        palette.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func close() {
        panel?.orderOut(nil)
        // Drop the strong ref so the panel + its SwiftUI hosting view
        // deallocate; show() rebuilds fresh. (isReleasedWhenClosed is
        // false, so nil-ing here is what actually releases it.)
        panel = nil
    }

    private static func makePanel() -> NSPanel {
        let panel = CommandPalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        let host = NSHostingView(rootView: CommandPaletteView(onDismiss: { CommandPalette.close() }))
        host.frame = panel.contentLayoutRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }
}

/// NSPanel subclass that accepts key + first-responder. The default
/// `.borderless` panel ignores key events, so the search field can't
/// receive focus without this override.
final class CommandPalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// The SwiftUI body. Owns the filter text, selection cursor, and
/// keyboard handling (↑↓ to move, Enter to fire, Esc to dismiss).
struct CommandPaletteView: View {
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    private let actions = CommandPaletteAction.all

    private var filtered: [CommandPaletteAction] {
        if query.isEmpty { return actions }
        let q = query.lowercased()
        return actions.filter { action in
            action.title.lowercased().contains(q)
                || action.subtitle?.lowercased().contains(q) == true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().background(HerminalDesign.Palette.border)
            resultList
        }
        .background(
            // Panel chrome: dark surface with a subtle inner glow. The
            // outer NSPanel shadow does the lift; this material gives
            // the rounded card feel.
            RoundedRectangle(cornerRadius: 12)
                .fill(HerminalDesign.Palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(HerminalDesign.Palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            searchFocused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(HerminalDesign.Palette.textSecondary)
            TextField("Type a command…", text: $query)
                .font(.system(size: 15))
                .foregroundColor(HerminalDesign.Palette.textPrimary)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { fireSelected() }
                .onKeyPress(.upArrow) {
                    selectedIndex = max(0, selectedIndex - 1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    selectedIndex = min(filtered.count - 1, selectedIndex + 1)
                    return .handled
                }
                .onKeyPress(.escape) {
                    onDismiss()
                    return .handled
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, action in
                        row(action: action, isSelected: index == selectedIndex)
                            .id(action.id)
                            .onTapGesture { fire(action: action) }
                    }
                }
                .padding(8)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                guard filtered.indices.contains(newIndex) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(filtered[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func row(action: CommandPaletteAction, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: action.icon)
                .font(.system(size: 13))
                .foregroundColor(isSelected
                                 ? HerminalDesign.Palette.accent
                                 : HerminalDesign.Palette.textSecondary)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(action.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(HerminalDesign.Palette.textPrimary)
                if let subtitle = action.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(HerminalDesign.Palette.textTertiary)
                }
            }
            Spacer(minLength: 0)
            if let shortcut = action.shortcutDisplay {
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(HerminalDesign.Palette.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HerminalDesign.Palette.surfaceOverlay)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                      ? HerminalDesign.Palette.accent.opacity(0.16)
                      : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func fireSelected() {
        guard filtered.indices.contains(selectedIndex) else { return }
        fire(action: filtered[selectedIndex])
    }

    private func fire(action: CommandPaletteAction) {
        onDismiss()
        // Defer so the panel closes before the action runs — keeps the
        // animation smooth and avoids the action targeting the
        // (closing) palette itself.
        DispatchQueue.main.async {
            NSApp.sendAction(action.selector, to: nil, from: nil)
        }
    }
}

/// Catalogue of palette entries. New menu items added to AppMenu
/// should also gain an entry here so the palette stays
/// discoverable. Selectors mirror the menu's `nil`-target routing —
/// the action travels the responder chain to whoever handles it
/// (WorkspaceView for tab/split actions, AppDelegate for Settings).
struct CommandPaletteAction: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let shortcutDisplay: String?
    let selector: Selector

    static let all: [CommandPaletteAction] = [
        .init(id: "new-tab", title: "New Tab", subtitle: "Open a new terminal tab",
              icon: "plus.square", shortcutDisplay: "⌘T",
              selector: #selector(WorkspaceView.newTab(_:))),
        .init(id: "close-tab", title: "Close Tab", subtitle: "Close the active pane",
              icon: "xmark.square", shortcutDisplay: "⌘W",
              selector: #selector(WorkspaceView.closeTab(_:))),
        .init(id: "next-tab", title: "Next Tab", subtitle: nil,
              icon: "arrow.right", shortcutDisplay: "⌘⇧]",
              selector: #selector(WorkspaceView.nextTab(_:))),
        .init(id: "prev-tab", title: "Previous Tab", subtitle: nil,
              icon: "arrow.left", shortcutDisplay: "⌘⇧[",
              selector: #selector(WorkspaceView.previousTab(_:))),
        .init(id: "split-right", title: "Split Pane Right",
              subtitle: "Vertical divider — side by side",
              icon: "rectangle.split.2x1", shortcutDisplay: "⌘D",
              selector: #selector(WorkspaceView.splitPaneVertical(_:))),
        .init(id: "split-down", title: "Split Pane Down",
              subtitle: "Horizontal divider — stacked",
              icon: "rectangle.split.1x2", shortcutDisplay: "⌘⇧D",
              selector: #selector(WorkspaceView.splitPaneHorizontal(_:))),
        .init(id: "focus-left", title: "Focus Pane Left",
              subtitle: "Move focus to the pane on the left",
              icon: "arrow.left.to.line", shortcutDisplay: "⌥⌘←",
              selector: #selector(WorkspaceView.focusPaneLeft(_:))),
        .init(id: "focus-right", title: "Focus Pane Right",
              subtitle: "Move focus to the pane on the right",
              icon: "arrow.right.to.line", shortcutDisplay: "⌥⌘→",
              selector: #selector(WorkspaceView.focusPaneRight(_:))),
        .init(id: "focus-up", title: "Focus Pane Up",
              subtitle: "Move focus to the pane above",
              icon: "arrow.up.to.line", shortcutDisplay: "⌥⌘↑",
              selector: #selector(WorkspaceView.focusPaneUp(_:))),
        .init(id: "focus-down", title: "Focus Pane Down",
              subtitle: "Move focus to the pane below",
              icon: "arrow.down.to.line", shortcutDisplay: "⌥⌘↓",
              selector: #selector(WorkspaceView.focusPaneDown(_:))),
        .init(id: "toggle-agents", title: "Toggle Agent Dashboard",
              subtitle: "claude / codex / aider runtimes",
              icon: "cpu", shortcutDisplay: "⌘⇧A",
              selector: #selector(WorkspaceView.toggleAgentDashboard(_:))),
        .init(id: "toggle-ssh", title: "Toggle SSH Hosts",
              subtitle: "From ~/.ssh/config",
              icon: "network", shortcutDisplay: "⌘⇧S",
              selector: #selector(WorkspaceView.toggleSSHHosts(_:))),
        .init(id: "toggle-claude", title: "Toggle Claude Sessions",
              subtitle: "Resume past Claude Code conversations",
              icon: "sparkles", shortcutDisplay: "⌘⇧C",
              selector: #selector(WorkspaceView.toggleClaudeSessions(_:))),
        .init(id: "toggle-notes", title: "Toggle Notes Panel",
              subtitle: "Per-session SQLite-backed notes",
              icon: "note.text", shortcutDisplay: "⌘⇧N",
              selector: #selector(WorkspaceView.toggleNotes(_:))),
        .init(id: "toggle-theme", title: "Toggle Light / Dark Theme",
              subtitle: nil, icon: "circle.lefthalf.filled",
              shortcutDisplay: "⌘⇧L",
              selector: #selector(WorkspaceView.toggleTheme(_:))),
        .init(id: "font-bigger", title: "Bigger Text",
              subtitle: "Increase font size in every pane",
              icon: "textformat.size.larger", shortcutDisplay: "⌘+",
              selector: #selector(WorkspaceView.increaseFontSize(_:))),
        .init(id: "font-smaller", title: "Smaller Text",
              subtitle: "Decrease font size in every pane",
              icon: "textformat.size.smaller", shortcutDisplay: "⌘-",
              selector: #selector(WorkspaceView.decreaseFontSize(_:))),
        .init(id: "font-reset", title: "Actual Size",
              subtitle: "Reset font size to the configured default",
              icon: "textformat.size", shortcutDisplay: "⌘0",
              selector: #selector(WorkspaceView.resetFontSize(_:))),
        .init(id: "zoom-pane", title: "Zoom Pane",
              subtitle: "Maximize the focused pane (toggle)",
              icon: "arrow.up.left.and.arrow.down.right", shortcutDisplay: "⌘⇧↩",
              selector: #selector(WorkspaceView.toggleZoomPane(_:))),
        .init(id: "find", title: "Find in Terminal…",
              subtitle: "Search the scrollback buffer",
              icon: "magnifyingglass", shortcutDisplay: "⌘F",
              selector: #selector(WorkspaceView.findInScrollback(_:))),
        .init(id: "import-ssh", title: "Import ~/.ssh/config",
              subtitle: "One-shot upsert into SSH host list",
              icon: "square.and.arrow.down",
              shortcutDisplay: nil,
              selector: #selector(WorkspaceView.importSSHConfig(_:))),
        .init(id: "export-note", title: "Export Note…",
              subtitle: "Save active session's note as Markdown",
              icon: "doc.text",
              shortcutDisplay: nil,
              selector: #selector(WorkspaceView.exportNote(_:))),
        .init(id: "import-note", title: "Import Note…",
              subtitle: "Load Markdown into active session",
              icon: "doc.badge.plus",
              shortcutDisplay: nil,
              selector: #selector(WorkspaceView.importNote(_:))),
        .init(id: "save-workspace", title: "Save Workspace As…",
              subtitle: "Name the current tab + split layout to reopen later",
              icon: "square.stack.3d.up",
              shortcutDisplay: "⌃⌘S",
              selector: #selector(AppDelegate.saveWorkspaceAs(_:))),
        .init(id: "settings", title: "Settings…",
              subtitle: "Theme · terminal · shell · onboarding",
              icon: "gearshape",
              shortcutDisplay: "⌘,",
              selector: #selector(AppDelegate.openPreferences(_:))),
        .init(id: "hotkey-window", title: "Show Hotkey Window",
              subtitle: "Activate herminal from any app",
              icon: "command",
              shortcutDisplay: "⌥Space",
              selector: #selector(AppDelegate.toggleHotkeyWindow(_:))),
    ]
}
