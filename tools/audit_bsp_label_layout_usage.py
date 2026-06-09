#!/usr/bin/env python3
"""Audit whether OriginKlineChart has migrated BSP text to label layout.

This is intentionally a narrow guardrail. It does not parse Dart AST; it checks
for the specific migration target:

- OriginKlineChart imports/uses BspChartLabelAdapter.
- OriginKlineChart imports/uses ChartLabelLayout and paintLaidOutChartLabels.
- _drawBsp no longer directly draws BSP text with _drawText.

Usage:
  python tools/audit_bsp_label_layout_usage.py

The script currently defaults to a warning-style exit code 0 while the migration
is in progress. Use --strict after OriginKlineChart is fully migrated.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TARGET = Path("lib/ui/widgets/origin_kline_chart.dart")


def _extract_method_body(source: str, method_name: str) -> str:
    match = re.search(rf"\n\s*void\s+{re.escape(method_name)}\s*\([^)]*\)\s*\{{", source)
    if not match:
        return ""
    start = match.end() - 1
    depth = 0
    for i in range(start, len(source)):
        ch = source[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[start : i + 1]
    return source[start:]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"FAIL: {TARGET} does not exist")
        return 1

    source = TARGET.read_text(encoding="utf-8")
    draw_bsp = _extract_method_body(source, "_drawBsp")
    direct_bsp_text = bool(re.search(r"_drawText\s*\([^;]*\$\{isSegLevel", draw_bsp, re.S))

    checks = {
        "uses_bsp_adapter": "BspChartLabelAdapter" in source,
        "uses_label_layout": "ChartLabelLayout" in source,
        "uses_laid_out_paint": "paintLaidOutChartLabels" in source,
        "draw_bsp_found": bool(draw_bsp.strip()),
        "no_direct_bsp_text": not direct_bsp_text,
    }

    missing = [name for name, ok in checks.items() if not ok]
    if missing:
        level = "FAIL" if args.strict else "WARN"
        print(f"{level}: BSP label layout migration incomplete")
        for name in missing:
            print(f"- {name}")
        print("Expected migration path:")
        print("1. _drawBsp keeps drawing triangle glyphs immediately.")
        print("2. _drawBsp appends BspChartLabelAdapter.buildLabel(...) to a label list.")
        print("3. paint() calls ChartLabelLayout(...).layout(labels).")
        print("4. paintLaidOutChartLabels(canvas, laidOutLabels) paints text once.")
        return 1 if args.strict else 0

    print("PASS: BSP label text uses ChartLabelLayout path")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
