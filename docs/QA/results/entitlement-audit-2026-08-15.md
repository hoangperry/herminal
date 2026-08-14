# Hardened-runtime entitlement audit — partial automated evidence

- Date: 2026-08-15
- Source artifact: CI run `31825206484` (175 tests)
- Source commit under test: PR #15 merge artifact
- Signature posture: Developer ID + hardened runtime + timestamp
- Notarization: not submitted; experiment copies were not distributable
- Production entitlements changed: **no**

Each row started from the full production entitlement plist, removed exactly one
exception on a copied app, re-signed the copy, verified its signature, and
launched a fresh process. A synthetic harness then required a shell filesystem
side effect, a detached tmux side effect, and detection of a synthetic local
`codex` executable. No terminal content, credentials, identity, paths, or argv
were recorded.

| Removed exception | App alive + PTY child | Shell | tmux | Codex detection |
|---|---:|---:|---:|---:|
| `com.apple.security.cs.allow-jit` | PASS | PASS | PASS | PASS |
| `com.apple.security.cs.allow-unsigned-executable-memory` | PASS | PASS | PASS | PASS |
| `com.apple.security.cs.allow-dyld-environment-variables` | PASS | PASS | PASS | PASS |
| `com.apple.security.cs.disable-library-validation` | PASS | PASS | PASS | PASS |

## Interpretation

This is strong evidence that none of the four exceptions is required for app
startup, PTY shell execution, tmux, or process-based agent detection. It also
matches vendored Ghostty 1.3.1's production entitlement plist, which contains
none of these four exceptions.

It is **not** sufficient to remove them yet: the source was a CI debug artifact
rather than the final release-optimized bundle, Metal output was not visually
checked, and the copied variants were not notarized. Issue #4 remains open until
an owner runs the one-at-a-time visual matrix on a release build and reviews the
result. Failed or incomplete checks must not be converted into a passing claim.
