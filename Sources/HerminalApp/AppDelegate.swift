// AppDelegate — builds the herminal window and drives the libghostty event loop.

import AppKit
import SwiftUI
import HerminalCore
import HerminalDB
import HerminalAgent

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var ghostty: GhosttyApp?
    private var window: NSWindow?
    private var tickTimer: Timer?
    /// Set after we restore the workspace state in didFinishLaunching so
    /// the windowDidMove/Resize callbacks don't write back the default
    /// frame on first launch. (M12-P5)
    private var windowStateReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register UserDefaults defaults FIRST so any other init code that
        // reads a preference sees a stable default rather than a nil/0
        // fallback. (M12-P1)
        Preferences.registerDefaults()
        // Hydrate the design palette from the persisted theme preference
        // BEFORE any SwiftUI host evaluates a Palette token. Without this,
        // the first window paint flashes the .dark default for one frame
        // even when the user picked .light.
        AppDelegate.applyPersistedTheme()
        // Touch the diary singleton next so crash handlers install before
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

        let savedState = WindowState.load()
        let workspace = WorkspaceView(
            app: ghostty.app,
            notesStore: AppDelegate.makeNotesStore(),
            sshHostsStore: AppDelegate.makeSSHHostsStore()
        )
        workspace.applyRestoredSidebarState(savedState)
        let window = AppDelegate.makeWindow(contentView: workspace,
                                            savedFrame: savedState.frame)
        window.delegate = self
        self.window = window
        windowStateReady = true

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

        // v0.3.1 — register the global ⌥Space hotkey. Safe to call
        // even if the combo is already grabbed; HotkeyManager logs
        // the conflict and the menu-bar binding still works.
        HotkeyManager.shared.install()

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
        if env["HERMINAL_TEST_CLIPBOARD"] != nil {
            let dumpPath = Self.validatedDumpPath(env["HERMINAL_TEST_CLIPBOARD_DUMP"])
            scheduleClipboardSmoke(into: workspace, dumpPath: dumpPath)
        }
        if env["HERMINAL_TEST_TITLE"] != nil {
            let dumpPath = Self.validatedDumpPath(env["HERMINAL_TEST_TITLE_DUMP"])
            scheduleTitleSmoke(into: workspace, dumpPath: dumpPath)
        }
    }

    /// OSC 0/2 title-set smoke (v0.2.4 regression-guard). Injects an
    /// `\033]0;...\007` escape into the shell, waits for libghostty to
    /// dispatch GHOSTTY_ACTION_SET_TITLE, then dumps the active tab's
    /// title from WorkspaceView's state snapshot. The shell-side
    /// script asserts the title matches the marker.
    private func scheduleTitleSmoke(into workspace: WorkspaceView, dumpPath: String?) {
        let marker = "TITLE_REGRESSION_MARKER_42"
        NSLog("herminal: title smoke armed (dump=\(dumpPath ?? "<unset>"))")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            NSLog("herminal: title smoke — injecting OSC 0 with marker")
            // OSC 0 sets both window and icon title; BEL terminates.
            // Using printf so the escape literal isn't mangled by zsh.
            workspace.injectTextIntoActivePane(
                "printf '\\033]0;\(marker)\\007'\n"
            )
            // Let libghostty parse the OSC + post the notification +
            // WorkspaceView rebuild the tab strip.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let state = workspace.dumpState()
            let titleLine = state
                .split(separator: "\n")
                .first(where: { $0.hasPrefix("active_title=") })
                .map { String($0) } ?? "<no-title-line>"
            let title = titleLine.replacingOccurrences(of: "active_title=", with: "")
            let containsMarker = title.contains(marker)
            let result = """
                marker=\(marker)
                active_title=\(title)
                title_contains_marker=\(containsMarker)
                """
            NSLog("herminal: title smoke result:\n\(result)")
            if let dumpPath {
                try? result.write(toFile: dumpPath, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Clipboard round-trip smoke (v0.2.2 regression-guard). Injects a
    /// known marker via `echo`, triggers libghostty's `select_all` and
    /// `copy_to_clipboard` binding actions, then reads the standard
    /// pasteboard and writes a structured result to `dumpPath`. The
    /// shell-side script asserts the pasteboard contains the marker —
    /// proving the read_clipboard_cb / write_clipboard_cb wiring plus
    /// the binding-action plumbing land bytes where they should.
    private func scheduleClipboardSmoke(into workspace: WorkspaceView, dumpPath: String?) {
        let marker = "CLIPBOARD_REGRESSION_MARKER_42"
        NSLog("herminal: clipboard smoke armed (dump=\(dumpPath ?? "<unset>"))")
        Task { @MainActor in
            // 8 s gives the shell + .zshrc time to render its first prompt.
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            NSLog("herminal: clipboard smoke — injecting marker")
            workspace.injectTextIntoActivePane("echo \(marker)\n")
            // Give the echo time to actually print + the renderer time to
            // commit the row before we select_all.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            NSLog("herminal: clipboard smoke — select_all")
            workspace.triggerBindingActionOnActivePane("select_all")
            try? await Task.sleep(nanoseconds: 500_000_000)
            let hadSelection = workspace.activePaneHasSelection()
            NSLog("herminal: clipboard smoke — has_selection=\(hadSelection)")
            workspace.triggerBindingActionOnActivePane("copy_to_clipboard")
            // write_clipboard_cb is synchronous on our main loop, but
            // give a beat for any state-machine settling.
            try? await Task.sleep(nanoseconds: 300_000_000)
            let pb = NSPasteboard.general.string(forType: .string) ?? ""
            let containsMarker = pb.contains(marker)
            let result = """
                marker=\(marker)
                has_selection=\(hadSelection)
                pasteboard_contains_marker=\(containsMarker)
                pasteboard_len=\(pb.count)
                """
            NSLog("herminal: clipboard smoke result:\n\(result)")
            if let dumpPath {
                try? result.write(toFile: dumpPath, atomically: true, encoding: .utf8)
                NSLog("herminal: clipboard smoke result written to \(dumpPath)")
            }
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
    private static func makeWindow(contentView: NSView,
                                   savedFrame: NSRect? = nil) -> NSWindow {
        let defaultRect = NSRect(x: 0, y: 0, width: 900, height: 560)
        let window = NSWindow(
            contentRect: savedFrame ?? defaultRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "herminal"

        // v0.3 polish — wrap the workspace inside an NSVisualEffectView so
        // the dark surface picks up the macOS background-blur material.
        // Without this the app reads as a flat hex-color box and the
        // owner's "không đã" feedback maps directly here (research note
        // docs/research/09-polish-audit.md, root-cause table row 1).
        //
        // .underWindowBackground material keeps the chrome dark in dark
        // mode and light in light mode — matches the dynamic theme without
        // us having to chase appearance changes manually.
        let effect = NSVisualEffectView()
        effect.material = .underWindowBackground
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        effect.frame = contentView.bounds
        contentView.autoresizingMask = [.width, .height]
        effect.addSubview(contentView)
        window.contentView = effect

        // Premium chrome: transparent title bar over the vibrancy layer.
        // Background colour is left clear so the visual-effect material
        // shows through; setting backgroundColor would punch a flat
        // rectangle on top of the blur.
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 480, height: 320)

        if savedFrame == nil {
            window.center()
        } else {
            // setFrame after construction so AppKit clamps to the screen if
            // needed (the centre-in-screen check in WindowState already
            // filtered out wildly invalid frames).
            window.setFrame(savedFrame!, display: false)
        }
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

    /// AppMenu's "Settings…" item targets this method (⌘,). Lifts the
    /// PreferencesWindow into view; opens it lazily on first use.
    @objc func openPreferences(_ sender: Any?) {
        PreferencesWindow.show()
    }

    // MARK: - Polish wave slice 2 — palette + hotkey (v0.3.1)

    /// ⌘⇧P — toggle the floating command palette. Indexed actions
    /// dispatch via the standard responder chain so the palette
    /// doesn't need to know what currently has focus.
    @objc func toggleCommandPalette(_ sender: Any?) {
        CommandPalette.toggle()
    }

    /// ⌥Space — bring herminal forward from anywhere on macOS, or
    /// hide it if it's already key. The Carbon hotkey installed in
    /// `applicationDidFinishLaunching` fires the same path so the
    /// behaviour is identical whether the user is inside or outside
    /// herminal.
    @objc func toggleHotkeyWindow(_ sender: Any?) {
        HotkeyManager.shared.handleFired()
    }

    // MARK: - NSWindowDelegate (M12-P5)

    func windowDidResize(_ notification: Notification) {
        persistWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        persistWindowFrame()
    }

    private func persistWindowFrame() {
        guard windowStateReady, let frame = window?.frame else { return }
        WindowState.saveFrame(frame)
    }

    /// Sets `HerminalDesign.currentTheme` from the persisted preference.
    /// `.system` follows NSApp.effectiveAppearance; `.dark` / `.light`
    /// force the matching value regardless of system setting.
    private static func applyPersistedTheme() {
        switch Preferences.theme {
        case .dark:
            HerminalDesign.currentTheme = .dark
        case .light:
            HerminalDesign.currentTheme = .light
        case .system:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            HerminalDesign.currentTheme = isDark ? .dark : .light
        }
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
