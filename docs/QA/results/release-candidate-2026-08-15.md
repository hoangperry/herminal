# Release candidate owner-gate evidence — 2026-08-15

## Provenance

- GitHub Actions workflow: **Release candidate build**
- Run: `31830331678`
- Immutable source commit: `657bf337837d545faebc9044e1fa5956af1484a0`
- Configuration: SwiftPM `release`
- libghostty submodule: `332b2aefc6e72d363aa93ab6ecfc86eeeeb5ed28`
- Artifact SHA-256 manifest: verified before extraction
- Source commit membership on `origin/main`: verified

The remote workflow had `contents: read`, received no Apple credentials, created
no tag or release, and uploaded an ad-hoc candidate only.

## Local owner checks

The extracted app was copied before mutation, then processed with the owner's
local Developer ID key and authenticated `notarytool` keychain profile. No
identity, account, team, profile contents, or credential values were recorded.

| Check | Result |
|---|---:|
| Developer ID hardened-runtime signing | PASS |
| Apple notarization response | PASS — Accepted |
| Staple + staple validation | PASS |
| Strict deep signature verification | PASS |
| Gatekeeper application assessment | PASS |
| Signed DMG creation and signature verification | PASS |
| Read-only DMG mount | PASS |
| Embedded app signature, staple, and Gatekeeper assessment | PASS |
| Installed-copy launch and PTY child | PASS without quarantine UI |
| Quarantined first-open confirmation | PENDING — test session was at loginwindow |
| Clean macOS account/machine installation | PENDING |
| Homebrew installation from final public URL | PENDING |

The owner-gate DMG is local and intentionally unpublished. It uses an
`rc.owner-gate` filename and must not be treated as the final v1 artifact.

## Interpretation

The full-local-Xcode blocker is removed: release optimization can happen in the
read-only GitHub workflow while signing and notarization remain exclusively on
the owner machine. Public v1 remains blocked by the live Telex/VNI matrix, an
unlocked quarantined first-open check, and final clean Homebrew installation.
No tag or GitHub release was created.
