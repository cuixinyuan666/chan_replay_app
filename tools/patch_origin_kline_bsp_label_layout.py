#!/usr/bin/env python3
"""Patch OriginKlineChart to route BSP text through ChartLabelLayout.

This script is intentionally idempotent and text-based. It exists because
`origin_kline_chart.dart` is a large painter file; using a small, reviewable
patch helper is safer than hand-editing the full file when working remotely.

Usage:
  python tools/patch_origin_kline_bsp_label_layout.py --check
  python tools/patch_origin_kline_bsp_label_layout.py --apply

After `--apply`, run:
  flutter analyze
  flutter test test/chart_label_layout_test.dart
  flutter test test/bsp_chart_label_adapter_test.dart
  python tools/audit_bsp_label_layout_usage.py --strict
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

TARGET = Path("lib/ui/widgets/origin_kline_chart.dart")

IMPORT_ANCHOR = "import '../drawing/tradingview_toolbox_host.dart';\n"
IMPORT_INSERT = "import 'bsp_chart_label_adapter.dart';\nimport 'chart_label_layout.dart';\n"

LABEL_LIST_ANCHOR = "    double rawToX(int rawIndex) => rect.left + (rawIndex - start + 0.5) * step;\n\n"
LABEL_LIST_INSERT = (
    "    final chartLabels = <ChartLabel>[];\n"
    "    const bspLabelAdapter = BspChartLabelAdapter();\n\n"
)
OLD_LABEL_LIST_INSERT = (
    "    final chartLabels = <ChartLabel>[];\n"
    "    final bspLabelAdapter = const BspChartLabelAdapter();\n\n"
)

DRAW_BSP_CALL_OLD = (
    "    if (showBiBsp || showSegBsp)\n"
    "      _drawBsp(canvas, rect, start, end, rawToX, priceToY);\n"
)
DRAW_BSP_CALL_NEW = (
    "    if (showBiBsp || showSegBsp)\n"
    "      _drawBsp(canvas, rect, start, end, rawToX, priceToY,\n"
    "          chartLabels, bspLabelAdapter);\n"
)

PAINT_LABELS_ANCHOR = (
    "    DrawingObjectPainter.paintObjects(\n"
    "        canvas: canvas,\n"
    "        chartRect: rect,\n"
    "        objects: drawingObjects,\n"
    "        startRawIndex: start,\n"
    "        endRawIndex: end,\n"
    "        rawToX: rawToX,\n"
    "        priceToY: priceToY);\n"
)
PAINT_LABELS_INSERT = (
    PAINT_LABELS_ANCHOR
    + "    final laidOutLabels = ChartLabelLayout(\n"
    + "      chartRect: rect,\n"
    + "      visibleCount: visible.length,\n"
    + "      reserved: const [Rect.fromLTWH(0, 0, 520, 28)],\n"
    + "    ).layout(chartLabels);\n"
    + "    paintLaidOutChartLabels(canvas, laidOutLabels);\n"
)

DRAW_BSP_SIGNATURE_OLD = (
    "  void _drawBsp(Canvas canvas, Rect rect, int start, int end,\n"
    "      double Function(int) rawToX, double Function(double) priceToY) {\n"
)
DRAW_BSP_SIGNATURE_NEW = (
    "  void _drawBsp(\n"
    "      Canvas canvas,\n"
    "      Rect rect,\n"
    "      int start,\n"
    "      int end,\n"
    "      double Function(int) rawToX,\n"
    "      double Function(double) priceToY,\n"
    "      List<ChartLabel> chartLabels,\n"
    "      BspChartLabelAdapter bspLabelAdapter) {\n"
)

DIRECT_BSP_TEXT_OLD = (
    "      _drawText(\n"
    "          canvas,\n"
    "          '${isSegLevel ? '段' : '笔'}${bsp.type}',\n"
    "          Offset(x + 5, y + (bsp.isSell ? -20 : 8)),\n"
    "          isSegLevel ? 10.5 : 9,\n"
    "          color);\n"
)
DIRECT_BSP_TEXT_NEW = (
    "      chartLabels.add(bspLabelAdapter.buildLabel(\n"
    "        bsp: bsp,\n"
    "        anchor: Offset(x, y),\n"
    "        isSegLevel: isSegLevel,\n"
    "        color: color,\n"
    "        visibleWhenWindowLe: windowSize,\n"
    "      ));\n"
)


@dataclass(frozen=True)
class PatchResult:
    content: str
    changed: bool
    notes: list[str]


def replace_once(source: str, old: str, new: str, label: str) -> tuple[str, bool, str]:
    if new in source:
        return source, False, f"already applied: {label}"
    if old not in source:
        raise ValueError(f"patch anchor not found: {label}")
    return source.replace(old, new, 1), True, f"applied: {label}"


def normalize_previous_patch(source: str) -> tuple[str, bool, str]:
    if OLD_LABEL_LIST_INSERT in source:
        return (
            source.replace(OLD_LABEL_LIST_INSERT, LABEL_LIST_INSERT, 1),
            True,
            "normalized: const BSP label adapter",
        )
    return source, False, "already normalized: const BSP label adapter"


def apply_patch(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []

    source, did, note = replace_once(
        source,
        IMPORT_ANCHOR,
        IMPORT_ANCHOR + IMPORT_INSERT,
        "imports",
    )
    changed |= did
    notes.append(note)

    source, did, note = replace_once(
        source,
        LABEL_LIST_ANCHOR,
        LABEL_LIST_ANCHOR + LABEL_LIST_INSERT,
        "label list setup",
    )
    changed |= did
    notes.append(note)

    source, did, note = replace_once(
        source,
        DRAW_BSP_CALL_OLD,
        DRAW_BSP_CALL_NEW,
        "BSP draw call",
    )
    changed |= did
    notes.append(note)

    source, did, note = replace_once(
        source,
        PAINT_LABELS_ANCHOR,
        PAINT_LABELS_INSERT,
        "label layout paint",
    )
    changed |= did
    notes.append(note)

    source, did, note = replace_once(
        source,
        DRAW_BSP_SIGNATURE_OLD,
        DRAW_BSP_SIGNATURE_NEW,
        "_drawBsp signature",
    )
    changed |= did
    notes.append(note)

    source, did, note = replace_once(
        source,
        DIRECT_BSP_TEXT_OLD,
        DIRECT_BSP_TEXT_NEW,
        "direct BSP _drawText",
    )
    changed |= did
    notes.append(note)

    source, did, note = normalize_previous_patch(source)
    changed |= did
    notes.append(note)

    return PatchResult(content=source, changed=changed, notes=notes)


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    if not TARGET.exists():
        print(f"FAIL: {TARGET} does not exist")
        return 1

    source = TARGET.read_text(encoding="utf-8")
    try:
        result = apply_patch(source)
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 1

    for note in result.notes:
        print(note)

    if args.check:
        print("PASS: patch anchors are valid" if result.changed else "PASS: patch already applied")
        return 0

    if result.changed:
        TARGET.write_text(result.content, encoding="utf-8")
        print(f"UPDATED: {TARGET}")
    else:
        print("NOOP: patch already applied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
