// WorkspaceView+Tmux — PRD launcher: new / attach / attach-or-create.
// Opens a herminal tab whose command is a validated tmux invocation.
// tmux stays in the PTY.

import AppKit

extension WorkspaceView {

    @objc func newTmuxSession(_ sender: Any?) {
        spawnTmux(action: .newSession)
    }

    @objc func attachTmuxSession(_ sender: Any?) {
        guard TmuxLaunch.resolveBinary() != nil else {
            presentTmuxError("tmux is not installed.")
            return
        }
        do {
            let names = try TmuxLaunch.listSessions()
            guard !names.isEmpty else {
                presentTmuxError("No tmux sessions. Create one first.")
                return
            }
            guard let chosen = pickSession(from: names) else { return }
            try TmuxLaunch.validateName(chosen)
            openTmuxTab(action: .attach, name: chosen, cwd: focusedWorkingDirectory())
        } catch TmuxLaunch.Error.tmuxMissing {
            presentTmuxError("tmux is not installed.")
        } catch TmuxLaunch.ValidationError {
            presentTmuxError("That session name is not safe to attach.")
        } catch {
            presentTmuxError("Could not list tmux sessions.")
        }
    }

    @objc func attachOrCreateTmuxSession(_ sender: Any?) {
        spawnTmux(action: .attachOrCreate)
    }

    private func spawnTmux(action: TmuxLaunch.Action) {
        guard let ctx = prelude() else { return }
        if action == .newSession {
            do {
                if try TmuxLaunch.hasSession(name: ctx.name) {
                    presentTmuxError("A tmux session with that name already exists. Use Attach or Create.")
                    return
                }
            } catch TmuxLaunch.Error.tmuxMissing {
                presentTmuxError("tmux is not installed.")
                return
            } catch {
                presentTmuxError("Could not talk to tmux.")
                return
            }
        }
        openTmuxTab(action: action, name: ctx.name, cwd: ctx.cwd)
    }

    private func prelude() -> (cwd: String, name: String)? {
        guard TmuxLaunch.resolveBinary() != nil else {
            presentTmuxError("tmux is not installed.")
            return nil
        }
        guard let cwd = focusedWorkingDirectory() else {
            presentTmuxError("The current pane has no working directory yet.")
            return nil
        }
        guard let name = TmuxLaunch.sessionName(fromCwd: cwd) else {
            presentTmuxError("Could not make a tmux session name from this folder.")
            return nil
        }
        return (cwd, name)
    }

    private func openTmuxTab(action: TmuxLaunch.Action, name: String, cwd: String? = nil) {
        do {
            let command = try TmuxLaunch.command(action: action, name: name)
            let directory = cwd ?? focusedWorkingDirectory()
            addTab(command: command, title: "tmux · \(name)", workingDirectory: directory)
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
