# herminal blog — drafts

Knowledge-transfer write-ups distilled from M1-M9 retros. Drafts
live here so the owner can publish them on any platform (personal
blog, dev.to, Medium, X thread) without needing to re-find the
source material.

## Index

1. [`proc_listchildpids` broken on Sequoia](01-proc-listchildpids-broken-on-sequoia.md)
   — kernel-API gotcha that cost us 2 months of silent bug
   coverage in the agent dashboard. Fix: `sysctl(KERN_PROC_ALL)`.
2. [`proc_pid_rusage` returns mach absolute time units, not
   nanoseconds](02-proc-pid-rusage-mach-time-units.md) — 42× CPU
   under-report on Apple Silicon. Fix: cache
   `mach_timebase_info` and multiply.
3. [libghostty `exec -l` prefixes `p_comm` with a dash](03-libghostty-exec-l-pcomm-dash.md)
   — spawned children look invisible to `pgrep -x`. Fix:
   `^-?<name>$` matcher. Bonus: pipes don't compose inside the
   exec wrapper.

## How to publish

These are markdown-first; most blog platforms render them as-is.
Suggested order:

1. Owner reads each draft, edits voice/length to taste.
2. Publish one per week so each post gets its own discussion
   window — they're a series but cross-link enough that
   reading order doesn't matter much.
3. Cross-post to:
   - personal blog (canonical URL)
   - dev.to (high search visibility for macOS-native tooling)
   - the herminal GitHub Discussions tab (so the bug report
     template can reference them)
4. After publishing post 3, link the series from the README's
   "tech stack" section so anyone evaluating the project sees
   the depth.

## Why this exists

The M7-3 retrospective explicitly called out: "the cost of NOT
turning these into write-ups is that the next macOS-native-tools
builder hits the same wall." Three real bugs, three save-an-evening
posts. Each one points at the herminal source code so a reader who
needs more depth can dive in.
