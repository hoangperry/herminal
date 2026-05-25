# `proc_listchildpids` is broken on macOS Sequoia. Use `sysctl(KERN_PROC_ALL)` instead.

**Status:** draft. Owner publishes when ready.
**Audience:** macOS-native tools developers walking process trees.
**Length:** ~600 words. One read.

---

If you're writing a macOS app that needs to enumerate the children of a
PID — terminal multiplexer, process monitor, agent dashboard — your
first instinct is probably `proc_listchildpids()` from `<libproc.h>`.
On macOS Sequoia (14+), it doesn't work.

We hit this in herminal during Month 4 when our agent dashboard
silently stopped detecting agents. Two months of unit tests on the
matching layer (string → agent kind) had passed. Integration was
broken from day one. Here's what's actually happening and what to
do instead.

## The symptom

```c
#include <libproc.h>

pid_t pid = getpid();
int probed = proc_listchildpids(pid, NULL, 0);
// probed > 0, looks normal.

pid_t buf[256];
int written = proc_listchildpids(pid, buf, sizeof(buf));
// written == 0, even though `ps -fp <pid>` clearly shows children.
```

The probe call returns a non-zero "size needed" hint, suggesting there
are children to enumerate. The fill call returns 0 bytes written. The
buffer stays zeroed. No errno, no log line — silent failure.

We verified with a minimal C program built outside the host app to
rule out entitlements or sandbox: same behaviour.

## What `ps` and `pgrep` actually do

Run `dtruss -n ps` (or strace equivalent). It doesn't call
`proc_listpids` or `proc_listchildpids`. It calls `sysctl` with
`KERN_PROC` / `KERN_PROC_ALL` and walks the snapshot itself.

That's the path that works:

```c
int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
size_t size = 0;
sysctl(mib, 4, NULL, &size, NULL, 0);
struct kinfo_proc *procs = malloc(size);
sysctl(mib, 4, procs, &size, NULL, 0);
int count = size / sizeof(struct kinfo_proc);
for (int i = 0; i < count; i++) {
    if (procs[i].kp_eproc.e_ppid == pid) {
        // child of pid
    }
}
free(procs);
```

Single snapshot, every process's `(pid, ppid, comm, starttime)` in one
buffer. Build a `[ppid → [pid]]` map once, query in O(1).

## Why this matters

The herminal codebase had ~200 lines wrapping `proc_listchildpids` with
careful error handling, buffer probing, repeated calls on partial
fills — all of it polishing a kernel API that returns garbage. The
sysctl-based version replaced it with one allocation, one snapshot,
one dictionary. Faster *and* correct.

We caught this by writing an integration test that actually launched
the app and asked it to find a child process we'd spawned. The unit
tests passed because they only exercised the matching layer; the
kernel walk had zero coverage. Lesson: any code that takes input from
the OS deserves an integration test that actually exercises the OS
boundary, even if the matching logic is well-tested in isolation.

## Implementation reference

The full Swift implementation lives at
[`Sources/HerminalAgent/AgentDetector.swift`](../../Sources/HerminalAgent/AgentDetector.swift)
under `ProcessSnapshot`. ~80 lines including the start-time +
parent-pointer fields we needed for agent↔pane attribution (the
same snapshot gives us all of those for free since they're all in
`kinfo_proc`).

## Caveat

`proc_pid_rusage` (per-process CPU usage) still works fine. It's
specifically the tree-walk APIs (`proc_listpids`, `proc_listchildpids`)
that misbehave on Sequoia. Don't throw out libproc wholesale —
just route process-tree queries through sysctl.

## Reporting upstream

We haven't filed this with Apple. The behaviour reproduces on multiple
machines on macOS 14.x and 14.7 (Tahoe). If Apple has documented this
change anywhere, we couldn't find it. If you know the formal status,
drop a note on
[`hoangperry/herminal#1`](https://github.com/hoangperry/herminal/issues)
(placeholder) so the next person finds the official guidance instead
of writing this post.

---

*This is post 1 of 3 in a series on macOS-native kernel-API gotchas
we hit building herminal. Next:
[proc_pid_rusage returns mach absolute time units, not nanoseconds](02-proc-pid-rusage-mach-time-units.md).*
