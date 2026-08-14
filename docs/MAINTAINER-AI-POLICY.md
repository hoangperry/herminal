# AI-assisted maintenance policy

Herminal uses coding agents as advisory development tools. They do not have
independent maintainer authority.

## Allowed assistance

Agents may help a maintainer:

- scout public code and documentation;
- propose a reproduction, tests, implementation, or review comments;
- compare a change with the threat model and architecture rules;
- draft documentation, changelog entries, and release checklists;
- summarize public issues and CI logs after sensitive values are removed.

Generated work is held to the same review, test, security, attribution, and
license standards as human-written work.

## Data agents must not receive

Do not put any of the following in an agent prompt, fixture, issue, or public
log:

- terminal history or command output that has not been reviewed and redacted;
- prompts, repository/client names, proprietary source, or private beta reports;
- process arguments, environment variables, tokens, cookies, or API keys;
- SSH configuration, hostnames, usernames, keys, or Keychain content;
- note bodies, local paths, Apple credentials, signing certificates, or
  notarization material.

Use minimal synthetic fixtures. Follow `SECURITY.md` for vulnerabilities and
`docs/TRIAGE.md` for public reports.

## Human-only decisions

A maintainer must personally approve:

- issue severity and whether a report is a security vulnerability;
- architecture and privacy tradeoffs;
- every merge and dependency update;
- release versioning, signing, notarization, publication, and rollback;
- use of tester identity, quotations, or private feedback;
- claims about adoption, performance, compatibility, or program eligibility.

CI success or an agent review is never sufficient authority to merge or ship.
Credentials remain outside agent context.

## Validation

For agent-assisted changes, the maintainer should record:

1. the public issue or maintenance goal;
2. the human decision boundary;
3. commands and manual checks used to validate the result;
4. any material agent mistake and the correction;
5. the merged PR or a reason the proposal was rejected.

Tests must exercise behavior, not merely reproduce generated implementation.
Live macOS input-source, Gatekeeper, signing, and notarization gates remain
manual where CI cannot establish them.

## Public evidence template

Use this only for real completed work:

```markdown
- Issue/PR: <public link>
- Agent-assisted task: <reproduction/test/review/docs>
- Human decision: <what the maintainer decided>
- Validation: `<commands>` plus <manual check if any>
- Correction: <agent mistake and correction, or "none observed">
- Outcome: <merged/rejected/released link>
- Time effect: <optional estimate, explicitly labeled estimate>
```

Do not backfill synthetic examples. A smaller evidence set is preferable to an
unverifiable one.
