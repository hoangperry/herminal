# Define: tmux launcher

Date: 2026-08-15
Status: Implemented on `feat/define-tmux-launcher`
Owner: Solo / herminal
Parent: [herminal.prd.md](herminal.prd.md) — Must Feature 3 leftover
Plan (after this define): `plans/260815-tmux-launcher/plan.md`

## 1. Problem

Lan (persona B) and Minh (persona A) already run tmux inside herminal.
Tabs and splits organize the GUI. tmux keeps long-lived servers and
agents alive *inside a pane*. The missing piece is a first-class way
to **create or rejoin a named tmux session** without typing
`tmux new -s …` / `tmux a -t …` every time.

Today they either:

- type the commands by hand, or
- keep one tmux client attached and never leave it.

Herminal’s PRD already required a launcher (new / attach /
attach-or-create by repo). Tabs, splits, and in-PTY tmux compatibility
shipped. The launcher did not.

This is not “herminal becomes tmux.” It is the last Must Feature 3
sentence.

## 2. Who and when

**Who:** A Vietnamese developer whose daily driver is herminal, who
already uses tmux for persist (dev servers, SSH jumps, agents that
must survive a tab close).

**Trigger:** Opening a repo and wanting a named session for that repo,
or coming back to a machine where `tmux ls` still has yesterday’s
sessions.

**If we skip it:** PRD Must Feature 3 stays incomplete. Users keep
tmux as a habit herminal merely tolerates. FlightDeck `⌘⌥W` worktrees
do not replace this — a worktree is a git checkout, not a living
process group.

## 3. Solution

A menu + command-palette launcher that opens a **new herminal tab**
whose child command is a validated `tmux` invocation in the focused
pane’s working directory:

| Action | Meaning |
|---|---|
| New tmux Session | Create a session named from the repo. Fail if that name already exists. |
| Attach tmux Session… | Pick an existing session from `tmux ls`, attach it. |
| Attach or Create tmux | `new-session -A` with the repo-derived name. |

tmux stays inside the PTY. Herminal does not interpret tmux windows,
panes, or layouts.

## 4. User stories

### P0 — must ship

**New session**

- As a developer in `~/src/api`, I want to start a tmux session named
  from that repo so the next attach finds the same name.
  - AC: Given a focused pane whose cwd is a git repo `api` and no
    session `api` exists, when I choose New tmux Session, then a new
    tab runs tmux creating session `api` with cwd `~/src/api`.
  - AC: Given session `api` already exists, when I choose New, then
    herminal shows an error and does not attach or replace it.

**Attach existing**

- As a developer with leftover sessions, I want to pick one and attach
  so I do not retype `tmux attach -t`.
  - AC: Given `tmux list-sessions` returns names, when I choose
    Attach…, then I see those names and picking one opens a tab that
    attaches that session.
  - AC: Given no sessions, when I choose Attach…, then I see that
    there is nothing to attach and no tab is created.

**Attach or create by repo**

- As a developer opening the same repo every morning, I want one
  action that attaches if the session exists and creates it otherwise.
  - AC: Given cwd repo slug `herminal`, when I choose Attach or
    Create, then a tab runs `tmux new-session -A` for that name in
    that cwd.

**Missing tmux**

- As a developer without tmux installed, I want a clear failure, not
  a broken pane.
  - AC: Given no executable tmux on the allowed path list, when I
    invoke any launcher action, then an alert explains tmux is
    missing and no tab is created.

### P1 — not this define

- Broadcast the same keystrokes to every native pane.
- A tree of tmux windows and panes (choose-tree).
- Remember last session name in Settings.

### P2 — never in this define

- iTerm2-style `tmux -CC`.
- Process resurrection when herminal quits.
- Mapping agents inside tmux panes onto the agent dashboard.
- Competing with or replacing `⌘⌥W` worktrees.

## 5. Scope

**In**

- Three Window-menu items and three command-palette rows.
- No new `⌘⌥` shortcut (cockpit already uses that family).
- Session name derived from git repo basename, else cwd basename,
  then slugged and validated.
- Attach… uses a small picker (alert + popup), not a new sidebar.
- Agent dashboard lists live sessions: click to attach, trash to
  confirm-kill (`kill-session -t =<name>`). Unsafe names are hidden.
  **New** attach-or-creates the repo session. A second attach
  focuses the tab that already spawned that session.

**Out**

- Control mode, mux server, detach-without-kill.
- synchronize-panes / broadcast.
- choose-tree, window/pane navigation of tmux from the GUI.
- Shell history, session rename UI.
- Changing IME, restore policy, or agent detection.

## 6. Constraints

- **Architecture:** Spawn only via existing
  `addTab(command:title:workingDirectory:)`. Do not attach an existing
  PTY. Closing herminal still kills the GUI’s tmux *client*; the
  tmux *server* and other sessions persist the way tmux already does.
- **Security:** Resolve tmux from a fixed executable list (never raw
  `PATH`). Validate session names before building the command.
  Quote the name if `config.command` goes through a shell (same class
  as `sshCommand`). No diary line may include a raw path or
  unvalidated name.
- **IME:** Launcher only runs at tab creation. It must not sit on
  the key/IME path.
- **Agents:** An agent started *inside* tmux remains one herminal
  pane. Dashboard focus will not target the inner tmux pane. Accept
  that; do not paper over it.
- **Concurrency:** Other agents edit `AppMenu`, `CommandPalette`,
  `WorkspaceView`. Implementation must be new files + additive menu
  rows.

## 7. Success

- A tmux user can start the day with Attach or Create and land in
  yesterday’s session without typing tmux commands.
- New / Attach / Attach-or-create each have a unit-tested name and
  command builder that rejects injection cases (`-evil`, spaces,
  `$(…)`, `/`).
- Diff contains no broadcast, `-CC`, or PTY-detach code.

## 8. Open questions (resolved for planning)

| Question | Decision |
|---|---|
| Keyboard shortcut? | None. Menu + `⌘⇧P` only. |
| Session name source? | Git repo basename, else cwd basename, slugged. |
| Name collision on New? | Fail. Do not attach. Attach-or-create is the steal/create path. |
| Picker UI? | NSAlert + popup, same family as the worktree dialog. |
| tmux binary? | First executable among `/opt/homebrew/bin/tmux`, `/usr/local/bin/tmux`, `/usr/bin/tmux`. |

No remaining product questions. Implementation detail belongs in the
plan, not here.
