#!/usr/bin/env python3
"""Force repair remaining OriginKlineChart constructor analyze errors.

This version intentionally applies a minimal compile-safe patch first:
- Add OriginKlineChart public fields for symbolLabel / Chan overlay callbacks.
- Add matching named constructor parameters.
- Fix the three const constructor lint infos in ChanLoadingOverlay.

It does not scan _OriginChartPainter constructor text, because local formatting
can vary and should not block the compile repair.

Run:
  python tools/force_repair_origin_kline_constructor.py --check
  python tools/force_repair_origin_kline_constructor.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
OVERLAY = Path("lib/ui/widgets/chan_loading_overlay.dart")


def replace_once(source: str, old: str, new: str, label: str):
    if new in source:
        return source, False, f"OK {label}"
    if old not in source:
        return source, False, f"SKIP anchor not found: {label}"
    return source.replace(old, new, 1), True, f"APPLY {label}"


def patch_chart(source: str):
    changed = False
    notes: list[str] = []

    if "final String symbolLabel;" not in source:
        old = "  final String drawingStorageKey;\n"
        new = (
            "  final String drawingStorageKey;\n"
            "  final String symbolLabel;\n"
            "  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n"
            "  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n"
        )
        source, did, note = replace_once(source, old, new, "OriginKlineChart fields")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK OriginKlineChart fields")

    if "this.symbolLabel = ''," not in source:
        old = "    this.drawingStorageKey = '',\n"
        new = (
            "    this.drawingStorageKey = '',\n"
            "    this.symbolLabel = '',\n"
            "    this.isChanOverlayVisible,\n"
            "    this.onChanOverlayToggled,\n"
        )
        source, did, note = replace_once(source, old, new, "OriginKlineChart constructor params")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK OriginKlineChart constructor params")

    # Opportunistically wire the symbol label into the painter if the local file
    # still has the known safe anchors. Missing anchors are reported as SKIP, not FAIL.
    if "symbolLabel: widget.symbolLabel" not in source:
        old = "                    snapshot: widget.snapshot,\n"
        new = "                    snapshot: widget.snapshot,\n                    symbolLabel: widget.symbolLabel,\n"
        source, did, note = replace_once(source, old, new, "pass symbolLabel to painter")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK pass symbolLabel to painter")

    if "  final String symbolLabel;\n  final bool showFx;" not in source:
        old = "  final ChanSnapshot snapshot;\n  final bool showFx;\n"
        new = "  final ChanSnapshot snapshot;\n  final String symbolLabel;\n  final bool showFx;\n"
        source, did, note = replace_once(source, old, new, "painter symbolLabel field")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK painter symbolLabel field")

    if "required this.symbolLabel," not in source:
        old = "       {required this.snapshot,\n"
        new = "       {required this.snapshot,\n       required this.symbolLabel,\n"
        source, did, note = replace_once(source, old, new, "painter symbolLabel constructor param")
        changed |= did
        notes.append(note)
    else:
        notes.append("OK painter symbolLabel constructor param")

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


def patch_overlay(source: str):
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
            notes.append(f"SKIP anchor not found: {label}")
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

    chart_source = CHART.read_text(encoding="utf-8")
    chart_next, chart_changed, chart_notes = patch_chart(chart_source)
    overlay_source = OVERLAY.read_text(encoding="utf-8")
    overlay_next, overlay_changed, overlay_notes = patch_overlay(overlay_source)

    for note in [*chart_notes, *overlay_notes]:
        print(note)

    if args.apply:
        if chart_changed:
            CHART.write_text(chart_next, encoding="utf-8")
        if overlay_changed:
            OVERLAY.write_text(overlay_next, encoding="utf-8")
        print("UPDATED" if chart_changed or overlay_changed else "NOOP already repaired")
    else:
        print("PASS can apply" if chart_changed or overlay_changed else "PASS already repaired")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
