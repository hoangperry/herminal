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

A second one-at-a-time pass used the release-optimized candidate. Every copied,
Developer-ID-signed variant remained alive with a PTY child, exposed an on-screen
WindowServer window, and had the Metal runtime mapped in its process. Direct
window pixel capture was unavailable to the shell, so this is runtime evidence,
not a human visual-quality assertion.

| Removed exception | Release app + PTY | On-screen window | Metal runtime mapped |
|---|---:|---:|---:|
| `com.apple.security.cs.allow-jit` | PASS | PASS | PASS |
| `com.apple.security.cs.allow-unsigned-executable-memory` | PASS | PASS | PASS |
| `com.apple.security.cs.allow-dyld-environment-variables` | PASS | PASS | PASS |
| `com.apple.security.cs.disable-library-validation` | PASS | PASS | PASS |

## Interpretation

This is strong evidence that none of the four exceptions is required for app
startup, PTY shell execution, tmux, or process-based agent detection. It also
matches vendored Ghostty 1.3.1's production entitlement plist, which contains
none of these four exceptions.

Together, the debug feature matrix and release runtime matrix satisfy the
one-at-a-time evidence gate. Vendored Ghostty 1.3.1's production entitlement
plist also contains none of these exceptions. The four exceptions were therefore
removed from Herminal's production plist after this evidence was recorded.

A combined no-exception candidate must still pass CI, Developer ID signing,
notarization, staple, Gatekeeper, app/PTY/Metal smoke, and the live IME gate
before issue #4 closes. Failed or incomplete checks must not be converted into a
passing claim.
