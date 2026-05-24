# Security Policy

## Supported versions

herminal is pre-1.0. Only the `main` branch receives security fixes.
There is no LTS; users on tagged releases should update to the latest
release for any reported vulnerability.

## What's in scope

herminal is a local macOS terminal emulator that runs the user's shell
and processes shell commands. It does not open network sockets, does
not send telemetry, and does not run a privileged background service.
Security-relevant surfaces:

- **libghostty embedding** — the C ABI between the Swift app and
  libghostty. Memory-safety regressions here are in scope.
- **PTY + shell spawn** — `config.command` overrides and child process
  isolation. Privilege-escalation paths here are in scope.
- **SQLite stores** — the notes DB and SSH-hosts DB. SQL injection or
  privilege escalation through the DB layer is in scope.
- **NSTextInputClient (IME)** — text-injection via composition. Bugs
  that let arbitrary text reach the PTY without user intent are in
  scope.
- **Diary file** — the crash diary at
  `~/Library/Application Support/herminal/diary.log` could in theory
  leak PII if commands typed at the prompt ended up there. (They
  don't — only category-tagged lifecycle events are logged.) Bugs
  that change that are in scope.
- **Test hooks** — `HERMINAL_TEST_*` env vars exist solely for the GUI
  test harness. Bugs that let a malicious env var harm a user (e.g.
  write to an arbitrary path) are in scope.

## What's out of scope

- macOS security model itself (sandbox, TCC). herminal runs as a
  non-sandboxed AppKit app, the same trust profile as iTerm2.
- libghostty internals — report those upstream at
  https://github.com/ghostty-org/ghostty.
- The user's shell, their `.zshrc`, or anything they execute in the
  terminal.

## Reporting a vulnerability

**Do not file a public issue** for anything you believe to be a
security vulnerability.

Email the maintainer directly: **hoangperry@proton.me**

Include:

1. A short description of the vulnerability.
2. Steps to reproduce (ideally a minimal repro).
3. The diary excerpt around the time of the bug, if applicable.
4. The herminal version (`git rev-parse HEAD` if from source) and
   macOS version.

Expected timeline:

- **Acknowledgement**: within 48 hours.
- **Initial assessment**: within 7 days. We'll tell you whether the
  issue is in scope, the severity we've assigned, and the expected
  patch window.
- **Patch**: within 30 days for HIGH/CRITICAL, best-effort otherwise.
- **Disclosure**: coordinated after the patch ships. We'll credit you
  in the release notes unless you'd prefer to stay anonymous.

## What we will NOT do

- Sue or threaten security researchers acting in good faith.
- Demand the issue be reported through any platform other than the
  email above.
- Treat a coordinated-disclosure delay as a hostile act.

Thank you for keeping herminal users safe.
