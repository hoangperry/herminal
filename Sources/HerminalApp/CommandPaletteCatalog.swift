import AppKit

struct CommandPaletteAction: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let shortcutDisplay: String?
    let selector: Selector
    let menuPath: String?
    let menuTitle: String?
}

@MainActor
enum CommandPaletteCatalog {
    private struct Descriptor {
        let id: String
        let title: String
        let subtitle: String?
        let icon: String
        let shortcutDisplay: String?
        let selector: Selector
    }

    private struct LiveMenuMatch {
        let title: String
        let selector: Selector
        let shortcutDisplay: String?
        let menuPath: String
    }

    static func actions(from mainMenu: NSMenu?) -> [CommandPaletteAction] {
        let liveMatches = mainMenu.map(menuMatches(from:)) ?? [:]

        return descriptors.compactMap { descriptor in
            let liveMatch = liveMatches[selectorKey(descriptor.selector)]
            if mainMenu != nil, liveMatch == nil {
                return nil
            }
            return CommandPaletteAction(
                id: descriptor.id,
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                icon: descriptor.icon,
                shortcutDisplay: liveMatch?.shortcutDisplay ?? descriptor.shortcutDisplay,
                selector: liveMatch?.selector ?? descriptor.selector,
                menuPath: liveMatch?.menuPath,
                menuTitle: liveMatch?.title
            )
        }
    }

    private static func menuMatches(from mainMenu: NSMenu) -> [String: LiveMenuMatch] {
        var matches: [String: LiveMenuMatch] = [:]
        for item in mainMenu.items {
            guard let submenu = item.submenu else { continue }
            let rootTitle = submenu.title.isEmpty ? item.title : submenu.title
            collectMenuMatches(
                in: submenu,
                rootTitle: rootTitle,
                parentTitles: [],
                into: &matches
            )
        }
        return matches
    }

    private static func collectMenuMatches(
        in menu: NSMenu,
        rootTitle: String,
        parentTitles: [String],
        into matches: inout [String: LiveMenuMatch]
    ) {
        for item in menu.items {
            if let submenu = item.submenu {
                collectMenuMatches(
                    in: submenu,
                    rootTitle: rootTitle,
                    parentTitles: parentTitles + [item.title],
                    into: &matches
                )
                continue
            }
            guard !item.isSeparatorItem, let selector = item.action else { continue }
            let key = selectorKey(selector)
            guard matches[key] == nil else { continue }
            let shortcutDisplay = item.keyEquivalent.isEmpty
                ? nil
                : KeyboardShortcutReference.displayShortcut(
                    keyEquivalent: item.keyEquivalent,
                    modifiers: item.keyEquivalentModifierMask
                )
            matches[key] = LiveMenuMatch(
                title: item.title,
                selector: selector,
                shortcutDisplay: shortcutDisplay,
                menuPath: ([rootTitle] + parentTitles).joined(separator: " › ")
            )
        }
    }

    private static func selectorKey(_ selector: Selector) -> String {
        NSStringFromSelector(selector)
    }

    private static let descriptors: [Descriptor] = [
        .init(
            id: "new-tab",
            title: "New Tab",
            subtitle: "Open a new terminal tab",
            icon: "plus.square",
            shortcutDisplay: "⌘T",
            selector: #selector(WorkspaceView.newTab(_:))
        ),
        .init(
            id: "close-tab",
            title: "Close Tab",
            subtitle: "Close the active pane",
            icon: "xmark.square",
            shortcutDisplay: "⌘W",
            selector: #selector(WorkspaceView.closeTab(_:))
        ),
        .init(
            id: "next-tab",
            title: "Next Tab",
            subtitle: nil,
            icon: "arrow.right",
            shortcutDisplay: "⌘⇧]",
            selector: #selector(WorkspaceView.nextTab(_:))
        ),
        .init(
            id: "prev-tab",
            title: "Previous Tab",
            subtitle: nil,
            icon: "arrow.left",
            shortcutDisplay: "⌘⇧[",
            selector: #selector(WorkspaceView.previousTab(_:))
        ),
        .init(
            id: "split-right",
            title: "Split Pane Right",
            subtitle: "Vertical divider — side by side",
            icon: "rectangle.split.2x1",
            shortcutDisplay: "⌘D",
            selector: #selector(WorkspaceView.splitPaneVertical(_:))
        ),
        .init(
            id: "split-down",
            title: "Split Pane Down",
            subtitle: "Horizontal divider — stacked",
            icon: "rectangle.split.1x2",
            shortcutDisplay: "⌘⇧D",
            selector: #selector(WorkspaceView.splitPaneHorizontal(_:))
        ),
        .init(
            id: "focus-left",
            title: "Focus Pane Left",
            subtitle: "Move focus to the pane on the left",
            icon: "arrow.left.to.line",
            shortcutDisplay: "⌥⌘←",
            selector: #selector(WorkspaceView.focusPaneLeft(_:))
        ),
        .init(
            id: "focus-right",
            title: "Focus Pane Right",
            subtitle: "Move focus to the pane on the right",
            icon: "arrow.right.to.line",
            shortcutDisplay: "⌥⌘→",
            selector: #selector(WorkspaceView.focusPaneRight(_:))
        ),
        .init(
            id: "focus-up",
            title: "Focus Pane Up",
            subtitle: "Move focus to the pane above",
            icon: "arrow.up.to.line",
            shortcutDisplay: "⌥⌘↑",
            selector: #selector(WorkspaceView.focusPaneUp(_:))
        ),
        .init(
            id: "focus-down",
            title: "Focus Pane Down",
            subtitle: "Move focus to the pane below",
            icon: "arrow.down.to.line",
            shortcutDisplay: "⌥⌘↓",
            selector: #selector(WorkspaceView.focusPaneDown(_:))
        ),
        .init(
            id: "new-agent-pane",
            title: "New Agent Pane",
            subtitle: "Split and launch Claude Code here",
            icon: "sparkles",
            shortcutDisplay: "⌘⌥A",
            selector: #selector(WorkspaceView.newAgentPane(_:))
        ),
        .init(
            id: "new-agent-tab",
            title: "New Agent Tab",
            subtitle: "Open Claude Code in a new tab",
            icon: "sparkle",
            shortcutDisplay: "⌘⌥T",
            selector: #selector(WorkspaceView.newAgentTab(_:))
        ),
        .init(
            id: "new-agent-worktree",
            title: "New Agent Worktree…",
            subtitle: "Isolated git checkout + agent (FlightDeck wt)",
            icon: "square.stack.3d.up",
            shortcutDisplay: "⌘⌥W",
            selector: #selector(WorkspaceView.newAgentWorktree(_:))
        ),
        .init(
            id: "open-lazygit",
            title: "Open Lazygit",
            subtitle: "Git TUI in a new tab at this directory",
            icon: "arrow.triangle.branch",
            shortcutDisplay: "⌘⌥G",
            selector: #selector(WorkspaceView.openLazygit(_:))
        ),
        .init(
            id: "tmux-new",
            title: "New tmux Session…",
            subtitle: "Create a named session (repo name prefilled)",
            icon: "square.split.2x1",
            shortcutDisplay: nil,
            selector: #selector(WorkspaceView.newTmuxSession(_:))
        ),
        .init(
            id: "tmux-attach",
            title: "Attach tmux Session…",
            subtitle: "Pick a live tmux session",
            icon: "link",
            shortcutDisplay: nil,
            selector: #selector(WorkspaceView.attachTmuxSession(_:))
        ),
        .init(
            id: "tmux-attach-or-create",
            title: "Attach or Create tmux Session",
            subtitle: "Rejoin this repo's session, or start one",
            icon: "square.split.2x1.fill",
            shortcutDisplay: nil,
            selector: #selector(WorkspaceView.attachOrCreateTmuxSession(_:))
        ),
        .init(
            id: "toggle-agents",
            title: "Toggle Agent Dashboard",
            subtitle: "claude / codex / aider runtimes + worktrees",
            icon: "cpu",
            shortcutDisplay: "⌘⇧A",
            selector: #selector(WorkspaceView.toggleAgentDashboard(_:))
        ),
        .init(
            id: "toggle-ssh",
            title: "Toggle SSH Hosts",
            subtitle: "From ~/.ssh/config",
            icon: "network",
            shortcutDisplay: "⌘⇧S",
            selector: #selector(WorkspaceView.toggleSSHHosts(_:))
        ),
        .init(
            id: "toggle-claude",
            title: "Toggle Claude Sessions",
            subtitle: "Resume past Claude Code conversations",
            icon: "sparkles",
            shortcutDisplay: "⌘⇧C",
            selector: #selector(WorkspaceView.toggleClaudeSessions(_:))
        ),
        .init(
            id: "toggle-notes",
            title: "Toggle Notes Panel",
            subtitle: "Per-session SQLite-backed notes",
            icon: "note.text",
            shortcutDisplay: "⌘⇧N",
            selector: #selector(WorkspaceView.toggleNotes(_:))
        ),
        .init(
            id: "toggle-theme",
            title: "Toggle Light / Dark Theme",
            subtitle: nil,
            icon: "circle.lefthalf.filled",
            shortcutDisplay: "⌘⇧L",
            selector: #selector(WorkspaceView.toggleTheme(_:))
        ),
        .init(
            id: "toggle-status-bar",
            title: "Toggle Status Bar",
            subtitle: "Show or hide the bottom status bar",
            icon: "info.circle",
            shortcutDisplay: nil,
            selector: #selector(WorkspaceView.toggleStatusBar(_:))
        ),
        .init(
            id: "font-bigger",
            title: "Bigger Text",
            subtitle: "Increase font size in every pane",
            icon: "textformat.size.larger",
            shortcutDisplay: "⌘+",
            selector: #selector(WorkspaceView.increaseFontSize(_:))
        ),
        .init(
            id: "font-smaller",
            title: "Smaller Text",
            subtitle: "Decrease font size in every pane",
            icon: "textformat.size.smaller",
            shortcutDisplay: "⌘-",
            selector: #selector(WorkspaceView.decreaseFontSize(_:))
        ),
        .init(
            id: "font-reset",
            title: "Actual Size",
            subtitle: "Reset font size to the configured default",
            icon: "textformat.size",
            shortcutDisplay: "⌘0",
            selector: #selector(WorkspaceView.resetFontSize(_:))
        ),
        .init(
            id: "zoom-pane",
            title: "Zoom Pane",
            subtitle: "Maximize the focused pane (toggle)",
            icon: "arrow.up.left.and.arrow.down.right",
            shortcutDisplay: "⌘⇧↩",
            selector: #selector(WorkspaceView.toggleZoomPane(_:))
        ),
        .init(
            id: "find",
            title: "Find in Terminal…",
            subtitle: "Search the scrollback buffer",
            icon: "magnifyingglass",
            shortcutDisplay: "⌘F",
            selector: #selector(WorkspaceView.findInScrollback(_:))
        ),
        .init(
            id: "keyboard-shortcuts",
            title: "Keyboard Shortcuts",
            subtitle: "Browse and search the current app shortcuts",
            icon: "keyboard",
            shortcutDisplay: "⌘/",
            selector: #selector(AppDelegate.showKeyboardShortcuts(_:))
        ),
        .init(
            id: "check-for-updates",
            title: "Check for Updates…",
            subtitle: "Open the latest release page on official GitHub",
            icon: "arrow.down.circle",
            shortcutDisplay: nil,
            selector: #selector(AppDelegate.checkForUpdates(_:))
        ),
        .init(
            id: "copy-redacted-diagnostics",
            title: "Copy Redacted Diagnostics for Bug Report",
            subtitle: "Copy the latest 200 privacy-redacted diagnostic entries for a bug report",
            icon: "doc.on.clipboard",
            shortcutDisplay: nil,
            selector: #selector(AppDelegate.copyRedactedDiary(_:))
        ),
        .init(
            id: "import-ssh",
            title: "Import ~/.ssh/config",
            subtitle: "One-shot upsert into SSH host list",
            icon: "square.and.arrow.down",
            shortcutDisplay: nil,
            selector: #selector(WorkspaceView.importSSHConfig(_:))
        ),
        .init(
            id: "export-note",
            title: "Export Note…",
            subtitle: "Save active session's note as Markdown",
            icon: "doc.text",
            shortcutDisplay: nil,
            selector: #selector(WorkspaceView.exportNote(_:))
        ),
        .init(
            id: "import-note",
            title: "Import Note…",
            subtitle: "Load Markdown into active session",
            icon: "doc.badge.plus",
            shortcutDisplay: nil,
            selector: #selector(WorkspaceView.importNote(_:))
        ),
        .init(
            id: "save-workspace",
            title: "Save Workspace As…",
            subtitle: "Name the current tab + split layout to reopen later",
            icon: "square.stack.3d.up",
            shortcutDisplay: "⌃⌘S",
            selector: #selector(AppDelegate.saveWorkspaceAs(_:))
        ),
        .init(
            id: "settings",
            title: "Settings…",
            subtitle: "Theme · terminal · shell · onboarding",
            icon: "gearshape",
            shortcutDisplay: "⌘,",
            selector: #selector(AppDelegate.openPreferences(_:))
        ),
        .init(
            id: "hotkey-window",
            title: "Show Hotkey Window",
            subtitle: "Activate herminal from any app",
            icon: "command",
            shortcutDisplay: "⌥Space",
            selector: #selector(AppDelegate.toggleHotkeyWindow(_:))
        ),
    ]
}
