# Month 11 Retrospective — Review + Docs + Marketing

**Period:** 2026-05-25 (single-session, owner requested
"review, tạo docs, marketing")
**Sprint goal:** Audit v0.1.0 before publish, fill missing
reference docs, produce multi-channel launch kit.
**Result:** ✅ All three phases shipped. 1 CRITICAL + 5 HIGH + 2
MEDIUM bugs fixed before v0.1.0 publishes. 9 new docs land. Owner
now has the materials to launch any week they choose.

---

## 1. What Got Done

| Phase | Items | Outcome |
|---|---|---|
| A — Review + fix | 1 CRITICAL + 5 HIGH + 2 MEDIUM | Fixed in commit `11c65b3`. 79/79 tests + 5/5 integration scripts still pass |
| B — Reference docs | 5 docs | ARCHITECTURE, ROADMAP, FAQ, TROUBLESHOOTING, KEYBOARD-SHORTCUTS |
| C — Marketing | 6 drafts | landing page + comparison + Show HN + Product Hunt + Reddit + demo video |

**Stats:** 10 commits this slice (`8ea9074` → `0614728`), 1 CRITICAL
+ 5 HIGH bugs that would have blocked publish are now fixed, 79/79
tests, 5/5 integration scripts.

---

## 2. What We Learned

### Parallel reviewer agents pay back the spec-up-front cost

Both review agents got dense, prioritised prompts pointing at
specific files + an explicit "what NOT to focus on" list. The
output came back as actionable bug reports with file:line citations,
not generic "consider X" prose. Two agents running in parallel
finished in ~120 seconds total — less time than a single sequential
review would have taken.

The CRITICAL finding (Diary signal handler `swift_once`) was the
single highest-value catch. A user-facing crash where the crash
diary deadlocked the runtime would have been the worst possible
v0.1.0 first impression. Worth every parallel-agent token spent.

### The "deferred for clear reason" pattern beats fixing everything

11 MEDIUM + 5 LOW findings stay deferred in `REVIEW.md`. Each one
has an explicit reason: theoretical-only overflow, fallback-path
attack window, defer-until-next-touch. The discipline of writing
the defer reason proved as valuable as the fix itself — future
review cycles read the doc and decide whether each item has moved
from "theoretical" to "actual" since the last pass.

This is the same shape M9 retro flagged for the post-MVP work: gate
on a real signal rather than a "while we're here" impulse.

### Docs that bridge code and audience need a different voice from each

ARCHITECTURE.md and PATTERNS.md (M9) speak to a contributor reading
the code with a debugger open. FAQ.md and TROUBLESHOOTING.md speak
to a user who just hit a problem. The marketing copy in
`docs/launch/` speaks to someone who has never heard of herminal.

Three different voices, three different vocabularies, three
different "what does the reader already know" assumptions. The
temptation is to write everything in the contributor voice (most
natural after 11 months in the codebase) but the reader-by-audience
discipline matters for which doc gets used.

### Honest comparison beats favourable comparison

`docs/launch/comparison.md` explicitly says "When NOT to pick
herminal." Three of the four bullet points there are real — herminal
genuinely doesn't ship recursive splits, doesn't ship Linux, doesn't
ship an AI chat assistant. The temptation in launch copy is to
omit those bullets. The bet is that honest comparison earns more
trust than "look at all these features" rhetoric, especially with
HN + r/programming audiences who detect spin by reflex.

---

## 3. Estimate vs Actual

- Estimated: 3 phases in one session.
- Actual: 3 phases in one session with the agent-driven fix pass
  fitting cleanly between phases A and B. No phase overran.

The compaction between phase B and phase C (after the docs landed)
needed a state-recovery turn but didn't cost meaningful work — the
M11 backlog file was already on disk and the launch directory was
populated incrementally.

---

## 4. Carry Into Slice 12 (still beta-feedback-gated)

| Item | Theme | Why pending |
|---|---|---|
| Recursive split trees + drag-resize | C | Bigger refactor, wait for beta to confirm single-axis hits |
| Opt-in diary upload toggle | F | Wait for beta to ask |
| 9 MEDIUM + 5 LOW review items | various | Each has explicit defer reason in `docs/REVIEW.md` |
| Owner: M6-2 dogfood days 2-30 | — | Calendar time |
| Owner: M7-2 social launch | — | Owner publishes the v0.1.0 draft + posts the 4-channel drafts |
| Owner: Developer-ID enrolment | E | Unblocks v0.1.1 notarized + Homebrew cask publish + Sparkle integration |
| Owner: Vietnamese IME + CJK live runs | D | 4 checklists ready in docs/QA/ |

---

## 5. Honest Self-Assessment

**Good:** Caught a CRITICAL signal-handler bug before users did.
Five HIGH bugs (including a real data-correctness bug in the SSH
config import that would have silently stored wrong hostnames)
fixed in the same pass. Reference docs + marketing kit ship
together so the launch itself becomes a single owner-driven sprint
rather than a documentation scavenger hunt.

**Could be better:** Phase C marketing copy hasn't been audience-
tested — the show-hn.md / product-hunt.md / reddit.md drafts are
my best guess at each platform's culture, not actual A/B-tested
copy. Reality will trim the drafts; owner edits are expected
before publish.

**Risk for slice 12:** the launch goes well enough that beta
feedback floods in and the discipline rule from M9/M10/M11 retros
gets tested in earnest. The point of those retros was to AVOID
shipping speculatively — beta-driven slice 12 is the moment the
machinery has to work. If the bug template captures clean
reproductions, triage will be fast. If it doesn't, the first
"slice 12 from beta feedback" will be improving the bug template
itself, and that's also a fine answer.
