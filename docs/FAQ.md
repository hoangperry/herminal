# Frequently asked questions

Quick answers to questions that come up before someone reaches for
the issue tracker. If your question isn't here, check
`docs/TROUBLESHOOTING.md` next, then file an issue with the bug
template (it prompts for the diary excerpt).

---

## General

### What is herminal?

A macOS terminal emulator built around two daily realities the
existing 2026 terminals each miss part of: living in Claude Code
all day, and typing Vietnamese reliably. Pairs the
[libghostty](https://github.com/ghostty-org/ghostty) engine with a
Swift/AppKit shell that owns the IME and the chrome.

Local-first. No telemetry. No account. MIT-licensed.

### Why a new terminal in 2026? iTerm2/Warp/Wave/Ghostty already exist.

None of them hit all five at once:

1. Native macOS rendering speed
2. Reliable Vietnamese IME (Telex + VNI)
3. tmux + multi-session compatibility
4. Built-in dashboard for the AI agents you're running
5. Per-session notes that don't leave your machine

See `README.md` for the comparison table and `docs/research/` for
the full scoring rubric.

### Is herminal for me if I don't write Vietnamese?

Yes — but the SSH manager, agent dashboard, notes, and tmux
compatibility ship the same regardless of language. The Vietnamese
IME work is just the part that wouldn't have existed if a Vietnamese
developer didn't build it.

### Will there be a Linux / Windows version?

No. macOS-only by design — see "Won't ship by design" in
`docs/ROADMAP.md` and `CONTRIBUTING.md`. The whole point of the
Swift/AppKit/Metal stack is native performance + native IME +
native window management. Cross-platform would mean Electron or a
non-trivial Qt rewrite, both of which kill the latency budget the
PRD targets.

---

## Install + first run

### How do I install?

From a tagged release once one is published:

1. Download `herminal-vX.Y.Z.zip` (or `.dmg`) from the
   [Releases](https://github.com/hoangperry/herminal/releases) page.
2. Drag `herminal.app` into `/Applications`.
3. Launch.

From source: see "Install" → "From source" in `README.md`.

### Why does Gatekeeper show "downloaded from the internet"?

Until owner Developer-ID enrolment lands, the v0.1.0 build is
**ad-hoc signed**, not notarized. The warning is one-time per
download — once you allow the launch, future launches are silent.

The full pipeline for notarized releases (`Scripts/sign-and-notarize.sh`
+ `.github/workflows/release.yml`) is ready; the next release after
the Developer ID lands will be Gatekeeper-clean.

### Does herminal work on Intel Macs?

No. Apple Silicon only. macOS 14+ (Sonoma). The libghostty engine +
agent CPU sampling (which uses `mach_timebase_info` with the
Apple-Silicon ratio) target ARM64 specifically.

### What's the right shell to use with herminal?

Whatever you already use — herminal spawns `$SHELL` (zsh on default
macOS, bash if you've changed it). It does NOT inject its own
prompt or shell config. Your `.zshrc` / `.bashrc` work unchanged.

---

## Features

### How does the agent dashboard know which agents are running?

It walks herminal's process subtree via `sysctl(KERN_PROC_ALL)` —
the same path `ps` and `pgrep` use. Matches each child process's
short name against a known list (`claude`, `codex`, `aider`). For
agents installed via `npx` or as Python scripts, it also reads
argv via `sysctl(KERN_PROCARGS2)` to find the actual agent name
behind a `node` or `python` interpreter.

Per-PID CPU sampling (`proc_pid_rusage`) flips the badge between
`running` / `idle`. BEL escape sequences (`\a`) from any pane
promote to `needs input`.

See `docs/ARCHITECTURE.md` for the full data flow.

### Why does the agent dashboard show `Tab N`?

`AgentPaneMapper` pairs each agent's `login` ancestor process with
the tab that spawned it (nth-oldest login → nth-oldest session by
creation time). When the pairing resolves you see `Tab 2`; when it
can't, the chip disappears (we don't fake precision).

### Can I disable the agent dashboard?

Yes — it's hidden by default and only polls when toggled open
(⌘⇧A). When hidden it does zero work. You can never see it again
and herminal works fine.

### Where are my notes stored?

`~/Library/Application Support/herminal/notes.db` — SQLite WAL.
Per-terminal-session, autosaved. Markdown round-trip via
File → Export / Import.

If you uninstall via `brew uninstall --zap herminal` (cask), the
DB gets removed. Manual `.app` delete leaves it in place.

### Where are my SSH hosts stored?

`~/Library/Application Support/herminal/ssh-hosts.db` — same shape
as the notes DB. herminal NEVER stores SSH passwords or private
keys — those stay in `~/.ssh/config`, Keychain, or wherever you
keep them today. herminal only stores the connection metadata
(nickname, hostname, user, port).

### Can I import my existing `~/.ssh/config`?

Yes. File menu → `Import ~/.ssh/config`. Every concrete `Host`
block becomes an `SSHHost` row. Wildcards (`Host *`) are skipped.
Multi-target lines (`Host a b c`) all get the same directives —
faithful to OpenSSH semantics.

### Does the SSH connect actually run ssh?

Yes — `WorkspaceView.connectSSH` builds a `ssh user@host -p port`
command and opens it in a new tab via libghostty's `config.command`.
Your OpenSSH config + keys are used unchanged. herminal doesn't
re-implement SSH, just spawns it.

---

## Privacy + telemetry

### Does herminal phone home?

No. The codebase contains no HTTP client, no analytics SDK, no
crash-reporter network code, no auto-update poll. The only network
activity is whatever YOU run in a terminal pane (curl, ssh, npm,
git push, etc.).

See `SECURITY.md` for the explicit threat model and what's
considered in vs out of scope.

### What's in the crash diary file?

`~/Library/Application Support/herminal/diary.log` — a local
text file. Captures app lifecycle events (launch, terminate, tab
open/close, sidebar toggles, SSH connect requests) and any crash
signal that fires. **No content from your terminal is logged.**
The shell output, the keystrokes you typed, the commands you ran —
none of it goes in the diary.

If you ever need to file a bug, the bug template will ask you to
paste the tail of this file. `Diary.exportRedacted()` strips
user-home paths so the paste is safe to share publicly.

### Will Sparkle send my system info to a server?

When Sparkle is wired in (post-v0.1.1), the only HTTP request it
makes is `GET appcast.xml` from the herminal release URL. macOS
adds standard User-Agent + Accept-Language headers; we don't add
identifying info. You can disable update checks entirely in
Preferences (planned UI; today the Updater stub is a no-op).

---

## Performance

### How fast is herminal?

Keystroke-to-render p95 < 5 ms on Apple Silicon. The `LatencyProbe`
logs per-tick stats; you can see them in Console.app filtered to
the herminal subsystem.

Compare to Electron-based terminals (Warp, Wave): 20-50 ms p95
keystroke latency is typical.

### Why does CPU spike when I open btop / htop?

Those tools redraw the whole screen on a fast timer (1-2 Hz). The
spike is libghostty's renderer churning through the redraws, not
herminal's chrome. Same behaviour you'd see in any other native
terminal. The CPU sampling in `AgentStatusTracker` won't tag them
as agents — only `claude`/`codex`/`aider` match.

### Does the agent dashboard polling slow things down?

Polls every 2s when open, never when closed. Each poll: one sysctl
call (~100 µs), one `proc_pid_rusage` per detected agent (negligible),
one snapshot of bell registry. Total CPU per poll: well under 1 ms.

---

## Building + contributing

### How do I build from source?

See `README.md` → "Install" → "From source". `Scripts/bootstrap.sh`
builds the libghostty xcframework via Zig (~5-15 min cold, cached
afterwards). `Scripts/make-app-bundle.sh` assembles the `.app`.

### Why does `swift test` take 80 seconds the first time?

libghostty's renderer warmup + SQLite WAL setup + the
`AgentStatusTracker` tests that genuinely wait 500 ms to measure
CPU deltas between samples. Subsequent runs are ~10 seconds.

### Can I run a subset of tests?

```sh
swift test --filter HerminalCore   # libghostty bridge + BellRegistry
swift test --filter HerminalDB     # NotesStore + SSHHostsStore + SSHConfigImporter
swift test --filter HerminalAgent  # AgentDetector + AgentStatusTracker + AgentPaneMapper
swift test --filter HerminalApp    # Workspace + Diary + IME bridge + SSH command
```

### Where do I file a bug?

GitHub Issues, using the bug template. The template prompts you
for the diary excerpt + dogfood journal day + dogfood-daily output
so triage is fast. For security issues: see `SECURITY.md` — email,
not GitHub.

### How do I contribute a fix?

Read `CONTRIBUTING.md` first — it spells out what's in/out of
scope and the code-style + testing requirements. PR template
prompts for the test plan + screenshots.

---

## Roadmap + non-goals

### Will herminal get [feature X]?

Check `docs/ROADMAP.md` first. It splits items into:
- **Shipped** (v0.1.0)
- **Next** (post-MVP, beta-feedback-gated)
- **Won't ship by design** (cross-platform, cloud sync, AI chat
  inside the terminal, App Store distribution, telemetry)

If your feature is in "Next", filing a feature request adds signal.
If it's in "Won't ship", a PR won't merge regardless of quality.

### Why no plugin system?

Out of scope for v1 — the maintenance surface of a plugin API would
double the test matrix and we don't have the bandwidth. If herminal
finds an audience and a feature genuinely needs the extensibility,
a v2.0 plugin system would be a focused project of its own.

### Why no AI chat inside the terminal?

The PRD positions the agent dashboard as the AI surface. Chat-in-
terminal duplicates what Claude Code, Codex, and Aider already do
inside any terminal — adding herminal-specific chat would just be
a worse version of those.

---

## Troubleshooting

### herminal crashes on launch

Tail `~/Library/Application Support/herminal/diary.log`. If you see
a `=== CRASHED signal=N ===` line, file a bug with the diary excerpt
and the macOS crash report from
`~/Library/Logs/DiagnosticReports/herminal-*.crash`.

### Vietnamese Telex types two characters per keystroke

This is the IME bridge desyncing. See `docs/TROUBLESHOOTING.md` for
the steps to capture the state. The 20-phrase smoke checklist at
`docs/QA/vietnamese-ime-checklist.md` will tell you exactly which
defect class it is.

### dogfood-daily.sh fails

See `docs/TROUBLESHOOTING.md` — the most common cause is a stale
HerminalApp process from a previous run. The script bumps the
inject-delay env var by default; if it's still flaking, the
back-to-back regression note in M6 retro applies.

---

If your question genuinely isn't in this FAQ, the troubleshooting
guide, or the bug template — file an issue. We update this doc
whenever a question shows up twice.
