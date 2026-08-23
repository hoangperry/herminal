import AppKit
import Testing

@testable import HerminalApp

@Suite("App menu conventions", .serialized)
@MainActor
struct AppMenuConventionsTests {
    @Test("About item opens the standard macOS About panel")
    func aboutItemUsesStandardPanel() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let appMenu = try #require(menu.items.first?.submenu)
        let aboutItem = try #require(
            appMenu.items.first { $0.title == "About herminal" }
        )

        #expect(
            aboutItem.action
                == #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        )
        #expect(aboutItem.target === NSApplication.shared)
        #expect(aboutItem.isEnabled)
    }

    @Test("App menu exposes a truthful manual update action")
    func appMenuExposesManualUpdateCheck() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let appMenu = try #require(menu.items.first?.submenu)
        let aboutIndex = try #require(
            appMenu.items.firstIndex { $0.title == "About herminal" }
        )
        let updateIndex = try #require(
            appMenu.items.firstIndex { $0.title == "Check for Updates…" }
        )
        let updateItem = appMenu.items[updateIndex]

        #expect(updateIndex == aboutIndex + 1)
        #expect(updateItem.action == #selector(AppDelegate.checkForUpdates(_:)))
        #expect(updateItem.target == nil)
        #expect(updateItem.keyEquivalent.isEmpty)
        #expect(updateItem.isEnabled)
    }

    @Test("App menu exposes the native hide commands")
    func appMenuUsesStandardHideCommands() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let appMenu = try #require(menu.items.first?.submenu)

        let hideItem = try #require(
            appMenu.items.first { $0.title == "Hide herminal" }
        )
        #expect(hideItem.action == #selector(NSApplication.hide(_:)))
        #expect(hideItem.target === NSApplication.shared)
        #expect(hideItem.keyEquivalent == "h")
        #expect(hideItem.keyEquivalentModifierMask == [.command])
        #expect(hideItem.isEnabled)

        let hideOthersItem = try #require(
            appMenu.items.first { $0.title == "Hide Others" }
        )
        #expect(
            hideOthersItem.action
                == #selector(NSApplication.hideOtherApplications(_:))
        )
        #expect(hideOthersItem.target === NSApplication.shared)
        #expect(hideOthersItem.keyEquivalent == "h")
        #expect(hideOthersItem.keyEquivalentModifierMask == [.command, .option])
        #expect(hideOthersItem.isEnabled)

        let showAllItem = try #require(
            appMenu.items.first { $0.title == "Show All" }
        )
        #expect(
            showAllItem.action
                == #selector(NSApplication.unhideAllApplications(_:))
        )
        #expect(showAllItem.target === NSApplication.shared)
        #expect(showAllItem.keyEquivalent.isEmpty)
        #expect(showAllItem.isEnabled)
    }

    @Test("App menu exposes the standard Services submenu")
    func appMenuUsesStandardServicesSubmenu() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let appMenu = try #require(menu.items.first?.submenu)
        let servicesItem = try #require(
            appMenu.items.first { $0.title == "Services" }
        )

        #expect(servicesItem.action == NSSelectorFromString("submenuAction:"))
        #expect(servicesItem.keyEquivalent.isEmpty)
        let servicesMenu = try #require(servicesItem.submenu)
        #expect(servicesMenu.title == "Services")
        #expect(AppMenu.servicesMenu(in: menu) === servicesMenu)
    }

    @Test("Window menu exposes native window management commands")
    func windowMenuUsesStandardWindowCommands() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let windowMenu = try #require(
            menu.items.compactMap(\.submenu).first { $0.title == "Window" }
        )
        #expect(AppMenu.windowMenu(in: menu) === windowMenu)

        let minimizeItem = try #require(
            windowMenu.items.first { $0.title == "Minimize" }
        )
        #expect(minimizeItem.action == #selector(NSWindow.performMiniaturize(_:)))
        #expect(minimizeItem.target == nil)
        #expect(minimizeItem.keyEquivalent == "m")

        let zoomItem = try #require(
            windowMenu.items.first { $0.title == "Zoom" }
        )
        #expect(zoomItem.action == #selector(NSWindow.performZoom(_:)))
        #expect(zoomItem.target == nil)
        #expect(zoomItem.keyEquivalent.isEmpty)

        let bringAllToFrontItem = try #require(
            windowMenu.items.first { $0.title == "Bring All to Front" }
        )
        #expect(
            bringAllToFrontItem.action
                == #selector(NSApplication.arrangeInFront(_:))
        )
        #expect(bringAllToFrontItem.target === NSApplication.shared)
        #expect(bringAllToFrontItem.keyEquivalent.isEmpty)
    }
}
