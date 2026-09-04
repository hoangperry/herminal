// AppDelegate — builds the herminal window and drives the libghostty event loop.

import AppKit
import SwiftUI
import HerminalCore
import HerminalDB
import HerminalAgent

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var ghostty: GhosttyApp?
    private var window: NSWindow?
    /// Kept so `applicationWillTerminate` can snapshot the workspace for
    /// session restore. (v0.4.1)
    private var workspace: WorkspaceView?
    /// The "Open Workspace" submenu — repopulated on open via
    /// `menuNeedsUpdate`. Owned here so the delegate identity check
    /// works. (v0.4.2)
    private let workspaceSubmenu = NSMenu(title: "Open Workspace")
    private var tickTimer: Timer?
    /// Observes the app-level appearance (which remains system-driven even
    /// though the window is pinned to Herminal's resolved chrome theme).
    private var systemAppearanceObservation: NSKeyValueObservation?
    /// Set after we restore the workspace state in didFinishLaunching so
    /// the windowDidMove/Resize callbacks don't write back the default
    /// frame on first launch. (M12-P5)
    private var windowStateReady = false
    private var closeRiskGate = CloseRiskGate()

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
        installSystemAppearanceObservation()
        // Touch the diary singleton next so crash handlers install before
        // any libghostty / Metal init that could fault.
        Diary.shared.log("applicationDidFinishLaunching", category: "lifecycle")

        let ghostty: GhosttyApp
        do {
            ghostty = try GhosttyApp()
        } catch {
            Diary.shared.log("GhosttyApp startup failed", category: "lifecycle")
            NSApp.terminate(nil)
            return
        }
        self.ghostty = ghostty

        workspaceSubmenu.delegate = self
        let mainMenu = AppMenu.build(openWorkspaceSubmenu: workspaceSubmenu)
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = AppMenu.windowMenu(in: mainMenu)
        NSApp.helpMenu = AppMenu.helpMenu(in: mainMenu)
        NSApp.servicesMenu = AppMenu.servicesMenu(in: mainMenu)

        let savedState = WindowState.load()
        let notesStorage = AppDelegate.makeNotesStore()
        let sshHostsStorage = AppDelegate.makeSSHHostsStore()
        let workspace = WorkspaceView(
            app: ghostty.app,
            notesStore: notesStorage.store,
            notesStorageIsDurable: notesStorage.isDurable,
            sshHostsStore: sshHostsStorage.store,
            sshHostsStorageIsDurable: sshHostsStorage.isDurable
        )
        // GUI-harness isolation: the test harnesses drive the workspace
        // from a clean default start and assert against it, so they must
        // NOT restore a prior session/sidebar on top — and must not
        // persist (which would clobber the owner's real workspace.json
        // with the test's throwaway layout, and let a restored layout race
        // the injection path). Covers every workspace-driving harness;
        // RESTORE_DUMP is deliberately excluded because it *tests* restore.
        // Debug-only so release builds never read these.
        var harnessIsolation = false
        #if DEBUG
        let harnessEnv = ProcessInfo.processInfo.environment
        let isolatingHooks = [
            "HERMINAL_TEST_SMOKE_PLAN", "HERMINAL_TEST_NAV", "HERMINAL_TEST_TEXT",
            "HERMINAL_TEST_CLIPBOARD", "HERMINAL_TEST_TITLE",
        ]
        harnessIsolation = isolatingHooks.contains { harnessEnv[$0] != nil }
        #endif
        if !harnessIsolation {
            workspace.applyRestoredSidebarState(savedState)
        }

        // v0.4.1 — session restore. If the owner left the restore
        // preference on and a snapshot exists, rebuild the tab/pane/split
        // layout. Panes open as plain shells unless the owner also opted into
        // replaying supported launch intents. Then enable persistence so
        // subsequent structural changes are saved. When restore is off, clear
        // any stale snapshot so it doesn't resurrect later if the owner flips
        // the toggle back on.
        if !harnessIsolation, Preferences.restoreSessionOnLaunch, let snapshot = WorkspaceStore.load() {
            workspace.restoreWorkspace(snapshot)
        } else if !harnessIsolation, !Preferences.restoreSessionOnLaunch {
            WorkspaceStore.clear()
        }
        if !harnessIsolation {
            workspace.enableSessionPersistence()
        }
        self.workspace = workspace
        let window = AppDelegate.makeWindow(contentView: workspace,
                                            savedFrame: savedState.frame)
        window.delegate = self
        self.window = window
        windowStateReady = true

        // libghostty's wakeup_cb is a no-op (C function pointers can't
        // capture context), so a timer drives the event loop. Full 60 Hz
        // while the window's content is on screen; throttled when it's
        // fully occluded (miniaturised / covered) so we don't burn the CPU
        // rendering a hidden window. libghostty's PTY IO runs on its own
        // thread, so a slower app tick never stalls a background process —
        // it just renders less until the window is visible again.
        installTickTimer()
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowOcclusionDidChange),
            name: NSWindow.didChangeOcclusionStateNotification, object: window
        )

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

    /// The driver-tick interval: full 60 Hz when the window's content is
    /// visible, throttled to 10 Hz when it's fully occluded. 10 Hz still
    /// drains libghostty's cross-thread mailbox (title/bell/pwd/close
    /// events) promptly while saving the bulk of the idle-render wakeups.
    private func tickInterval() -> TimeInterval {
        let visible = window?.occlusionState.contains(.visible) ?? true
        return visible ? (1.0 / 60.0) : (1.0 / 10.0)
    }

    /// (Re)installs the driver tick timer at the current interval.
    private func installTickTimer() {
        tickTimer?.invalidate()
        guard let ghostty = self.ghostty else { return }
        tickTimer = Timer.scheduledTimer(withTimeInterval: tickInterval(), repeats: true) { _ in
            MainActor.assumeIsolated {
                let start = ContinuousClock.now
                ghostty.tick()
                LatencyProbe.shared.recordTick(ContinuousClock.now - start)
            }
        }
    }

    @objc private func windowOcclusionDidChange() {
        installTickTimer()
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
        if env["HERMINAL_TEST_NAV"] != nil {
            let dumpPath = Self.validatedDumpPath(env["HERMINAL_TEST_NAV_DUMP"])
            scheduleNavSmoke(into: workspace, dumpPath: dumpPath)
        }
        if env["HERMINAL_TEST_CLIPBOARD"] != nil {
            let dumpPath = Self.validatedDumpPath(env["HERMINAL_TEST_CLIPBOARD_DUMP"])
            scheduleClipboardSmoke(into: workspace, dumpPath: dumpPath)
        }
        if env["HERMINAL_TEST_TITLE"] != nil {
            let dumpPath = Self.validatedDumpPath(env["HERMINAL_TEST_TITLE_DUMP"])
            scheduleTitleSmoke(into: workspace, dumpPath: dumpPath)
        }
        if env["HERMINAL_TEST_RESTORE_DUMP"] != nil {
            let dumpPath = Self.validatedDumpPath(env["HERMINAL_TEST_RESTORE_DUMP"])
            scheduleRestoreDump(into: workspace, dumpPath: dumpPath)
        }
    }

    /// Session-restore regression hook (v0.4.1 carry-forward). Restore
    /// already ran in `applicationDidFinishLaunching` before this fires;
    /// we just wait for the launch to settle, then dump the workspace
    /// state so `verify-session-restore.sh` can assert the crafted
    /// snapshot was rebuilt. Pure read — no mutation.
    private func scheduleRestoreDump(into workspace: WorkspaceView, dumpPath: String?) {
        NSLog("herminal: restore-dump armed")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            let state = workspace.dumpState()
            NSLog("herminal: restore-dump state captured")
            if let dumpPath {
                try? state.write(toFile: dumpPath, atomically: true, encoding: .utf8)
            }
        }
    }

    /// OSC 0/2 title-set smoke (v0.2.4 regression-guard). Injects an
    /// `\033]0;...\007` escape into the shell, waits for libghostty to
    /// dispatch GHOSTTY_ACTION_SET_TITLE, then dumps the active tab's
    /// title from WorkspaceView's state snapshot. The shell-side
    /// script asserts the title matches the marker.
    private func scheduleTitleSmoke(into workspace: WorkspaceView, dumpPath: String?) {
        let marker = "TITLE_REGRESSION_MARKER_42"
        NSLog("herminal: title smoke armed")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            NSLog("herminal: title smoke — injecting OSC 0 with marker")
            // OSC 0 sets both window and icon title; BEL terminates. Keep the
            // shell busy briefly after printf: otherwise the next prompt's OSC
            // cwd title can legitimately overwrite the marker before we sample.
            workspace.injectTextIntoActivePane(
                "printf '\\033]0;\(marker)\\007'; sleep 5\n"
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
            NSLog("herminal: title smoke completed success=\(containsMarker)")
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
        NSLog("herminal: clipboard smoke armed")
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
            NSLog("herminal: clipboard smoke completed success=\(containsMarker)")
            if let dumpPath {
                try? result.write(toFile: dumpPath, atomically: true, encoding: .utf8)
                NSLog("herminal: clipboard smoke result written")
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
        NSLog("herminal: test dump path rejected (must live under a temp dir)")
        return nil
    }
    #endif

    #if DEBUG
    /// Walks the workspace through every interactive code path once so the
    /// harness can prove menus + toggles + splits + tabs all work. Spaced
    /// 0.5s apart to give libghostty time to react between actions.
    private func scheduleSmokePlan(into workspace: WorkspaceView, dumpPath: String?) {
        NSLog("herminal: smoke plan armed")
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
            NSLog("herminal: smoke: final state captured")
            if let dumpPath {
                try? state.write(toFile: dumpPath, atomically: true, encoding: .utf8)
                NSLog("herminal: smoke: state written")
            }
        }
    }

    /// Directional-nav guard (v0.5.1): split vertically (focus lands on the
    /// new right pane, index 1), then move focus LEFT. If spatial nav works
    /// the focused pane becomes index 0; if it no-ops, it stays 1 — so the
    /// dumped `focused_pane` distinguishes working from broken.
    private func scheduleNavSmoke(into workspace: WorkspaceView, dumpPath: String?) {
        NSLog("herminal: nav smoke armed")
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            workspace.splitActivePane(vertical: true)
            try? await Task.sleep(nanoseconds: 500_000_000)
            workspace.moveFocus(.left)
            try? await Task.sleep(nanoseconds: 300_000_000)
            let state = workspace.dumpState()
            NSLog("herminal: nav smoke: final state captured")
            if let dumpPath {
                try? state.write(toFile: dumpPath, atomically: true, encoding: .utf8)
                NSLog("herminal: nav smoke: result written")
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
                NSLog("herminal: dumped \(agents.count) agents to test output")
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
            // fullSizeContentView lets the workspace own the titlebar row so
            // the tab strip can live there instead of below it — one bar of
            // chrome above the terminal rather than two. Verified that a
            // content-view subview in that row still receives clicks while
            // the traffic lights keep their own region.
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Title stays set for Mission Control and the Window menu, but the
        // tab strip occupies that row now, so AppKit must not draw it.
        window.title = "herminal"
        window.titleVisibility = .hidden

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
        // Pin the whole window to our theme rather than System Settings;
        // it cascades to the vibrancy material and to everything AppKit
        // draws itself. Unpinned, a light-appearance Mac running our dark
        // chrome resolves the material near-white — it bleeds through the
        // surface inset and the pane seams — and renders the title text in
        // dark grey on our dark titlebar. See HerminalDesign.nsAppearance.
        window.appearance = HerminalDesign.nsAppearance
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
    private static func makeNotesStore() -> (store: NotesStore, isDurable: Bool) {
        do {
            let dbPath = try appSupportFile("notes.db")
            return (try NotesStore(.uri(dbPath)), true)
        } catch {
            NSLog("herminal: notes DB unavailable — using in-memory store")
            // In-memory SQLite effectively never fails to open.
            return (try! NotesStore(.inMemory), false)
        }
    }

    /// Opens the SSH hosts database in Application Support, falling back to
    /// an in-memory store if the on-disk location is unavailable.
    private static func makeSSHHostsStore() -> (store: SSHHostsStore, isDurable: Bool) {
        do {
            let dbPath = try appSupportFile("ssh-hosts.db")
            return (store: try SSHHostsStore(.uri(dbPath)), isDurable: true)
        } catch {
            NSLog("herminal: ssh hosts DB unavailable — using in-memory store")
            return (store: try! SSHHostsStore(.inMemory), isDurable: false)
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

    /// Opens the searchable shortcut reference generated from the installed
    /// main menu, keeping help copy aligned with the bindings users can run.
    @objc func showKeyboardShortcuts(_ sender: Any?) {
        KeyboardShortcutsWindow.show(menu: NSApp.mainMenu)
    }

    /// Opens the official GitHub release page on explicit user request.
    /// This remains manual and makes no background network request while
    /// the signed Sparkle pipeline is still intentionally deferred.
    @objc func checkForUpdates(_ sender: Any?) {
        let outcome = Updater.openLatestRelease { destination in
            NSWorkspace.shared.open(destination)
        }
        guard outcome == .failed else {
            Diary.shared.log("opened latest release page", category: "updater")
            return
        }

        Diary.shared.log("could not open latest release page", category: "updater")
        NSSound.beep()
        let presentation = Updater.manualUpdateFailureAlert
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = presentation.messageText
        alert.informativeText = presentation.informativeText
        alert.addButton(withTitle: presentation.buttonTitle)
        alert.runModal()
    }

    /// Copies only Diary's redacted export. The raw on-disk diary never
    /// reaches the pasteboard through this user-facing support action.
    @objc func copyRedactedDiary(_ sender: Any?) {
        let payload = Diary.shared.exportRedacted(maxLines: 200)
        let outcome = DiagnosticDiaryClipboard.write(payload)
        let feedback = DiagnosticDiaryClipboard.feedback(for: outcome)
        if feedback.shouldBeep {
            NSSound.beep()
        }
        if outcome == .copied {
            Diary.shared.log("copied redacted diagnostics", category: "support")
        }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: feedback.announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    /// Opens the official bug-report template on explicit user request.
    /// Diagnostics remain local and are copied only through the separate,
    /// privacy-redacted Help action above.
    @objc func reportProblem(_ sender: Any?) {
        let outcome = SupportIssueReporter.openBugReport { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportIssueOpenResult(
            outcome,
            topic: "bug report",
            failureAlert: SupportIssueReporter.openFailureAlert,
            copyURL: { SupportIssueReporter.copyBugReportURL() }
        )
    }

    /// Opens the official privacy-safe beta workflow form. Herminal sends
    /// nothing automatically; the tester reviews and submits the form in
    /// their browser.
    @objc func shareBetaFeedback(_ sender: Any?) {
        let outcome = SupportIssueReporter.openBetaFeedback { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportIssueOpenResult(
            outcome,
            topic: "beta feedback",
            failureAlert: SupportIssueReporter.betaFeedbackOpenFailureAlert,
            copyURL: { SupportIssueReporter.copyBetaFeedbackURL() }
        )
    }

    /// Opens the official GitHub feature request template. Herminal sends
    /// nothing automatically; the contributor reviews and submits the form
    /// in their browser.
    @objc func suggestFeature(_ sender: Any?) {
        let outcome = SupportIssueReporter.openFeatureRequest { destination in
            NSWorkspace.shared.open(destination)
        }
        handleSupportIssueOpenResult(
            outcome,
            topic: "feature request",
            failureAlert: SupportIssueReporter.featureRequestOpenFailureAlert,
            copyURL: { SupportIssueReporter.copyFeatureRequestURL() }
        )
    }

    private func handleSupportIssueOpenResult(
        _ outcome: SupportIssueOpenOutcome,
        topic: String,
        failureAlert: SupportIssueOpenFailureAlert,
        copyURL: () -> DiagnosticDiaryClipboard.Outcome
    ) {
        guard outcome == .failed else {
            Diary.shared.log("opened \(topic) form", category: "support")
            return
        }

        Diary.shared.log("could not open \(topic) form", category: "support")
        NSSound.beep()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = failureAlert.messageText
        alert.informativeText = failureAlert.informativeText
        alert.addButton(withTitle: failureAlert.copyButtonTitle)
        alert.addButton(withTitle: failureAlert.cancelButtonTitle)
        if let manualRecoveryURL = failureAlert.manualRecoveryURL {
            alert.accessoryView = Self.makeSupportIssueRecoveryURLField(
                for: manualRecoveryURL,
                accessibilityLabel: "Feature request URL"
            )
        }
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let copyOutcome = copyURL()
        let announcementTopic = topic.prefix(1).uppercased() + topic.dropFirst()
        let announcement: String
        switch copyOutcome {
        case .copied:
            Diary.shared.log("copied \(topic) URL", category: "support")
            announcement = "\(announcementTopic) URL copied."
        case .empty, .failed:
            NSSound.beep()
            announcement = "Could not copy the \(topic) URL."
        }
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ]
        )
    }

    static func makeSupportIssueRecoveryURLField(
        for url: URL,
        accessibilityLabel: String
    ) -> NSTextField {
        let field = NSTextField(string: url.absoluteString)
        field.frame = NSRect(x: 0, y: 0, width: 420, height: 22)
        field.isEditable = false
        field.isSelectable = true
        field.lineBreakMode = .byTruncatingMiddle
        field.toolTip = url.absoluteString
        field.setAccessibilityLabel(accessibilityLabel)
        field.setAccessibilityHelp(
            "Select and copy this address if the Copy URL button does not work."
        )
        return field
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

    // MARK: - Named workspaces (v0.4.2)

    /// Prompts for a name and saves the current layout as a named
    /// workspace. Pre-fills with any existing name match so re-saving
    /// the same workspace is a quick overwrite.
    @objc func saveWorkspaceAs(_ sender: Any?) {
        guard let workspace else { return }
        let alert = NSAlert()
        alert.messageText = "Save Workspace"
        alert.informativeText =
            "Name this tab + split layout so you can reopen it later. "
            + "Supported launch intents are saved without storing raw shell commands."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "e.g. kamimind"
        alert.accessoryView = field
        ModalControlAccessibility.prepare(
            field,
            label: ModalControlAccessibility.Labels.workspaceName,
            initialResponderIn: alert
        )
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard WorkspacesStore.save(name: field.stringValue, snapshot: workspace.snapshotWorkspace()) else {
            return
        }
        Diary.shared.log("saved named workspace", category: "session")
    }

    /// Opens a saved workspace, identified by the menu item's
    /// representedObject (its name). Replaces the current layout.
    @objc func openWorkspaceMenuAction(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let saved = WorkspacesStore.workspace(named: name) else { return }
        workspace?.restoreWorkspace(saved.snapshot)
        Diary.shared.log("opened named workspace", category: "session")
    }

    /// Deletes a saved workspace (Option-click alternate in the menu).
    @objc func deleteWorkspaceMenuAction(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        WorkspacesStore.delete(name: name)
        Diary.shared.log("deleted named workspace", category: "session")
    }

    // MARK: - NSMenuDelegate (dynamic "Open Workspace" submenu)

    /// Repopulates the Open-Workspace submenu each time it's about to
    /// open, so newly-saved workspaces appear without an app restart.
    /// Each workspace gets an "Open" item plus an Option-key alternate
    /// "Delete" item (the classic Mac hidden-destructive pattern).
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === workspaceSubmenu else { return }
        menu.removeAllItems()
        let saved = WorkspacesStore.all()
        guard !saved.isEmpty else {
            let empty = NSMenuItem(title: "No saved workspaces", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for workspace in saved {
            let open = NSMenuItem(
                title: workspace.name,
                action: #selector(openWorkspaceMenuAction(_:)),
                keyEquivalent: ""
            )
            open.target = self
            open.representedObject = workspace.name
            menu.addItem(open)

            let delete = NSMenuItem(
                title: "Delete “\(workspace.name)”",
                action: #selector(deleteWorkspaceMenuAction(_:)),
                keyEquivalent: ""
            )
            delete.target = self
            delete.representedObject = workspace.name
            delete.isAlternate = true
            delete.keyEquivalentModifierMask = [.option]
            menu.addItem(delete)
        }
    }

    // MARK: - NSWindowDelegate (M12-P5)

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === window else { return true }
        let isLastVisibleWindow = NSApplication.shared.windows.allSatisfy { candidate in
            candidate === sender || !candidate.isVisible
        }
        let action = CloseRiskAction.windowClose(isLastVisibleWindow: isLastVisibleWindow)
        let decision = workspace?.confirmCloseForWindow(action: action)
            ?? CloseRiskWindowDecision(approved: true, approvedFingerprint: nil)
        closeRiskGate.recordWindowClose(
            approvedFingerprint: decision.approvedFingerprint
        )
        return decision.approved
    }

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
    private static func applyPersistedTheme() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        HerminalDesign.currentTheme = HerminalDesign.resolvedTheme(
            preference: Preferences.theme,
            systemIsDark: isDark
        )
    }

    /// `NSApplication.effectiveAppearance` is KVO-compliant. Observe the app,
    /// not the explicitly themed window, so Follow System keeps receiving
    /// macOS Light/Dark changes after the window appearance is pinned.
    private func installSystemAppearanceObservation() {
        systemAppearanceObservation = NSApp.observe(
            \.effectiveAppearance,
            options: [.new]
        ) { _, _ in
            Task { @MainActor in
                guard Preferences.theme == .system else { return }
                // Update the global palette even if this fires during startup
                // before WorkspaceView has registered its notification listener.
                AppDelegate.applyPersistedTheme()
                Preferences.broadcastChange()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let currentFingerprint = workspace?.closeRiskFingerprint()
            ?? CloseRiskFingerprint(
                sessions: [],
                includeNotes: Preferences.confirmCloseWithNote
            )
        if closeRiskGate.consumeWindowCloseApproval(
            matchingCurrentFingerprint: currentFingerprint
        ) {
            return .terminateNow
        }
        let decision = workspace?.confirmCloseForWindow(action: .quitApplication)
            ?? CloseRiskWindowDecision(approved: true, approvedFingerprint: nil)
        return decision.approved ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        Diary.shared.log("applicationWillTerminate", category: "lifecycle")
        // v0.4.1 — capture the final workspace layout + pane cwds so the
        // next launch restores it. Only when the owner wants restore;
        // otherwise leave the (cleared-at-launch) store alone.
        if Preferences.restoreSessionOnLaunch {
            workspace?.persistWorkspace()
        }
        Diary.shared.flush()
        tickTimer?.invalidate()
        tickTimer = nil
    }
}
