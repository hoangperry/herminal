---
name: Bug report
about: Something broke in herminal
title: '[BUG] '
labels: bug
assignees: ''
---

## What happened

A clear description of the bug. One sentence is fine.

## What you expected

What should have happened instead.

## Steps to reproduce

1.
2.
3.

## Environment

- herminal version (or `git rev-parse HEAD` if from source):
- macOS version:
- Apple Silicon / Intel:
- Shell ($SHELL):
- IME source (if relevant — Telex, VNI, ABC, US):

## Crash diary excerpt

Paste the last ~30 lines of `~/Library/Application Support/herminal/diary.log`
around the time of the bug. Look for any `=== CRASHED signal=N ===` line.

```
# diary tail goes here
```

## Dogfood journal day (if applicable)

If you were on day N of the 30-day dogfood (`docs/QA/dogfood/day-NN-*.md`),
note the day number and link the journal entry:

- Day:
- Journal:

## dogfood-daily.sh output (if you ran it)

```
# Paste the output of Scripts/dogfood-daily.sh
```

## Additional context

Anything else — screenshots (drag into the issue body), prior issues
that look similar, things you've already tried.
