// WindowState — internal persistence for the workspace window's
// last-seen geometry + sidebar layout.
//
// Kept separate from `Preferences` because these are NOT user-facing
// settings; they're the kind of thing macOS apps quietly remember
// between launches (window position, "was the notes pane open last
// time?"). Reading them is opportunistic: if we can't validate the
// stored frame against the current screens, we fall back to the
// default centred geometry.

import AppKit

enum WindowState {

    /// Snapshot of the workspace's restorable state. All fields default
    /// to "no opinion" so a fresh launch (or a stored frame that no
    /// longer fits any attached screen) keeps the existing behaviour.
    struct Snapshot: Equatable {
        var frame: NSRect?
        var leftSidebar: LeftSidebar
        var notesVisible: Bool

        static let empty = Snapshot(
            frame: nil,
            leftSidebar: .none,
            notesVisible: false
        )
    }

    /// Mirrors WorkspaceView's private LeftSidebar enum. Lives at module
    /// scope so the AppDelegate can read it without exposing the
    /// internal type. Persisted as the raw String.
    enum LeftSidebar: String {
        case none, agents, ssh
    }

    private enum Key {
        static let frameX = "windowState.frame.x"
        static let frameY = "windowState.frame.y"
        static let frameW = "windowState.frame.w"
        static let frameH = "windowState.frame.h"
        static let leftSidebar = "windowState.leftSidebar"
        static let notesVisible = "windowState.notesVisible"
    }

    /// Reads the snapshot, validating any stored frame against the
    /// current screen list. An off-screen frame (e.g. saved when a
    /// second monitor was attached) is rejected so the user doesn't
    /// launch into an invisible window.
    static func load() -> Snapshot {
        let defaults = UserDefaults.standard
        let frame: NSRect?
        if defaults.object(forKey: Key.frameW) != nil {
            let candidate = NSRect(
                x: defaults.double(forKey: Key.frameX),
                y: defaults.double(forKey: Key.frameY),
                width: defaults.double(forKey: Key.frameW),
                height: defaults.double(forKey: Key.frameH)
            )
            frame = isFrameOnAnyScreen(candidate) ? candidate : nil
        } else {
            frame = nil
        }
        let sidebarRaw = defaults.string(forKey: Key.leftSidebar) ?? LeftSidebar.none.rawValue
        let notesVisible = defaults.bool(forKey: Key.notesVisible)
        return Snapshot(
            frame: frame,
            leftSidebar: LeftSidebar(rawValue: sidebarRaw) ?? .none,
            notesVisible: notesVisible
        )
    }

    static func saveFrame(_ frame: NSRect) {
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: Key.frameX)
        defaults.set(frame.origin.y, forKey: Key.frameY)
        defaults.set(frame.size.width, forKey: Key.frameW)
        defaults.set(frame.size.height, forKey: Key.frameH)
    }

    static func saveSidebar(left: LeftSidebar, notesVisible: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(left.rawValue, forKey: Key.leftSidebar)
        defaults.set(notesVisible, forKey: Key.notesVisible)
    }

    /// True when the stored rect's centre point lands inside at least
    /// one currently-attached screen's visible frame. Rejecting more
    /// strictly (full rect inside one screen) would discard valid
    /// multi-monitor straddle layouts.
    private static func isFrameOnAnyScreen(_ frame: NSRect) -> Bool {
        // Reject NaN / infinity explicitly. `>=` on NaN evaluates false
        // (NaN-safe by accident), but +infinity passes a `>= 200` check
        // and then breaks downstream geometry — guard at the entry.
        // (M12 review MEDIUM — security-reviewer finding 2.)
        guard frame.width.isFinite,
              frame.height.isFinite,
              frame.origin.x.isFinite,
              frame.origin.y.isFinite,
              frame.width >= 200,
              frame.height >= 200 else { return false }
        let centre = NSPoint(x: frame.midX, y: frame.midY)
        for screen in NSScreen.screens where screen.visibleFrame.contains(centre) {
            return true
        }
        return false
    }
}
