# Troubleshooting

When something doesn't work, this is the first place to check. The
flow is: identify the symptom → run the diagnostic → capture the
output → either fix yourself or file a bug with the captured data.

If you can't find your symptom here, see `docs/FAQ.md` and then
file a bug using the GitHub template (it auto-prompts for the
diagnostic output below).

---

## "herminal crashes on launch"

### Diagnose

```sh
tail -50 "$HOME/Library/Application Support/herminal/diary.log"
```

What to look for:

- `=== CRASHED signal=N ===` line at the end. That's the crash diary
  recording the signal that killed the previous run. Common values:
  - `signal=11` (SIGSEGV) — libghostty Metal renderer fault.
  - `signal=6` (SIGABRT) — Swift runtime assert or a `fatalError`.
  - `signal=4` (SIGILL) — illegal instruction; usually a binary built
    for the wrong arch.
- `=== herminal launched pid=...` followed by a different signal —
  the previous run completed normally; current crash is fresh.

### Capture the crash report

```sh
ls -lt "$HOME/Library/Logs/DiagnosticReports/" | grep -i herminal | head -3
```

macOS writes a full crash report per-launch in
`~/Library/Logs/DiagnosticReports/`. Grab the most recent
`herminal-*.crash` (or `.ips` on newer macOS). File the bug with
both the diary tail AND the crash report attached.

### Workaround

Some crashes can be cleared by purging the WAL files:

```sh
rm "$HOME/Library/Application Support/herminal/"{notes.db-wal,ssh-hosts.db-wal,notes.db-shm,ssh-hosts.db-shm}
```

This is safe — the WAL files are recreated on next launch and the
main `.db` files keep their data. Only do this if the diary shows a
SQLite-related stack.

---

## "Vietnamese Telex / VNI types two characters per keystroke"

### Diagnose

This is the IME bridge desyncing. Run the smoke checklist:

```sh
open docs/QA/vietnamese-ime-checklist.md
```

Type each phrase in column 1; compare what lands against column 2.
If a row shows a doubled character (DUP defect per the taxonomy in
the checklist), that's the diagnostic.

### Common cases

- **"d" doubles to "dd"** → likely a Telex `dd → đ` conversion
  failing. Check the bridge unit tests are green:
  ```sh
  swift test --filter "IME bridge"
  ```
- **First letter of every word doubles** → `setMarkedText` isn't
  REPLACING the previous preview; it's appending. This is a real
  bug, not user-fixable. File the row from the checklist.
- **No double, but missing diacritic** → not a bridge issue. The
  system IME isn't converting before commit. Verify with
  `Dictation & Speech → Input Sources → Vietnamese Telex` is
  selected (not Vietnamese ABC or Telex with a different layout).

### Capture for a bug report

The IME state machine doesn't write to the diary (no PTY pollution).
Capture by running the failing phrase with logging:

```sh
log stream --predicate 'subsystem == "com.hoangperry.herminal"' &
# type the failing phrase in herminal
# Ctrl+C
```

Include the log output in the bug.

---

## "Agent dashboard shows nothing even though Claude is running"

### Diagnose

```sh
# In a herminal pane, with Claude/Codex/Aider running:
pgrep -af "claude\|codex\|aider" | grep -v grep
```

You should see your agent process. Now check its kernel comm:

```sh
ps -axo pid,comm,args | grep <pid>
```

### Common cases

- **`p_comm` is `node` or `Python`** — that's an `npx`-installed or
  Python-script-hosted agent. herminal SHOULD catch this via argv
  inspection. If it doesn't, the argv-matching regex is missing your
  install path. File a bug with the `ps` output above.
- **agent isn't a child of `HerminalApp`** — the detection walks
  herminal's subtree only. If you started the agent from outside
  herminal (e.g. in another terminal), it won't appear. Open it in
  a herminal pane.
- **Tab open but dashboard wasn't toggled** — the dashboard only
  polls when open (Cmd+Shift+A). Toggle it and wait 2 seconds.

### Confirm the kernel sees the right tree

```sh
ps -axo pid,ppid,comm | awk -v parent=$(pgrep -x HerminalApp) '$2==parent || $1==parent'
```

This should show `HerminalApp → /usr/bin/login → -zsh → <your agent>`.
If `-zsh` has no children, the agent didn't actually spawn under
herminal.

---

## "SSH connect opens a tab but ssh fails"

### Diagnose

The SSH spawn path runs your `ssh` binary unchanged. If it fails in
herminal but works in another terminal, the difference is the
environment.

```sh
# In a fresh herminal pane (no SSH yet):
env | sort > /tmp/herminal-env.txt
# In your other working terminal:
env | sort > /tmp/other-env.txt
diff /tmp/herminal-env.txt /tmp/other-env.txt
```

### Common cases

- **Missing `SSH_AUTH_SOCK`** — your SSH agent isn't reachable.
  herminal launches as a non-login shell child of `/usr/bin/login`;
  if your agent is started by a launchd user agent that needs the
  full login flow, it may not be in herminal's env. Verify with
  `ssh-add -l` inside herminal.
- **`HOME` mismatch** — extremely unlikely but causes
  `~/.ssh/config` lookups to fail. Confirm `echo $HOME` matches your
  expectation.
- **`HostName` mismatch after import** — if you used "Import
  ~/.ssh/config" before the M11-A2 fix, multi-target entries
  (`Host a b c`) might have wrong hostnames stored. Delete them
  from the SSH manager and re-import.

### What the connect command actually runs

The SSH manager's "Connect" button runs:

```
ssh '<user>'@'<hostname>'              # port 22
ssh -p <port> '<user>'@'<hostname>'    # other ports
```

Test that string manually in another terminal to isolate herminal
from the SSH layer.

---

## "dogfood-daily.sh fails"

### Diagnose

The script runs all 5 integration scripts in sequence. If one fails:

```sh
# Reproduce the failing script standalone:
Scripts/verify-codex-detection.sh   # or whichever failed
```

### Common cases

- **Flake on back-to-back runs** — see the M6 retro note. `pkill -9`
  is async, and a previous run's `HerminalApp` can still hold the
  Metal layer + PTY fds when the next launch happens. The script
  has a 2s sleep between checks for this reason; if you're invoking
  scripts manually, add `sleep 3` between them.
- **All scripts fail** — likely a build issue, not a runtime issue.
  Rebuild:
  ```sh
  Scripts/bootstrap.sh
  swift build
  Scripts/make-app-bundle.sh
  ```
- **Only `verify-compat-matrix.sh` fails** — an app in the matrix
  isn't installed. Install via brew (the script's needs are
  documented inside the file).

---

## "App takes forever to open"

### Diagnose

```sh
# Measure cold-launch time:
time Scripts/make-app-bundle.sh
time open .build/herminal.app
```

If `make-app-bundle.sh` is slow (>5 seconds), `swift build` is the
bottleneck — usually a fresh SPM resolve.

If the `.app` open is slow (>2 seconds), check whether libghostty
is JIT-compiling Metal shaders. The first launch after a libghostty
update warms the shader cache; subsequent launches are <500 ms.

```sh
# Force a clean shader cache and retry:
rm -rf "$HOME/Library/Caches/com.hoangperry.herminal"
open .build/herminal.app
```

---

## "Tests fail on my machine but pass in CI"

### Diagnose

Most common causes:

1. **Apple-Silicon vs Intel** — `AgentStatusTracker.cpuSeconds`
   uses `mach_timebase_info`. On Apple Silicon the timebase is
   `125/3`; on Intel it's `1/1`. CI runs on `macos-15` (Apple
   Silicon by default in 2026), so Intel-only failures need a
   local repro on an Apple Silicon machine.
2. **`/tmp/codex` left over** — `Scripts/verify-codex-detection.sh`
   builds a `/tmp/codex` binary. If a previous run was killed
   uncleanly, the leftover file can confuse subsequent runs.
   ```sh
   rm -f /tmp/codex /tmp/codex.c /tmp/herminal-*
   ```
3. **`HerminalApp` still running** — `swift test` can't get a clean
   process tree if a previous launch is alive.
   ```sh
   pkill -9 -x HerminalApp
   ```

---

## "I want to see what herminal is doing under the hood"

```sh
# Live event stream from herminal's diary:
tail -f "$HOME/Library/Application Support/herminal/diary.log"

# Unified macOS log filtered to herminal:
log stream --predicate 'subsystem == "com.hoangperry.herminal"'

# Process tree of the running herminal:
ps -axo pid,ppid,comm,args | awk -v parent=$(pgrep -x HerminalApp) '$2==parent || $1==parent'

# Per-tick latency (already in the unified log, just filter):
log stream --predicate 'subsystem == "com.hoangperry.herminal"' --info | grep -i latency
```

---

## Reset everything

If something is genuinely broken and you want to start clean:

```sh
pkill -9 -x HerminalApp
rm -rf "$HOME/Library/Application Support/herminal"
rm -rf "$HOME/Library/Caches/com.hoangperry.herminal"
rm -rf "$HOME/Library/Preferences/com.hoangperry.herminal.plist"
```

This deletes:

- All notes (irrecoverable)
- All saved SSH hosts (re-importable from `~/.ssh/config`)
- The crash diary
- All cached state

Re-install from a release zip or rebuild from source. If the problem
persists after a clean install, file a bug — that means the issue is
in the codebase, not local state.
