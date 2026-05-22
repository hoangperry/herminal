// AppDelegate — builds the herminal window and drives the libghostty event loop.

import AppKit
import SwiftUI
import HerminalCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var ghostty: GhosttyApp?
    private var window: NSWindow?
    private var tickTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let ghostty: GhosttyApp
        do {
            ghostty = try GhosttyApp()
        } catch {
            NSLog("herminal: GhosttyApp startup failed: \(error)")
            NSApp.terminate(nil)
            return
        }
        self.ghostty = ghostty

        NSApp.mainMenu = AppMenu.build()

        let workspace = WorkspaceView(app: ghostty.app)
        let window = AppDelegate.makeWindow(contentView: workspace)
        self.window = window

        // libghostty's wakeup_cb is a no-op (C function pointers cannot capture
        // context), so a steady 60 Hz timer drives the event loop for the spike.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                ghostty.tick()
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    /// Builds the herminal window with premium chrome styled from design tokens.
    private static func makeWindow(contentView: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "herminal"
        window.contentView = contentView

        // Premium chrome: transparent title bar over a dark surface so the
        // window reads as one intentional dark panel, not default AppKit grey.
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(HerminalDesign.Palette.surfaceBase)
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 480, height: 320)

        window.center()
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
        tickTimer = nil
    }
}
