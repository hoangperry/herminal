// PreferencesWindow — owns the single NSWindow that hosts PreferencesView.
//
// SwiftUI's `Settings` scene is the cleaner way to do this in an app
// that uses the SwiftUI lifecycle, but herminal is an AppKit
// @NSApplicationDelegateAdaptor host (so libghostty's NSView surfaces
// can attach Metal layers correctly). The AppKit-native equivalent is
// one window controller managing one window with an NSHostingView
// inside it.
//
// One window per process; opening twice raises the existing instance.

import AppKit
import SwiftUI

@MainActor
public enum PreferencesWindow {
    private static var window: NSWindow?

    /// Opens the Preferences window. If already open, brings it to
    /// front. Called from `AppMenu` → `Settings...`.
    public static func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingView(rootView: PreferencesView())
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "herminal — Preferences"
        panel.contentView = hosting
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = panel

        // Drop the static reference when the user closes the window so a
        // re-open builds a fresh NSHostingView. Without this, `show()`
        // returns the cached instance forever, and any @AppStorage
        // binding that was seeded BEFORE registerDefaults() ran would
        // remain stuck on the unseeded value for the whole process.
        // (M12 review HIGH — code-reviewer finding 3.)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { PreferencesWindow.window = nil }
        }
    }
}
