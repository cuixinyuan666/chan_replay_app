#!/usr/bin/env python3
"""Add missing foundation imports for ValueListenable.

The drag-refinement patch adds ValueListenable<int> to:
- lib/ui/drawing/tradingview_toolbox_host.dart
- lib/ui/widgets/origin_kline_chart.dart

Run:
  python tools/fix_value_listenable_imports.py --check
  python tools/fix_value_listenable_imports.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

TARGETS = [
    Path("lib/ui/drawing/tradingview_toolbox_host.dart"),
    Path("lib/ui/widgets/origin_kline_chart.dart"),
]

FOUNDATION = "import 'package:flutter/foundation.dart';\n"
MATERIAL = "import 'package:flutter/material.dart';\n"


def patch(source: str) -> tuple[str, bool, str]:
    if FOUNDATION in source:
        return source, False, "OK foundation import already present"
    if MATERIAL not in source:
        return source, False, "SKIP material import anchor not found"
    return source.replace(MATERIAL, FOUNDATION + MATERIAL, 1), True, "APPLY foundation import"


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    changed_any = False
    for path in TARGETS:
        if not path.exists():
            print(f"FAIL missing {path}")
            return 1
        source = path.read_text(encoding="utf-8")
        target, changed, note = patch(source)
        changed_any |= changed
        print(f"{path}: {note}")
        if args.apply and changed:
            path.write_text(target, encoding="utf-8")

    if args.apply:
        print("UPDATED" if changed_any else "NOOP already fixed")
    else:
        print("PASS can apply" if changed_any else "PASS already fixed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
