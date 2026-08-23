import AppKit
import Foundation
import Testing

@testable import HerminalApp

@Suite("Status bar discoverability", .serialized)
@MainActor
struct StatusBarDiscoverabilityTests {
    private final class NotificationCounter: NSObject {
        private(set) var count = 0

        @objc func record() {
            count += 1
        }
    }

    @Test("View menu says Hide Status Bar when the bar is visible")
    func viewMenuTitleWhenStatusBarVisible() throws {
        let defaults = UserDefaults.standard
        let key = Preferences.Key.showStatusBar
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(true, forKey: key)

        let menu = AppMenu.build(openWorkspaceSubmenu: NSMenu(title: "Open Workspace"))
        let viewMenu = try #require(submenu(in: menu, titled: "View"))
        let toggleItem = try #require(statusBarToggleItem(in: viewMenu))

        #expect(toggleItem.title == "Hide Status Bar")
        #expect(toggleItem.action == NSSelectorFromString("toggleStatusBar:"))
    }

    @Test("View menu says Show Status Bar when the bar is hidden")
    func viewMenuTitleWhenStatusBarHidden() throws {
        let defaults = UserDefaults.standard
        let key = Preferences.Key.showStatusBar
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(false, forKey: key)

        let menu = AppMenu.build(openWorkspaceSubmenu: NSMenu(title: "Open Workspace"))
        let viewMenu = try #require(submenu(in: menu, titled: "View"))
        let toggleItem = try #require(statusBarToggleItem(in: viewMenu))

        #expect(toggleItem.title == "Show Status Bar")
        #expect(toggleItem.action == NSSelectorFromString("toggleStatusBar:"))
    }

    @Test("command palette exposes a stable status bar action without a shortcut")
    func commandPaletteStatusBarAction() throws {
        let menu = AppMenu.build(openWorkspaceSubmenu: NSMenu(title: "Open Workspace"))
        let action = try #require(CommandPaletteCatalog.actions(from: menu).first {
            $0.id == "toggle-status-bar"
        })

        #expect(action.title == "Toggle Status Bar")
        #expect(action.subtitle == "Show or hide the bottom status bar")
        #expect(action.selector == NSSelectorFromString("toggleStatusBar:"))
        #expect(action.shortcutDisplay == nil)
        #expect(action.menuPath == "View")
    }

    @Test("preference helper flips visibility and broadcasts exactly once")
    func preferenceTogglePersistsAndBroadcasts() {
        let defaults = UserDefaults.standard
        let key = Preferences.Key.showStatusBar
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(true, forKey: key)
        let counter = NotificationCounter()
        NotificationCenter.default.addObserver(
            counter,
            selector: #selector(NotificationCounter.record),
            name: Preferences.didChangeNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(counter) }

        let isVisible = Preferences.toggleStatusBarVisibility()

        #expect(!isVisible)
        #expect(!Preferences.showStatusBar)
        #expect(counter.count == 1)
    }

    private func submenu(in mainMenu: NSMenu, titled title: String) -> NSMenu? {
        mainMenu.items.compactMap(\.submenu).first { $0.title == title }
    }

    private func statusBarToggleItem(in menu: NSMenu) -> NSMenuItem? {
        menu.items.first {
            $0.action == NSSelectorFromString("toggleStatusBar:")
                || $0.title == "Hide Status Bar"
                || $0.title == "Show Status Bar"
        }
    }
}
