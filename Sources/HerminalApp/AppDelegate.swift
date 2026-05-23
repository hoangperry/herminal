// AppDelegate — builds the herminal window and drives the libghostty event loop.

import AppKit
import SwiftUI
import HerminalCore
import HerminalDB
import HerminalAgent

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var ghostty: GhosttyApp?
    private var window: NSWindow?
    private var tickTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Touch the diary singleton first so crash handlers install before
        // any libghostty / Metal init that could fault.
        Diary.shared.log("applicationDidFinishLaunching", category: "lifecycle")

        let ghostty: GhosttyApp
        do {
            ghostty = try GhosttyApp()
        } catch {
            Diary.shared.log("GhosttyApp startup failed: \(error)", category: "lifecycle")
            NSApp.terminate(nil)
            return
        }
        self.ghostty = ghostty

        NSApp.mainMenu = AppMenu.build()

        let workspace = WorkspaceView(
            app: ghostty.app,
            notesStore: AppDelegate.makeNotesStore(),
            sshHostsStore: AppDelegate.makeSSHHostsStore()
        )
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
        // M4-4 verification hook: when HERMINAL_TEST_SPAWN_COMMAND is set,
        // open a tab that runs the command via libghostty's `config.command`
        // path instead of the default shell. Used by
        // `Scripts/verify-ssh-spawn.sh` to prove the SSH-connect mechanism
        // wires through to a real PTY exec.
        if let spawnCommand = env["HERMINAL_TEST_SPAWN_COMMAND"] {
            NSLog("herminal: spawning test tab with command=\(spawnCommand)")
            Task { @MainActor in
                // Wait until the first tab settles before adding ours —
                // libghostty serializes surface creation on the IO thread.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                workspace.addTab(command: spawnCommand, title: "spawn-test")
            }
        }

        // M5 smoke-test hook: when HERMINAL_TEST_SMOKE_PLAN is set, walk
        // through a hardcoded sequence of interactive actions and dump the
        // resulting state to HERMINAL_TEST_STATE_DUMP. Used by
        // `Scripts/verify-smoke-m1-m3.sh` to assert tabs/splits/sidebars
        // all wire through without crashing or silently desyncing.
        if env["HERMINAL_TEST_SMOKE_PLAN"] != nil {
            let dumpPath = env["HERMINAL_TEST_STATE_DUMP"]
            scheduleSmokePlan(into: workspace, dumpPath: dumpPath)
        }
    }

    /// Walks the workspace through every interactive code path once so the
    /// harness can prove menus + toggles + splits + tabs all work. Spaced
    /// 0.5s apart to give libghostty time to react between actions.
    private func scheduleSmokePlan(into workspace: WorkspaceView, dumpPath: String?) {
        NSLog("herminal: smoke plan armed (dump=\(dumpPath ?? "<unset>"))")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            NSLog("herminal: smoke: addTab x2")
            workspace.addTab()
            try? await Task.sleep(nanoseconds: 500_000_000)
            workspace.addTab()
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSLog("herminal: smoke: split vertical x2")
            workspace.splitActivePane(vertical: true)
            try? await Task.sleep(nanoseconds: 500_000_000)
            workspace.splitActivePane(vertical: true)
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSLog("herminal: smoke: toggleAgentDashboard")
            workspace.toggleAgentDashboard(nil)
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSLog("herminal: smoke: toggleSSHHosts (mutex with agents)")
            workspace.toggleSSHHosts(nil)
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSLog("herminal: smoke: toggleNotes")
            workspace.toggleNotes(nil)
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSLog("herminal: smoke: nextTab x2")
            workspace.selectNextTab()
            try? await Task.sleep(nanoseconds: 200_000_000)
            workspace.selectNextTab()
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSLog("herminal: smoke: previousTab")
            workspace.selectPreviousTab()
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSLog("herminal: smoke: closeActivePane")
            workspace.closeActivePane()
            try? await Task.sleep(nanoseconds: 500_000_000)
            let state = workspace.dumpState()
            NSLog("herminal: smoke: final state\n\(state)")
            if let dumpPath {
                try? state.write(toFile: dumpPath, atomically: true, encoding: .utf8)
                NSLog("herminal: smoke: state written to \(dumpPath)")
            }
        }
    }

    private func scheduleTestInjection(text: String, into workspace: WorkspaceView) {
        let preInjectDelaySeconds = ProcessInfo.processInfo.environment["HERMINAL_TEST_DELAY"]
            .flatMap { UInt64($0) } ?? 8
        NSLog("herminal: test harness scheduled (will inject in \(preInjectDelaySeconds)s)")
        let agentDumpPath = ProcessInfo.processInfo.environment["HERMINAL_TEST_AGENT_DUMP"]
        Task { @MainActor in
            // Default 8s lets a normal interactive shell finish init and
            // render its first prompt. Heavy .zshrc setups (oh-my-zsh +
            // pyenv + nvm + ...) need more — override via HERMINAL_TEST_DELAY.
            try? await Task.sleep(nanoseconds: preInjectDelaySeconds * 1_000_000_000)
            NSLog("herminal: injecting test text (\(text.count) chars)")
            workspace.injectTextIntoActivePane(text)

            if let agentDumpPath {
                // Give the injected command time to spawn its child process —
                // shell parse + fork + exec can take a couple of seconds.
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                let agents = AgentDetector.detectAgents()
                var lines = agents
                    .map { "\($0.kind.rawValue) \($0.processName) \($0.pid)" }
                if ProcessInfo.processInfo.environment["HERMINAL_TEST_TREE_DUMP"] != nil {
                    // Diagnostic: include the whole subtree so the harness can
                    // see what zsh actually spawned. Helps debug missing matches.
                    lines.append("--- full subtree ---")
                    lines.append(contentsOf: AgentDetector.dumpSubtree(of: getpid()))
                }
                let dump = lines.joined(separator: "\n")
                try? dump.write(toFile: agentDumpPath, atomically: true, encoding: .utf8)
                NSLog("herminal: dumped \(agents.count) agents to \(agentDumpPath)")
            }
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
            let dbPath = try appSupportFile("notes.db")
            return try NotesStore(.uri(dbPath))
        } catch {
            NSLog("herminal: notes DB unavailable (\(error)) — using in-memory store")
            // In-memory SQLite effectively never fails to open.
            return try! NotesStore(.inMemory)
        }
    }

    /// Opens the SSH hosts database in Application Support, falling back to
    /// an in-memory store if the on-disk location is unavailable.
    private static func makeSSHHostsStore() -> SSHHostsStore {
        do {
            let dbPath = try appSupportFile("ssh-hosts.db")
            return try SSHHostsStore(.uri(dbPath))
        } catch {
            NSLog("herminal: ssh hosts DB unavailable (\(error)) — using in-memory store")
            return try! SSHHostsStore(.inMemory)
        }
    }

    /// Resolves an Application Support file path under our app subdirectory,
    /// creating the directory on demand. Centralises the duplicate plumbing
    /// the two store factories were repeating.
    private static func appSupportFile(_ name: String) throws -> String {
        let fileManager = FileManager.default
        let directory = try fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("herminal", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name).path
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Diary.shared.log("applicationWillTerminate", category: "lifecycle")
        Diary.shared.flush()
        tickTimer?.invalidate()
        tickTimer = nil
    }
}
