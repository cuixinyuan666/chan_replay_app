#!/usr/bin/env python3
"""Patch OriginKlineChart structural text into the shared label layout.

Scope:
- FX top/bottom labels: 顶 / 底
- BI endpoint labels: Bn
- SEG endpoint labels: Sn / Sn?
- Existing BSP labels are expected to be already routed through ChartLabelLayout.

Out of scope:
- Price axis labels
- Date axis labels
- Top summary text
- Crosshair readout
- User drawing-object text

Usage:
  python tools/patch_origin_kline_global_label_layout.py --check
  python tools/patch_origin_kline_global_label_layout.py --apply

After `--apply`, run:
  flutter analyze
  python tools/audit_origin_kline_global_label_layout_usage.py --strict
  python tools/audit_bsp_label_layout_usage.py --strict
  flutter test test/chart_label_layout_test.dart
  flutter test test/bsp_chart_label_adapter_test.dart
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

TARGET = Path("lib/ui/widgets/origin_kline_chart.dart")

BI_CALL_OLD = "    if (showBi) _drawBi(canvas, rect, start, end, rawToX, priceToY);\n"
BI_CALL_NEW = "    if (showBi) _drawBi(canvas, rect, start, end, rawToX, priceToY, chartLabels);\n"

SEG_CALL_OLD = "    if (showSeg) _drawSeg(canvas, rect, start, end, rawToX, priceToY);\n"
SEG_CALL_NEW = "    if (showSeg) _drawSeg(canvas, rect, start, end, rawToX, priceToY, chartLabels);\n"

FX_CALL_OLD = "    if (showFx) _drawFx(canvas, rect, start, end, rawToX, priceToY);\n"
FX_CALL_NEW = "    if (showFx) _drawFx(canvas, rect, start, end, rawToX, priceToY, chartLabels);\n"

FX_SIGNATURE_OLD = (
    "  void _drawFx(Canvas canvas, Rect rect, int start, int end,\n"
    "      double Function(int) rawToX, double Function(double) priceToY) {\n"
)
FX_SIGNATURE_NEW = (
    "  void _drawFx(Canvas canvas, Rect rect, int start, int end,\n"
    "      double Function(int) rawToX, double Function(double) priceToY,\n"
    "      List<ChartLabel> chartLabels) {\n"
)

BI_SIGNATURE_OLD = (
    "  void _drawBi(Canvas canvas, Rect rect, int start, int end,\n"
    "      double Function(int) rawToX, double Function(double) priceToY) {\n"
)
BI_SIGNATURE_NEW = (
    "  void _drawBi(Canvas canvas, Rect rect, int start, int end,\n"
    "      double Function(int) rawToX, double Function(double) priceToY,\n"
    "      List<ChartLabel> chartLabels) {\n"
)

SEG_SIGNATURE_OLD = (
    "  void _drawSeg(Canvas canvas, Rect rect, int start, int end,\n"
    "      double Function(int) rawToX, double Function(double) priceToY) {\n"
)
SEG_SIGNATURE_NEW = (
    "  void _drawSeg(Canvas canvas, Rect rect, int start, int end,\n"
    "      double Function(int) rawToX, double Function(double) priceToY,\n"
    "      List<ChartLabel> chartLabels) {\n"
)

FX_TEXT_OLD = (
    "      if (showFxText)\n"
    "        _drawText(canvas, fx.isTop ? '顶' : '底',\n"
    "            Offset(p.dx - 6, p.dy + (fx.isTop ? -20 : 8)), 11, color);\n"
)
FX_TEXT_NEW = (
    "      if (showFxText) {\n"
    "        chartLabels.add(ChartLabel(\n"
    "          text: fx.isTop ? '顶' : '底',\n"
    "          anchor: p,\n"
    "          side: fx.isTop ? ChartLabelSide.top : ChartLabelSide.bottom,\n"
    "          priority: ChartLabelPriority.fx,\n"
    "          rawIndex: fx.rawIndex,\n"
    "          color: color,\n"
    "          fontSize: 11,\n"
    "          visibleWhenWindowLe: 240,\n"
    "        ));\n"
    "      }\n"
)

BI_TEXT_OLD = (
    "      if (showBiText)\n"
    "        _drawText(\n"
    "            canvas,\n"
    "            'B${bi.index + 1}',\n"
    "            Offset(p2.dx - 12, p2.dy + (bi.isUp ? -18 : 6)),\n"
    "            10,\n"
    "            const Color(0xFFFF8A80));\n"
)
BI_TEXT_NEW = (
    "      if (showBiText) {\n"
    "        chartLabels.add(ChartLabel(\n"
    "          text: 'B${bi.index + 1}',\n"
    "          anchor: p2,\n"
    "          side: bi.isUp ? ChartLabelSide.top : ChartLabelSide.bottom,\n"
    "          priority: ChartLabelPriority.bi,\n"
    "          rawIndex: bi.endRawIndex,\n"
    "          color: const Color(0xFFFF8A80),\n"
    "          fontSize: 10,\n"
    "          visibleWhenWindowLe: 240,\n"
    "        ));\n"
    "      }\n"
)

SEG_TEXT_OLD = (
    "      if (showSegText)\n"
    "        _drawText(\n"
    "            canvas,\n"
    "            'S${seg.index + 1}${seg.isSure ? '' : '?'}',\n"
    "            Offset(p2.dx - 14, p2.dy + (seg.isUp ? -20 : 8)),\n"
    "            10,\n"
    "            Colors.white70);\n"
)
SEG_TEXT_NEW = (
    "      if (showSegText) {\n"
    "        chartLabels.add(ChartLabel(\n"
    "          text: 'S${seg.index + 1}${seg.isSure ? '' : '?'}',\n"
    "          anchor: p2,\n"
    "          side: seg.isUp ? ChartLabelSide.top : ChartLabelSide.bottom,\n"
    "          priority: ChartLabelPriority.seg,\n"
    "          rawIndex: seg.endRawIndex,\n"
    "          color: Colors.white70,\n"
    "          fontSize: 10,\n"
    "          visibleWhenWindowLe: 360,\n"
    "        ));\n"
    "      }\n"
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


def apply_patch(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []
    replacements = [
        (BI_CALL_OLD, BI_CALL_NEW, "BI draw call"),
        (SEG_CALL_OLD, SEG_CALL_NEW, "SEG draw call"),
        (FX_CALL_OLD, FX_CALL_NEW, "FX draw call"),
        (FX_SIGNATURE_OLD, FX_SIGNATURE_NEW, "_drawFx signature"),
        (BI_SIGNATURE_OLD, BI_SIGNATURE_NEW, "_drawBi signature"),
        (SEG_SIGNATURE_OLD, SEG_SIGNATURE_NEW, "_drawSeg signature"),
        (FX_TEXT_OLD, FX_TEXT_NEW, "FX direct _drawText"),
        (BI_TEXT_OLD, BI_TEXT_NEW, "BI direct _drawText"),
        (SEG_TEXT_OLD, SEG_TEXT_NEW, "SEG direct _drawText"),
    ]
    for old, new, label in replacements:
        source, did, note = replace_once(source, old, new, label)
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
