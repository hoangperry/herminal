# Sprint 7 — Owner-gate automation

**Status:** tooling complete — owner execution pending

## Goal

Turn the three remaining manual issues into deterministic, privacy-safe owner
commands without pretending keyboard, keychain, or signed-runtime checks can be
completed by CI.

## Tasks

1. [x] Add a non-secret release-readiness checker for full Xcode, Developer ID
   identity selection, notary profile naming, and required local tools.
2. [x] Add an interactive Telex/VNI gate recorder that stores only commit, OS/input
   source labels, case IDs, pass/fail, and reviewed notes—never terminal history.
3. [x] Add a hardened-runtime entitlement experiment runner that removes exactly
   one exception per copied build, signs with runtime options, records the
   shell/Metal/tmux/agent matrix, and never changes production entitlements.
4. [x] Document commands on issues #2/#4/#13 and leave them open until owner runs
   produce real evidence.
5. [x] Shellcheck/static-test every runner without accessing credentials.

## Exit criteria

- Every remaining issue has one reproducible command and output location.
- Scripts fail closed when prerequisites are absent.
- No script prints identity details, credentials, terminal content, SSH data, or
  test commands.
- Production entitlements and release state remain unchanged until evidence is
  reviewed.
