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

        // GUI test harness — debug builds only. M11-A2 fix
        // (HIGH H-1 + H-2 from security-reviewer): these env hooks let an
        // attacker who can set environment variables before launch (a
        // child shell that re-exports env, a parent process with control
        // over our env) trigger arbitrary command execution or write to
        // arbitrary user-writable paths. Compiling them out of release
        // binaries closes that vector entirely while keeping the harness
        // intact for `swift test`, CI, and local owner runs (which build
        // debug by default).
        #if DEBUG
        installTestHarnessHooks(workspace: workspace)
        #endif
    }

    #if DEBUG
    /// All HERMINAL_TEST_* env hook wiring lives here so release builds
    /// genuinely don't carry the code. Keep production AppDelegate
    /// methods free of any reference into this function.
    private func installTestHarnessHooks(workspace: WorkspaceView) {
        let env = ProcessInfo.processInfo.environment
        // Log the harness text only when actually set — production paths
        // shouldn't emit env-var noise into Apple's unified log even in
        // debug builds (M11-A2 fix, MEDIUM M-5).
        if let testText = env["HERMINAL_TEST_TEXT"] {
            NSLog("herminal: HERMINAL_TEST_TEXT set (%d chars)", testText.count)
            scheduleTestInjection(text: testText, into: workspace)
        }
        if let spawnCommand = env["HERMINAL_TEST_SPAWN_COMMAND"] {
            NSLog("herminal: spawning test tab")
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                workspace.addTab(command: spawnCommand, title: "spawn-test")
            }
        }
        if env["HERMINAL_TEST_SMOKE_PLAN"] != nil {
            let dumpPath = Self.validatedDumpPath(env["HERMINAL_TEST_STATE_DUMP"])
            scheduleSmokePlan(into: workspace, dumpPath: dumpPath)
        }
    }

    /// M11-A2 fix (HIGH H-1 from security-reviewer): refuse dump paths
    /// outside the temp directory. Even in debug builds we want the
    /// harness to fail loudly rather than silently overwriting a user
    /// file at `~/.zshrc` or `~/.ssh/authorized_keys`.
    private static func validatedDumpPath(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let tmpRoot = NSTemporaryDirectory()
        // `/tmp/...` resolves to `/private/tmp/...` on macOS; accept both
        // shapes since callers commonly write the short form in scripts.
        let allowedPrefixes = [tmpRoot, "/tmp/", "/private/tmp/", "/var/folders/"]
        let absolute = (raw as NSString).standardizingPath
        if allowedPrefixes.contains(where: { absolute.hasPrefix($0) }) {
            return absolute
        }
        NSLog("herminal: HERMINAL_TEST_STATE_DUMP rejected (must live under a temp dir): %@", raw)
        return nil
    }
    #endif

    #if DEBUG
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
        // Sandbox the dump path the same way the smoke plan does
        // (M11-A2 fix, HIGH H-1 from security-reviewer).
        let agentDumpPath = Self.validatedDumpPath(
            ProcessInfo.processInfo.environment["HERMINAL_TEST_AGENT_DUMP"]
        )
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
    #endif

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
