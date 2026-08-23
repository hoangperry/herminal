import AppKit
import Testing
@testable import HerminalApp

@Suite("Command palette policy")
@MainActor
struct CommandPalettePolicyTests {
    private func actions() -> [CommandPaletteAction] {
        CommandPaletteCatalog.actions(
            from: AppMenu.build(openWorkspaceSubmenu: NSMenu(title: "Open Workspace"))
        )
    }

    @Test("selection index sanitizes invalid values and empty result sets")
    func selectionIndexSanitization() {
        #expect(CommandPaletteView.normalizedSelectionIndex(-1, total: 4) == 0)
        #expect(CommandPaletteView.normalizedSelectionIndex(9, total: 4) == 3)
        #expect(CommandPaletteView.normalizedSelectionIndex(0, total: 0) == 0)
        #expect(CommandPaletteView.normalizedSelectionIndex(0, total: -1) == 0)
    }

    @Test("result positions are omitted for invalid row indexes and totals")
    func resultPositionSanitization() {
        #expect(CommandPaletteView.resultPositionText(rowIndex: 0, total: 0) == nil)
        #expect(CommandPaletteView.resultPositionText(rowIndex: -1, total: 3) == nil)
        #expect(CommandPaletteView.resultPositionText(rowIndex: 3, total: 3) == nil)
        #expect(CommandPaletteView.resultPositionText(rowIndex: 1, total: 3) == "2 of 3")
    }

    @Test("Tab from search transfers focus to the highlighted result")
    func highlightedResultFocusTarget() {
        let actions = Array(actions().prefix(3))

        #expect(
            CommandPaletteView.resultFocusTarget(
                actions: actions,
                selectedIndex: 2
            ) == actions[2].id
        )
        #expect(
            CommandPaletteView.resultFocusTarget(
                actions: actions,
                selectedIndex: 99
            ) == actions[2].id
        )
        #expect(
            CommandPaletteView.resultFocusTarget(
                actions: [],
                selectedIndex: 0
            ) == nil
        )
    }

    @Test("selected rows announce metadata and expose selected state semantically")
    func accessibilityForSelectedRowWithSubtitleAndShortcut() throws {
        let action = try #require(actions().first { $0.id == "new-tab" })

        #expect(
            CommandPaletteView.rowAccessibilityPresentation(
                for: action,
                rowIndex: 0,
                total: 3,
                isSelected: true
            ) == .init(
                label: "New Tab",
                value: "Open a new terminal tab. Shortcut ⌘T. 1 of 3",
                hint: "Press Return or Space to run this command",
                isSelected: true
            )
        )
    }

    @Test("search stays explicitly named and explains keyboard operation")
    func searchAccessibilityPresentation() {
        #expect(
            CommandPaletteView.searchAccessibilityPresentation == .init(
                label: "Command search",
                hint: "Use the Up and Down Arrow keys to choose a command, then press Return to run it"
            )
        )
    }

    @Test("arrow-key selection announcements mirror the highlighted row")
    func selectedResultAnnouncement() throws {
        let liveActions = actions()
        let newTabIndex = try #require(liveActions.firstIndex { $0.id == "new-tab" })

        #expect(
            CommandPaletteView.selectedResultAnnouncement(
                actions: liveActions,
                selectedIndex: newTabIndex
            ) == "New Tab. Open a new terminal tab. Shortcut ⌘T. \(newTabIndex + 1) of \(liveActions.count). Selected"
        )
        #expect(
            CommandPaletteView.selectedResultAnnouncement(
                actions: [],
                selectedIndex: 0
            ) == nil
        )
    }

    @Test("arrow-key movement is silent when selection cannot change")
    func selectionMovementBoundaries() {
        #expect(
            CommandPaletteView.selectionIndex(
                afterMoving: 1,
                by: 1,
                total: 3
            ) == 2
        )
        #expect(
            CommandPaletteView.selectionIndex(
                afterMoving: 0,
                by: -1,
                total: 3
            ) == nil
        )
        #expect(
            CommandPaletteView.selectionIndex(
                afterMoving: 2,
                by: 1,
                total: 3
            ) == nil
        )
        #expect(
            CommandPaletteView.selectionIndex(
                afterMoving: 0,
                by: 1,
                total: 0
            ) == nil
        )
    }

    @Test("rows omit missing metadata without awkward punctuation")
    func accessibilityForRowsMissingOptionalMetadata() throws {
        let noSubtitle = try #require(
            actions().first { $0.id == "next-tab" }
        )
        let noShortcut = try #require(
            actions().first { $0.id == "tmux-new" }
        )

        #expect(
            CommandPaletteView.rowAccessibilityPresentation(
                for: noSubtitle,
                rowIndex: 1,
                total: 3,
                isSelected: false
            ) == .init(
                label: "Next Tab",
                value: "Shortcut ⇧⌘]. 2 of 3",
                hint: "Press Return or Space to run this command",
                isSelected: false
            )
        )
        #expect(
            CommandPaletteView.rowAccessibilityPresentation(
                for: noShortcut,
                rowIndex: 2,
                total: 3,
                isSelected: false
            ) == .init(
                label: "New tmux Session…",
                value: "Create a named session (repo name prefilled). 3 of 3",
                hint: "Press Return or Space to run this command",
                isSelected: false
            )
        )
    }

    @Test("hover and focus receive emphasis while focus gets a distinct stroke")
    func rowChromeParity() {
        let passive = CommandPaletteView.rowChromePresentation(
            isSelected: false,
            isHovered: false,
            isFocused: false
        )
        let selected = CommandPaletteView.rowChromePresentation(
            isSelected: true,
            isHovered: false,
            isFocused: false
        )
        let hovered = CommandPaletteView.rowChromePresentation(
            isSelected: false,
            isHovered: true,
            isFocused: false
        )
        let focused = CommandPaletteView.rowChromePresentation(
            isSelected: false,
            isHovered: false,
            isFocused: true
        )

        #expect(!passive.isEmphasized)
        #expect(!passive.showsFocusStroke)
        #expect(selected.isEmphasized)
        #expect(hovered.isEmphasized)
        #expect(focused.isEmphasized)
        #expect(focused.showsFocusStroke)
    }

    @Test("selection scroll honors Reduce Motion and Escape covers the whole palette")
    func motionAndDismissalPolicy() {
        #expect(CommandPaletteView.shouldAnimateSelectionScroll(reduceMotion: false))
        #expect(!CommandPaletteView.shouldAnimateSelectionScroll(reduceMotion: true))
        #expect(CommandPaletteView.escapeDismissalScope == .palette)
    }

    @Test("catalog derives shortcut and menu path from the live menu")
    func catalogUsesLiveMenuBindings() throws {
        let liveActions = actions()
        let shortcuts = try #require(liveActions.first { $0.id == "keyboard-shortcuts" })
        let find = try #require(liveActions.first { $0.id == "find" })
        let updates = try #require(liveActions.first { $0.id == "check-for-updates" })

        #expect(shortcuts.shortcutDisplay == "⌘/")
        #expect(shortcuts.menuPath == "Help")
        #expect(shortcuts.menuTitle == "Keyboard Shortcuts…")
        #expect(shortcuts.selector == #selector(AppDelegate.showKeyboardShortcuts(_:)))
        #expect(find.shortcutDisplay == "⌘F")
        #expect(find.menuPath == "Edit")
        #expect(find.menuTitle == "Find in Terminal…")
        #expect(updates.shortcutDisplay == nil)
        #expect(updates.menuPath == "herminal")
        #expect(updates.menuTitle == "Check for Updates…")
        #expect(updates.selector == #selector(AppDelegate.checkForUpdates(_:)))
    }

    @Test("filtering matches title, subtitle, menu path, menu title, and shortcut")
    func filterMatchesLiveMetadata() throws {
        let liveActions = actions()

        #expect(
            CommandPaletteView.filteredActions(liveActions, query: "help")
                .contains { $0.id == "keyboard-shortcuts" }
        )
        #expect(
            CommandPaletteView.filteredActions(liveActions, query: "⌘/")
                .contains { $0.id == "keyboard-shortcuts" }
        )
        #expect(
            CommandPaletteView.filteredActions(liveActions, query: "bug report")
                .contains { $0.id == "copy-redacted-diagnostics" }
        )
        #expect(
            CommandPaletteView.filteredActions(liveActions, query: "find in terminal")
                .contains { $0.id == "find" }
        )
        #expect(
            CommandPaletteView.filteredActions(liveActions, query: "latest release")
                .contains { $0.id == "check-for-updates" }
        )
    }

}
