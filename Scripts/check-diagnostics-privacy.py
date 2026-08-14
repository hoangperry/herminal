#!/usr/bin/env python3
"""Reject sensitive Swift interpolation in Diary and OSLog calls.

This is intentionally a narrow source guard, not a Swift parser. It removes
comments, locates balanced logging calls, then inspects balanced string
interpolations. OSLog values explicitly marked `.private` are allowed; Diary
has no public/private interpolation distinction and must use safe summaries.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "Sources"
FIXTURES = ROOT / "Tests" / "Fixtures" / "DiagnosticsPrivacy"

CALL_START = re.compile(
    r"(?:NSLog|Diary\.shared\.log|(?:Self\.)?[A-Za-z_][\w.]*\.(?:debug|info|notice|warning|error|critical|fault))\s*\("
)
FORBIDDEN = re.compile(
    r"(?:"
    r"\b(?:\w*command\w*|\w*argv\w*|\w*arguments?\w*|session_?id|hostname|username|workspace_?name|working_?directory|cwd|\w*path\w*|error)\b"
    r"|\bnote\s*\.\s*body\b"
    r"|\b(?:pane|tab|host|session)\s*\.\s*id\b"
    r")",
    re.IGNORECASE,
)


def strip_comments(text: str) -> str:
    """Replace Swift comments with whitespace while preserving strings/lines."""
    out = list(text)
    i = 0
    block_depth = 0
    in_string = False
    escaped = False
    while i < len(text):
        if block_depth:
            if text.startswith("/*", i):
                out[i : i + 2] = "  "
                block_depth += 1
                i += 2
            elif text.startswith("*/", i):
                out[i : i + 2] = "  "
                block_depth -= 1
                i += 2
            else:
                if text[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        if in_string:
            if escaped:
                escaped = False
            elif text[i] == "\\":
                escaped = True
            elif text[i] == '"':
                in_string = False
            i += 1
            continue
        if text.startswith("//", i):
            end = text.find("\n", i)
            end = len(text) if end == -1 else end
            out[i:end] = " " * (end - i)
            i = end
        elif text.startswith("/*", i):
            out[i : i + 2] = "  "
            block_depth = 1
            i += 2
        elif text[i] == '"':
            in_string = True
            i += 1
        else:
            i += 1
    return "".join(out)


def balanced_slice(text: str, open_index: int) -> tuple[str, int]:
    depth = 0
    in_string = False
    escaped = False
    for i in range(open_index, len(text)):
        char = text[i]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == '"':
            in_string = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return text[open_index : i + 1], i + 1
    return text[open_index:], len(text)


def interpolations(call: str) -> list[str]:
    values: list[str] = []
    i = 0
    while True:
        start = call.find("\\(", i)
        if start == -1:
            return values
        value, end = balanced_slice(call, start + 1)
        values.append(value[1:-1])
        i = end


def format_arguments(call: str) -> list[str]:
    """Return simple NSLog varargs (`%@: value`) outside interpolation."""
    return re.findall(r",\s*([A-Za-z_]\w*(?:\.\w+)*)\s*(?=[,)])", call)


def violations(path: Path) -> list[str]:
    original = path.read_text(encoding="utf-8")
    text = strip_comments(original)
    found: list[str] = []
    for match in CALL_START.finditer(text):
        call, _ = balanced_slice(text, match.end() - 1)
        call_name = match.group(0)
        is_diary = call_name.startswith("Diary.shared.log")
        values = interpolations(call)
        if call_name.startswith("NSLog"):
            values.extend(format_arguments(call))
        for value in values:
            sensitive_context = is_diary and "workspace" in call.lower()
            if not FORBIDDEN.search(value) and not sensitive_context:
                continue
            # Boolean/count/presence summaries describe behavior without
            # recording the underlying value. Raw identifiers remain forbidden.
            if is_diary and (
                re.search(r"\.(?:isEmpty|count)\b", value)
                or re.search(r"(?:==|!=)\s*nil\b", value)
            ):
                continue
            if not is_diary and re.search(r"privacy\s*:\s*\.private\b", value):
                continue
            line = original.count("\n", 0, match.start()) + 1
            compact = " ".join(value.split())
            found.append(f"{path.relative_to(ROOT)}:{line}: forbidden log interpolation: {compact}")
    return found


def main() -> int:
    allowed = FIXTURES / "allowed.swift.fixture"
    forbidden = FIXTURES / "forbidden.swift.fixture"
    if violations(allowed):
        print("privacy guard rejected its allowed fixture", file=sys.stderr)
        print(*violations(allowed), sep="\n", file=sys.stderr)
        return 1
    if not violations(forbidden):
        print("privacy guard failed to reject its forbidden fixture", file=sys.stderr)
        return 1

    failures: list[str] = []
    for path in sorted(SOURCES.rglob("*.swift")):
        failures.extend(violations(path))
    if failures:
        print(*failures, sep="\n", file=sys.stderr)
        print(f"FAIL: {len(failures)} diagnostics privacy violation(s)", file=sys.stderr)
        return 1
    print("PASS: diagnostics logging contains no forbidden raw metadata")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
