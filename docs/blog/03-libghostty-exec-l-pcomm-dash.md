# libghostty's `exec -l` prefixes `p_comm` with a dash. `pgrep -x` silently misses every spawned process.

**Status:** draft. Owner publishes when ready.
**Audience:** macOS-native tools embedding libghostty (or any code
that walks a shell-spawned process subtree).
**Length:** ~500 words. One read.

---

If you're embedding [libghostty](https://github.com/ghostty-org/ghostty)
in a macOS app and walking the process subtree it spawns, here's a
gotcha we hit in herminal Month 5 that cost us an evening.

## The symptom

You spawn a child via libghostty's surface (`ghostty_surface_new`
with `config.command`). You check it landed via `pgrep`:

```bash
$ pgrep -x vim
$    # empty
```

But the process is clearly running:

```bash
$ ps -ax | grep -i vim
67890 ttys001  0:00.04 -vim
```

There it is. PID 67890. Note the leading dash: `-vim`. That's not a
typo, that's the actual `p_comm` value.

## Why the dash

libghostty wraps every spawned command as a login session for shell
integration:

```
/usr/bin/login -flp $USER /bin/bash --noprofile --norc -c "exec -l <cmd>"
```

The `exec -l` flag tells the shell to "execute as a login process":
prepend a `-` to `argv[0]`. The kernel records that `argv[0]` into
`p_comm`. So `-vim` literally is the BSD-comm field as far as the
kernel is concerned.

This is the same convention macOS uses for login shells everywhere —
`/usr/bin/login` runs your shell as `-bash` / `-zsh`, and tools like
`ps` traditionally read it as "running under a login session." Most
of the time you never notice because nothing reads `p_comm` for an
exact match. `pgrep -x` does.

## The fix

Match both shapes when the source might be libghostty-spawned (or any
login-prefixed) process:

```bash
ps -axo comm | grep -E "^-?vim$"     # matches both "vim" and "-vim"
```

Or in code (Swift, the basename-match path of our agent classifier):

```swift
let trimmed = name.hasPrefix("-") ? String(name.dropFirst()) : name
return AgentKind.detect(processName: trimmed)
```

Tools that walk `kinfo_proc.kp_proc.p_comm` directly need the same
strip — sysctl returns the raw kernel value.

## Why this isn't a libghostty bug

The login-shell wrapper is intentional: it's what makes shell
integration (prompt detection, OSC sequences, command boundaries)
work the way it does in iTerm2 / Terminal.app / kitty. Stripping the
dash would silently break that integration.

The lesson is that **`p_comm` for a libghostty-spawned process isn't
the binary name you handed in**, it's the binary's name with possibly
a login-session prefix. Matching code needs to know.

## Where else this bites you

- **Integration tests** with `pkill -x <name>` — same problem. Use
  `pkill -f` or strip the dash in your matcher.
- **macOS Activity Monitor** shows `-vim` in the Process Name column
  when launched through any login wrapper. Reading from there:
  same shape.
- **`launchctl`** doesn't see these as named services, but if you're
  walking the process tree to find a launchd-spawned login child,
  same prefix.

## Pipes don't work inside the wrapper either

Bonus gotcha from the same investigation: a command with a pipe gets
parsed weirdly by the wrapper.

```
exec -l seq 1 200 | fzf --reverse
```

bash parses this as `(exec -l seq 1 200) | fzf`. The exec replaces
the wrapping bash with `seq` (argv[0]=`-seq`), so `fzf` gets EOF as
soon as seq finishes its 200 lines. fzf appears to launch and
immediately die.

Fix: wrap your pipeline in your own `bash -c "<pipeline>"` so the
exec-l only sees a single command argument:

```
config.command = "bash -c 'seq 1 200 | fzf --reverse'"
```

## Implementation reference

The Swift `^-?<name>$` matcher lives at
[`Scripts/verify-compat-matrix.sh`](../../Scripts/verify-compat-matrix.sh).
The dashed-name pass-through in our agent classifier is at
[`Sources/HerminalAgent/AgentDetector.swift`](../../Sources/HerminalAgent/AgentDetector.swift)
inside `AgentDetector.scan`.

---

*This is post 3 of 3 in a series on macOS-native kernel-API gotchas
we hit building herminal. Previous:
[proc_pid_rusage returns mach absolute time units, not nanoseconds](02-proc-pid-rusage-mach-time-units.md).
Series start:
[proc_listchildpids broken on Sequoia](01-proc-listchildpids-broken-on-sequoia.md).*
