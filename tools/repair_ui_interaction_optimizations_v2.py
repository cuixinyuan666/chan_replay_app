#!/usr/bin/env python3
"""Robust repair for partially applied UI interaction optimizations.

This script fixes the state where OriginReplayPageV2 already references:
- TradingViewDrawingTool.chanFxText
- OriginKlineChart(symbolLabel: ...)
- OriginKlineChart(isChanOverlayVisible: ...)
- OriginKlineChart(onChanOverlayToggled: ...)

but tradingview_drawing_tool.dart / origin_kline_chart.dart have not yet been
patched.

Run:
  python tools/repair_ui_interaction_optimizations_v2.py --check
  python tools/repair_ui_interaction_optimizations_v2.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

PAGE = Path("lib/ui/pages/origin_replay_page_v2.dart")
CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
TOOL = Path("lib/ui/drawing/tradingview_drawing_tool.dart")
TOOLBOX = Path("lib/ui/drawing/tradingview_toolbox_host.dart")
OVERLAY = Path("lib/ui/widgets/chan_loading_overlay.dart")


def replace_once(source: str, old: str, new: str, label: str) -> tuple[str, bool, str]:
    if new in source:
        return source, False, f"already applied: {label}"
    if old not in source:
        raise ValueError(f"patch anchor not found: {label}")
    return source.replace(old, new, 1), True, f"applied: {label}"


def insert_after(source: str, anchor: str, insert: str, label: str, present_token: str) -> tuple[str, bool, str]:
    if present_token in source:
        return source, False, f"already applied: {label}"
    idx = source.find(anchor)
    if idx < 0:
        raise ValueError(f"patch anchor not found: {label}")
    end = idx + len(anchor)
    return source[:end] + insert + source[end:], True, f"applied: {label}"


def remove_block(source: str, block: str, label: str) -> tuple[str, bool, str]:
    if block not in source:
        return source, False, f"already applied: {label}"
    return source.replace(block, "", 1), True, f"applied: {label}"


def patch_page(source: str) -> tuple[str, bool, list[str]]:
    changed = False
    notes: list[str] = []

    if "TradingViewDrawingTool.chanFxText => _showFxText" not in source:
        source, did, note = replace_once(
            source,
            "      TradingViewDrawingTool.chanFxLine => _showFxLine,\n",
            "      TradingViewDrawingTool.chanFxLine => _showFxLine,\n      TradingViewDrawingTool.chanFxText => _showFxText,\n",
            "page FX text visibility getter",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: page FX text visibility getter")

    if "case TradingViewDrawingTool.chanFxText:" not in source:
        source, did, note = replace_once(
            source,
            "        case TradingViewDrawingTool.chanFxLine:\n          _showFxLine = !_showFxLine;\n          break;\n        case TradingViewDrawingTool.chanBi:\n",
            "        case TradingViewDrawingTool.chanFxLine:\n          _showFxLine = !_showFxLine;\n          break;\n        case TradingViewDrawingTool.chanFxText:\n          _showFxText = !_showFxText;\n          break;\n        case TradingViewDrawingTool.chanBi:\n",
            "page FX text toggle setter",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: page FX text toggle setter")

    if "import '../drawing/tradingview_drawing_tool.dart';" not in source:
        source, did, note = replace_once(
            source,
            "import '../../data/python_chan_analysis_source.dart';\n",
            "import '../../data/python_chan_analysis_source.dart';\nimport '../drawing/tradingview_drawing_tool.dart';\n",
            "page tradingview tool import",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: page tradingview tool import")

    return source, changed, notes


def patch_tool(source: str) -> tuple[str, bool, list[str]]:
    changed = False
    notes: list[str] = []

    if "  chanFxText," not in source:
        source, did, note = replace_once(
            source,
            "  chanFx,\n  chanFxLine,\n  chanBi,\n",
            "  chanFx,\n  chanFxLine,\n  chanFxText,\n  chanBi,\n",
            "TradingViewDrawingTool.chanFxText enum",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: TradingViewDrawingTool.chanFxText enum")

    if "tool: TradingViewDrawingTool.chanFxText" not in source:
        anchor = (
            "    TradingViewDrawingToolMeta(\n"
            "        tool: TradingViewDrawingTool.chanFxLine,\n"
            "        group: TradingViewDrawingGroup.chanOverlay,\n"
            "        label: '分型连线',\n"
            "        description: '显示分型连接辅助线，不参与计算',\n"
            "        minPoints: 0,\n"
            "        maxPoints: 0,\n"
            "        canPersist: false,\n"
            "        requiresChanSnapshot: true),\n"
        )
        insert = (
            "    TradingViewDrawingToolMeta(\n"
            "        tool: TradingViewDrawingTool.chanFxText,\n"
            "        group: TradingViewDrawingGroup.chanOverlay,\n"
            "        label: '分型文字',\n"
            "        description: '显示分型顶/底文字',\n"
            "        minPoints: 0,\n"
            "        maxPoints: 0,\n"
            "        canPersist: false,\n"
            "        requiresChanSnapshot: true),\n"
        )
        source, did, note = insert_after(source, anchor, insert, "chanFxText metadata", "tool: TradingViewDrawingTool.chanFxText")
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: chanFxText metadata")

    return source, changed, notes


def patch_chart(source: str) -> tuple[str, bool, list[str]]:
    changed = False
    notes: list[str] = []

    if "final String symbolLabel;" not in source:
        source, did, note = replace_once(
            source,
            "  final String drawingStorageKey;\n",
            "  final String drawingStorageKey;\n  final String symbolLabel;\n  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n",
            "OriginKlineChart public fields",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: OriginKlineChart public fields")

    if "this.symbolLabel = ''," not in source:
        source, did, note = replace_once(
            source,
            "    this.drawingStorageKey = '',\n",
            "    this.drawingStorageKey = '',\n    this.symbolLabel = '',\n    this.isChanOverlayVisible,\n    this.onChanOverlayToggled,\n",
            "OriginKlineChart constructor args",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: OriginKlineChart constructor args")

    if "onImportDrawings: _importDrawings" not in source:
        source, did, note = replace_once(
            source,
            "      onClearDrawings: _drawings.objects.isEmpty\n          ? null\n          : () {\n              _setDrawings(const DrawingObjectCollection());\n              _showDrawMessage('已清空手动画线');\n            },\n",
            "      onClearDrawings: _drawings.objects.isEmpty\n          ? null\n          : () {\n              _setDrawings(const DrawingObjectCollection());\n              _showDrawMessage('已清空手动画线');\n            },\n      onImportDrawings: _importDrawings,\n      onExportDrawings: _exportDrawings,\n      canExportDrawings: _drawings.objects.isNotEmpty,\n      isChanOverlayVisible: widget.isChanOverlayVisible,\n      onChanOverlayToggled: widget.onChanOverlayToggled,\n",
            "TradingViewToolboxHost callbacks",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: TradingViewToolboxHost callbacks")

    floating_bar = (
        "          Positioned(\n"
        "              left: 52,\n"
        "              bottom: 8,\n"
        "              child: _DrawingPersistenceBar(\n"
        "                  drawingCount: _drawings.objects.length,\n"
        "                  onImport: _importDrawings,\n"
        "                  onExport:\n"
        "                      _drawings.objects.isEmpty ? null : _exportDrawings)),\n"
    )
    source, did, note = remove_block(source, floating_bar, "remove floating import/export bar")
    changed |= did
    notes.append(note)

    if "symbolLabel: widget.symbolLabel" not in source:
        source, did, note = replace_once(
            source,
            "                    snapshot: widget.snapshot,\n",
            "                    snapshot: widget.snapshot,\n                    symbolLabel: widget.symbolLabel,\n",
            "pass symbol label to painter",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: pass symbol label to painter")

    # Patch painter field and constructor independently from widget field.
    if "  final String symbolLabel;\n  final bool showFx;" not in source:
        source, did, note = replace_once(
            source,
            "  final ChanSnapshot snapshot;\n  final bool showFx;\n",
            "  final ChanSnapshot snapshot;\n  final String symbolLabel;\n  final bool showFx;\n",
            "painter symbol label field",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: painter symbol label field")

    if "required this.symbolLabel," not in source:
        source, did, note = replace_once(
            source,
            "       {required this.snapshot,\n",
            "       {required this.snapshot,\n       required this.symbolLabel,\n",
            "painter symbol label constructor",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: painter symbol label constructor")

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


def patch_toolbox(source: str) -> tuple[str, bool, list[str]]:
    changed = False
    notes: list[str] = []

    if "TradingViewDrawingTool.chanFxText => Icons.format_color_text" not in source:
        source, did, note = replace_once(
            source,
            "    TradingViewDrawingTool.chanFxLine => Icons.timeline,\n",
            "    TradingViewDrawingTool.chanFxLine => Icons.timeline,\n    TradingViewDrawingTool.chanFxText => Icons.format_color_text,\n",
            "toolbox icon for chanFxText",
        )
        changed |= did
        notes.append(note)
    else:
        notes.append("already applied: toolbox icon for chanFxText")

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
        if old in source:
            source = source.replace(old, new, 1)
            changed = True
            notes.append(f"applied: {label}")
        else:
            notes.append(f"already applied: {label}")
    return source, changed, notes


def patch_file(path: Path, patcher, apply: bool) -> tuple[bool, list[str]]:
    source = path.read_text(encoding="utf-8")
    next_source, changed, notes = patcher(source)
    if apply and changed:
        path.write_text(next_source, encoding="utf-8")
    return changed, [f"{path}: {note}" for note in notes]


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    for path in (PAGE, CHART, TOOL, TOOLBOX, OVERLAY):
        if not path.exists():
            print(f"FAIL: {path} does not exist")
            return 1

    changes: list[bool] = []
    notes: list[str] = []
    try:
        for path, patcher in (
            (PAGE, patch_page),
            (TOOL, patch_tool),
            (CHART, patch_chart),
            (TOOLBOX, patch_toolbox),
            (OVERLAY, patch_overlay),
        ):
            changed, file_notes = patch_file(path, patcher, args.apply)
            changes.append(changed)
            notes.extend(file_notes)
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 1

    for note in notes:
        print(note)
    if args.check:
        print("PASS: UI interaction repair v2 anchors are valid" if any(changes) else "PASS: UI interaction repair v2 already applied")
        return 0
    print("UPDATED" if any(changes) else "NOOP: repair already applied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
