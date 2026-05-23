// AppDelegate — builds the herminal window and drives the libghostty event loop.

import AppKit
import SwiftUI
import HerminalCore
import HerminalDB

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

        let workspace = WorkspaceView(app: ghostty.app, notesStore: AppDelegate.makeNotesStore())
        let window = AppDelegate.makeWindow(contentView: workspace)
        self.window = window

        // libghostty's wakeup_cb is a no-op (C function pointers cannot capture
        // context), so a steady 60 Hz timer drives the event loop for the spike.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                let start = ContinuousClock.now
                ghostty.tick()
                LatencyProbe.shared.recordTick(ContinuousClock.now - start)
            }
        }

        NSApp.activate(ignoringOtherApps: true)

        // GUI test harness: when HERMINAL_TEST_TEXT is set, inject the text
        // into the active surface and exit. Lets CI / a script drive herminal
        // without osascript / system IME interference.
        let env = ProcessInfo.processInfo.environment
        NSLog("herminal: HERMINAL_TEST_TEXT=\(env["HERMINAL_TEST_TEXT"]?.debugDescription ?? "<unset>")")
        if let testText = env["HERMINAL_TEST_TEXT"] {
            scheduleTestInjection(text: testText, into: workspace)
        }
    }

    private func scheduleTestInjection(text: String, into workspace: WorkspaceView) {
        NSLog("herminal: test harness scheduled (will inject in 4s)")
        Task { @MainActor in
            // 4 seconds lets the shell finish login + shell-integration setup
            // even on a cold cache. Anything less is flaky.
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            NSLog("herminal: injecting test text (\(text.count) chars)")
            workspace.injectTextIntoActivePane(text)
            // The harness script controls lifecycle (polls for the expected
            // side-effect, then pkill). Self-terminating here would close the
            // shell before its output had a chance to flush.
        }
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

    /// Opens the notes database in Application Support, falling back to an
    /// in-memory store if the on-disk location is unavailable.
    private static func makeNotesStore() -> NotesStore {
        do {
            let fileManager = FileManager.default
            let directory = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            ).appendingPathComponent("herminal", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let dbPath = directory.appendingPathComponent("notes.db").path
            return try NotesStore(.uri(dbPath))
        } catch {
            NSLog("herminal: notes DB unavailable (\(error)) — using in-memory store")
            // In-memory SQLite effectively never fails to open.
            return try! NotesStore(.inMemory)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
        tickTimer = nil
    }
}
