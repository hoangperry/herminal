import AppKit

@MainActor
extension HerminalSurfaceView {
    static func editActionIsEnabled(
        _ action: Selector?,
        hasSurface: Bool,
        hasSelection: Bool,
        hasPasteboardString: Bool
    ) -> Bool {
        guard hasSurface else { return false }

        switch action {
        case #selector(copy(_:)), #selector(cut(_:)):
            return hasSelection
        case #selector(paste(_:)):
            return hasPasteboardString
        case #selector(selectAll(_:)):
            return true
        default:
            return true
        }
    }

    /// Builds the fallback menu used only when libghostty does not claim
    /// the right click. Kept separate from event handling so menu order and
    /// responder routing can be regression-tested without a live PTY.
    func makeFallbackContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(localMenuItem("Copy", action: #selector(copy(_:)), keyEquivalent: "c"))
        menu.addItem(localMenuItem("Paste", action: #selector(paste(_:)), keyEquivalent: "v"))
        menu.addItem(localMenuItem("Select All", action: #selector(selectAll(_:)), keyEquivalent: "a"))
        menu.addItem(.separator())

        let find = NSMenuItem(
            title: "Find in Terminal…",
            action: #selector(WorkspaceView.findInScrollback(_:)),
            keyEquivalent: "f"
        )
        find.target = nil
        find.keyEquivalentModifierMask = .command
        menu.addItem(find)
        return menu
    }

    private func localMenuItem(
        _ title: String,
        action: Selector,
        keyEquivalent: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = .command
        return item
    }
}
