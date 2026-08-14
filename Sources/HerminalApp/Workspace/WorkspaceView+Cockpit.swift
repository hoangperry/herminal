// WorkspaceView+Cockpit — FlightDeck-style agent launchers.
//
// Native equivalents of `wt`, `prefix a`, `prefix g`, and Ghostty
// ⌘1…⌘9. Spawn commands are the AgentLaunch whitelist only.

import AppKit

extension WorkspaceView {

    @objc func newAgentPane(_ sender: Any?) {
        spawnInSplit(kind: .claude)
    }

    @objc func newAgentTab(_ sender: Any?) {
        spawnInTab(kind: .claude)
    }

    @objc func openLazygit(_ sender: Any?) {
        spawnInTab(kind: .lazygit)
    }

    @objc func newAgentWorktree(_ sender: Any?) {
        guard let cwd = focusedWorkingDirectory() else {
            presentCockpitError("The current pane has no working directory yet.")
            return
        }
        guard let _ = try? GitWorktree.resolveContext(cwd: cwd) else {
            presentCockpitError("The current pane is not inside a git repository.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "New agent worktree"
        alert.informativeText = "Creates an isolated checkout next to this repo and opens an agent there."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: "")
        field.placeholderString = "branch-name"
        field.frame = NSRect(x: 0, y: 26, width: 280, height: 22)

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 22), pullsDown: false)
        for kind in [AgentLaunch.Kind.claude, .codex, .aider, .shell] {
            popup.addItem(withTitle: kind.displayName)
            popup.lastItem?.representedObject = kind.rawValue
        }

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 52))
        accessory.addSubview(field)
        accessory.addSubview(popup)
        alert.accessoryView = accessory
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = popup.selectedItem?.representedObject as? String
        let kind = raw.flatMap(AgentLaunch.Kind.init(rawValue:)) ?? .claude
        createWorktree(named: name, kind: kind, cwd: cwd)
    }

    @objc func selectTabByNumber(_ sender: Any?) {
        guard let item = sender as? NSMenuItem else { return }
        if item.tag == 9 {
            selectTab(at: tabCount - 1)
        } else {
            selectTab(at: item.tag - 1)
        }
    }

    func openWorktree(_ tree: GitWorktree.Entry, kind: AgentLaunch.Kind) {
        let command = AgentLaunch.command(for: kind)
        addTab(
            command: command ?? "",
            title: tree.label,
            workingDirectory: tree.path
        )
    }

    func confirmRemoveWorktree(_ tree: GitWorktree.Entry) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove worktree “\(tree.label)”?"
        alert.informativeText = "This deletes the extra checkout. Uncommitted work in that folder will be lost if git refuses a clean remove."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try GitWorktree.remove(path: tree.path)
            Diary.shared.log("worktree removed", category: "worktree")
            revealAgentDashboard()
        } catch {
            presentCockpitError("Could not remove the worktree. Commit or stash changes first.")
        }
    }

    private func spawnInSplit(kind: AgentLaunch.Kind) {
        let command = AgentLaunch.command(for: kind)
        splitActivePane(vertical: true, command: command, title: kind.displayName)
        Diary.shared.log("cockpit spawn pane kind=\(kind.rawValue)", category: "worktree")
    }

    private func spawnInTab(kind: AgentLaunch.Kind) {
        let command = AgentLaunch.command(for: kind)
        addTab(
            command: command ?? "",
            title: kind.displayName,
            workingDirectory: focusedWorkingDirectory()
        )
        Diary.shared.log("cockpit spawn tab kind=\(kind.rawValue)", category: "worktree")
    }

    private func createWorktree(named name: String, kind: AgentLaunch.Kind, cwd: String) {
        do {
            try GitWorktree.validateBranchName(name)
            let path = try GitWorktree.add(branch: name, cwd: cwd)
            let command = AgentLaunch.command(for: kind)
            addTab(command: command ?? "", title: name, workingDirectory: path)
            Diary.shared.log("worktree created", category: "worktree")
            revealAgentDashboard()
        } catch is GitWorktree.ValidationError {
            presentCockpitError("Use a git-safe branch name (letters, numbers, /, -, _).")
        } catch GitWorktree.Error.pathBusy {
            presentCockpitError("That worktree folder is already used by another branch.")
        } catch let GitWorktree.Error.gitFailed(message) {
            presentCockpitError(shortGitMessage(message))
        } catch {
            presentCockpitError("Could not create the worktree.")
        }
    }

    private func presentCockpitError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Worktree"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Surface a short git error without dumping a full path-heavy
    /// stderr blob into the UI.
    private func shortGitMessage(_ stderr: String) -> String {
        let line = stderr.split(whereSeparator: \.isNewline).first.map(String.init) ?? stderr
        if line.count <= 180 { return line.isEmpty ? "git worktree failed." : line }
        return String(line.prefix(180))
    }
}
