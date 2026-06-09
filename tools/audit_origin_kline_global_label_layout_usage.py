#!/usr/bin/env python3
"""Audit OriginKlineChart structural labels use the shared label layout.

This guard focuses on chart-internal structure labels that can visually collide:
- FX top/bottom labels: 顶 / 底
- BI endpoint labels: Bn
- SEG endpoint labels: Sn / Sn?
- BSP labels

It intentionally ignores axis labels, top summary text, crosshair readouts, and
user drawing-object text because those belong to fixed UI or user-authored layers.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

TARGET = Path("lib/ui/widgets/origin_kline_chart.dart")
STRUCTURE_METHODS = ("_drawFx", "_drawBi", "_drawSeg", "_drawBsp")


def _extract_method_body(source: str, method_name: str) -> str:
    match = re.search(rf"\bvoid\s+{re.escape(method_name)}\b", source)
    if not match:
        return ""
    open_brace = source.find("{", match.end())
    if open_brace < 0:
        return ""
    depth = 0
    for i in range(open_brace, len(source)):
        ch = source[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[open_brace : i + 1]
    return source[open_brace:]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"FAIL: {TARGET} does not exist")
        return 1

    source = TARGET.read_text(encoding="utf-8")
    missing: list[str] = []

    if "final chartLabels = <ChartLabel>[];" not in source:
        missing.append("missing chartLabels collection in paint()")
    if "ChartLabelLayout(" not in source or "paintLaidOutChartLabels" not in source:
        missing.append("missing shared ChartLabelLayout paint path")

    expected_priorities = {
        "fx": "ChartLabelPriority.fx",
        "bi": "ChartLabelPriority.bi",
        "seg": "ChartLabelPriority.seg",
        "bsp": "ChartLabelPriority.bsp",
    }
    for name, token in expected_priorities.items():
        if token not in source:
            missing.append(f"missing {name.upper()} label priority token: {token}")

    for method in STRUCTURE_METHODS:
        body = _extract_method_body(source, method)
        if not body.strip():
            missing.append(f"method not found: {method}")
            continue
        if re.search(r"\b_drawText\s*\(", body):
            missing.append(f"direct _drawText still used inside {method}")
        if method != "_drawBsp" and "List<ChartLabel> chartLabels" not in source[source.find(f"void {method}"): source.find("{", source.find(f"void {method}"))]:
            missing.append(f"{method} does not accept chartLabels")

    if missing:
        level = "FAIL" if args.strict else "WARN"
        print(f"{level}: global structure label layout migration incomplete")
        for item in missing:
            print(f"- {item}")
        print("Expected: FX / BI / SEG / BSP labels all append ChartLabel and paint once through ChartLabelLayout.")
        return 1 if args.strict else 0

    print("PASS: FX / BI / SEG / BSP labels use the shared ChartLabelLayout path")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
