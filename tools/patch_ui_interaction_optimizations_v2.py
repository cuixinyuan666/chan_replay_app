#!/usr/bin/env python3
"""Robust UI interaction optimization patch.

Use this script instead of patch_ui_interaction_optimizations.py.

Run:
  python tools/patch_ui_interaction_optimizations_v2.py --check
  python tools/patch_ui_interaction_optimizations_v2.py --apply

Then:
  flutter pub get
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

from patch_ui_interaction_optimizations import (
    CHART,
    PAGE,
    TOOLBOX,
    PatchResult,
    patch_chart,
    patch_page,
)

TOOLBOX_CONTENT = r'''import 'package:flutter/material.dart';

import 'tradingview_drawing_tool.dart';

class TradingViewToolboxHost extends StatefulWidget {
  final Widget child;
  final bool hasBars;
  final bool hasChanSnapshot;
  final bool Function(TradingViewDrawingTool tool)? isToolAvailable;
  final TradingViewDrawingTool? selectedTool;
  final ValueChanged<TradingViewDrawingTool>? onSelected;
  final VoidCallback? onClearDrawings;
  final VoidCallback? onImportDrawings;
  final VoidCallback? onExportDrawings;
  final bool canExportDrawings;
  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;
  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;
  final int drawingCount;

  const TradingViewToolboxHost({
    super.key,
    required this.child,
    this.hasBars = false,
    this.hasChanSnapshot = false,
    this.isToolAvailable,
    this.selectedTool,
    this.onSelected,
    this.onClearDrawings,
    this.onImportDrawings,
    this.onExportDrawings,
    this.canExportDrawings = false,
    this.isChanOverlayVisible,
    this.onChanOverlayToggled,
    this.drawingCount = 0,
  });

  @override
  State<TradingViewToolboxHost> createState() => _TradingViewToolboxHostState();
}

class _TradingViewToolboxHostState extends State<TradingViewToolboxHost> {
  bool _open = false;
  TradingViewDrawingTool _localSelectedTool = TradingViewDrawingTool.cursor;

  TradingViewDrawingTool get _effectiveSelectedTool =>
      widget.selectedTool ?? _localSelectedTool;

  @override
  Widget build(BuildContext context) {
    final selected = _effectiveSelectedTool;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 8,
          top: 8,
          child: _ToolboxButton(
            open: _open,
            selectedLabel:
                TradingViewDrawingToolRegistry.metaOf(selected).label,
            drawingCount: widget.drawingCount,
            onPressed: () => setState(() => _open = !_open),
          ),
        ),
        if (_open)
          Positioned(
            left: 8,
            top: 52,
            bottom: 12,
            width: 356,
            child: _ToolboxPanel(
              selectedTool: selected,
              hasBars: widget.hasBars,
              hasChanSnapshot: widget.hasChanSnapshot,
              isToolAvailable: widget.isToolAvailable,
              drawingCount: widget.drawingCount,
              canExportDrawings: widget.canExportDrawings,
              onClearDrawings: widget.onClearDrawings,
              onImportDrawings: widget.onImportDrawings,
              onExportDrawings: widget.onExportDrawings,
              isChanOverlayVisible: widget.isChanOverlayVisible,
              onChanOverlayToggled: widget.onChanOverlayToggled,
              onClose: () => setState(() => _open = false),
              onSelected: (tool) {
                setState(() => _localSelectedTool = tool);
                widget.onSelected?.call(tool);
                final meta = TradingViewDrawingToolRegistry.metaOf(tool);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(meta.minPoints > 0
                        ? '已选择：${meta.label}。请在K线图上点击放置锚点。'
                        : '已选择：${meta.label}。'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFF1E3A8A),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ToolboxButton extends StatelessWidget {
  final bool open;
  final String selectedLabel;
  final int drawingCount;
  final VoidCallback onPressed;

  const _ToolboxButton({
    required this.open,
    required this.selectedLabel,
    required this.drawingCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final suffix = drawingCount > 0 ? ' · $drawingCount' : '';
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: 'TradingView 工具箱：$selectedLabel$suffix',
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: Icon(open ? Icons.close : Icons.architecture, size: 18),
          label: Text('TV工具$suffix'),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: const Color(0xDD1F2937),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
    );
  }
}

class _ToolboxPanel extends StatelessWidget {
  final TradingViewDrawingTool selectedTool;
  final bool hasBars;
  final bool hasChanSnapshot;
  final bool Function(TradingViewDrawingTool tool)? isToolAvailable;
  final int drawingCount;
  final bool canExportDrawings;
  final VoidCallback? onClearDrawings;
  final VoidCallback? onImportDrawings;
  final VoidCallback? onExportDrawings;
  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;
  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;
  final VoidCallback onClose;
  final ValueChanged<TradingViewDrawingTool> onSelected;

  const _ToolboxPanel({
    required this.selectedTool,
    required this.hasBars,
    required this.hasChanSnapshot,
    required this.isToolAvailable,
    required this.drawingCount,
    required this.canExportDrawings,
    required this.onClearDrawings,
    required this.onImportDrawings,
    required this.onExportDrawings,
    required this.isChanOverlayVisible,
    required this.onChanOverlayToggled,
    required this.onClose,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = TradingViewDrawingToolRegistry.byGroup();
    return Material(
      elevation: 18,
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF2131722),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(
                blurRadius: 20, offset: Offset(0, 8), color: Color(0x99000000)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  const Icon(Icons.architecture,
                      size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'TradingView 画线工具箱',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: '导入画线 JSON',
                    onPressed: onImportDrawings,
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                    disabledColor: Colors.white24,
                  ),
                  IconButton(
                    tooltip: canExportDrawings ? '导出画线 JSON' : '暂无手动画线可导出',
                    onPressed: canExportDrawings ? onExportDrawings : null,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                    disabledColor: Colors.white24,
                  ),
                  IconButton(
                    tooltip: drawingCount > 0 ? '清空手动画线' : '暂无手动画线',
                    onPressed: drawingCount > 0 ? onClearDrawings : null,
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                    disabledColor: Colors.white24,
                  ),
                  IconButton(
                    tooltip: '关闭工具箱',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                '选择工具后在K线图上点击创建锚点；缠论叠加在右侧开关中控制显示，不在前端重算。',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.35),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 640,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 10),
                  children: [
                    for (final entry in grouped.entries)
                      _ToolGroupTile(
                        group: entry.key,
                        tools: entry.value,
                        selectedTool: selectedTool,
                        hasBars: hasBars,
                        hasChanSnapshot: hasChanSnapshot,
                        isToolAvailable: isToolAvailable,
                        isChanOverlayVisible: isChanOverlayVisible,
                        onChanOverlayToggled: onChanOverlayToggled,
                        onSelected: onSelected,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolGroupTile extends StatelessWidget {
  final TradingViewDrawingGroup group;
  final List<TradingViewDrawingToolMeta> tools;
  final TradingViewDrawingTool selectedTool;
  final bool hasBars;
  final bool hasChanSnapshot;
  final bool Function(TradingViewDrawingTool tool)? isToolAvailable;
  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;
  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;
  final ValueChanged<TradingViewDrawingTool> onSelected;

  const _ToolGroupTile({
    required this.group,
    required this.tools,
    required this.selectedTool,
    required this.hasBars,
    required this.hasChanSnapshot,
    required this.isToolAvailable,
    required this.isChanOverlayVisible,
    required this.onChanOverlayToggled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: PageStorageKey('tv_tool_group_${group.name}'),
      maintainState: true,
      initiallyExpanded: group == TradingViewDrawingGroup.lines ||
          group == TradingViewDrawingGroup.chanOverlay,
      leading: Icon(_groupIcon(group), color: Colors.white70, size: 18),
      title: Text(_groupLabel(group),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600)),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      collapsedIconColor: Colors.white54,
      iconColor: Colors.white70,
      children: [
        for (final meta in tools)
          _ToolTile(
            meta: meta,
            selected: selectedTool == meta.tool,
            disabledReason: _disabledReason(meta),
            isChanOverlayVisible: isChanOverlayVisible,
            onChanOverlayToggled: onChanOverlayToggled,
            onSelected: onSelected,
          ),
      ],
    );
  }

  String? _disabledReason(TradingViewDrawingToolMeta meta) {
    if (meta.requiresChanSnapshot && !hasChanSnapshot) {
      return '需要先加载 Python chan.py/Vespa 快照结果';
    }
    if (meta.minPoints > 0 && !hasBars) {
      return '需要先加载K线后才能绑定时间/价格坐标';
    }
    final isAvailable = isToolAvailable?.call(meta.tool) ?? true;
    if (!isAvailable) {
      return '当前后端快照未返回${meta.label}数据';
    }
    return null;
  }
}

class _ToolTile extends StatelessWidget {
  final TradingViewDrawingToolMeta meta;
  final bool selected;
  final String? disabledReason;
  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;
  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;
  final ValueChanged<TradingViewDrawingTool> onSelected;

  const _ToolTile({
    required this.meta,
    required this.selected,
    required this.disabledReason,
    required this.isChanOverlayVisible,
    required this.onChanOverlayToggled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = disabledReason == null;
    final subtitle = disabledReason ?? meta.description;
    final isChanSwitch = meta.group == TradingViewDrawingGroup.chanOverlay &&
        meta.maxPoints == 0 &&
        onChanOverlayToggled != null;
    final visible = isChanOverlayVisible?.call(meta.tool) ?? selected;
    return Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: Tooltip(
        message: enabled ? meta.description : '${meta.label}：$disabledReason',
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          enabled: enabled,
          selected: selected || (isChanSwitch && visible),
          selectedTileColor: const Color(0x332962FF),
          leading: Icon(_toolIcon(meta.tool),
              size: 18,
              color: selected || (isChanSwitch && visible)
                  ? const Color(0xFF8AB4FF)
                  : Colors.white60),
          title: Text(meta.label,
              style: TextStyle(
                  color: enabled ? Colors.white : Colors.white60,
                  fontSize: 13)),
          subtitle: Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: enabled ? 0.50 : 0.36),
                  fontSize: 11)),
          trailing: isChanSwitch
              ? Switch.adaptive(
                  value: visible,
                  onChanged:
                      enabled ? (_) => onChanOverlayToggled?.call(meta.tool) : null,
                )
              : Text(_pointLabel(meta),
                  style: const TextStyle(color: Colors.white30, fontSize: 10)),
          onTap: enabled
              ? () {
                  if (isChanSwitch) {
                    onChanOverlayToggled?.call(meta.tool);
                  } else {
                    onSelected(meta.tool);
                  }
                }
              : null,
        ),
      ),
    );
  }
}

String _groupLabel(TradingViewDrawingGroup group) {
  return switch (group) {
    TradingViewDrawingGroup.cursorAndMeasure => '光标 / 测量',
    TradingViewDrawingGroup.lines => '线类工具',
    TradingViewDrawingGroup.pitchforks => '音叉工具',
    TradingViewDrawingGroup.fibonacciAndGann => '斐波那契 / 江恩',
    TradingViewDrawingGroup.geometricShapes => '几何图形',
    TradingViewDrawingGroup.annotation => '文字 / 标注',
    TradingViewDrawingGroup.patterns => '形态工具',
    TradingViewDrawingGroup.predictionAndMeasurement => '预测 / 仓位测量',
    TradingViewDrawingGroup.icons => '图标标记',
    TradingViewDrawingGroup.chanOverlay => '缠论叠加',
  };
}

IconData _groupIcon(TradingViewDrawingGroup group) {
  return switch (group) {
    TradingViewDrawingGroup.cursorAndMeasure => Icons.straighten,
    TradingViewDrawingGroup.lines => Icons.show_chart,
    TradingViewDrawingGroup.pitchforks => Icons.fork_left,
    TradingViewDrawingGroup.fibonacciAndGann => Icons.grid_4x4,
    TradingViewDrawingGroup.geometricShapes => Icons.category,
    TradingViewDrawingGroup.annotation => Icons.text_fields,
    TradingViewDrawingGroup.patterns => Icons.polyline,
    TradingViewDrawingGroup.predictionAndMeasurement => Icons.assessment,
    TradingViewDrawingGroup.icons => Icons.emoji_symbols,
    TradingViewDrawingGroup.chanOverlay => Icons.account_tree,
  };
}

IconData _toolIcon(TradingViewDrawingTool tool) {
  return switch (tool) {
    TradingViewDrawingTool.cursor => Icons.near_me,
    TradingViewDrawingTool.crosshair => Icons.control_camera,
    TradingViewDrawingTool.ruler => Icons.straighten,
    TradingViewDrawingTool.dateRange => Icons.date_range,
    TradingViewDrawingTool.priceRange => Icons.attach_money,
    TradingViewDrawingTool.dateAndPriceRange => Icons.open_in_full,
    TradingViewDrawingTool.longPosition => Icons.trending_up,
    TradingViewDrawingTool.shortPosition => Icons.trending_down,
    TradingViewDrawingTool.forecast => Icons.timeline,
    TradingViewDrawingTool.barsPattern => Icons.content_copy,
    TradingViewDrawingTool.ghostFeed => Icons.auto_fix_high,
    TradingViewDrawingTool.trendLine => Icons.show_chart,
    TradingViewDrawingTool.infoLine => Icons.query_stats,
    TradingViewDrawingTool.extendedLine => Icons.linear_scale,
    TradingViewDrawingTool.ray => Icons.call_made,
    TradingViewDrawingTool.horizontalLine => Icons.horizontal_rule,
    TradingViewDrawingTool.horizontalRay => Icons.east,
    TradingViewDrawingTool.verticalLine => Icons.vertical_align_center,
    TradingViewDrawingTool.crossLine => Icons.add,
    TradingViewDrawingTool.parallelChannel => Icons.view_stream,
    TradingViewDrawingTool.regressionTrend => Icons.analytics,
    TradingViewDrawingTool.flatTopBottom => Icons.table_rows,
    TradingViewDrawingTool.disjointChannel => Icons.ssid_chart,
    TradingViewDrawingTool.anchoredVwap => Icons.anchor,
    TradingViewDrawingTool.anchoredText => Icons.text_fields,
    TradingViewDrawingTool.pitchfork => Icons.fork_left,
    TradingViewDrawingTool.schiffPitchfork => Icons.alt_route,
    TradingViewDrawingTool.modifiedSchiffPitchfork => Icons.account_tree,
    TradingViewDrawingTool.insidePitchfork => Icons.device_hub,
    TradingViewDrawingTool.fibRetracement => Icons.format_line_spacing,
    TradingViewDrawingTool.trendBasedFibExtension => Icons.trending_flat,
    TradingViewDrawingTool.fibChannel => Icons.grid_3x3,
    TradingViewDrawingTool.fibTimeZone => Icons.more_time,
    TradingViewDrawingTool.fibSpeedResistanceFan => Icons.filter_tilt_shift,
    TradingViewDrawingTool.fibSpeedResistanceArcs => Icons.architecture,
    TradingViewDrawingTool.fibWedge => Icons.change_history,
    TradingViewDrawingTool.pitchfan => Icons.air,
    TradingViewDrawingTool.gannBox => Icons.grid_4x4,
    TradingViewDrawingTool.gannSquareFixed => Icons.crop_7_5,
    TradingViewDrawingTool.gannSquare => Icons.crop_square,
    TradingViewDrawingTool.gannFan => Icons.radar,
    TradingViewDrawingTool.brush => Icons.brush,
    TradingViewDrawingTool.highlighter => Icons.highlight,
    TradingViewDrawingTool.arrow => Icons.arrow_forward,
    TradingViewDrawingTool.arrowMarker => Icons.near_me,
    TradingViewDrawingTool.rectangle => Icons.rectangle_outlined,
    TradingViewDrawingTool.rotatedRectangle => Icons.crop_rotate,
    TradingViewDrawingTool.ellipse => Icons.circle_outlined,
    TradingViewDrawingTool.triangle => Icons.change_history,
    TradingViewDrawingTool.polyline => Icons.polyline,
    TradingViewDrawingTool.curve => Icons.gesture,
    TradingViewDrawingTool.path => Icons.route,
    TradingViewDrawingTool.arc => Icons.roundabout_right,
    TradingViewDrawingTool.circle => Icons.radio_button_unchecked,
    TradingViewDrawingTool.text => Icons.title,
    TradingViewDrawingTool.anchoredNote => Icons.sticky_note_2,
    TradingViewDrawingTool.note => Icons.notes,
    TradingViewDrawingTool.callout => Icons.chat_bubble_outline,
    TradingViewDrawingTool.balloon => Icons.mode_comment_outlined,
    TradingViewDrawingTool.priceLabel => Icons.label,
    TradingViewDrawingTool.priceNote => Icons.request_quote,
    TradingViewDrawingTool.signpost => Icons.signpost,
    TradingViewDrawingTool.flagMark => Icons.flag,
    TradingViewDrawingTool.abcdPattern => Icons.pattern,
    TradingViewDrawingTool.xabcdPattern => Icons.hub,
    TradingViewDrawingTool.trianglePattern => Icons.change_history,
    TradingViewDrawingTool.threeDrivesPattern => Icons.multiline_chart,
    TradingViewDrawingTool.headAndShoulders => Icons.groups,
    TradingViewDrawingTool.cypherPattern => Icons.enhanced_encryption,
    TradingViewDrawingTool.elliottImpulseWave => Icons.waves,
    TradingViewDrawingTool.elliottTriangleWave => Icons.schema,
    TradingViewDrawingTool.elliottTripleComboWave => Icons.merge,
    TradingViewDrawingTool.elliottCorrectionWave => Icons.replay,
    TradingViewDrawingTool.cyclicLines => Icons.loop,
    TradingViewDrawingTool.timeCycles => Icons.timelapse,
    TradingViewDrawingTool.sineLine => Icons.ssid_chart,
    TradingViewDrawingTool.iconArrowUp => Icons.arrow_upward,
    TradingViewDrawingTool.iconArrowDown => Icons.arrow_downward,
    TradingViewDrawingTool.iconCheck => Icons.check_circle_outline,
    TradingViewDrawingTool.iconCross => Icons.cancel_outlined,
    TradingViewDrawingTool.iconCircle => Icons.trip_origin,
    TradingViewDrawingTool.iconStar => Icons.star_border,
    TradingViewDrawingTool.iconFlag => Icons.outlined_flag,
    TradingViewDrawingTool.chanFx => Icons.filter_center_focus,
    TradingViewDrawingTool.chanFxLine => Icons.timeline,
    TradingViewDrawingTool.chanBi => Icons.edit_note,
    TradingViewDrawingTool.chanBiText => Icons.format_color_text,
    TradingViewDrawingTool.chanSeg => Icons.account_tree,
    TradingViewDrawingTool.chanSegText => Icons.short_text,
    TradingViewDrawingTool.chanZs => Icons.select_all,
    TradingViewDrawingTool.chanBiBsp => Icons.shopping_cart_checkout,
    TradingViewDrawingTool.chanSegBsp => Icons.sell_outlined,
    TradingViewDrawingTool.chanMergedBars => Icons.view_week,
  };
}

String _pointLabel(TradingViewDrawingToolMeta meta) {
  if (meta.maxPoints == 0) return '开关';
  if (meta.maxPoints < 0) return '${meta.minPoints}+点';
  if (meta.minPoints == meta.maxPoints) return '${meta.minPoints}点';
  return '${meta.minPoints}-${meta.maxPoints}点';
}
'''


def replace_once(source: str, old: str, new: str, label: str) -> tuple[str, bool, str]:
    if new in source:
        return source, False, f"already applied: {label}"
    if old not in source:
        raise ValueError(f"patch anchor not found: {label}")
    return source.replace(old, new, 1), True, f"applied: {label}"


def fix_page(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []
    source, did, note = replace_once(
        source,
        "import '../../data/python_chan_analysis_source.dart';\n",
        "import '../../data/python_chan_analysis_source.dart';\nimport '../drawing/tradingview_drawing_tool.dart';\n",
        "tradingview tool import",
    )
    changed |= did
    notes.append(note)

    for old, new, label in [
        ("          _showFx = !_showFx;\n        case", "          _showFx = !_showFx;\n          break;\n        case", "FX switch break"),
        ("          _showFxLine = !_showFxLine;\n        case", "          _showFxLine = !_showFxLine;\n          break;\n        case", "FX line switch break"),
        ("          _showBi = !_showBi;\n        case", "          _showBi = !_showBi;\n          break;\n        case", "BI switch break"),
        ("          _showBiText = !_showBiText;\n        case", "          _showBiText = !_showBiText;\n          break;\n        case", "BI text switch break"),
        ("          _showSeg = !_showSeg;\n        case", "          _showSeg = !_showSeg;\n          break;\n        case", "SEG switch break"),
        ("          _showSegText = !_showSegText;\n        case", "          _showSegText = !_showSegText;\n          break;\n        case", "SEG text switch break"),
        ("          _showZs = !_showZs;\n        case", "          _showZs = !_showZs;\n          break;\n        case", "ZS switch break"),
        ("          _showBiBsp = !_showBiBsp;\n        case", "          _showBiBsp = !_showBiBsp;\n          break;\n        case", "BI BSP switch break"),
        ("          _showSegBsp = !_showSegBsp;\n        case", "          _showSegBsp = !_showSegBsp;\n          break;\n        case", "SEG BSP switch break"),
        ("          _showMergedBars = !_showMergedBars;\n        default:", "          _showMergedBars = !_showMergedBars;\n          break;\n        default:", "merged bars switch break"),
    ]:
        if old in source:
            source = source.replace(old, new, 1)
            changed = True
            notes.append(f"applied: {label}")
        else:
            notes.append(f"already applied: {label}")
    return PatchResult(source, changed, notes)


def apply_patcher(path: Path, patcher, apply: bool) -> tuple[bool, list[str]]:
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

    for path in (PAGE, CHART, TOOLBOX):
        if not path.exists():
            print(f"FAIL: {path} does not exist")
            return 1

    notes: list[str] = []
    changes: list[bool] = []
    try:
        page_changed, page_notes = apply_patcher(PAGE, patch_page, args.apply)
        changes.append(page_changed)
        notes.extend(page_notes)
        if args.apply:
            page_fix_changed, page_fix_notes = apply_patcher(PAGE, fix_page, True)
        else:
            fixed_preview = fix_page(patch_page(PAGE.read_text(encoding="utf-8")).content)
            page_fix_changed, page_fix_notes = fixed_preview.changed, [f"{PAGE}: {note}" for note in fixed_preview.notes]
        changes.append(page_fix_changed)
        notes.extend(page_fix_notes)

        chart_changed, chart_notes = apply_patcher(CHART, patch_chart, args.apply)
        changes.append(chart_changed)
        notes.extend(chart_notes)

        current_toolbox = TOOLBOX.read_text(encoding="utf-8")
        toolbox_changed = current_toolbox != TOOLBOX_CONTENT
        changes.append(toolbox_changed)
        notes.append(f"{TOOLBOX}: {'applied' if toolbox_changed else 'already applied'}: robust toolbox content")
        if args.apply and toolbox_changed:
            TOOLBOX.write_text(TOOLBOX_CONTENT, encoding="utf-8")
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 1

    for note in notes:
        print(note)
    if args.check:
        print("PASS: UI optimization v2 patch anchors are valid" if any(changes) else "PASS: UI optimization v2 patch already applied")
        return 0
    print("UPDATED" if any(changes) else "NOOP: patch already applied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
