// WorkspaceView+Tmux — PRD launcher: new / attach / attach-or-create.
// Opens a herminal tab whose command is a validated tmux invocation.
// Process and git queries stay off MainActor; tmux stays in the PTY.

import AppKit

private enum TmuxListOutcome: Sendable {
    case sessions([String])
    case missing
    case failed
}

private enum TmuxSpawnOutcome: Sendable {
    case ready(name: String)
    case exists
    case missing
    case invalidName
    case failed
}

extension WorkspaceView {

    @objc func newTmuxSession(_ sender: Any?) {
        spawnTmux(action: .newSession)
    }

    @objc func attachTmuxSession(_ sender: Any?) {
        guard TmuxLaunch.resolveBinary() != nil else {
            presentTmuxError("tmux is not installed.")
            return
        }
        Task { [weak self] in
            let outcome = await Task.detached(priority: .utility) {
                do {
                    return TmuxListOutcome.sessions(try TmuxLaunch.listSessions())
                } catch TmuxLaunch.Error.tmuxMissing {
                    return TmuxListOutcome.missing
                } catch {
                    return TmuxListOutcome.failed
                }
            }.value
            guard let self else { return }
            switch outcome {
            case let .sessions(names):
                let shown = TmuxLaunch.displayableSessions(names)
                guard !shown.isEmpty else {
                    presentTmuxError("No tmux sessions. Create one first.")
                    return
                }
                guard let chosen = pickSession(from: shown) else { return }
                do {
                    try TmuxLaunch.validateName(chosen)
                    openTmuxTab(action: .attach, name: chosen, cwd: focusedWorkingDirectory())
                } catch {
                    presentTmuxError("That session name is not safe to attach.")
                }
            case .missing:
                presentTmuxError("tmux is not installed.")
            case .failed:
                presentTmuxError("Could not list tmux sessions.")
            }
        }
    }

    @objc func attachOrCreateTmuxSession(_ sender: Any?) {
        spawnTmux(action: .attachOrCreate)
    }

    func attachTmuxNamed(_ name: String) {
        do {
            try TmuxLaunch.validateName(name)
            openTmuxTab(action: .attach, name: name, cwd: focusedWorkingDirectory())
        } catch {
            presentTmuxError("That session name is not safe to attach.")
        }
    }

    func confirmKillTmux(_ name: String) {
        do {
            try TmuxLaunch.validateName(name)
        } catch {
            presentTmuxError("That session name is not safe to kill.")
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Kill tmux session “\(name)”?"
        alert.informativeText = "Attached clients detach. Processes in that session stop."
        alert.addButton(withTitle: "Kill")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { [weak self] in
            let killed = await Task.detached(priority: .userInitiated) {
                do {
                    try TmuxLaunch.killSession(name: name)
                    return true
                } catch {
                    return false
                }
            }.value
            guard let self else { return }
            if killed {
                Diary.shared.log("tmux kill", category: "tmux")
                self.refreshTmuxSessions(force: true)
            } else {
                self.presentTmuxError("Could not kill the tmux session.")
            }
        }
    }

    private func spawnTmux(action: TmuxLaunch.Action) {
        guard TmuxLaunch.resolveBinary() != nil else {
            presentTmuxError("tmux is not installed.")
            return
        }
        guard let cwd = focusedWorkingDirectory() else {
            presentTmuxError("The current pane has no working directory yet.")
            return
        }

        Task { [weak self] in
            let outcome = await Task.detached(priority: .utility) {
                guard let name = TmuxLaunch.sessionName(fromCwd: cwd) else {
                    return TmuxSpawnOutcome.invalidName
                }
                guard action == .newSession else {
                    return TmuxSpawnOutcome.ready(name: name)
                }
                do {
                    return try TmuxLaunch.hasSession(name: name)
                        ? TmuxSpawnOutcome.exists
                        : TmuxSpawnOutcome.ready(name: name)
                } catch TmuxLaunch.Error.tmuxMissing {
                    return TmuxSpawnOutcome.missing
                } catch {
                    return TmuxSpawnOutcome.failed
                }
            }.value
            guard let self else { return }
            switch outcome {
            case let .ready(name):
                openTmuxTab(action: action, name: name, cwd: cwd)
            case .exists:
                presentTmuxError("A tmux session with that name already exists. Use Attach or Create.")
            case .missing:
                presentTmuxError("tmux is not installed.")
            case .invalidName:
                presentTmuxError("Could not make a tmux session name from this folder.")
            case .failed:
                presentTmuxError("Could not talk to tmux.")
            }
        }
    }

    private func openTmuxTab(action: TmuxLaunch.Action, name: String, cwd: String? = nil) {
        do {
            let command = try TmuxLaunch.command(action: action, name: name)
            let directory = cwd ?? focusedWorkingDirectory()
            addTab(command: command, title: "tmux · \(name)", workingDirectory: directory)
            refreshTmuxSessions(optimistic: name, force: true)
            let label: String
            switch action {
            case .newSession: label = "new"
            case .attach: label = "attach"
            case .attachOrCreate: label = "attachOrCreate"
            }
            Diary.shared.log("tmux spawn action=\(label)", category: "tmux")
        } catch {
            presentTmuxError("Could not build the tmux command.")
        }
    }

    private func pickSession(from names: [String]) -> String? {
        let alert = NSAlert()
        alert.messageText = "Attach tmux session"
        alert.informativeText = "Pick a live session to attach in a new tab."
        alert.addButton(withTitle: "Attach")
        alert.addButton(withTitle: "Cancel")
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 22), pullsDown: false)
        for name in names {
            popup.addItem(withTitle: name)
        }
        alert.accessoryView = popup
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return popup.titleOfSelectedItem
    }

    private func presentTmuxError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "tmux"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
