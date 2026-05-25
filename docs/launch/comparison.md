# herminal vs the field — full comparison

Long-form version of the comparison table on the landing page,
intended for a /comparison route or a blog post. Each row is a
specific user-visible behaviour, not an abstract feature label.

Updated 2026-05-25. The competitor data reflects the state of
each project at their latest stable release as of that date.

---

## TL;DR

If you're a macOS developer who:

1. Spends a meaningful fraction of your day in Claude Code, Codex,
   or Aider, AND
2. Types Vietnamese (or any non-Latin script) at least sometimes,
   AND
3. Uses tmux + multi-pane workflows,

…there is no terminal in 2026 that hits all three well. herminal is
the only one specifically designed around that intersection. If you
don't match all three, the choice between iTerm2 / Ghostty / Wave
depends on which axis matters most.

---

## Comparison axes

### Native rendering performance

| Terminal | Renderer | p95 keystroke→render | Subjective feel |
|---|---|---|---|
| **herminal** | libghostty + Metal | < 5 ms | indistinguishable from VT100 |
| iTerm2 | AppKit + CoreAnimation | 8-15 ms | excellent |
| Ghostty | libghostty + Metal | < 5 ms | indistinguishable from VT100 |
| Warp | Rust + WebGPU (via Electron-y shell) | 15-50 ms | noticeable on fast typing |
| Wave | Electron + Chromium | 20-80 ms | noticeable on fast typing, jank on resize |

**herminal verdict:** ties Ghostty (same engine) at the top of the
class. iTerm2 is great too; Warp and Wave pay an Electron tax that
shows on burst-type workloads.

---

### Vietnamese IME (Telex + VNI)

| Terminal | NSTextInputClient | Marked-text preview | Diacritic correctness |
|---|---|---|---|
| **herminal** | full implementation | underline preview | passes 20-phrase smoke matrix |
| iTerm2 | full implementation | underline preview | passes |
| Ghostty | full implementation | underline preview | passes |
| Warp | partial (custom input layer) | inconsistent | fails on tonal stacking |
| Wave | partial (Electron IME bridge) | inconsistent | fails on `aw`/`ow`/`oo` |

**herminal verdict:** iTerm2, Ghostty, and herminal all do this
right. herminal additionally has owner-runnable smoke matrices for
KR/JP/CN ready for the next audience expansion.

---

### tmux + multi-session

| Terminal | tmux compatibility | Native tabs | Native splits |
|---|---|---|---|
| **herminal** | full | ✓ | vertical + horizontal (single-axis per tab) |
| iTerm2 | full | ✓ | recursive tree, drag-resize |
| Ghostty | full | ✓ | recursive tree, drag-resize |
| Warp | partial (own "Blocks" model competes) | ✓ | grid layout, no axis nesting |
| Wave | none (no tmux-style I/O guarantees) | ✓ | grid layout |

**herminal verdict:** ties iTerm2/Ghostty on tmux correctness;
trails them on recursive split-tree depth and drag-resize (both
deferred to v0.2.x per roadmap Theme C).

---

### Agent dashboard (running AI CLIs)

| Terminal | Detects Claude / Codex / Aider | Per-pane attribution | Status discrimination |
|---|---|---|---|
| **herminal** | ✓ — native, via process tree walk | ✓ — `Tab N` chip | running / idle / needs-input / starting |
| iTerm2 | ✗ — no agent surface | — | — |
| Ghostty | ✗ — no agent surface | — | — |
| Warp | partial — proprietary "AI assist" replaces agent CLIs rather than detecting them | n/a | n/a |
| Wave | ✗ — no agent surface | — | — |

**herminal verdict:** the differentiator. No other terminal in 2026
treats AI CLIs as first-class observable processes. Warp's "AI
Assist" is a competitive product to Claude Code, not a dashboard for
it.

---

### Per-session notes

| Terminal | Notes UI | Storage | Privacy |
|---|---|---|---|
| **herminal** | sidebar, per-tab | local SQLite WAL | local-only by design |
| iTerm2 | session "notes" annotation | per-window state | local-only |
| Ghostty | none | — | — |
| Warp | "Notebooks" feature | proprietary cloud + local | cloud-tied, requires account |
| Wave | "AI Workflows" tagged commands | proprietary cloud | cloud-tied, requires account |

**herminal verdict:** iTerm2 has the closest equivalent (session
notes) but no Markdown round-trip. herminal's notes are explicitly
not-cloud — that's the point.

---

### Telemetry + privacy

| Terminal | Network calls at idle | Account required | Analytics |
|---|---|---|---|
| **herminal** | none | no | none |
| iTerm2 | none | no | opt-in Sparkle update check |
| Ghostty | none | no | opt-in update check |
| Warp | many — telemetry, auth, AI features | yes | extensive |
| Wave | many — AI command history sync, telemetry | yes | extensive |

**herminal verdict:** ties iTerm2 + Ghostty (cleanest tier). The
two AI-first competitors trade privacy for their feature stack;
herminal explicitly refuses that trade.

---

### SSH manager

| Terminal | UI | `~/.ssh/config` import | Stores secrets |
|---|---|---|---|
| **herminal** | sidebar with add/edit/connect | one-click | NO |
| iTerm2 | profile-based, manual | per-profile manual | optional via Keychain |
| Ghostty | none | — | — |
| Warp | "Drive" feature | partial | yes (cloud-synced) |
| Wave | none in stable | — | — |

**herminal verdict:** herminal is the only Mac terminal with a
first-class SSH manager that doesn't ALSO ship a secrets storage
layer. We deliberately don't compete with OpenSSH config or
Keychain — we just provide the UI on top.

---

### Distribution + price

| Terminal | License | Price | Distribution |
|---|---|---|---|
| **herminal** | MIT, OSS | free | GitHub Releases (cask post-v0.1.1) |
| iTerm2 | GPLv2, OSS | free | direct download, Homebrew cask |
| Ghostty | MIT, OSS | free | direct download, Homebrew cask |
| Warp | proprietary, free for individuals | freemium | direct download |
| Wave | proprietary, free | free | direct download |

**herminal verdict:** herminal + Ghostty are the only options that
are simultaneously MIT-licensed AND ship an agent surface or a
modern toolkit-class UX. The "MIT + open source" axis was a
deliberate choice in the PRD.

---

### Linux / Windows

| Terminal | Linux | Windows |
|---|---|---|
| **herminal** | NO — by design | NO — by design |
| iTerm2 | NO | NO |
| Ghostty | YES (Linux) | NO (planned) |
| Warp | YES (Linux) | YES |
| Wave | YES (Linux) | YES |

**herminal verdict:** if cross-platform matters more than the
macOS-specific surface (native IME, native AppKit chrome, Metal
performance), Ghostty is the right pick. herminal is specifically
the macOS slice of that decision.

---

## When to pick herminal

✓ You're on Apple Silicon macOS.
✓ You run Claude Code / Codex / Aider as part of your daily flow.
✓ You write Vietnamese (or any CJK script) regularly.
✓ You want local-only state — no cloud, no account.
✓ You appreciate a documented audit trail and small dependency
  surface.

## When to NOT pick herminal

✗ You need a Linux or Windows terminal — pick Ghostty or your
  platform's native option.
✗ You want the Warp/Wave AI-block UX inside the terminal itself —
  herminal explicitly doesn't ship that.
✗ You need recursive split trees or drag-resize TODAY — iTerm2 or
  Ghostty is the current pick; herminal's roadmap Theme C will
  catch up if beta feedback confirms the need.
✗ You're on Intel macOS — Apple Silicon only.

---

## A note on this comparison

We tried to be honest about where herminal trails. The "wait until
beta confirms the need" deferrals on the roadmap mean herminal's
v0.1.0 footprint is intentionally smaller than iTerm2's 20-year
feature set. The bet is that the things v0.1.0 DOES do — agent
dashboard, IME, local notes, .ssh/config integration — are worth
more to the target user than the things it doesn't (yet) do.

If that bet is wrong for you, no offence taken. Pick the terminal
that fits the work.
