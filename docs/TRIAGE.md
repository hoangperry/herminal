# Issue and pull-request triage

## Response targets

- Security reports: acknowledge privately within 48 hours (`SECURITY.md`).
- Suspected data loss, unintended command execution, or launch crash: initial public triage within 48 hours.
- Other bugs and PRs: initial triage within 7 days.
- Feature requests: reviewed during the next feedback-driven roadmap pass.

Targets are best effort for a solo-maintained project, not an SLA.

## Severity

- `P0`: exploitable command execution, credential disclosure, release compromise, or repeatable data loss. Stop feature work.
- `P1`: launch blocker, frequent crash, broken terminal input, or major regression without a reasonable workaround.
- `P2`: bounded functional bug or important compatibility issue.
- `P3`: polish, documentation, or optional enhancement.

Security-sensitive details move to a private advisory immediately.

## Evidence

A useful report includes version/commit, macOS and hardware, input source or shell where relevant, minimal reproduction, expected/actual behavior, and a reviewed redacted diagnostic excerpt if needed. Maintainers must not request raw terminal output, argv, credentials, SSH configuration, or note contents.

## Lifecycle

1. Reproduce or mark `needs-reproduction`.
2. Assign severity and component.
3. Confirm acceptance criteria before implementation.
4. Link the fixing PR and a regression test/checklist.
5. Close after the fix is available on `main`; mark the release milestone separately.

Duplicates link to the canonical issue and close without losing unique evidence. Inactive feature requests may close after 60 days with an explanation; confirmed bugs do not auto-close merely for inactivity.

## Pull requests

Review architecture fit, privacy/security impact, tests, user-visible documentation, and release-note need. Agent-generated review is advisory only; a maintainer must approve every merge. Never auto-merge a dependency or release change solely because CI is green.
