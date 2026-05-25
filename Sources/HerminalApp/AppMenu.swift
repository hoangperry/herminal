// AppMenu — the macOS main menu.
// Tab actions target nil, so they travel the responder chain to the
// WorkspaceView (which is in the chain as the window's content view).

import AppKit

enum AppMenu {
    static func build() -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About herminal", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit herminal",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

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

        return mainMenu
    }
}
