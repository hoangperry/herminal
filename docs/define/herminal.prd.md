# Herminal Product Requirements Document

Date: 2026-05-20
Status: Draft for MVP definition
Owner: Solo developer
Product: herminal, an AI-native macOS terminal emulator for Vietnamese developers

## 1. Vision

Herminal is a local-first macOS terminal for Vietnamese developers who run Claude Code and other coding agents all day: it should feel as fast and native as Ghostty, input Vietnamese as reliably as iTerm2, keep tmux/multi-session workflows intact, expose active AI agents in a first-class dashboard, and attach durable notes to each terminal session without sending terminal context to a cloud product.

## 2. Problem Statement

Vietnamese AI-heavy developers currently stitch together an awkward stack: iTerm2 for reliable Vietnamese input and tmux control mode, Ghostty for fast Claude Code streaming, Warp or Wave for AI-oriented UX, Obsidian/Bear/Notes for per-task scratchpads, and tmux for long-running work. The stack works, but it is fragmented. Context lives in too many places, agent sessions are hard to monitor, and terminal state is not linked to the notes that explain why a command was run.

The pain is concrete:

- iTerm2 is the safest daily terminal for Vietnamese IME and tmux, but it has no real AI-agent dashboard and no terminal-attached notes.
- Warp is strong for AI workflows, but its cloud/account posture and block model are not a natural fit for privacy-first tmux users.
- Wave has useful AI/workspace ideas, but Electron weight and non-native input make it less attractive as a Vietnamese-first macOS daily driver.
- Ghostty is fast and agent-friendly, but intentionally does not solve notes, agent orchestration, or workflow UI.
- tmux is excellent for persistence, but it hides semantic structure from GUI tools and AI dashboards.
- Claude Code and similar tools stream lots of rich ANSI/OSC output, but most terminals treat them like ordinary noisy shells rather than long-running collaborators that need status, focus, and notes.

The market gap is narrow but real: no 2026 macOS terminal hits all five required axes at once: Claude Code optimization, Vietnamese Telex/VNI correctness, tmux + multi-session, multi-agent dashboard, and per-terminal persistent notes.

## 3. Target User Personas

### Persona A: Minh Nguyen, Solo AI Product Engineer

- Role: Full-stack product engineer in Ho Chi Minh City building side projects and internal tools.
- Daily workflow: Opens 3-6 terminal sessions per repo, runs Claude Code for implementation, uses tmux for long-running dev servers, writes Vietnamese task notes in another app, checks browser and Git constantly.
- Current pain: Claude Code sessions blur together; he loses which agent is editing which task. Notes are detached from terminal tabs. iTerm2 is stable but not AI-aware. Warp feels useful but too cloud-oriented for repo context and credentials.
- Willingness to switch: High if herminal can become his default terminal for one repo for a week without breaking Vietnamese input, tmux, or Claude Code streaming.

### Persona B: Lan Tran, Senior Backend Engineer and Team Lead

- Role: Backend/platform lead at a Vietnamese startup, often reviews infra, CI, Kubernetes, and service incidents.
- Daily workflow: Lives in tmux, SSH, logs, lazygit, vim/neovim, and Claude Code/Codex for debugging. Keeps incident notes and command snippets in markdown files.
- Current pain: Needs tmux reliability and privacy more than AI magic. Existing AI terminals feel like a separate environment. During incident-style work, agent outputs, shell state, and notes diverge quickly.
- Willingness to switch: Medium. She will not switch for a pretty terminal. She may switch if herminal preserves tmux habits, stays local-first, and makes multi-agent monitoring materially calmer.

### Persona C: An Pham, macOS-Native Developer and Open-Source Maintainer

- Role: Swift/macOS developer maintaining native apps and CLI tools.
- Daily workflow: Uses Xcode, SwiftPM, terminal test loops, Claude Code for refactors, and Vietnamese/English mixed writing in commit messages, docs, and prompts.
- Current pain: Terminal IME bugs are unacceptable because Vietnamese prompts and commit text must not corrupt. Existing terminal notes are either absent or not linked to repo/session context.
- Willingness to switch: High for a native-feeling app with excellent keyboard behavior, low latency, and an honest pet-project scope. Low tolerance for Electron-like feel or broken AppKit conventions.

## 4. MVP Scope (3 Months)

Ruthless rule: the MVP is not a general terminal platform. It is a daily-driver candidate for one Vietnamese developer running Claude Code locally. If a feature does not directly support that job, it waits.

### MoSCoW Feature List

Only these seven product features are considered for the 3-month MVP.

| Priority | Feature | Decision |
|---|---|---|
| Must | Claude Code optimized native terminal core | Build |
| Must | Vietnamese IME correctness for Telex/VNI via macOS input methods | Build |
| Must | Multi-session workspace with tmux-compatible terminal behavior | Build |
| Must | Multi-agent dashboard for active terminal sessions | Build |
| Must | Per-terminal persistent notes backed by local SQLite | Build |
| Should | Minimal preferences: shell, font, working directory, key behavior | Build only if Must features are stable |
| Could | Local debug/session bundle export for bug reports | Build only if it takes less than one week |

## 5. Feature Specs

### Must Feature 1: Claude Code Optimized Native Terminal Core

User story:

As a developer running Claude Code for long implementation sessions, I want herminal to render streaming agent output quickly and correctly so I can treat it as my primary terminal instead of falling back to Ghostty or iTerm2.

Acceptance criteria:

- Herminal can launch the user's default login shell, run `claude`, `codex`, `npm`, `git`, `vim`, `lazygit`, and `tmux` without corrupting basic terminal output.
- Claude Code streaming output stays responsive during long token streams; the UI must not visibly freeze during normal agent output.
- ANSI colors, truecolor, alternate screen, mouse reporting, hyperlinks, clipboard OSC 52 policy, OSC 7 current-directory reporting, and OSC 133 semantic prompt sequences are either supported through libghostty or intentionally ignored without display corruption.
- Copy/paste, selection, scrolling, and prompt navigation work during and after long Claude Code sessions.
- A compatibility smoke test document can be run manually against Claude Code, tmux, neovim, fzf, starship/p10k, btop, and lazygit before beta.

Technical notes:

- Use `libghostty` as the terminal engine through its C ABI. Do not write a terminal parser, grid, renderer, or PTY layer from scratch in the MVP.
- Build a thin Swift wrapper around the engine. Keep the wrapper boring: lifecycle, surface hosting, process/session IDs, and event bridging.
- Prefer an AppKit `NSView`/Metal-backed terminal surface where libghostty expects native drawing hooks. SwiftUI should host panels and app chrome, not own the terminal rendering hot path.
- Add lightweight instrumentation from day one: keydown-to-render latency, frame stalls, PTY throughput, dropped frames, and crash logs stored locally.

### Must Feature 2: Vietnamese IME Correctness for Telex/VNI

User story:

As a Vietnamese developer writing prompts, commit messages, shell commands, and notes in Vietnamese, I want Telex/VNI input to work predictably so I never have to switch terminals just to type Vietnamese safely.

Acceptance criteria:

- macOS Vietnamese Telex and VNI input methods can enter common words and sentences such as `tiếng Việt`, `đường dẫn`, `kiểm thử`, `không ghi đè`, and `xử lý lỗi` in shell prompts and notes.
- Marked text composition is visible and stable while typing; marked text is not sent to the PTY until committed.
- Candidate windows appear at the correct location relative to the cursor on Retina displays and after window resize.
- Copy/paste preserves Vietnamese Unicode text between herminal, VS Code/Cursor, browsers, and Notes without mojibake or lost combining marks.
- Command shortcuts such as Cmd+C, Cmd+V, Cmd+T, Cmd+W, Cmd+K, and Option-as-Meta behavior do not break IME composition.

Technical notes:

- Implement the macOS input path through `NSTextInputClient` behavior at the terminal view boundary. Do not invent a custom Telex/VNI engine in MVP.
- Treat IME state as a first-class terminal input mode: composition, commit, cancel, and selection must be explicit events.
- Normalize pasted text consistently, but avoid destructive transformations. Record whether NFC normalization is needed after empirical testing.
- Maintain a manual Vietnamese IME regression checklist because automated IME tests on macOS are brittle.

### Must Feature 3: Multi-Session Workspace with tmux-Compatible Behavior

User story:

As a tmux user who runs multiple repos, servers, and agents, I want tabs/splits and tmux compatibility so herminal can organize real work without replacing my existing shell habits.

Acceptance criteria:

- Users can create, close, rename, and focus terminal tabs and splits with keyboard shortcuts.
- Each terminal session tracks shell PID, working directory when available, title, creation time, last activity time, and optional Git branch metadata.
- Herminal can run tmux normally inside a terminal session with correct colors, mouse behavior, alternate screen handling, resize behavior, and clipboard policy.
- Herminal provides a simple tmux launcher profile: new tmux session, attach existing session, and attach-or-create by repo name.
- Closing a window warns when sessions contain active foreground processes or agent sessions that appear to be running.

Technical notes:

- MVP does not include iTerm2-style `tmux -CC` native control mode. Standard tmux inside the PTY plus launcher support is enough for the first release.
- Model herminal sessions separately from shell processes. A `TerminalSession` should own metadata and note linkage even when the child shell exits.
- Store session metadata locally, but do not promise full process resurrection. If the app restarts, it may reopen layout shells and notes, not revive dead processes.
- Use OSC 7, shell title updates, and Git detection heuristics for context. Do not require shell integration scripts for MVP.

### Must Feature 4: Multi-Agent Dashboard

User story:

As a developer running several Claude Code/Codex/Aider sessions at once, I want a dashboard showing which agents are active, blocked, done, or failed so I can supervise work without clicking every tab.

Acceptance criteria:

- Herminal can mark a terminal as an agent session automatically when known commands such as `claude`, `codex`, or `aider` are detected, and manually through a user action.
- The dashboard shows one row/card per agent session with name, command, working directory/repo, current status, last activity age, and linked note indicator.
- Status detection supports at least: running, idle, needs input, exited success, exited error, and unknown.
- Selecting an agent in the dashboard focuses the correct terminal session.
- Users can copy the latest visible agent output snippet and stop/kill a stuck agent from the dashboard with confirmation.

Technical notes:

- Start with local heuristics: process name, PTY output patterns, exit status, and idle timers. Do not build an agent protocol before observing real usage.
- Keep the dashboard read-mostly. It should supervise terminals, not become a full orchestration platform in MVP.
- Persist agent session summaries in SQLite for notes linkage and post-session review.
- Avoid cloud LLM calls. Herminal should not interpret private terminal output through a remote model.

### Must Feature 5: Per-Terminal Persistent Notes

User story:

As a developer switching between terminals and agents, I want each terminal to have a persistent note so task intent, commands, decisions, and follow-ups stay attached to the session that produced them.

Acceptance criteria:

- Every terminal session has a note panel that autosaves locally without explicit save actions.
- Notes are linked to terminal session ID, working directory, optional Git repo, optional Git branch, title, and timestamp.
- Closing and reopening herminal preserves notes and can show recent notes even if the original shell process is gone.
- Notes support plain markdown editing, basic search by text/repo/session title, and copy/paste with Vietnamese text.
- Notes never leave the machine in MVP. There is no account, sync, telemetry upload, or cloud notebook feature.

Technical notes:

- Use local SQLite with WAL mode for notes, sessions, and agent summaries.
- Suggested tables: `sessions`, `notes`, `agent_runs`, and `schema_migrations`.
- Use a simple markdown text editor in MVP. Rendering preview is optional and should not block.
- Full encryption is not MVP unless it is nearly free through a proven local library. FileVault plus local-only storage is the baseline.

## 6. Out of Scope (Explicit)

Do not build these in the MVP, even if they are tempting:

1. Cross-platform support for Linux, Windows, or iPad.
2. A custom terminal engine, VT parser, text renderer, or PTY implementation from scratch.
3. A custom Vietnamese Telex/VNI input engine.
4. Full iTerm2-style `tmux -CC` control mode.
5. Built-in LLM chat assistant.
6. Multiple LLM provider integrations.
7. Cloud sync for notes, settings, shell history, or sessions.
8. Team collaboration, shared terminals, multiplayer presence, or comments.
9. Plugin system, extension marketplace, or scripting API.
10. Theme marketplace or deep theme editor.
11. SSH connection manager, secrets vault, bastion workflows, or SFTP browser.
12. Full IDE/file explorer/editor features.
13. Built-in browser automation panel.
14. Remote persistent sessions beyond what tmux already provides.
15. Enterprise policies, admin controls, SSO, or audit logs.
16. App Store distribution.
17. Mobile companion app.
18. AI-generated command suggestions.
19. Shell history search across all projects as a product feature.
20. Monetization, billing, license keys, or paid plans.

## 7. Success Metrics

### End of Month 1

- Technical spike proves libghostty can be embedded in a macOS app controlled from Swift.
- Herminal can launch `zsh -l`, run basic commands, and render a usable terminal window.
- Owner can run one Claude Code session for 30 minutes without crashing.
- Vietnamese IME smoke checklist passes for at least 20 Telex/VNI phrases in shell input and notes.
- Keydown-to-visible-render p95 is under 20 ms on the owner's primary Mac during ordinary shell use.
- No more than one crash per two hours of owner testing.

### End of Month 3

- Owner uses herminal as daily driver for at least 5 workdays in one real repo.
- MVP Must features are all present: terminal core, Vietnamese IME, multi-session/tmux-compatible workflow, agent dashboard, persistent notes.
- Five Vietnamese developers complete a guided beta test covering Claude Code, tmux, Vietnamese typing, and notes.
- At least 80% of the manual compatibility matrix passes: Claude Code, tmux, neovim, fzf, starship/p10k, lazygit, btop, Git workflows, npm/pnpm scripts.
- Agent dashboard correctly identifies active/exited/needs-input states in at least 80% of observed Claude Code/Codex/Aider sessions during beta.
- Notes database survives app restart and forced quit with no observed note loss in beta.
- Public repo or private build has at least 20 tracked issues/feedback items from real usage, not imagined backlog.

### End of Month 6

- 20 Vietnamese developers have tried herminal; at least 5 use it for real work more than twice per week.
- Owner has used herminal as primary terminal for one full month with fallback only for known missing features.
- GitHub reaches 100 stars if open source, or private beta waitlist reaches 50 developers if closed source.
- p95 keydown-to-render stays under 16 ms and no normal Claude Code streaming session causes multi-second UI freezes.
- Crash-free session rate is above 99% across beta builds.
- Notes and agent dashboard are cited by beta users as the reason to use herminal over Ghostty/iTerm2, not just "it looks nice."
- Clear go/no-go decision exists for v0.2: tmux control mode, local LLM features, or broader beta. Only one can be chosen next.

## 8. Risks + Mitigations

| Risk | Why it matters | Mitigation |
|---|---|---|
| libghostty C ABI is unstable or hard to embed | The entire schedule depends on not writing a terminal engine | Spike in month 1 before building product UI. Keep wrapper thin. Track upstream closely. Be ready to fall back to a Ghostty fork only if embedding fails. |
| Swift/AppKit/SwiftUI integration becomes messy | Terminal rendering, IME, focus, and panels cross framework boundaries | Use AppKit for the terminal surface and SwiftUI for surrounding UI. Do not force pure SwiftUI where it fights IME or rendering. |
| Vietnamese IME bugs are deeper than expected | This is a core differentiator; one bad input bug destroys trust | Build a manual IME regression suite early. Test Telex/VNI every week. Treat IME regressions as release blockers. |
| Scope creep turns MVP into a Warp/Wave clone | Solo pet-project cannot compete with funded AI terminals feature-for-feature | Freeze the seven-feature MoSCoW list. Anything outside it goes to `Out of Scope` or post-MVP. |
| tmux expectations exceed MVP support | iTerm2 users may expect full control mode | Be explicit: MVP supports tmux inside terminal plus launcher workflows, not native control mode. Consider tmux control mode only after daily-driver stability. |
| Agent status detection is unreliable | Heuristics can mislabel sessions and annoy users | Start with transparent statuses and manual override. Store observed patterns. Avoid pretending to have perfect agent awareness. |
| Performance regressions appear once notes/dashboard are added | Side panels can accidentally slow the terminal hot path | Keep terminal engine/rendering isolated. Dashboard observes events asynchronously. Never parse full scrollback on the main thread. |
| SQLite note corruption or data loss | Notes are a trust feature; losing them is worse than not having notes | Use SQLite WAL, migrations, frequent autosave, backup-on-migration, and crash testing. Keep schema simple. |
| macOS distribution slows beta | Codesigning/notarization can burn weeks | Ignore App Store. Plan Developer ID, notarization, DMG/Homebrew distribution only after MVP works locally. |
| Market is too niche | Vietnamese AI terminal may not sustain attention beyond owner | Define success first as owner daily-driver. Month 6 beta metrics decide whether this remains a personal tool or becomes public product. |
| Solo developer burnout | Terminal projects are notoriously deep | Build in vertical slices. Ship internal builds weekly. Do not chase parity with Ghostty, iTerm2, Warp, or Wave. |
| Upstream competitor ships similar features | Ghostty/cmux/Warp/Wave may close parts of the gap | Differentiate on Vietnamese IME, local notes, and small native workflow. Avoid competing on generic AI chat. |

## 9. Tech Stack Decisions

### Terminal Engine: libghostty over Alacritty core

Decision: Use `libghostty` through its Zig C ABI.

Rationale:

- Ghostty is the strongest 2026 baseline for native macOS performance, modern protocols, and Claude Code-friendly behavior.
- It avoids spending 12-18 months rebuilding parsing, grid state, rendering, Unicode handling, and protocol compatibility.
- A C ABI is easier to bridge to Swift than a Rust crate if the ABI is stable enough.
- Alacritty's core is excellent, but its OpenGL heritage and Rust integration path add work that does not directly improve herminal's differentiation.

Trade-off:

- Herminal becomes dependent on Ghostty internals and upstream ABI maturity. This is acceptable only if the month-1 spike proves embedding is stable enough.

### macOS App: Swift plus AppKit terminal surface plus SwiftUI chrome

Decision: Use Swift as the app language. Use AppKit/NSView for terminal rendering, focus, keyboard, and IME. Use SwiftUI for dashboard, notes panel, settings, and app shell where it is productive.

Rationale:

- IME correctness on macOS is AppKit-shaped. A terminal view needs precise control over `NSTextInputClient`, cursor rects, marked text, and key events.
- SwiftUI is good for sidebars and forms, but too risky as the sole owner of terminal input/rendering.
- A native app is the point. Electron is disqualified for this product.

Trade-off:

- The app has two UI layers. Keep boundaries strict: terminal surface is AppKit; product panels are SwiftUI.

### Notes Storage: SQLite over file-based markdown

Decision: Store notes, session metadata, and agent summaries in local SQLite.

Rationale:

- Notes are attached to sessions, agents, repos, branches, timestamps, and future search. This is relational data.
- SQLite gives atomic autosave, migrations, FTS later, and fewer edge cases than many loose markdown files.
- File-based notes are nice for user ownership, but they make linkage, search, and crash-safe autosave harder in the MVP.

Trade-off:

- Users cannot simply browse all notes as markdown files in Finder. Post-MVP can add export/sync, but MVP should protect data integrity first.

### Local-First Privacy: no account, no sync, no remote AI calls

Decision: Herminal MVP is local-only.

Rationale:

- Privacy-first is one of the few credible differences versus Warp.
- Terminal scrollback may contain secrets, internal code, logs, and credentials. Herminal should not upload it.
- Solo developer cannot safely operate a cloud AI/data product in MVP.

Trade-off:

- No cloud sync, team notebooks, or magic agent interpretation. This is a feature, not a bug, for the target user.

### MVP Agent Intelligence: heuristics over protocol

Decision: Detect agent sessions using local process/output heuristics and manual marking.

Rationale:

- Claude Code/Codex/Aider do not share one stable terminal-agent protocol.
- A custom protocol would be speculative before real usage.
- Heuristics are enough to validate whether the dashboard is valuable.

Trade-off:

- Status will sometimes be wrong. Manual override and transparent "unknown" states are required.

### Distribution: unsigned/dev builds first, Developer ID DMG later

Decision: Use local developer builds during month 1-2. Prepare Developer ID signing/notarization only when MVP is stable enough for beta.

Rationale:

- Distribution work does not reduce product risk until the terminal is usable.
- App Store sandboxing is a bad fit for a terminal emulator.

Trade-off:

- Early testers may need manual trust steps until notarized beta builds exist.

## 10. Open Questions

These require user decision before or during early coding:

1. Is herminal intended to become open source? If yes, what license is acceptable given Ghostty/libghostty constraints?
2. Is the goal personal daily-driver, public free tool, or eventual paid product?
3. How many hours per week are realistically available for the next three months?
4. What macOS versions and hardware are supported for MVP?
5. Should note encryption be required before beta, or is local SQLite plus FileVault acceptable for v0.1?
6. Is full `tmux -CC` control mode a post-MVP priority, or is standard tmux compatibility enough long-term?
7. Which agent CLIs are first-class in MVP: Claude Code only, or Claude Code plus Codex and Aider?
8. Should herminal expose any telemetry at all, even local opt-in diagnostics, or stay zero-telemetry?
9. What is the minimum acceptable visual design bar: utilitarian iTerm2-like, Ghostty-like minimal, or opinionated Raycast/Linear-style native UI?
10. Should notes be private to herminal's SQLite DB, or should markdown export/import be required from day one?
11. What is the preferred default shell and setup assumption: system `zsh -l`, user's `$SHELL`, or configurable first-run profile?
12. Who are the first five Vietnamese beta users, and what workflows must they test?
13. Does the product need to support remote SSH-heavy workflows in MVP, or only local terminal/tmux sessions?
14. What is the exact definition of "daily-driver for owner": hours per day, fallback threshold, and required commands?
15. Is the name `herminal` final enough for bundle ID, repo name, and notarization planning?

---

## 11. Open Questions — RESOLVED (2026-05-20)

Sau Define phase Q&A với chủ nhân, 15 open questions đã được trả lời:

| # | Question | Answer |
|---|---|---|
| 1+2 | License + goal | **Open source MIT**, public OSS, target community contribution |
| 3 | Hours/week | **Full-time 40h+/week** (480h total cho 3 tháng) |
| 4 | macOS support | **macOS 14+ Apple Silicon only** — không Universal Intel |
| 5 | Note encryption | **FileVault baseline** trong MVP, SQLCipher post-MVP |
| 6 | tmux -CC | **Defer v0.2** — MVP chỉ standard tmux trong PTY + launcher |
| 7 | Agent CLIs | **Claude Code (priority) + Codex (secondary)**. Aider/Cursor defer |
| 8 | Telemetry | **Zero telemetry** — không local diagnostics, không opt-in |
| 9 | Design bar | **Opinionated Raycast/Linear-style premium native** |
| 10 | Notes export | ⚠️ **Markdown export + import round-trip** — vượt recommended, +1 tuần effort |
| 11 | Default shell | **User's $SHELL + login** (`$SHELL -l`) |
| 12 | Beta users | **Bạn bè network cá nhân (ưu tiên) + Twitter/LinkedIn VN dev influencers** |
| 13 | SSH | ⚠️ **Connection manager UI built-in** — vượt recommended, +4-6 tuần effort |
| 14 | Daily-driver def | ⚠️ **8h+/day, không fallback** — aggressive commitment |
| 15 | Name | **herminal FINAL** — đăng ký bundle ID `com.{user}.herminal` + repo |

## 12. ⚠️ Scope Creep Warning

Sau khi resolve 15 questions, MVP scope đã mở rộng beyond original 3-month plan:

### Effort breakdown (estimate)
| Feature | Original | Updated | Delta |
|---|---|---|---|
| Terminal core (libghostty + Swift) | 6 tuần | 6 tuần | 0 |
| Vietnamese IME | 3 tuần | 3 tuần | 0 |
| Multi-session + tmux compat | 2 tuần | 2 tuần | 0 |
| Multi-agent dashboard | 2 tuần | 3 tuần (Claude + Codex) | +1 tuần |
| Persistent notes | 2 tuần | 3 tuần (round-trip export/import) | +1 tuần |
| **Premium design polish** | _included_ | **+3 tuần** (Raycast/Linear bar) | +3 tuần |
| **SSH Connection Manager UI** | _out of scope_ | **+5 tuần** | +5 tuần |
| Compatibility testing | 1 tuần | 1.5 tuần (2 CLIs) | +0.5 tuần |
| QA + bug fixing buffer | 2 tuần | 2 tuần | 0 |
| **TỔNG** | **18 tuần (~4.5 tháng)** | **28.5 tuần (~7 tháng)** | **+10.5 tuần** |

### Implication
**MVP với full scope hiện tại ≈ 7 tháng full-time**, không phải 3 tháng. Đây là math thực tế dựa trên solo dev với libghostty C ABI learning curve, AppKit IME quirks, và Swift premium UI polish.

### 3 phương án để chốt

#### Option A: Giữ scope, kéo timeline → 7 tháng MVP
- ✓ Mọi feature đều có trong MVP
- ✗ Risk burnout, market window chậm
- ✗ Premium design + SSH manager là consume time lớn

#### Option B: Cắt scope, giữ 3 tháng (★ Recommended)
**Cắt:**
- ❌ SSH Connection Manager UI → defer v0.2 (giữ standard `ssh` qua PTY trong MVP)
- ❌ Notes markdown round-trip → defer v0.2 (chỉ SQLite trong MVP, export sau)
- ⚠ Premium design polish → giảm xuống "Ghostty-style minimal native" cho MVP, premium polish ở v0.2

**MVP còn:** 5 MUST features gốc + Claude Code priority + Codex detection. **~4 tháng** với buffer.

#### Option C: Hybrid — 5 tháng MVP
- ✓ Giữ premium design (đây là USP của herminal)
- ✓ Notes export-only (no import — 2 ngày thay 1 tuần)
- ❌ SSH UI defer v0.2
- → **~5 tháng full-time**

### Khuyến nghị của phù phù醬

**Option B** — vì:
1. 3-4 tháng MVP cho phép owner dogfood sớm và iterate dựa trên usage thật
2. SSH manager UI và markdown round-trip không phải core USP — defer không mất differentiation
3. Premium design + Vietnamese IME + Claude Code + agent dashboard + notes ĐÃ đủ ấn tượng
4. Tránh burnout — 7 tháng solo full-time là zone đỏ

**Nếu chủ nhân quyết Option A hoặc C**, phù phù醬 sẽ tuân theo và adjust roadmap.


---

## 13. ✅ LOCKED DECISION — Option A: Full Scope, 7-Month MVP

**Date locked:** 2026-05-20
**Decision by:** Owner

### MVP Scope (7 tháng, full feature)

Tất cả 7 features đều trong MVP:
1. Claude Code optimized native terminal core (libghostty)
2. Vietnamese IME Telex/VNI correctness
3. Multi-session workspace + tmux-compatible
4. Multi-agent dashboard (Claude Code + Codex)
5. Per-terminal persistent notes + **markdown export/import round-trip**
6. **SSH Connection Manager UI built-in**
7. **Premium Raycast/Linear-style design polish**

### Updated Timeline Milestones

| Month | Milestone |
|---|---|
| **1** | libghostty spike + Swift app skeleton + basic terminal + IME smoke pass |
| **2** | Premium design system + tabs/splits + tmux-compat verified |
| **3** | Multi-agent dashboard alpha + notes SQLite + basic export |
| **4** | SSH Connection Manager UI + markdown round-trip + Codex CLI detection |
| **5** | Polish pass + compatibility matrix 80%+ (Claude, Codex, vim, tmux, fzf, lazygit) |
| **6** | Owner dogfood daily-driver 8h+/day, 30 ngày liên tục — collect honest feedback |
| **7** | Beta with 5+ VN dev friends + Twitter/LinkedIn recruit + GA prep |

### ⚠️ Burnout Mitigation (Top Risk #3, must execute)

7 tháng solo full-time là **zone đỏ**. Bắt buộc mitigations:

1. **Vertical slicing weekly** — ship 1 feature-end-to-end mỗi tuần thay vì horizontal layers
2. **Weekly demo log** — record 5-min demo cho mình, đo progress observable
3. **Friday "no-code" day** — chỉ design/research/admin Friday, tránh burnout
4. **Monthly retrospective** — review xem có cắt được scope không (re-open Option B/C)
5. **Beta network warm-up** — bắt đầu DM bạn bè VN dev từ Month 2 để có 5 beta ready Month 6
6. **Public progress** — Twitter/X build-in-public threads → external accountability
7. **Health checkpoint** — không quá 50h/week thực tế, tracking time

### Updated Success Metrics

#### End of Month 1
- libghostty embed Swift app proven, không phải fallback strategy
- Vietnamese IME pass 20 phrases trong shell + notes
- p95 keydown-to-render < 20ms
- Crash < 1/2h owner testing

#### End of Month 3
- 5 MUST features all functional (terminal, IME, multi-session, dashboard, notes)
- Compatibility matrix 70%+ pass
- Premium design system v0 (palette, typography, components)
- Owner dogfood 4h+/day informal

#### End of Month 5
- Compatibility 80%+ (Claude, Codex, vim, tmux, fzf, lazygit, btop, starship)
- SSH Connection Manager UI alpha
- Markdown round-trip functional
- Agent dashboard correctly classify status 80%+

#### End of Month 7 (GA prep)
- Owner dogfood 8h+/day 30 ngày liên tục, không fallback
- 5+ VN dev beta users active >2x/week
- p95 keydown-to-render < 16ms ProMotion
- Crash-free session > 99%
- 50+ GitHub stars (target nhẹ với pre-launch buzz)
- Public launch ready: notarized DMG + Homebrew formula + README

