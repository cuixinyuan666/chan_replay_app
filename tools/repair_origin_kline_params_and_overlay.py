#!/usr/bin/env python3
"""Focused repair for the remaining UI optimization analyze errors.

Fixes:
- OriginKlineChart missing symbolLabel / isChanOverlayVisible / onChanOverlayToggled.
- _OriginChartPainter missing symbolLabel field / constructor arg.
- Symbol label routed into ChartLabelLayout.
- Chan loading overlay const constructor infos.

Run:
  python tools/repair_origin_kline_params_and_overlay.py --check
  python tools/repair_origin_kline_params_and_overlay.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
OVERLAY = Path("lib/ui/widgets/chan_loading_overlay.dart")


def insert_after(source: str, anchor: str, insert: str, token: str, label: str):
    if token in source:
        return source, False, f"already applied: {label}"
    idx = source.find(anchor)
    if idx < 0:
        raise ValueError(f"anchor not found: {label}")
    return source[: idx + len(anchor)] + insert + source[idx + len(anchor) :], True, f"applied: {label}"


def replace_once(source: str, old: str, new: str, label: str):
    if new in source:
        return source, False, f"already applied: {label}"
    if old not in source:
        raise ValueError(f"anchor not found: {label}")
    return source.replace(old, new, 1), True, f"applied: {label}"


def patch_chart(source: str):
    changed = False
    notes = []

    # Public widget fields.
    source, did, note = insert_after(
        source,
        "  final String drawingStorageKey;\n",
        "  final String symbolLabel;\n  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n",
        "final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;",
        "OriginKlineChart public fields",
    )
    changed |= did
    notes.append(note)

    # Public widget constructor parameters.
    source, did, note = insert_after(
        source,
        "    this.drawingStorageKey = '',\n",
        "    this.symbolLabel = '',\n    this.isChanOverlayVisible,\n    this.onChanOverlayToggled,\n",
        "this.onChanOverlayToggled,",
        "OriginKlineChart constructor params",
    )
    changed |= did
    notes.append(note)

    # Pass callbacks into TradingViewToolboxHost.
    if "onImportDrawings: _importDrawings" not in source:
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
        source, did, note = replace_once(source, old, new, "TradingViewToolboxHost callbacks")
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: TradingViewToolboxHost callbacks")

    # Remove old floating import/export bar if still present.
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
        notes.append("applied: remove old floating drawing import/export bar")
    else:
        notes.append("already applied: remove old floating drawing import/export bar")

    # Pass symbol label to painter.
    if "symbolLabel: widget.symbolLabel" not in source:
        source, did, note = replace_once(
            source,
            "                    snapshot: widget.snapshot,\n",
            "                    snapshot: widget.snapshot,\n                    symbolLabel: widget.symbolLabel,\n",
            "pass symbolLabel to painter",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: pass symbolLabel to painter")

    # Painter field. This is intentionally anchored on the painter field block,
    # not the public widget field block.
    if "  final String symbolLabel;\n  final bool showFx;" not in source:
        source, did, note = replace_once(
            source,
            "  final ChanSnapshot snapshot;\n  final bool showFx;\n",
            "  final ChanSnapshot snapshot;\n  final String symbolLabel;\n  final bool showFx;\n",
            "painter symbolLabel field",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: painter symbolLabel field")

    # Painter constructor arg. Avoid confusing this with the public widget constructor.
    if "       required this.symbolLabel,\n       required this.showFx," not in source:
        source, did, note = replace_once(
            source,
            "       {required this.snapshot,\n       required this.showFx,\n",
            "       {required this.snapshot,\n       required this.symbolLabel,\n       required this.showFx,\n",
            "painter symbolLabel constructor arg",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: painter symbolLabel constructor arg")

    # Symbol label in the shared label layout queue.
    if "final trimmedSymbolLabel = symbolLabel.trim();" not in source:
        source, did, note = replace_once(
            source,
            "    final chartLabels = <ChartLabel>[];\n    const bspLabelAdapter = BspChartLabelAdapter();\n",
            "    final chartLabels = <ChartLabel>[];\n    const bspLabelAdapter = BspChartLabelAdapter();\n    final trimmedSymbolLabel = symbolLabel.trim();\n    if (trimmedSymbolLabel.isNotEmpty) {\n      chartLabels.add(ChartLabel(\n        text: trimmedSymbolLabel,\n        anchor: Offset(rect.left + 12, rect.top + 18),\n        side: ChartLabelSide.inside,\n        priority: ChartLabelPriority.grid,\n        color: Colors.white70,\n        fontSize: 12,\n        forceVisible: true,\n      ));\n    }\n",
            "symbol label ChartLabelLayout entry",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: symbol label ChartLabelLayout entry")

    return source, changed, notes


def patch_overlay(source: str):
    changed = False
    notes = []
    replacements = [
        ("      _LineSpec(const Color(0xFF64B5F6), 0.0),", "      const _LineSpec(Color(0xFF64B5F6), 0.0),", "const blue line spec"),
        ("      _LineSpec(const Color(0xFFFFD54F), math.pi * 0.62),", "      const _LineSpec(Color(0xFFFFD54F), math.pi * 0.62),", "const yellow line spec"),
        ("      _LineSpec(const Color(0xFFAB47BC), math.pi * 1.25),", "      const _LineSpec(Color(0xFFAB47BC), math.pi * 1.25),", "const purple line spec"),
    ]
    for old, new, label in replacements:
        if new in source:
            notes.append(f"already applied: {label}")
        elif old in source:
            source = source.replace(old, new, 1)
            changed = True
            notes.append(f"applied: {label}")
        else:
            notes.append(f"already applied: {label}")
    return source, changed, notes


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    for path in (CHART, OVERLAY):
        if not path.exists():
            print(f"FAIL: missing {path}")
            return 1

    changes = []
    all_notes = []
    try:
        chart_source = CHART.read_text(encoding="utf-8")
        chart_next, chart_changed, chart_notes = patch_chart(chart_source)
        changes.append(chart_changed)
        all_notes.extend(f"{CHART}: {note}" for note in chart_notes)
        if args.apply and chart_changed:
            CHART.write_text(chart_next, encoding="utf-8")

        overlay_source = OVERLAY.read_text(encoding="utf-8")
        overlay_next, overlay_changed, overlay_notes = patch_overlay(overlay_source)
        changes.append(overlay_changed)
        all_notes.extend(f"{OVERLAY}: {note}" for note in overlay_notes)
        if args.apply and overlay_changed:
            OVERLAY.write_text(overlay_next, encoding="utf-8")
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 1

    for note in all_notes:
        print(note)
    if args.check:
        print("PASS: focused OriginKlineChart repair anchors are valid" if any(changes) else "PASS: focused OriginKlineChart repair already applied")
    else:
        print("UPDATED" if any(changes) else "NOOP: repair already applied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
