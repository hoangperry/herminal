// AppDelegate — builds the herminal window and drives the libghostty event loop.
// Month-1 spike scope: one window, one terminal surface, timer-driven ticks.

import AppKit
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

        let surfaceView = HerminalSurfaceView(app: ghostty.app)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "herminal"
        window.contentView = surfaceView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(surfaceView)
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
        tickTimer = nil
    }
}
