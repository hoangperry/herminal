# Sprint 9 — Remote release build, local owner signing

## Goal

Remove the full-local-Xcode bottleneck without moving Developer ID or Apple
notary credentials into GitHub. GitHub produces a traceable release-optimized,
unsigned candidate; the owner downloads, signs, notarizes, staples, and verifies
it locally.

## Tasks

1. [ ] Add a manually dispatched, read-only release-candidate workflow pinned to
   a requested ref.
2. [ ] Build `HerminalApp` with SwiftPM release optimization and package the app
   plus commit/submodule provenance and SHA-256 metadata.
3. [ ] Allow `sign-and-notarize.sh` to consume an explicit candidate app instead
   of always rebuilding, while failing closed on invalid/missing input.
4. [ ] Add static regression guards for build-only workflow permissions,
   release configuration, provenance, and source-app validation.
5. [ ] Document the two-machine trust boundary and commands.
6. [ ] Run CI, dispatch a candidate from `main`, download it, and locally verify
   Developer ID signing/notarization without tagging or publishing.

## Safety gates

- Workflow has `contents: read` and no Apple/signing secrets.
- Candidate is never described as signed, notarized, or distributable.
- Local finalization verifies the downloaded app and commit provenance.
- No tag or GitHub release is created by the candidate workflow.
- Public v1 remains blocked by the live Telex/VNI owner gate.
