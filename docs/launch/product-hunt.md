# Product Hunt launch — draft

Product Hunt rewards: a polished hero image, a 3-sentence tagline,
a "Maker's first comment" with concrete numbers, and engagement
within the first 4 hours after launch. Plan ~2 weeks ahead so the
hunter relationship (if you go that route) lands cleanly.

---

## Product name

```
herminal
```

(Lowercase. Same as the GitHub repo + the .app bundle. Product
Hunt's slug will be `herminal` if you submit early enough; if
taken, fall back to `herminal-terminal` or `herminal-mac`.)

## Tagline (60-char limit)

```
AI-native macOS terminal built for Vietnamese devs
```

Alternatives that target other angles:

```
Local-first macOS terminal with built-in AI agent dashboard
Native macOS terminal: Claude Code + Vietnamese + tmux
```

## Topics

Pick at most 4 (Product Hunt cap):

1. **Developer Tools** — primary
2. **Productivity** — secondary
3. **Open Source** — flag the MIT
4. **macOS** — platform anchor

## Hero image specs

PH renders at 1270 × 760. The hero needs to read at 240 × 144
(homepage thumbnail) and full-size.

Suggested composition (owner to produce):

```
┌────────────────────────────────────────────────────┐
│  ┌──────────┐                                       │
│  │ AGENTS  3│                                       │
│  ├──────────┤    [ herminal window screenshot       │
│  │ ● Claude │      showing the agent dashboard      │
│  │ ● Codex  │      open + a vim session + tmux      │
│  │ ○ Aider  │      status line ]                    │
│  └──────────┘                                       │
│                                                     │
│   "macOS terminal cho dev người Việt sống trong    │
│    Claude Code"  — tagline overlay top-right       │
│                                                     │
│   herminal · v0.1.0 beta · MIT · Apple Silicon     │
└────────────────────────────────────────────────────┘
```

Dark theme (the herminal default). Real screenshot, not a mock.
Title font: SF Pro Display (system); body: SF Mono.

## Gallery images (3-5 additional)

PH allows up to 8 gallery images. Suggested:

1. **Agent dashboard close-up** — full sidebar with all 4 status
   states (running, idle, needs-input, starting) visible. Tab N
   chip clearly readable.
2. **Vietnamese IME composition** — mid-typing screenshot of
   `tieesng vieejt → tiếng việt` with the underlined preedit
   visible.
3. **SSH manager** — sidebar showing 5-6 imported hosts from
   `~/.ssh/config` + the Connect button hover state.
4. **Notes panel** — markdown-formatted note in the right
   sidebar, with the file menu's Export option visible.
5. **Comparison table** — the one from the landing page,
   rendered as an image so PH thumbnail can show it without
   markdown.

## Maker's first comment (~500 words)

> Hi PH 👋 herminal maker here.
>
> I built herminal over 7 months because I needed a macOS terminal
> that did three things existing terminals don't all do at once:
>
> 1. **Run AI agents (Claude Code / Codex / Aider) all day** with
>    a glanceable view of which one is running, idle, or waiting
>    on me. Today this is 3-4 different terminal windows or a
>    "did it finish?" guessing game. herminal builds a process-
>    tree-walking dashboard that catches each agent within 2
>    seconds and tells me which tab it's in.
>
> 2. **Type Vietnamese reliably** in vim, tmux, claude code,
>    everywhere. Most modern terminals (Warp, Wave) get Telex
>    wrong. iTerm2 and Ghostty are great but neither has the
>    agent surface.
>
> 3. **Keep everything local.** I don't want my terminal session
>    shipped to anyone's cloud for "AI command improvements." No
>    account, no telemetry, no sync. Notes go to a local SQLite
>    file; SSH manager stores zero secrets and just imports your
>    existing ~/.ssh/config.
>
> What's under the hood:
>
> - libghostty 1.3.1 (the Zig engine that powers Ghostty) embedded
>   statically. Native Metal renderer; sub-5ms keystroke latency.
> - Swift 6 + AppKit + SwiftUI for chrome.
> - SQLite WAL for the notes + SSH host metadata.
> - 79 unit tests, 5 integration scripts (run real binaries, not
>   stubs), 1 CRITICAL + 5 HIGH security/code findings fixed in
>   a parallel-agent audit before launch.
>
> What's explicit non-goals:
>
> - No Linux/Windows. macOS-only by design.
> - No cloud sync, no account, no telemetry.
> - No AI chat inside the terminal — the dashboard is the AI
>   surface.
> - No App Store. Sandbox kills how libghostty spawns shells.
>
> v0.1.0 is the MVP. Roadmap is feedback-driven: SSH groups,
> recursive splits, opt-in diary upload all wait until beta says
> they hurt without them.
>
> Three real kernel bugs I documented along the way that other
> macOS-native-tools devs will probably hit:
> [link to docs/blog/]
>
> If you try it and something doesn't work, file a bug — the
> template auto-prompts for the diary excerpt + dogfood-daily
> output, so triage is fast.
>
> Happy to answer anything!

## Engagement plan (first 4 hours)

PH's algorithm weights vote velocity in the first hours. Plan:

- **Hour 0:** Owner posts launch tweet (`docs/launch/twitter-thread.md`)
  with the PH link. Pin it for the day.
- **Hour 0-2:** Respond to every comment within 15 minutes. The
  "maker is engaged" signal matters more than vote count.
- **Hour 0-4:** Cross-post the PH link to:
  - Reddit r/MacOS (sole post, follow their self-promo rules)
  - LinkedIn (the `docs/launch/linkedin-post.md` draft, with the
    PH link inserted into the CTA)
  - The Vietnamese developer community channels (Discord/Slack
    groups owner is part of)
- **Hour 4-8:** Reply to late-arriving comments. The PH "Top
  product of the day" cut happens around hour 6-8 PT.
- **Hour 24:** Thank-you tweet with the day's stats + a link to
  whatever issue was filed (proves the bug template works).

## Risks to expect

- **"Yet another terminal"** — most-cited critique. Counter with
  the comparison table — herminal is positioned against agent
  dashboard + Vietnamese IME, not general "Mac terminal."
- **"Why MIT not GPL"** — usually a single commenter; pointer to
  CONTRIBUTING.md is enough.
- **"Where's the Windows version"** — explicit non-goal; pointer
  to ROADMAP.md "Won't ship by design."
- **"This looks like Ghostty"** — fair! herminal uses libghostty.
  Counter: Ghostty is a great terminal-only product; herminal
  adds the agent dashboard + Vietnamese IME-as-first-class on top.
  Both can exist; we're not competing for the same user.

## Don't do

- Don't ask for upvotes. PH's TOS bans it; their algorithm
  penalises the post if reports come in.
- Don't post AGAIN if the launch underperforms. PH disallows
  duplicate launches; you'd need a meaningfully different version
  (e.g. v0.2.0 with new features) to relaunch.
- Don't engage with hostile comments combatively. "Thanks for the
  feedback, we explicitly designed for [X]; if that's not your fit,
  totally understand" is the right shape.
