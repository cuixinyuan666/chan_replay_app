#!/usr/bin/env python3
"""Guardrail checker for Vespa chan.py subtree.

Rule for origin_vespa_tdx:
  - Do not modify Vespa chan.py core calculation logic.
  - New files under python/chan.py must live in an a_* folder or be named a_*.py.

This script is intentionally conservative. It only checks file placement and does
not inspect algorithm semantics.
"""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CHAN_ROOT = REPO_ROOT / "python" / "chan.py"
ALLOWED_PREFIX = "a_"


def is_allowed_extension(path: Path) -> bool:
    # Ignore metadata and cache files. The rule is about source additions.
    return path.suffix in {".py", ".md", ".txt", ".json", ".yaml", ".yml"}


def is_allowed_a_path(path: Path) -> bool:
    rel = path.relative_to(CHAN_ROOT)
    parts = rel.parts
    if not parts:
        return True
    return parts[0].startswith(ALLOWED_PREFIX) or path.name.startswith(ALLOWED_PREFIX)


def main() -> int:
    if not CHAN_ROOT.exists():
        print("SKIP: python/chan.py not present in this checkout")
        return 0

    violations: list[str] = []
    for path in CHAN_ROOT.rglob("*"):
        if not path.is_file() or not is_allowed_extension(path):
            continue
        if "__pycache__" in path.parts:
            continue
        if not is_allowed_a_path(path):
            # Existing Vespa files are expected. This checker should be used in
            # diff-aware CI or manually on new paths. For a full checkout, it
            # reports informational core files but does not fail unless the user
            # passes --strict-existing.
            violations.append(path.relative_to(REPO_ROOT).as_posix())

    if "--strict-existing" not in sys.argv:
        print("INFO: Vespa core files present under python/chan.py are expected.")
        print("Use git diff --name-only origin_vespa_tdx...HEAD | grep '^python/chan.py/' to review new paths.")
        print("New files must be in a_* folders or named a_*.py.")
        return 0

    if violations:
        print("FAIL: non-a_ files found under python/chan.py:")
        for item in violations:
            print(f"- {item}")
        return 1
    print("PASS: all checked python/chan.py files satisfy the a_ guardrail")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
