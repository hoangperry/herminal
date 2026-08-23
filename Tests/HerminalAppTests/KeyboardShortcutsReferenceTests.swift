import AppKit
import Testing

@testable import HerminalApp

@Suite("Keyboard shortcuts reference", .serialized)
@MainActor
struct KeyboardShortcutsReferenceTests {
    @Test("Help and command palette expose the same shortcuts reference action")
    func discoverableEntryPoints() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )
        let helpMenu = try #require(AppMenu.helpMenu(in: menu))
        let helpItem = try #require(helpMenu.items.first {
            $0.title == "Keyboard Shortcuts…"
        })

        #expect(helpItem.action == #selector(AppDelegate.showKeyboardShortcuts(_:)))
        #expect(helpItem.keyEquivalent == "/")
        #expect(helpItem.keyEquivalentModifierMask == [.command])

        let paletteAction = try #require(CommandPaletteCatalog.actions(from: menu).first {
            $0.id == "keyboard-shortcuts"
        })
        #expect(paletteAction.title == "Keyboard Shortcuts")
        #expect(paletteAction.subtitle == "Browse and search the current app shortcuts")
        #expect(paletteAction.shortcutDisplay == "⌘/")
        #expect(
            paletteAction.selector
                == #selector(AppDelegate.showKeyboardShortcuts(_:))
        )
    }

    @Test("reference derives grouped entries from live menu bindings")
    func derivesEntriesFromMenu() throws {
        let menu = AppMenu.build(
            openWorkspaceSubmenu: NSMenu(title: "Open Workspace")
        )

        let groups = KeyboardShortcutReference.groups(from: menu)
        #expect(groups.allSatisfy { !$0.title.isEmpty })
        #expect(groups.contains { $0.title == "herminal" })
        let file = try #require(groups.first { $0.title == "File" })
        let newTab = try #require(file.entries.first { $0.title == "New Tab" })
        let view = try #require(groups.first { $0.title == "View" })
        let zoomPane = try #require(view.entries.first { $0.title == "Zoom Pane" })

        #expect(newTab.shortcut == "⌘T")
        #expect(newTab.menuPath == "File")
        #expect(zoomPane.shortcut == "⇧⌘↩")
        #expect(zoomPane.menuPath == "View")
        #expect(Set(groups.map(\.id)).count == groups.count)
        let entries = groups.flatMap(\.entries)
        #expect(Set(entries.map(\.id)).count == entries.count)
    }

    @Test("formatter speaks native modifiers and special keys deterministically")
    func formatsSpecialKeys() {
        #expect(
            KeyboardShortcutReference.displayShortcut(
                keyEquivalent: "\u{F702}",
                modifiers: [.command, .option]
            ) == "⌥⌘←"
        )
        #expect(
            KeyboardShortcutReference.displayShortcut(
                keyEquivalent: "\r",
                modifiers: [.command, .shift]
            ) == "⇧⌘↩"
        )
        #expect(
            KeyboardShortcutReference.displayShortcut(
                keyEquivalent: " ",
                modifiers: [.option]
            ) == "⌥Space"
        )
    }

    @Test("search matches action title, menu group, and displayed shortcut")
    func filtersReference() {
        let groups = [
            KeyboardShortcutGroup(
                id: "file",
                title: "File",
                entries: [
                    .init(
                        id: "new-tab",
                        title: "New Tab",
                        menuPath: "File",
                        shortcut: "⌘T"
                    ),
                ]
            ),
            KeyboardShortcutGroup(
                id: "window",
                title: "Window",
                entries: [
                    .init(
                        id: "focus-left",
                        title: "Focus Pane Left",
                        menuPath: "Window",
                        shortcut: "⌥⌘←"
                    ),
                ]
            ),
        ]

        #expect(
            KeyboardShortcutReference.filtered(groups, query: "pane")
                .flatMap(\.entries).map(\.id) == ["focus-left"]
        )
        #expect(
            KeyboardShortcutReference.filtered(groups, query: "file")
                .flatMap(\.entries).map(\.id) == ["new-tab"]
        )
        #expect(
            KeyboardShortcutReference.filtered(groups, query: "⌘t")
                .flatMap(\.entries).map(\.id) == ["new-tab"]
        )
        #expect(KeyboardShortcutReference.filtered(groups, query: "missing").isEmpty)
        #expect(KeyboardShortcutReference.filtered(groups, query: "  ") == groups)
    }

    @Test("row accessibility describes action, shortcut, and menu location")
    func rowAccessibility() {
        let entry = KeyboardShortcutEntry(
            id: "new-tab",
            title: "New Tab",
            menuPath: "File",
            shortcut: "⌘T"
        )

        #expect(
            KeyboardShortcutsView.accessibilityPresentation(for: entry)
                == .init(
                    label: "New Tab",
                    value: "Shortcut ⌘T",
                    hint: "File menu command"
                )
        )
        #expect(KeyboardShortcutsView.initialFocusTarget == .search)
    }
}
