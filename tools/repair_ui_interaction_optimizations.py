#!/usr/bin/env python3
"""Repair partially applied UI interaction optimization patches.

This script is safe to run after patch_ui_interaction_optimizations_v2.py when
OriginReplayPageV2 has already been patched but OriginKlineChart / toolbox /
Chan overlay metadata are still missing some pieces.

Run:
  python tools/repair_ui_interaction_optimizations.py --check
  python tools/repair_ui_interaction_optimizations.py --apply

Then:
  flutter analyze
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

PAGE = Path("lib/ui/pages/origin_replay_page_v2.dart")
CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
TOOL = Path("lib/ui/drawing/tradingview_drawing_tool.dart")
OVERLAY = Path("lib/ui/widgets/chan_loading_overlay.dart")


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


def patch_page(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []
    replacements = [
        (
            "      TradingViewDrawingTool.chanFxLine => _showFxLine,\n",
            "      TradingViewDrawingTool.chanFxLine => _showFxLine,\n      TradingViewDrawingTool.chanFxText => _showFxText,\n",
            "FX text visibility getter",
        ),
        (
            "        case TradingViewDrawingTool.chanFxLine:\n          _showFxLine = !_showFxLine;\n          break;\n        case TradingViewDrawingTool.chanBi:\n",
            "        case TradingViewDrawingTool.chanFxLine:\n          _showFxLine = !_showFxLine;\n          break;\n        case TradingViewDrawingTool.chanFxText:\n          _showFxText = !_showFxText;\n          break;\n        case TradingViewDrawingTool.chanBi:\n",
            "FX text toggle setter",
        ),
    ]
    for old, new, label in replacements:
        source, did, note = replace_once(source, old, new, label)
        changed |= did
        notes.append(note)
    return PatchResult(source, changed, notes)


def patch_chart(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []
    replacements = [
        (
            "  final String drawingStorageKey;\n",
            "  final String drawingStorageKey;\n  final String symbolLabel;\n  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n",
            "OriginKlineChart new public fields",
        ),
        (
            "    this.drawingStorageKey = '',\n",
            "    this.drawingStorageKey = '',\n    this.symbolLabel = '',\n    this.isChanOverlayVisible,\n    this.onChanOverlayToggled,\n",
            "OriginKlineChart constructor args",
        ),
        (
            "      onClearDrawings: _drawings.objects.isEmpty\n          ? null\n          : () {\n              _setDrawings(const DrawingObjectCollection());\n              _showDrawMessage('已清空手动画线');\n            },\n",
            "      onClearDrawings: _drawings.objects.isEmpty\n          ? null\n          : () {\n              _setDrawings(const DrawingObjectCollection());\n              _showDrawMessage('已清空手动画线');\n            },\n      onImportDrawings: _importDrawings,\n      onExportDrawings: _exportDrawings,\n      canExportDrawings: _drawings.objects.isNotEmpty,\n      isChanOverlayVisible: widget.isChanOverlayVisible,\n      onChanOverlayToggled: widget.onChanOverlayToggled,\n",
            "toolbox callbacks from chart",
        ),
        (
            "          Positioned(\n              left: 52,\n              bottom: 8,\n              child: _DrawingPersistenceBar(\n                  drawingCount: _drawings.objects.length,\n                  onImport: _importDrawings,\n                  onExport:\n                      _drawings.objects.isEmpty ? null : _exportDrawings)),\n",
            "",
            "remove floating import/export bar",
        ),
        (
            "                    snapshot: widget.snapshot,\n",
            "                    snapshot: widget.snapshot,\n                    symbolLabel: widget.symbolLabel,\n",
            "pass symbol label to painter",
        ),
        (
            "  final ChanSnapshot snapshot;\n",
            "  final ChanSnapshot snapshot;\n  final String symbolLabel;\n",
            "painter symbol label field",
        ),
        (
            "       {required this.snapshot,\n",
            "       {required this.snapshot,\n       required this.symbolLabel,\n",
            "painter symbol label constructor",
        ),
        (
            "    final chartLabels = <ChartLabel>[];\n    const bspLabelAdapter = BspChartLabelAdapter();\n",
            "    final chartLabels = <ChartLabel>[];\n    const bspLabelAdapter = BspChartLabelAdapter();\n    final trimmedSymbolLabel = symbolLabel.trim();\n    if (trimmedSymbolLabel.isNotEmpty) {\n      chartLabels.add(ChartLabel(\n        text: trimmedSymbolLabel,\n        anchor: Offset(rect.left + 12, rect.top + 18),\n        side: ChartLabelSide.inside,\n        priority: ChartLabelPriority.grid,\n        color: Colors.white70,\n        fontSize: 12,\n        forceVisible: true,\n      ));\n    }\n",
            "chart symbol label routed through ChartLabelLayout",
        ),
    ]
    for old, new, label in replacements:
        source, did, note = replace_once(source, old, new, label)
        changed |= did
        notes.append(note)
    return PatchResult(source, changed, notes)


def patch_tool_metadata(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []
    replacements = [
        (
            "  chanFx,\n  chanFxLine,\n",
            "  chanFx,\n  chanFxLine,\n  chanFxText,\n",
            "chanFxText enum",
        ),
        (
            "    TradingViewDrawingToolMeta(\n        tool: TradingViewDrawingTool.chanFxLine,\n        group: TradingViewDrawingGroup.chanOverlay,\n        label: '分型连线',\n        description: '显示分型连接辅助线，不参与计算',\n        minPoints: 0,\n        maxPoints: 0,\n        canPersist: false,\n        requiresChanSnapshot: true),\n",
            "    TradingViewDrawingToolMeta(\n        tool: TradingViewDrawingTool.chanFxLine,\n        group: TradingViewDrawingGroup.chanOverlay,\n        label: '分型连线',\n        description: '显示分型连接辅助线，不参与计算',\n        minPoints: 0,\n        maxPoints: 0,\n        canPersist: false,\n        requiresChanSnapshot: true),\n    TradingViewDrawingToolMeta(\n        tool: TradingViewDrawingTool.chanFxText,\n        group: TradingViewDrawingGroup.chanOverlay,\n        label: '分型文字',\n        description: '显示分型顶/底文字',\n        minPoints: 0,\n        maxPoints: 0,\n        canPersist: false,\n        requiresChanSnapshot: true),\n",
            "chanFxText metadata",
        ),
    ]
    for old, new, label in replacements:
        source, did, note = replace_once(source, old, new, label)
        changed |= did
        notes.append(note)
    return PatchResult(source, changed, notes)


def patch_overlay(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []
    for old, new, label in [
        ("      _LineSpec(const Color(0xFF64B5F6), 0.0),", "      const _LineSpec(Color(0xFF64B5F6), 0.0),", "const blue line spec"),
        ("      _LineSpec(const Color(0xFFFFD54F), math.pi * 0.62),", "      const _LineSpec(Color(0xFFFFD54F), math.pi * 0.62),", "const yellow line spec"),
        ("      _LineSpec(const Color(0xFFAB47BC), math.pi * 1.25),", "      const _LineSpec(Color(0xFFAB47BC), math.pi * 1.25),", "const purple line spec"),
    ]:
        source, did, note = replace_once(source, old, new, label)
        changed |= did
        notes.append(note)
    return PatchResult(source, changed, notes)


def patch_file(path: Path, patcher, apply: bool) -> tuple[bool, list[str]]:
    source = path.read_text(encoding="utf-8")
    result = patcher(source)
    if apply and result.changed:
        path.write_text(result.content, encoding="utf-8")
    return result.changed, [f"{path}: {note}" for note in result.notes]


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    for path in (PAGE, CHART, TOOL, OVERLAY):
        if not path.exists():
            print(f"FAIL: {path} does not exist")
            return 1

    changes = []
    notes: list[str] = []
    try:
        for path, patcher in (
            (PAGE, patch_page),
            (CHART, patch_chart),
            (TOOL, patch_tool_metadata),
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
        print("PASS: UI optimization repair anchors are valid" if any(changes) else "PASS: UI optimization repair already applied")
        return 0
    print("UPDATED" if any(changes) else "NOOP: repair already applied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
