#!/usr/bin/env python3
"""Remove checkout-specific paths from `swift package show-dependencies` JSON."""

from __future__ import annotations

import json
import os
from pathlib import Path
import sys
from typing import Any


def relative_local_path(value: str, repository: Path) -> str:
    candidate = Path(value)
    if not candidate.is_absolute():
        return value

    resolved = candidate.resolve()
    try:
        relative = resolved.relative_to(repository)
    except ValueError as error:
        raise ValueError(
            f"dependency path escapes repository checkout: {value}"
        ) from error
    return "." if relative == Path(".") else relative.as_posix()


def sanitize(value: Any, repository: Path) -> Any:
    if isinstance(value, list):
        return [sanitize(item, repository) for item in value]
    if not isinstance(value, dict):
        return value

    cleaned: dict[str, Any] = {}
    for key, item in value.items():
        if key == "path" and isinstance(item, str):
            cleaned[key] = relative_local_path(item, repository)
        elif key == "url" and isinstance(item, str) and os.path.isabs(item):
            cleaned[key] = relative_local_path(item, repository)
        else:
            cleaned[key] = sanitize(item, repository)
    return cleaned


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} REPOSITORY_ROOT", file=sys.stderr)
        return 2

    repository = Path(sys.argv[1]).resolve()
    document = sanitize(json.load(sys.stdin), repository)
    if not isinstance(document, dict):
        raise ValueError("SwiftPM dependency document must be a JSON object")

    # SwiftPM derives the root identity from the checkout directory name. That
    # name is runner-specific, unlike the package's declared name.
    name = document.get("name")
    if isinstance(name, str) and name:
        document["identity"] = name.lower()

    json.dump(document, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (json.JSONDecodeError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1) from error
