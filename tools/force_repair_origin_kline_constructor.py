#!/usr/bin/env python3
"""Force repair OriginKlineChart constructor parameters after half-applied UI patch.

This script does not rely on broad global token checks. It inspects the
OriginKlineChart widget class and _OriginChartPainter separately, then inserts
only the missing declarations / constructor params.

Run:
  python tools/force_repair_origin_kline_constructor.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
OVERLAY = Path("lib/ui/widgets/chan_loading_overlay.dart")


def section(source: str, start_token: str, end_token: str) -> tuple[int, int, str]:
    start = source.find(start_token)
    if start < 0:
        raise ValueError(f"start token not found: {start_token}")
    end = source.find(end_token, start)
    if end < 0:
        raise ValueError(f"end token not found: {end_token}")
    return start, end, source[start:end]


def replace_once(source: str, old: str, new: str, label: str) -> tuple[str, bool, str]:
    if old not in source:
        return source, False, f"SKIP anchor not found: {label}"
    return source.replace(old, new, 1), True, f"APPLY {label}"


def patch_chart(source: str) -> tuple[str, bool, list[str]]:
    changed = False
    notes: list[str] = []

    # 1) OriginKlineChart public field declarations.
    cls_start, ctor_start, cls_before_ctor = section(
        source,
        "class OriginKlineChart extends StatefulWidget {",
        "  const OriginKlineChart({",
    )
    if "final String symbolLabel;" not in cls_before_ctor:
        old = "  final String drawingStorageKey;\n"
        new = (
            "  final String drawingStorageKey;\n"
            "  final String symbolLabel;\n"
            "  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n"
            "  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n"
        )
        source, did, note = replace_once(source, old, new, "widget field declarations")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK widget field declarations")

    # 2) OriginKlineChart constructor named params.
    ctor_start, ctor_end, ctor = section(
        source,
        "  const OriginKlineChart({",
        "  });",
    )
    if "this.symbolLabel = ''," not in ctor:
        old = "    this.drawingStorageKey = '',\n"
        new = (
            "    this.drawingStorageKey = '',\n"
            "    this.symbolLabel = '',\n"
            "    this.isChanOverlayVisible,\n"
            "    this.onChanOverlayToggled,\n"
        )
        source, did, note = replace_once(source, old, new, "widget constructor named params")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK widget constructor named params")

    # 3) Pass callbacks and drawing import/export into TV toolbox.
    host_start, host_end, host = section(
        source,
        "    return TradingViewToolboxHost(",
        "      child: Stack(",
    )
    if "onImportDrawings: _importDrawings" not in host:
        old = (
            "      onClearDrawings: _drawings.objects.isEmpty\n"
            "          ? null\n"
            "          : () {\n"
            "              _setDrawings(const DrawingObjectCollection());\n"
            "              _showDrawMessage('已清空手动画线');\n"
            "            },\n"
        )
        new = old + (
            "      onImportDrawings: _importDrawings,\n"
            "      onExportDrawings: _exportDrawings,\n"
            "      canExportDrawings: _drawings.objects.isNotEmpty,\n"
            "      isChanOverlayVisible: widget.isChanOverlayVisible,\n"
            "      onChanOverlayToggled: widget.onChanOverlayToggled,\n"
        )
        source, did, note = replace_once(source, old, new, "TV toolbox callbacks")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK TV toolbox callbacks")

    # 4) Remove legacy floating import/export bar.
    floating = (
        "          Positioned(\n"
        "              left: 52,\n"
        "              bottom: 8,\n"
        "              child: _DrawingPersistenceBar(\n"
        "                  drawingCount: _drawings.objects.length,\n"
        "                  onImport: _importDrawings,\n"
        "                  onExport:\n"
        "                      _drawings.objects.isEmpty ? null : _exportDrawings)),\n"
    )
    if floating in source:
        source = source.replace(floating, "", 1)
        changed = True
        notes.append("APPLY remove legacy floating import/export bar")
    else:
        notes.append("OK remove legacy floating import/export bar")

    # 5) Pass symbol label to painter.
    paint_start, paint_end, paint_call = section(
        source,
        "                  painter: _OriginChartPainter(",
        "                  ),",
    )
    if "symbolLabel: widget.symbolLabel" not in paint_call:
        old = "                    snapshot: widget.snapshot,\n"
        new = "                    snapshot: widget.snapshot,\n                    symbolLabel: widget.symbolLabel,\n"
        source, did, note = replace_once(source, old, new, "painter call symbolLabel")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK painter call symbolLabel")

    # 6) Painter field and constructor.
    painter_start, painter_ctor_start, painter_fields = section(
        source,
        "class _OriginChartPainter extends CustomPainter {",
        "  _OriginChartPainter(",
    )
    if "final String symbolLabel;" not in painter_fields:
        old = "  final ChanSnapshot snapshot;\n"
        new = "  final ChanSnapshot snapshot;\n  final String symbolLabel;\n"
        source, did, note = replace_once(source, old, new, "painter field symbolLabel")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK painter field symbolLabel")

    painter_ctor_start, painter_ctor_end, painter_ctor = section(
        source,
        "  _OriginChartPainter(",
        "       this.crosshairIndex});",
    )
    if "required this.symbolLabel," not in painter_ctor:
        old = "       {required this.snapshot,\n"
        new = "       {required this.snapshot,\n       required this.symbolLabel,\n"
        source, did, note = replace_once(source, old, new, "painter constructor symbolLabel")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK painter constructor symbolLabel")

    # 7) Symbol label ChartLabel entry.
    if "final trimmedSymbolLabel = symbolLabel.trim();" not in source:
        old = "    final chartLabels = <ChartLabel>[];\n    const bspLabelAdapter = BspChartLabelAdapter();\n"
        new = (
            "    final chartLabels = <ChartLabel>[];\n"
            "    const bspLabelAdapter = BspChartLabelAdapter();\n"
            "    final trimmedSymbolLabel = symbolLabel.trim();\n"
            "    if (trimmedSymbolLabel.isNotEmpty) {\n"
            "      chartLabels.add(ChartLabel(\n"
            "        text: trimmedSymbolLabel,\n"
            "        anchor: Offset(rect.left + 12, rect.top + 18),\n"
            "        side: ChartLabelSide.inside,\n"
            "        priority: ChartLabelPriority.grid,\n"
            "        color: Colors.white70,\n"
            "        fontSize: 12,\n"
            "        forceVisible: true,\n"
            "      ));\n"
            "    }\n"
        )
        source, did, note = replace_once(source, old, new, "symbol label ChartLabel entry")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK symbol label ChartLabel entry")

    return source, changed, notes


def patch_overlay(source: str) -> tuple[str, bool, list[str]]:
    changed = False
    notes: list[str] = []
    replacements = [
        ("      _LineSpec(const Color(0xFF64B5F6), 0.0),", "      const _LineSpec(Color(0xFF64B5F6), 0.0),", "const blue line spec"),
        ("      _LineSpec(const Color(0xFFFFD54F), math.pi * 0.62),", "      const _LineSpec(Color(0xFFFFD54F), math.pi * 0.62),", "const yellow line spec"),
        ("      _LineSpec(const Color(0xFFAB47BC), math.pi * 1.25),", "      const _LineSpec(Color(0xFFAB47BC), math.pi * 1.25),", "const purple line spec"),
    ]
    for old, new, label in replacements:
        if new in source:
            notes.append(f"OK {label}")
        elif old in source:
            source = source.replace(old, new, 1)
            changed = True
            notes.append(f"APPLY {label}")
        else:
            notes.append(f"SKIP {label}")
    return source, changed, notes


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    for path in (CHART, OVERLAY):
        if not path.exists():
            print(f"FAIL missing {path}")
            return 1

    try:
        chart_source = CHART.read_text(encoding="utf-8")
        chart_next, chart_changed, chart_notes = patch_chart(chart_source)
        overlay_source = OVERLAY.read_text(encoding="utf-8")
        overlay_next, overlay_changed, overlay_notes = patch_overlay(overlay_source)
    except ValueError as exc:
        print(f"FAIL {exc}")
        return 1

    for note in [*chart_notes, *overlay_notes]:
        print(note)

    if args.apply:
        if chart_changed:
            CHART.write_text(chart_next, encoding="utf-8")
        if overlay_changed:
            OVERLAY.write_text(overlay_next, encoding="utf-8")
        print("UPDATED" if chart_changed or overlay_changed else "NOOP already repaired")
    else:
        print("PASS force repair can apply" if chart_changed or overlay_changed else "PASS already repaired")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
