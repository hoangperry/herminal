# Month 9 Retrospective — Post-MVP Slice 2

**Period:** 2026-05-25 (single-session, same day as M8 slice 1)
**Sprint goal:** Close every post-MVP item tractable without beta
feedback — multi-theme batch.
**Result:** ✅ 7 items shipped across themes A, B, C, D, F, G.
Theme A is fully closed. Three carry questions resolved. Beta-feedback-
dependent items remain deferred.

---

## 1. What Got Done

| Item | Theme | Outcome |
|---|---|---|
| A3 | A | Agent↔pane mapping via login start-time pairing — closes Theme A |
| F | F | `Diary.exportRedacted()` with PII rules — backs the bug-report flow |
| C-light | C | Light theme variant — closes Q5-002 (open since M5) |
| B | B | `~/.ssh/config` import — first Theme B slice |
| G-patterns | G | `docs/PATTERNS.md` capturing 7 recurring codebase shapes |
| G-vn-readme | G | `README.vi.md` Vietnamese mirror |
| D | D | KR/JP/CN IME owner-manual smoke checklists |

**Stats this slice:**
- 13 new unit tests (64 → **77**: +7 AgentPaneMapper + ProcessSnapshot
  + 5 Diary redaction + 8 SSHConfigImporter — minus 7 that fold
  into the existing AgentDetector suite count)
- 4 new docs (PATTERNS.md, README.vi.md, cjk-ime-checklist.md,
  month-9 backlog)
- 7 commits, `6d0a98b` → `ffc5f27`
- Zero production regressions; existing integration scripts still
  PASS

---

## 2. What We Learned

### Multi-theme batching paid off

Bundling 7 small items in one session beat per-item cycles. Most of
the items shared an isolation domain (`HerminalApp` for Diary +
WorkspaceView wiring; `HerminalDB` for SSHConfigImporter;
`HerminalAgent` for A3) so context-switch cost between commits
stayed low. The two doc-only commits (PATTERNS, README.vi) cost
almost nothing because they crystallised knowledge that was already
in the retros.

The risk side of batching: a single bad mid-batch commit can
destabilise the rest. Mitigated by running `swift test` after every
commit (still 100% green at end of slice).

### The "honest blank" pattern earned its third hit

AgentPaneMapper deliberately returns `nil` tabHint when pairing
fails (no login ancestor / mismatched counts). That's the third
hit of the coarse-but-honest pattern that earned its PATTERNS.md
entry this slice:

1. `AgentStatusTracker` first-sighting `.unknown` (M6)
2. `AgentDetector` no-match returns nil — basename matcher (M3)
3. `AgentPaneMapper` pairing-failed → tabHint nil (M9/A3)

Three hits, formalised into a documented pattern. The "add to
PATTERNS.md after the third hit" rule held its budget.

### Q5-002 (light theme) was always going to be cheap

The retros kept deferring light theme to "after dogfood says yes
or no." The actual cost: ~150 lines of computed Color tokens. The
deferral was about discipline (don't ship before knowing the user
wants it) rather than complexity. Sometimes the conservative
deferral is correct; sometimes the cost is so low that shipping
optimistically beats waiting. M9 picked the latter for this one.

The discipline frame from M5 retro is still correct as a default —
just not a one-size-fits-all rule.

### `~/.ssh/config` parser surprises

Multi-target Host lines (`Host a b c`) needed a design call: emit
one row per target with the block's directives applied to all, or
emit only the first? OpenSSH applies the block to every match at
CONNECT time, but the import is a one-time snapshot — we picked
"first target gets directives, siblings get defaults" as the
faithful-but-simple interpretation. Documented inline + in tests
so the next contributor doesn't second-guess.

### CJK checklists exposed a knowledge gap

Writing the Korean / Japanese / Chinese checklists meant naming the
`NSTextInputClient` paths each IME exercises differently from
Vietnamese Telex. Korean is pure preedit (no candidate window);
Japanese is candidate-window-driven by `Space`; Chinese adds
number-key shortcuts that must NOT be consumed by `keyDown` when
composition is active. Writing the docs forced clarifying which
code path each language stress-tests — the doc became a debug
guide as well as a checklist.

---

## 3. Estimate vs Actual

- Estimated: 7 items in one session.
- Actual: 7 items in one session, no overruns. The most complex
  single item was A3 (~250 LoC + tests); the others averaged ~100
  LoC. Total session ~3 hours.

---

## 4. Carry Into Slice 3

Themes whose first slice DIDN'T ship this round are explicitly
beta-feedback-gated:

- **Theme C** recursive split trees (Q2-003) + drag-resize
  (Q2-002). Bigger refactors; want beta to confirm the single-axis
  limitation hits real workflows.
- **Theme E** distribution. Sequential on Developer-ID enrolment
  (owner) → first notarized release → Homebrew cask → Sparkle.
- **Theme F** opt-in diary upload toggle. Wait for beta to ask.

Themes whose first slice SHIPPED but have follow-up items:

- **A**: dashboard could expose libghostty BEL/progress reports more
  granularly. Wait for beta to ask.
- **B**: SSH groups / search / per-host keypair UI. Wait for beta
  scale (how many hosts before flat list hurts?).
- **D**: live owner runs of the CJK checklists. Manual; sequence
  after Vietnamese live run (#11).
- **G**: kernel-gotcha blog posts. Independent — owner writes when
  ready.

---

## 5. Honest Self-Assessment

**Good:** Cleared seven post-MVP items in one session without
introducing regressions. Closed Theme A entirely (now the
differentiator pitch is "see what your agents are doing AND where
they live"). Closed three open questions that had been on carry
lists for months. The PATTERNS.md doc paid back its writing time
the moment it captured the three-hit rule for coarse-but-honest —
future slices won't relitigate.

**Could be better:** This slice is the LAST one phù phù醬 (the AI
agent) can productively ship without beta input. Themes B / C / E
all gate on either real user feedback or owner-only actions
(Developer-ID, social posting, screenshots). The next slice should
wait for genuine signal rather than us continuing to ship "items I
can think of" — that would slide back into feature-work-disguised-
as-roadmap, exactly the M5/M6 discipline warning.

**Risk for next session:** the temptation to keep batching. If the
owner says "do more," the right answer is "wait for beta — anything
else we ship now is speculation." Discipline applied.
