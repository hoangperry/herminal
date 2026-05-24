# Month 7 Retrospective — herminal Beta Infrastructure + 7-Month Wrap

**Period:** 2026-05-25 (single-session infrastructure pass — M7-2
launch + first feedback wave are owner-led and amend this retro
after the fact)
**Sprint goal (PRD roadmap):** Beta release prep + launch + post-MVP
roadmap.
**Result:** ✅ Infrastructure goal met (M7-1 a/b/c/d done). **M7-2**
launch is owner-pending — the AI can prep the release pipeline, draft
the announcement copy, and wire CI, but it cannot publish to socials
or cut the actual tagged release. This retro covers the
infrastructure pass and serves as the **closing entry for the
7-month MVP**.

---

## 1. What Got Done

| # | Task | Outcome |
|---|------|---------|
| M7-1a | OSS hygiene | `CONTRIBUTING`, `CODE_OF_CONDUCT`, `SECURITY`, GitHub bug + feature + PR templates |
| M7-1b | CI | Two-lane GitHub Actions workflow with aggressive caching |
| M7-1c | Release tooling | `CHANGELOG.md` populated for [0.1.0]; `Scripts/release.sh` (version-gated, dogfood-daily-gated, signed, prints `gh release create`) |
| M7-1d | README v0.1.0 + launch copy | README reflects shipped state; press kit + Twitter thread + LinkedIn post drafts in `docs/launch/` |
| M7-2 | Beta launch | **Owner-pending** — needs human to post on socials + cut the tag |
| M7-3 | This retro | Bootstrapped; final amendment after M7-2 launches and first feedback wave settles |

**Stats this session:**
- 0 new unit tests (M7 is infrastructure, not behaviour — test count
  stays at 48).
- 1 new utility script (`Scripts/release.sh`); script count now 9.
- 6 commits, `0d28e53` → `98d36f2`.
- 12 new doc files (README rewrite + 11 new docs across OSS
  hygiene, CHANGELOG, launch copy, M7 backlog + retro).

**Month-7 infrastructure goal is met.**

---

## 2. The 7-Month Wrap — what shipped overall

| Month | Headline | Tests added | Bugs caught |
|---|---|---|---|
| M1 | libghostty embedded; Swift app skeleton; IME bridge wired | 12 | Renderer crash (BUG-001 — actor-isolated C callback), app exits without bundle (BUG-002) |
| M2 | Multi-session workspace; design system; tmux verified | 7 (cumulative 19) | NSSplitView pane sizing (workaround: manual layout, Q2-002) |
| M3 | Agent dashboard alpha; notes (SQLite + Markdown round-trip) | 13 (cumulative ~26) | proc_listchildpids 4096 PID truncation; redundant `?? nil` (both MEDIUM, fixed in `f5a82f0`) |
| M4 | GUI test harness; SSH manager; Codex detection | 6 (cumulative 32) | **Bracketed paste swallowed harness Enter**, **`proc_listchildpids` returns garbage on Sequoia** — first two real-bug catches by the new verification harness |
| M5 | Compat matrix (9/9); polish (slide + hover + a11y); IME bridge tests; signing pipeline | 8 (cumulative 40) | libghostty `exec -l` adds dash to p_comm; pipes don't work inside exec wrapper (both documented, not herminal bugs) |
| M6 | Crash diary; dogfood infrastructure; **agent status discrimination** | 8 (cumulative 48) | **`proc_pid_rusage` returns mach absolute time units, not nanoseconds (42× under-reporting)**; dogfood-daily back-to-back flake |
| M7 | OSS hygiene; CI; release pipeline; launch copy | 0 (infrastructure pass) | n/a |

**7-month totals:** 48 unit tests, 6 integration scripts, 9 utility
scripts, **0 unresolved crashes**, 3 production-grade macOS-kernel
bugs documented + worked around (`proc_listchildpids`,
`proc_pid_rusage`, bracketed paste), 1 active OSS repo ready to ship.

---

## 3. What We Learned (the cross-cutting lessons)

### The verification gap was the single most important debt

The M1-M3 retros each flagged it; M4-0 finally closed it; M4-1
immediately justified the closing by surfacing two bugs that had
survived two months of unit tests. Every subsequent month added
another integration script (`verify-ssh-spawn.sh`,
`verify-smoke-m1-m3.sh`, `verify-compat-matrix.sh`,
`dogfood-daily.sh`) and each of them caught at least one regression
or quirk before it could land in beta. **Build the test harness
before the feature, not after.**

### `MainActor.assumeIsolated` + `nonisolated(unsafe)` are the load-bearing Swift 6 patterns

Hit three times across the project:
- Timer tick into `ghostty.tick()` (M1)
- `NSAnimationContext.completionHandler` for sidebar slide (M5)
- IO callbacks on background queues (M1, M3, M6)

The pattern is the same every time: a non-isolated callback runs on
the main runloop and needs to touch `@MainActor` state. The wrap is
the correct acknowledgement, not a workaround. **Capture this in
`docs/PATTERNS.md` post-MVP** so the fourth hit doesn't relearn it.

### Three macOS-kernel-API surprises in one project

`proc_listchildpids` returning garbage on Sequoia, `proc_pid_rusage`
returning mach absolute time units, libghostty's `exec -l` prefixing
`p_comm` with a dash. Each cost half an hour to root-cause and was
worth a write-up. The post-MVP "Theme G" item in
`docs/backlog/month-7.md` to turn these into blog posts genuinely
saves the next macOS-native-tools builder a day.

### Discipline matters more than the code

Two of the three retros (M5, M6) flagged discipline as the
structural risk: signing/notarize as the historical solo-dev
time-sink (M5), dogfood as "use it, don't fix it" (M6). Neither
was solved by writing more code; both were solved by writing more
guidance into the docs (dogfood-checklist's "when NOT to fix"
section, RELEASE.md's troubleshooting front-matter). **Process
documentation is feature work in a solo project.**

### AI pair scope was clear by month 4

By M4 the pattern was set: AI proposes + executes; owner makes the
binary go/no-go calls (paid Apple Developer cert, 30-day dogfood,
"do I ship the beta now"). AI cannot substitute for human
judgement on what to ship or for human use of the product.
**This retro documents the boundary so future projects know which
month-types are infrastructure (AI-doable) vs experience (human-only).**

---

## 4. Estimate vs Actual — the whole 7-month picture

PRD Month-by-month plan vs what landed:

| Month | PRD goal | Outcome | Slip? |
|---|---|---|---|
| M1 | libghostty spike + IME smoke | spike + 12 tests + bundle infra | none |
| M2 | tabs/splits + tmux-compat + design tokens | as planned | none |
| M3 | dashboard alpha + notes + export | as planned, alpha was honestly shallow | none |
| M4 | SSH + Codex detect | as planned + closed verification debt | none (verification was unscoped bonus) |
| M5 | compat + polish + signing | as planned + IME bridge unit tests | none (signing waits on cert, but pipeline is ready) |
| M6 | dogfood 30 days | infrastructure done; 30 days in flight | "30 days" runs in real time, not session time |
| M7 | beta launch | infrastructure done; launch owner-pending | same shape as M6 — calendar, not code |

**The 7-month MVP arrives on plan,** with the asterisk that two
months end on "infrastructure done, the human-only part is in
progress." That's the right shape for both: dogfood and announcement
launch both require lived time, not just code.

No scope downgrade to Option B/C was needed.

---

## 5. Carry Into Post-MVP

The post-MVP roadmap is captured in detail at
`docs/backlog/month-7.md` § "Post-MVP roadmap" — seven themes (A
through G). Tightest carry list:

| Item | Theme | Why post-MVP |
|---|---|---|
| OSC 9 / BEL "needs input" agent status | A — Agent dashboard depth | Wait for beta to confirm `idle` vs `needs input` mismatch matters |
| Agent ↔ pane mapping | A | Needs libghostty upstream change or PTY scraping |
| Node-wrapped agent detection | A | `npx`-installed Claude appears as `node` (Q3-002) |
| SSH groups / search / `~/.ssh/config` import | B | Wait for beta to confirm flat list is a real friction |
| Recursive split trees, drag-to-resize | C | M2 deferrals (Q2-002, Q2-003); polish for v0.2 |
| Light theme | C | Owner dogfood + beta feedback decides yes/no (Q5-002) |
| IME hardening — KR/JP/CN smoke | D | Vietnamese is in place; other CJK is the natural next |
| First notarized release | E | Owner Developer-ID enrolment is in-flight |
| Homebrew cask | E | Pursue once one notarized release exists |
| Sparkle auto-update | E | Wait until > 2 release data points |
| `Diary.export()` with redaction | F | Wait for beta to ask for it |
| docs/PATTERNS.md + 3 kernel-gotcha blog posts | G | Saves the next macOS-native-tools builder a day each |
| Vietnamese-language README | G | Helps the target audience adopt |

---

## 6. Honest Self-Assessment (closing entry)

**Good:** The 7-month MVP arrived with every PRD-scoped feature
shipped, every behaviour covered by either a unit test or an
integration script, zero unresolved crashes, three macOS-kernel
gotchas documented + worked around, and a release pipeline that
turns "cut a tag" into a one-command invocation. The cross-cutting
patterns (`MainActor.assumeIsolated`, sysctl over libproc, env-var
test hooks, single-isolation `final class` stores) generalised
cleanly across modules and made the M5-M7 work faster, not slower.
The verification harness M4-0 built paid for itself on its first
real use (M4-1) and kept paying for itself through M5 polish, M6
dogfood, and M7 release infrastructure — every retroactive
refactor's regression check was a script away.

**Could be better:** The agent dashboard remains the project's
pitched differentiator and is the area most exposed to "alpha
quality" criticism. M3 shipped detection, M6 added
running/idle/starting, but agent ↔ pane mapping and OSC 9 / BEL
"needs input" detection are real gaps the post-MVP roadmap should
prioritise based on beta feedback rather than gut. The two big
"owner-pending" items (M6-2 30 days, M7-2 launch) are still in
front of us — until those land, this retro is genuinely
incomplete. Five themes from the post-MVP backlog are deferred
"until beta says it matters," which is the right discipline but
also the right kind of risk: if beta says it matters in week 1,
post-MVP needs to ship fast.

**Risk for post-MVP:** the launch itself. The release pipeline
shipped, the announcement copy shipped, the OSS hygiene shipped —
but the actual GitHub release tag, Twitter thread post, and first
issue triage are human acts the AI can't perform. Whatever week
the owner picks for M7-2 needs to be cleared of other commitments;
the first 72 hours of feedback set the project's reputation
trajectory more than the next six months of incremental work.

---

**End of 7-month MVP build log.** Post-MVP cadence is feedback-
driven, not calendar-driven — the next retrospective lands when
the first themed batch (probably Theme A — agent dashboard depth)
ships its first slice in response to beta input.

Made with 🐈 by Yuuhou Meow team in Việt Nam.
