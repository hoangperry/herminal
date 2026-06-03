# herminal roadmap

Public-facing summary of what's shipped, what's next, and what
won't ship by design. For the per-month implementation detail see
`docs/backlog/`.

---

## Shipped — v0.1.0 beta (M1-M10)

Every PRD MVP feature plus the first post-MVP wave:

### Terminal core
- libghostty 1.3.1 embedded statically via xcframework
- Native Metal renderer, p95 keystroke-to-render < 5 ms
- Multi-tab workspace, vertical + horizontal pane splits
- Premium dark + light theme variants (⌘⇧L to toggle)
- Compatibility verified with vim, tmux, nano, less, htop, fzf,
  lazygit, btop, starship

### Vietnamese-first IME
- Telex + VNI verified end-to-end via NSTextInputClient
- 20-phrase smoke checklist for owner runs
- KR / JP / CN smoke checklists drafted for non-Vietnamese expansion

### Agent dashboard (the differentiator)
- Auto-detects Claude Code, Codex, Aider via process subtree walk
- Catches npm/python wrapper installs (`npx @anthropic-ai/claude-code`,
  `python3 -m aider`) with display name attribution like
  `aider (Python)`
- Running / idle / starting / needs-input badges with CPU + bell
  signals
- Per-tab attribution: each detected agent shows the tab number
  hosting its PTY

### SSH manager
- Local SQLite store; add / edit / delete with inline form
- Connect spawns `ssh user@host` in a new tab via
  libghostty `config.command`
- One-click import from `~/.ssh/config`
- Recency-sorted sidebar

### Per-session notes
- SQLite WAL store; autosave; per-session isolation
- Markdown export + import round-trips losslessly

### Telemetry-free observability
- Diary captures app lifecycle + tab/pane events to local file
- Signal handler records crash signal for cross-reference with
  process tree
- Redacted export for safe bug-report pasting (PII rewriting:
  `/Users/<redacted>`, libghostty surface addresses)

### Distribution infrastructure
- Developer-ID codesign + notarytool + stapler pipeline (script
  ready; gates on owner Developer-ID enrolment)
- DMG packaging with /Applications symlink
- Homebrew cask formula template (publishes once first
  notarized release lands)
- Sparkle update wiring stub + appcast template (framework
  integration in v0.2.x)
- GitHub Actions release workflow: tag-triggered, auto-builds,
  signs, packages, drafts GH release

---

## Next — v0.1.1 + beta cycle (owner-gated)

These items unlock once the corresponding owner action lands:

| Item | Unblocked by |
|---|---|
| First notarized release | Apple Developer cert enrolment |
| Homebrew cask publish | First notarized release |
| Sparkle framework integration | First notarized release + EdDSA key gen |
| Beta-feedback-driven slice 4+ | First beta-tester reports |

The dogfood journal under `docs/QA/dogfood/` and any GitHub
issues opened against the v0.1.0 draft will drive what ships in
the next slice. Until that signal arrives, the post-MVP roadmap
items below stay deferred — see "Why deferred" for each.

---

## Post-MVP roadmap (themed, feedback-driven)

Cadence isn't calendar-based after v0.1.0 — slices ship when an
input signal arrives that confirms the work's shape.

### Theme B — SSH manager v1 (slice 1 shipped)
- **Shipped:** `~/.ssh/config` import
- **Deferred:** Groups / folders (wait: how many hosts before
  flat list hurts?)
- **Deferred:** Search / filter (same — usability gate)
- **Deferred:** Per-host keypair UI (security review needed
  first; .ssh/config is the canonical source today)

### Theme C — Workspace ergonomics (multiple slices shipped)
- **Shipped:** Light theme variant (Q5-002)
- **Shipped:** Drag-to-resize dividers (Q2-002) — v0.3.3 polish wave
- **Shipped:** Auto-follow-system theme — v0.4.0 ("Follow System"
  picker reading `NSApp.effectiveAppearance`)
- **Shipped:** Recursive split trees (Q2-003) — tmux-style nesting
  (v0.5.0). Panes nest along either axis arbitrarily deep; the layout is
  a binary `LayoutNode` tree, persisted in `workspace.json` (old flat
  sessions still load).

### Theme H — Sessions (✅ fully closed in v0.4.0-v0.4.2)

The "terminal for devs living in Claude Code" continuity layer.
Retro: `docs/backlog/v0.4-sessions-retrospective.md`.

- **Shipped:** OSC 7 working-directory tracking + `working_directory`
  spawn (v0.4.0 foundation)
- **Shipped:** Claude session browser (⌘⇧C) — reads
  `~/.claude/projects`, one-click `claude --resume` in the right cwd
  (v0.4.0)
- **Shipped:** Session restore — last layout + per-pane cwd reopened
  on launch, toggle in Settings (v0.4.1)
- **Shipped:** Named workspaces — save/open/delete layouts via the
  Window menu + ⌃⌘S + palette (v0.4.2)
- **Shipped:** Live cwd in the status bar + tab title, with git branch
  next to the path (v0.4.4). Tab falls back to cwd basename only when no
  program set an OSC title; the status bar always shows the full path.
- **Deferred:** Re-running commands on restore (opt-in per pane) —
  conservative default is layout+cwd only; revisit if asked

### Theme D — IME hardening (slices ready)
- **Shipped:** Vietnamese checklist (20 phrases, owner runs live)
- **Shipped:** KR/JP/CN checklists (20 phrases each, owner runs)
- **Pending:** Live owner runs of each checklist + filing any
  failing rows
- **Deferred:** Live-Telex CI automation (would need a Telex
  simulator; unclear it's worth building)

### Theme E — Distribution (mostly shipped)
- **Shipped:** Sign + notarize pipeline, DMG, CD workflow
- **Shipped:** Developer-ID enrolment + notarized releases
  (v0.1.0 → v0.4.2, all signed + notarized + stapled)
- **Shipped:** Homebrew tap live —
  `brew install --cask hoangperry/herminal/herminal`
  (repo: `hoangperry/homebrew-herminal`, cask audit passes online)
- **Handoff-ready:** Sparkle auto-update — full integration spec at
  `docs/SPARKLE-NEXT.md`. Gated on the owner's EdDSA key (a secret)
  + careful framework-embedding into the hand-rolled bundle.
- **Pending (owner):** Push the tap upstream to homebrew-cask after
  ≥1 month stable + enough installs

### Theme F — Telemetry-free observability v2 (slice 1 shipped)
- **Shipped:** `Diary.exportRedacted()` for bug-report pasting
- **Deferred:** Opt-in upload toggle — wait for beta to ask
- **Deferred:** Daily diary rotation (Q6-002) — wait until file
  size becomes a complaint

### Theme G — Docs + community (slice 1 shipped)
- **Shipped:** PATTERNS.md, Vietnamese README, CJK checklists,
  3 kernel-gotcha blog drafts
- **Pending (owner):** Publish blog posts (one per week
  recommended)
- **Deferred:** Sponsor / Bountysource integration — wait for
  contributor demand

### Theme A — Agent dashboard depth (✅ fully closed in M8-M9)
- ✅ Node-wrapped detection (Q3-002)
- ✅ BEL / OSC 9 needs-input (Q6-001)
- ✅ Agent ↔ pane attribution

---

## Won't ship by design

These are deliberate non-goals per the PRD. PRs implementing
them won't merge.

| Non-goal | Reason |
|---|---|
| Linux / Windows builds | macOS-only by design |
| Cloud sync / accounts / team features | Local-first, no servers |
| Plugin marketplace | Out of scope for v1 |
| Theme marketplace | Out of scope for v1 |
| AI chat assistant inside the terminal | Agent dashboard is the AI surface |
| App Store distribution | Sandbox is incompatible with how libghostty spawns shells |
| Telemetry / phone-home | Telemetry-free is a load-bearing promise |

---

## How to influence the roadmap

- File a bug → `docs/QA/dogfood/` informs Theme D + frees up
  P0 budget
- File a feature request → answers a "deferred until beta asks"
  item
- Submit a PR → check `CONTRIBUTING.md` for scope rules first
- Send the owner an email → `hoangperry@proton.me` for things
  that don't fit GitHub

The roadmap re-evaluates after each beta-feedback wave, not on
a calendar.
