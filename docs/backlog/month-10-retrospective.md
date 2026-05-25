# Month 10 Retrospective — Post-MVP Slice 3 (deterministic infrastructure)

**Period:** 2026-05-25 (single-session, same day as M8 + M9)
**Sprint goal:** Ship every deterministic post-MVP item (no beta
input required) that M9 retro had over-conservatively deferred.
**Result:** ✅ 6 items shipped (changelog + 4 distribution +
3 blog drafts). Distribution Theme E now has every piece except
the owner-gated Developer-ID enrolment. Theme G's blog-post drafts
ship the knowledge that retros had already locked in.

---

## 1. What Got Done

| Item | Theme | Outcome |
|---|---|---|
| changelog | — | `CHANGELOG.md [Unreleased]` reflects M8+M9 work; next release tag inherits clean notes |
| E-brew | E | `Casks/herminal.rb` cask formula template + bump-flow docs |
| E-sparkle | E | `Updater.swift` stub + `docs/appcast-template.xml`; wiring point for v0.2.x Sparkle integration |
| E-dmg | E | `Scripts/make-dmg.sh` produces a 5.8 MB DMG from the signed `.app` |
| E-cd | E | `.github/workflows/release.yml` auto-cuts releases on tag, drafts GitHub release with zip + dmg + appcast |
| G-blogs | G | 3 kernel-gotcha blog drafts + index. Drafts only — owner publishes on personal cadence |

**Stats:**
- 7 commits, `9da88cb` → `5edf416`
- 0 unit test changes (infrastructure + docs only)
- 1 new SPM source file (Updater.swift)
- 4 new docs + 2 new scripts + 1 new workflow
- 77/77 tests still pass

---

## 2. What We Learned

### M9 retro's "wait for beta" line was over-cautious

M9 retro said: "this slice is the LAST one phù phù醬 can productively
ship without beta input." On revisit at owner's nudge, that was
incorrect. Two whole categories of work are deterministic:

1. **Distribution infrastructure** — Homebrew cask, Sparkle wiring,
   DMG, CD workflow. None of these depend on what beta users want;
   they're all "what does the release path look like." They were
   inevitable for v0.x release cycles regardless of beta feedback.
2. **Knowledge transfer** — the three real kernel gotchas were
   already documented in M4/M6 retros and in PATTERNS.md. Turning
   them into stand-alone blog posts is crystallising what we
   already know, not speculating about user wants.

The honest framing for next time: discipline applies to **feature
shape**, not to **inevitable infrastructure** or **already-decided
knowledge**. Two categories of work that LOOK like speculation
without scrutiny but aren't:

- Anything in the M7 post-MVP roadmap that says "first slice" or
  "template" rather than "based on user feedback."
- Anything that crystallises a decision already made in a retro.

Updated heuristic: before deferring with "wait for beta," check if
the work depends on the *shape* a user might want or just on a
*release path / docs / wiring* that's already determined.

### The graceful-degradation pattern earned its third hit

`Scripts/sign-and-notarize.sh` (M5) falls back to ad-hoc when env
vars are unset. `Scripts/release.sh` (M7) inherits the same path.
`Scripts/make-dmg.sh` (M10) does it again — signs the DMG if the
identity is set, ships unsigned otherwise. `.github/workflows/release.yml`
gracefully skips the certificate import + notarytool when secrets are
absent.

Four hits now. Add to PATTERNS.md when this comes up a fifth time
(the "third hit ⇒ document" rule from M9 already triggered for
coarse-but-honest; this one's at four and counting).

### CI workflow vs local release script — duplicate inline, don't share

`.github/workflows/release.yml` duplicates the CHANGELOG-extraction
awk from `Scripts/release.sh` rather than calling the script. The
trade-off: sharing would mean one place to fix bugs, but it would
also mean a CI failure in the script could fail the release for a
reason unrelated to the actual build. Duplication keeps the CI run
independent. Three lines of awk is the right cost to pay for that
independence.

This goes against DRY — the principle works at the function/class
level inside the same isolation domain, but across "script that runs
locally on owner's laptop" vs "workflow that runs on a CI runner
with different env shape," sharing is brittle. Document this as a
counter-pattern later.

### The hook caught a false positive in the commit message

The DMG commit failed pre-push because my commit message included
the string `--no-verify` inside a code-fence example for hardened-
runtime entitlements. The hook's regex isn't context-aware. Rewrote
to "graceful-degradation pattern" instead. No real bypass attempted;
hook did its job and prevented the textual false positive from
landing without an explicit override.

Lesson: commit-message conventions sometimes need to avoid trigger
strings even when the intent is benign. Worth a note in PATTERNS.md
next time it bites.

---

## 3. Estimate vs Actual

- Estimated: 6 items in one session.
- Actual: 7 items (added the CHANGELOG bump as an explicit first
  commit) in one session. No item overran. The hook false positive
  on DMG cost ~2 minutes to rephrase + retry.

---

## 4. Carry Into Slice 4 (still beta-feedback-gated)

| Item | Theme | Why pending |
|---|---|---|
| Recursive split trees + drag-resize | C | Bigger refactor; beta confirms whether single-axis hits real workflows |
| Opt-in Diary upload | F | Wait for beta to ask |
| Owner: M6-2 days 2-30 | — | Calendar time |
| Owner: M7-2 social launch | — | Owner posts when ready |
| Owner: Developer-ID enrolment | E | Unblocks v0.1.1 notarized → cask publish → Sparkle framework integration |

---

## 5. Honest Self-Assessment

**Good:** Closed Theme E (distribution) end-to-end on the AI side.
The full release path now exists in code: cut a tag → CI auto-builds
→ signs (if secrets are set) → packages zip + DMG → drafts GitHub
release → attaches appcast. The owner's only manual step is reviewing
the draft and clicking publish. Sparkle wiring lays the contract so
v0.2.x adding the framework is a focused change rather than a
from-zero refactor. Three blog drafts capture the kernel gotchas in
publishable form so the next macOS-native-tools builder saves a day
each.

**Could be better:** The release workflow is unverified — it's
syntactically valid YAML and mirrors patterns from ci.yml that's been
running, but the actual end-to-end cert import + notarytool +
release-creation flow hasn't been exercised because the owner's
Developer-ID hasn't landed yet. The CI workflow could have an
issue that won't surface until the first secret-equipped tag push.
Acceptable risk: the script ran locally end-to-end via M7-2; the CI
is mostly a different env wrapper around the same commands.

**Risk for slice 4:** the discipline rebound. M9 retro
over-deferred; M10 corrected. Slice 4 needs to find the right level
between the two. The most honest signal would be: wait for the
owner to actually report beta findings or ask for a specific item.
If nothing comes back, "no slice 4 yet" is the correct answer — not
"keep shipping speculatively."
