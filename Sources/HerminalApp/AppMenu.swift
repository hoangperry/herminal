// AppMenu — the macOS main menu.
// Tab actions target nil, so they travel the responder chain to the
// WorkspaceView (which is in the chain as the window's content view).

import AppKit

enum AppMenu {
    /// `openWorkspaceSubmenu` is owned by AppDelegate (which is its
    /// delegate) so it can repopulate the saved-workspace list each time
    /// the menu opens. (v0.4.2)
    static func build(openWorkspaceSubmenu: NSMenu) -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About herminal", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        // ⌘, is the macOS-wide Settings/Preferences convention. Target
        // is the AppDelegate; responder chain reaches it via NSApp.
        appMenu.addItem(NSMenuItem(
            title: "Settings…",
            action: #selector(AppDelegate.openPreferences(_:)),
            keyEquivalent: ","
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit herminal",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        // Edit menu — standard Cut/Copy/Paste/Select All. Actions target
        // `nil` so they travel the responder chain to the focused
        // HerminalSurfaceView, which forwards into libghostty's matching
        // keybinding action (copy_to_clipboard, paste_from_clipboard,
        // select_all). Without this menu the keyboard shortcuts still
        // work (libghostty's macOS default keybindings catch ⌘C / ⌘V
        // at the keyDown level), but adding the menu makes the actions
        // discoverable and shows the shortcut hints to first-time users.
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(NSMenuItem(
            title: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        ))
        editMenu.addItem(NSMenuItem(
            title: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        ))
        editMenu.addItem(NSMenuItem(
            title: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        ))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(
            title: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        ))

        // File menu — tab lifecycle
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        fileMenu.addItem(NSMenuItem(
            title: "New Tab",
            action: #selector(WorkspaceView.newTab(_:)),
            keyEquivalent: "t"
        ))
        fileMenu.addItem(NSMenuItem(
            title: "Close Tab",
            action: #selector(WorkspaceView.closeTab(_:)),
            keyEquivalent: "w"
        ))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(
            title: "Export Note…",
            action: #selector(WorkspaceView.exportNote(_:)),
            keyEquivalent: ""
        ))
        fileMenu.addItem(NSMenuItem(
            title: "Import Note…",
            action: #selector(WorkspaceView.importNote(_:)),
            keyEquivalent: ""
        ))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(
            title: "Import ~/.ssh/config",
            action: #selector(WorkspaceView.importSSHConfig(_:)),
            keyEquivalent: ""
        ))

        // Edit menu gains find — separator already exists. (v0.3.2.)
        editMenu.addItem(.separator())
        let find = NSMenuItem(
            title: "Find in Terminal…",
            action: #selector(WorkspaceView.findInScrollback(_:)),
            keyEquivalent: "f"
        )
        editMenu.addItem(find)
        let findNext = NSMenuItem(
            title: "Find Next",
            action: #selector(WorkspaceView.findNext(_:)),
            keyEquivalent: "g"
        )
        editMenu.addItem(findNext)
        let findPrev = NSMenuItem(
            title: "Find Previous",
            action: #selector(WorkspaceView.findPrevious(_:)),
            keyEquivalent: "g"
        )
        findPrev.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(findPrev)

        // View menu — font size (libghostty binding actions, applied to
        // every surface). Pane zoom joins this menu in v1.0 (S2).
        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu
        viewMenu.addItem(NSMenuItem(
            title: "Bigger Text",
            action: #selector(WorkspaceView.increaseFontSize(_:)),
            keyEquivalent: "+"
        ))
        viewMenu.addItem(NSMenuItem(
            title: "Smaller Text",
            action: #selector(WorkspaceView.decreaseFontSize(_:)),
            keyEquivalent: "-"
        ))
        viewMenu.addItem(NSMenuItem(
            title: "Actual Size",
            action: #selector(WorkspaceView.resetFontSize(_:)),
            keyEquivalent: "0"
        ))

        // Window menu — tab navigation
        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        let nextTab = NSMenuItem(
            title: "Next Tab",
            action: #selector(WorkspaceView.nextTab(_:)),
            keyEquivalent: "]"
        )
        nextTab.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(nextTab)
        let prevTab = NSMenuItem(
            title: "Previous Tab",
            action: #selector(WorkspaceView.previousTab(_:)),
            keyEquivalent: "["
        )
        prevTab.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(prevTab)

        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(
            title: "Split Pane Right",
            action: #selector(WorkspaceView.splitPaneVertical(_:)),
            keyEquivalent: "d"
        ))
        let splitDown = NSMenuItem(
            title: "Split Pane Down",
            action: #selector(WorkspaceView.splitPaneHorizontal(_:)),
            keyEquivalent: "d"
        )
        splitDown.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(splitDown)

        // v0.5.1 — directional pane focus (⌥⌘ + arrow), matching iTerm2's
        // split-pane navigation. The arrow key equivalents use the AppKit
        // function-key unicode scalars (↑ F700 ↓ F701 ← F702 → F703).
        windowMenu.addItem(.separator())
        for (title, key, selector): (String, String, Selector) in [
            ("Focus Pane Left",  "\u{F702}", #selector(WorkspaceView.focusPaneLeft(_:))),
            ("Focus Pane Right", "\u{F703}", #selector(WorkspaceView.focusPaneRight(_:))),
            ("Focus Pane Up",    "\u{F700}", #selector(WorkspaceView.focusPaneUp(_:))),
            ("Focus Pane Down",  "\u{F701}", #selector(WorkspaceView.focusPaneDown(_:))),
        ] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.keyEquivalentModifierMask = [.command, .option]
            windowMenu.addItem(item)
        }

        windowMenu.addItem(.separator())
        let toggleDashboard = NSMenuItem(
            title: "Toggle Agent Dashboard",
            action: #selector(WorkspaceView.toggleAgentDashboard(_:)),
            keyEquivalent: "a"
        )
        toggleDashboard.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(toggleDashboard)

        let toggleSSH = NSMenuItem(
            title: "Toggle SSH Hosts",
            action: #selector(WorkspaceView.toggleSSHHosts(_:)),
            keyEquivalent: "s"
        )
        toggleSSH.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(toggleSSH)

        // v0.4 — Claude session browser. ⌘⇧C reads ~/.claude/projects.
        let toggleClaude = NSMenuItem(
            title: "Toggle Claude Sessions",
            action: #selector(WorkspaceView.toggleClaudeSessions(_:)),
            keyEquivalent: "c"
        )
        toggleClaude.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(toggleClaude)

        let toggleNotes = NSMenuItem(
            title: "Toggle Notes",
            action: #selector(WorkspaceView.toggleNotes(_:)),
            keyEquivalent: "n"
        )
        toggleNotes.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(toggleNotes)

        windowMenu.addItem(.separator())
        let toggleTheme = NSMenuItem(
            title: "Toggle Light / Dark Theme",
            action: #selector(WorkspaceView.toggleTheme(_:)),
            keyEquivalent: "l"
        )
        toggleTheme.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(toggleTheme)

        windowMenu.addItem(.separator())
        // v0.3.1 — command palette + hotkey window.
        let palette = NSMenuItem(
            title: "Command Palette…",
            action: #selector(AppDelegate.toggleCommandPalette(_:)),
            keyEquivalent: "p"
        )
        palette.keyEquivalentModifierMask = [.command, .shift]
        windowMenu.addItem(palette)

        let hotkey = NSMenuItem(
            title: "Show Hotkey Window",
            action: #selector(AppDelegate.toggleHotkeyWindow(_:)),
            keyEquivalent: " "
        )
        // ⌥Space is also registered globally by HotkeyManager; the
        // menu binding is the in-app fallback for users who can't
        // grant the global hotkey (combo taken by another app).
        hotkey.keyEquivalentModifierMask = [.option]
        windowMenu.addItem(hotkey)

        windowMenu.addItem(.separator())
        // v0.4.2 — named workspaces. Save the current layout under a
        // name; reopen any saved one from the dynamic submenu (AppDelegate
        // repopulates it on open, with an Option-key alternate to delete).
        let saveWorkspace = NSMenuItem(
            title: "Save Workspace As…",
            action: #selector(AppDelegate.saveWorkspaceAs(_:)),
            keyEquivalent: "s"
        )
        saveWorkspace.keyEquivalentModifierMask = [.command, .control]
        windowMenu.addItem(saveWorkspace)

        let openWorkspace = NSMenuItem(title: "Open Workspace", action: nil, keyEquivalent: "")
        openWorkspace.submenu = openWorkspaceSubmenu
        windowMenu.addItem(openWorkspace)

        return mainMenu
    }
}
