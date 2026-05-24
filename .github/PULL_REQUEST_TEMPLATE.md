## What

Single-line summary of the change.

## Why

Link the issue this fixes (e.g. `Fixes #123`) or, if no issue, explain
the user-facing problem this solves. PRs without an issue link or a
clear "why" will be asked to add one before review.

## How

Brief overview of the approach. Non-obvious decisions get a paragraph;
obvious ones get a sentence.

## Testing

- [ ] `swift test` passes locally
- [ ] `Scripts/dogfood-daily.sh` passes locally (5/5)
- [ ] New code is covered by a unit test (or an integration script)
- [ ] If the change touches a kernel API, libghostty surface, or shell IO,
      I added a `Scripts/verify-*.sh` script for it

## Screenshots / GIFs (UI changes only)

Drag in before/after for any visible change.

## Risks / open questions

Anything reviewer-y you'd flag. Half-baked PRs are fine — just say
where they're half-baked.
