# Reddit submissions — drafts

Reddit is a constellation of small communities with different
self-promotion rules. Owner posts ONE submission per subreddit;
do not cross-post the same text. The drafts below are deliberately
different lengths + framings to match each sub's culture.

---

## r/MacOS

**Title:**
```
herminal — open-source macOS terminal with built-in AI agent dashboard
```

**Self-text:**

> I've been building a macOS-native terminal called herminal for
> the past 7 months and just cut v0.1.0. It's MIT-licensed, no
> telemetry, no account.
>
> The pitch: every other macOS terminal in 2026 misses at least one
> of these — native rendering speed, reliable Vietnamese IME, tmux
> compatibility, a built-in dashboard for AI agent CLIs (Claude
> Code / Codex / Aider), per-session local notes. herminal does
> all five.
>
> Under the hood it's the libghostty engine (Ghostty's Zig core)
> embedded statically + a Swift 6 + AppKit shell. Sub-5ms
> keystroke latency. 79 unit tests + 5 integration scripts, all
> green.
>
> The agent dashboard is the differentiator — it walks herminal's
> process subtree, catches `claude`, `codex`, `aider` (including
> npm-wrapped + Python-wrapped variants), and tells you which
> tab each one is running in. Status badge inferred from per-PID
> CPU sampling + BEL ("needs input") detection.
>
> Honest non-goals: Linux/Windows (macOS-only by design), cloud
> sync, AI chat inside the terminal (the dashboard is the AI
> surface). Apple Silicon only.
>
> Repo: https://github.com/hoangperry/herminal
> Bug template auto-prompts for the diary excerpt so triage is
> fast if you find something.
>
> Happy to answer questions.

**Subreddit rules to check:**
- r/MacOS allows self-promotion in "Tools" tagged posts
- Title can't include emoji (some moderators auto-remove)
- Link to GitHub repo is fine; link to a landing page may trigger
  the spam filter

---

## r/programming

**Title:**
```
herminal: a Swift/libghostty macOS terminal — and 3 macOS kernel bugs I documented along the way
```

**Self-text:**

> I cut v0.1.0 of herminal (open-source macOS terminal built around
> Claude Code + Vietnamese IME) and figured the kernel gotchas I
> hit are the part most likely to save someone else time:
>
> **proc_listchildpids returns garbage on macOS Sequoia.** Probe
> call reports a buffer size, fill call returns 0 children, no
> errno. Use sysctl(KERN_PROC_ALL) and walk yourself — that's
> what ps and pgrep do under the hood.
>
> **proc_pid_rusage's ri_user_time / ri_system_time are mach
> absolute time units, NOT nanoseconds.** On Apple Silicon
> mach_timebase is 125/3 ≈ 41.67 ns per unit, so naive reading
> under-reports CPU by 42×. Cache mach_timebase_info and multiply.
>
> **libghostty's `exec -l` wrapper prefixes p_comm with a dash.**
> pgrep -x silently misses every spawned child because the comm
> field is `-vim` not `vim`. Match `^-?<name>$`.
>
> Full write-ups (each ~600 words):
> https://github.com/hoangperry/herminal/blob/main/docs/blog/
>
> Repo: https://github.com/hoangperry/herminal
> 7-month MVP, solo + Claude Opus 4.7 pair, 79 unit tests, 5
> integration scripts, all green. MIT.
>
> AMA on the implementation or the kernel APIs — I went deep on
> the second one (proc_pid_rusage) and have empirical timing data
> across Intel and Apple Silicon if anyone's curious.

**Subreddit rules:**
- r/programming bans pure project promotion but allows technical
  write-ups. This framing leads with the bugs (technical) and
  surfaces the repo as a sidebar.
- Don't include phrases like "check out my project" — the mod
  team's filter catches those.

---

## r/swift

**Title:**
```
herminal — a Swift 6 macOS terminal embedding libghostty (Zig). Lessons from 7 months of strict concurrency.
```

**Self-text:**

> Just shipped v0.1.0 of herminal, a macOS terminal built around
> Claude Code + Vietnamese IME. The whole codebase is Swift 6 with
> strict concurrency enabled from day one. Some patterns that
> earned their repetition along the way:
>
> **`MainActor.assumeIsolated` for Sendable closures that always
> run on main.** Timer fire blocks, `NSAnimationContext.completionHandler`,
> IO callbacks — all of them are `@Sendable` typed, all of them
> actually fire on the main runloop, and Swift 6 needs the
> explicit acknowledgement.
>
> **`nonisolated(unsafe)` for C handles + signal-handler state.**
> NSView's deinit is nonisolated; libghostty handles are non-
> Sendable C pointers. The unsafe is the explicit "I promise the
> lifecycle is safe."
>
> **File-scope globals for signal-handler state.** Swift's
> `static let` goes through `swift_once` which acquires a lock —
> not async-signal-safe. Move signal-handler state to module-level
> vars to bypass the runtime lazy-init path entirely.
>
> Full write-up of the 7 patterns:
> https://github.com/hoangperry/herminal/blob/main/docs/PATTERNS.md
>
> Repo (MIT): https://github.com/hoangperry/herminal
>
> 79 unit tests, 5 integration scripts, all green. Embeds
> libghostty 1.3.1 as a static xcframework. Sub-5ms keystroke
> latency on Apple Silicon.
>
> Happy to AMA on the strict-concurrency choices — especially the
> ones where I went through 2-3 iterations before settling on the
> right shape.

**Subreddit rules:**
- r/swift is friendly to OSS projects; the framing is technical
  + Swift-specific so it doesn't read as cross-post spam.

---

## r/commandline

**Title:**
```
herminal — macOS terminal with built-in AI agent dashboard + ~/.ssh/config import
```

**Self-text:**

> Cut v0.1.0 of herminal yesterday. It's a macOS-only terminal
> with two specific bets:
>
> 1. **AI agent CLIs deserve a dashboard.** If you run `claude`,
>    `codex`, or `aider` as part of your daily flow, herminal
>    walks its process subtree and tells you which agent is in
>    which tab, whether it's running / idle / needs-input. No
>    other terminal does this in 2026.
>
> 2. **Your ~/.ssh/config already works.** herminal's SSH manager
>    imports it directly. Stores zero secrets — your keys + your
>    `IdentityFile` directives stay where they are. Just one-click
>    `ssh user@host`.
>
> + Vietnamese IME (Telex + VNI), light/dark theme, tmux
> compatibility verified against vim/htop/fzf/lazygit/btop/starship,
> sub-5ms keystroke latency.
>
> Engine is libghostty (Ghostty's Zig core, embedded statically).
> Shell is Swift 6 + AppKit. MIT.
>
> Apple Silicon only, macOS 14+. No Linux/Windows by design.
>
> https://github.com/hoangperry/herminal
>
> What I'd love feedback on:
> - Is the agent-dashboard latency (2s poll) acceptable, or do
>   people want it more real-time?
> - Are there agent CLIs besides Claude/Codex/Aider that I
>   should auto-detect?
> - What's the right UX for "agent is waiting on me" beyond a
>   sidebar badge?

**Subreddit rules:**
- r/commandline is small but tightly-knit. They downvote pure
  promotion but reward "here's a thing + here are questions for
  the community."

---

## r/vietnam (and Vietnamese-language dev groups)

**Title:**
```
herminal — terminal macOS làm cho dev người Việt dùng Claude Code
```

**Self-text (Vietnamese):**

> Mình vừa ra v0.1.0 của herminal — terminal macOS open-source mình
> code 7 tháng vừa rồi cùng với Claude Opus 4.7 làm pair programmer.
>
> Lý do build:
>
> - Mọi terminal trên macOS 2026 đều thiếu ít nhất 1 trong 5 thứ:
>   - Performance native (Metal renderer)
>   - Vietnamese IME (Telex + VNI) thực sự work, không gấp đôi
>     ký tự, đặt dấu đúng chỗ
>   - tmux + multi-pane compatibility
>   - Dashboard cho AI agent (Claude Code / Codex / Aider) đang
>     chạy trong các tab
>   - Notes per-session lưu local, không ship lên cloud nào
>
> herminal làm hết 5 thứ trên. MIT-licensed, không telemetry,
> không account, không sync cloud.
>
> Đặc biệt với người Việt:
>
> - Vietnamese IME đã verify qua bộ 20 câu smoke test
>   (docs/QA/vietnamese-ime-checklist.md trong repo). Telex,
>   VNI, dấu thanh stacking — đều đúng ngay lần đầu.
> - README.vi.md có bản tiếng Việt đầy đủ.
> - 3 bài blog về kernel bugs trên macOS Sequoia (cũng viết tiếng
>   Anh, định translate sang Việt nếu có người quan tâm).
>
> Yêu cầu hệ thống: macOS 14+ Apple Silicon (M1/M2/M3/M4).
>
> Link: https://github.com/hoangperry/herminal
>
> Cần feedback từ Việt devs đang dùng Claude Code hằng ngày —
> đặc biệt là phần agent dashboard. File bug qua issue template
> trên GitHub, template tự prompt diary excerpt nên triage nhanh.

**Notes for the owner:**

- Vietnamese dev communities (Facebook groups, Telegram channels,
  Discord servers) are often gated. Don't cross-post the same
  text wholesale — adapt to each community's tone.
- "Open-source" + "không telemetry" + "MIT" are the load-bearing
  trust signals for Việt devs who've been burned by SaaS
  privacy issues.

---

## Posting order + cadence

Recommended week:

| Day | Subreddit | Note |
|---|---|---|
| Mon | r/MacOS | Best macOS-specific audience day |
| Tue | r/swift | Swift-tagged tech audience |
| Wed | (pause) | Avoid stacking; let r/MacOS settle |
| Thu | r/commandline | Niche but engaged community |
| Fri | r/programming | Highest reach but most critical |
| Sat | r/vietnam | Weekend = better engagement |

Don't post the same day to multiple subs — Reddit's anti-spam
heuristics flag rapid cross-posting even when content is genuinely
different.
