#!/usr/bin/env python3
"""Remove legacy _DrawingPersistenceBar after moving import/export into TV toolbox.

Run:
  python tools/remove_legacy_drawing_persistence_bar.py --check
  python tools/remove_legacy_drawing_persistence_bar.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

TARGET = Path("lib/ui/widgets/origin_kline_chart.dart")

START = "class _DrawingPersistenceBar extends StatelessWidget {"
END = "class _SelectedDrawingBar extends StatelessWidget {"


def patch(source: str) -> tuple[str, bool, str]:
    start = source.find(START)
    if start < 0:
        return source, False, "OK legacy _DrawingPersistenceBar already removed"
    end = source.find(END, start)
    if end < 0:
        raise ValueError(f"end marker not found: {END}")
    return source[:start] + source[end:], True, "APPLY remove legacy _DrawingPersistenceBar"


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"FAIL missing {TARGET}")
        return 1

    try:
        source = TARGET.read_text(encoding="utf-8")
        target, changed, note = patch(source)
    except ValueError as exc:
        print(f"FAIL {exc}")
        return 1

    print(f"{TARGET}: {note}")
    if args.apply and changed:
        TARGET.write_text(target, encoding="utf-8")
        print("UPDATED")
    elif args.apply:
        print("NOOP already clean")
    else:
        print("PASS can apply" if changed else "PASS already clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
