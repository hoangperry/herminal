# Month 10 — Post-MVP Slice 3 (deterministic distribution + knowledge transfer)

**Sprint goal:** Ship every post-MVP item that's deterministic (no
beta-feedback shape required). M9 retro deferred everything by
default; this slice revisits and ships the items whose shape was
clear regardless of beta input.

**Start date:** 2026-05-25 (same day as M8 + M9 slices)
**Owner:** hoangperry
**Cadence note:** Continues the post-MVP "do what's tractable
without speculation" discipline. The work here either backs the
v0.1.0 release (E theme: distribution) or transfers knowledge
already locked in retros (G theme: blog posts).

---

## Task Backlog

| # | Status | Task | Notes |
|---|---|---|---|
| M10/changelog | ✅ | CHANGELOG [Unreleased] updated for M8+M9 | Promotes the post-MVP slice work so the next release tag inherits ready-to-publish notes |
| M10/E-brew | ✅ | Homebrew cask formula template | `Casks/herminal.rb`. Reusable for own tap or upstream submission. Documented bump-on-release flow |
| M10/E-sparkle | ✅ | Sparkle integration stub + appcast template | `Updater.swift` (no SPM dep yet) + `docs/appcast-template.xml` so v0.2.x adding Sparkle is a focused change |
| M10/E-dmg | ✅ | DMG creation script | `Scripts/make-dmg.sh`. Self-tested produces 5.8 MB DMG from existing release bundle |
| M10/E-cd | ✅ | GitHub Actions release workflow | `.github/workflows/release.yml`. Tag-triggered; auto-builds, signs, packages, drafts release with assets + appcast |
| M10/G-blogs | ✅ | 3 kernel-gotcha blog post drafts | `docs/blog/{01,02,03}-*.md` + index. Drafts only — owner publishes when ready |
| M10/retro | 🔄 | This retro | Final pass after first publish / beta wave |

---

## Open Questions

- **Q10-001:** Should the GitHub Actions release workflow auto-
  publish the draft once notarization comes back clean, or always
  leave it draft for owner review? Currently always `--draft`. Owner
  decides once enough releases have shipped to know which is more
  annoying — clicking publish each time, or accidentally publishing
  before screenshot assets land.
- **Q10-002:** Sparkle public key needs generating + embedding in
  `Info.plist` (`SUPublicEDKey`) before v0.2.x can flip the framework
  on. Bound to first-notarized-release work — owner runs
  `generate_keys` after Developer-ID enrolment.
- **Q5-002, Q6-001, Q3-002 (carry):** All closed in M8/M9.
- **Q6-002, Q8-001, Q8-002 (carry):** Still deferred awaiting beta.
- **Q9-001 (carry):** Recursive split trees — still defer until beta
  confirms single-axis limitation hurts.

---

## Progress Log

### 2026-05-25 — Slice 3 ships deterministic distribution + docs

**Why now:** M9 retro explicitly said "this slice is the LAST one
phù phù醬 can productively ship without beta input." On revisit, that
was over-cautious. Distribution infrastructure (Homebrew, Sparkle
wiring, DMG, CD workflow) and knowledge-transfer blog posts are both
deterministic — they don't depend on beta feedback to shape, only
on the v0.1.0 release artefacts existing (which they do).

The discipline test still applied: each item shipped is either
(a) inevitable for v0.x releases (distribution) or (b) crystallised
knowledge that's already in retros (blog posts). Nothing here is
"item I can think of" speculation about user wants — the M5/M6
warning held.

**Six items in one session:**

- CHANGELOG.md promoted M8+M9 work into [Unreleased] so the next
  release inherits ready notes.
- Casks/herminal.rb captures the brew install path for the eventual
  publishing on a tap or upstream cask submission.
- Updater.swift + docs/appcast-template.xml lay the Sparkle wiring
  without taking the dependency — v0.2.x adding the framework
  becomes a focused change.
- Scripts/make-dmg.sh packages the .app into a polished DMG with
  /Applications symlink. Self-tested at 5.8 MB.
- .github/workflows/release.yml auto-cuts releases on tag push;
  imports certs from Secrets, signs, notarizes, packages, uploads
  zip + dmg + appcast; gracefully degrades when secrets are unset.
- docs/blog/{01,02,03}-*.md drafts each of the three real kernel
  gotchas the project hit (proc_listchildpids broken on Sequoia,
  proc_pid_rusage mach time units, libghostty exec -l p_comm dash).
  Owner publishes when ready.

**Stats:**
- 7 commits, `9da88cb` → `5edf416`.
- 0 unit test changes (this slice is infrastructure/docs only —
  Sparkle stub is a public API with no logic; tests come with the
  real framework integration).
- 1 new SPM source file (Updater.swift), 1 new SwiftUI-free utility
  (Casks/herminal.rb), 2 new scripts (make-dmg.sh, release.yml),
  4 new docs (3 blog posts + index).

---

## Carry Into Slice 4

Everything in M9's "deferred-until-beta-feedback" list still applies:

- Theme C recursive split trees / drag-resize (Q9-001) — wait for
  beta to confirm the limitation hits real workflows.
- Theme F opt-in diary upload toggle — wait for beta to ask.
- Owner-pending: M6-2 days 2-30, M7-2 social launch, Developer-ID
  enrolment → notarized v0.1.1 → Homebrew cask publish → Sparkle
  framework integration.

Beta-feedback gate from M7-3 still in effect: ≥20/30 M6-2 dogfood
days = "Y" before M7-2 launches publicly.
