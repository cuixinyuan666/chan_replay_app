#!/usr/bin/env python3
"""Apply the remaining app UI optimizations.

This script targets the current origin_vespa_tdx state after
"Fix OriginKlineChart symbol label integration".

It completes:
- Loading/success/failure visual overlay wiring.
- Default symbol 600340 and current end date.
- Startup auto-load.
- Symbol Chinese name label passed to OriginKlineChart.
- Left toolbar auto reveal / delayed collapse; remove Chan overlay items.
- Drawing import/export moved into the TV toolbox.
- Chan overlay switches moved into the TV toolbox.
- TV toolbox smooth scrolling and more distinct icons.

Run:
  python tools/apply_remaining_ui_optimizations.py --check
  python tools/apply_remaining_ui_optimizations.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

PAGE = Path("lib/ui/pages/origin_replay_page_v2.dart")
CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
TOOL = Path("lib/ui/drawing/tradingview_drawing_tool.dart")
TOOLBOX = Path("lib/ui/drawing/tradingview_toolbox_host.dart")

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
    TradingViewDrawingTool.chanFxText => Icons.format_color_text,
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


def replace_once(src: str, old: str, new: str, label: str):
    if new in src:
        return src, False, f"OK {label}"
    if old not in src:
        return src, False, f"SKIP {label}"
    return src.replace(old, new, 1), True, f"APPLY {label}"


def replace_method(src: str, signature: str, new_method: str, label: str):
    if new_method in src:
        return src, False, f"OK {label}"
    start = src.find(signature)
    if start < 0:
        return src, False, f"SKIP {label}: signature not found"
    open_brace = src.find('{', start)
    if open_brace < 0:
        return src, False, f"SKIP {label}: open brace not found"
    depth = 0
    end = -1
    for i in range(open_brace, len(src)):
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end < 0:
        return src, False, f"SKIP {label}: close brace not found"
    return src[:start] + new_method + src[end:], True, f"APPLY {label}"


def patch_tool(src: str):
    changed = False
    notes = []
    if '  chanFxText,' not in src:
        src, did, note = replace_once(
            src,
            '  chanFx,\n  chanFxLine,\n  chanBi,\n',
            '  chanFx,\n  chanFxLine,\n  chanFxText,\n  chanBi,\n',
            'chanFxText enum',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chanFxText enum')
    if 'tool: TradingViewDrawingTool.chanFxText' not in src:
        old = (
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
        new = old + (
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
        src, did, note = replace_once(src, old, new, 'chanFxText metadata')
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chanFxText metadata')
    return src, changed, notes


def patch_chart(src: str):
    changed = False
    notes = []
    src, did, note = replace_once(
        src,
        "      TradingViewDrawingTool.chanFx => widget.snapshot.fxs.isNotEmpty,\n      TradingViewDrawingTool.chanFxLine => widget.snapshot.fxs.length >= 2,\n",
        "      TradingViewDrawingTool.chanFx => widget.snapshot.fxs.isNotEmpty,\n      TradingViewDrawingTool.chanFxLine => widget.snapshot.fxs.length >= 2,\n      TradingViewDrawingTool.chanFxText => widget.snapshot.fxs.isNotEmpty,\n",
        'chart chanFxText availability',
    )
    changed |= did
    notes.append(note)
    if 'onImportDrawings: _importDrawings' not in src:
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
        src, did, note = replace_once(src, old, new, 'chart toolbox callbacks')
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chart toolbox callbacks')
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
    if floating in src:
        src = src.replace(floating, '', 1)
        changed = True
        notes.append('APPLY remove floating drawing persistence bar')
    else:
        notes.append('OK remove floating drawing persistence bar')
    return src, changed, notes


def patch_page(src: str):
    changed = False
    notes = []
    for old, new, label in [
        ("import '../../data/python_chan_analysis_source.dart';\n", "import '../../data/python_chan_analysis_source.dart';\nimport '../drawing/tradingview_drawing_tool.dart';\n", 'page tradingview import'),
        ("import '../widgets/origin_kline_chart.dart';\n", "import '../widgets/chan_loading_overlay.dart';\nimport '../widgets/origin_kline_chart.dart';\n", 'page loading overlay import'),
        ("  static final DateTime _defaultEndDate = DateTime(2026, 6, 6);\n", "  static final DateTime _defaultEndDate = DateTime.now();\n", 'default end date now'),
        ("      TextEditingController(text: '000001');\n", "      TextEditingController(text: '600340');\n", 'default symbol 600340'),
    ]:
        src, did, note = replace_once(src, old, new, label)
        changed |= did
        notes.append(note)
    if 'Timer? _toolbarCollapseTimer;' not in src:
        src, did, note = replace_once(
            src,
            '  Timer? _timer;\n',
            '  Timer? _timer;\n  Timer? _toolbarCollapseTimer;\n  Timer? _loadVisualTimer;\n  ChanLoadVisualState? _loadVisualState;\n  bool _toolbarHovering = false;\n',
            'page toolbar/loading fields',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK page toolbar/loading fields')
    if 'void initState()' not in src:
        src, did, note = replace_once(
            src,
            '  @override\n  void dispose() {\n',
            "  @override\n  void initState() {\n    super.initState();\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      Future<void>.delayed(const Duration(milliseconds: 320), () {\n        if (mounted) _load();\n      });\n    });\n  }\n\n  @override\n  void dispose() {\n",
            'startup auto load initState',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK startup auto load initState')
    if '_toolbarCollapseTimer?.cancel();' not in src:
        src, did, note = replace_once(
            src,
            '    _timer?.cancel();\n',
            '    _timer?.cancel();\n    _toolbarCollapseTimer?.cancel();\n    _loadVisualTimer?.cancel();\n',
            'dispose extra timers',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK dispose extra timers')

    helpers = r'''  void _finishLoadVisual(ChanLoadVisualState state) {
    if (!mounted) return;
    _loadVisualTimer?.cancel();
    setState(() => _loadVisualState = state);
    _loadVisualTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _loadVisualState = null);
    });
  }

  void _handleToolbarEnter() {
    _toolbarHovering = true;
    _toolbarCollapseTimer?.cancel();
    if (!_toolbarExpanded) setState(() => _toolbarExpanded = true);
  }

  void _handleToolbarExit() {
    _toolbarHovering = false;
    _toolbarCollapseTimer?.cancel();
    _toolbarCollapseTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_toolbarHovering) setState(() => _toolbarExpanded = false);
    });
  }

  static const Map<String, String> _knownStockNames = {
    '600340': '华夏幸福',
  };

  String get _stockDisplayName {
    if (_dataSource == 'csv') {
      return _localCsvName.isEmpty ? '本地CSV' : _localCsvName;
    }
    final symbol = _parseSymbol(_stockCodeController.text.trim());
    if (symbol == null) return _stockCodeController.text.trim().toUpperCase();
    final name = _knownStockNames[symbol.code];
    final marketCode = '${symbol.market}${symbol.code}';
    return name == null ? marketCode : '$name $marketCode';
  }

  bool _isChanOverlayVisible(TradingViewDrawingTool tool) {
    return switch (tool) {
      TradingViewDrawingTool.chanFx => _showFx,
      TradingViewDrawingTool.chanFxLine => _showFxLine,
      TradingViewDrawingTool.chanFxText => _showFxText,
      TradingViewDrawingTool.chanBi => _showBi,
      TradingViewDrawingTool.chanBiText => _showBiText,
      TradingViewDrawingTool.chanSeg => _showSeg,
      TradingViewDrawingTool.chanSegText => _showSegText,
      TradingViewDrawingTool.chanZs => _showZs,
      TradingViewDrawingTool.chanBiBsp => _showBiBsp,
      TradingViewDrawingTool.chanSegBsp => _showSegBsp,
      TradingViewDrawingTool.chanMergedBars => _showMergedBars,
      _ => false,
    };
  }

  void _toggleChanOverlayTool(TradingViewDrawingTool tool) {
    setState(() {
      switch (tool) {
        case TradingViewDrawingTool.chanFx:
          _showFx = !_showFx;
          break;
        case TradingViewDrawingTool.chanFxLine:
          _showFxLine = !_showFxLine;
          break;
        case TradingViewDrawingTool.chanFxText:
          _showFxText = !_showFxText;
          break;
        case TradingViewDrawingTool.chanBi:
          _showBi = !_showBi;
          break;
        case TradingViewDrawingTool.chanBiText:
          _showBiText = !_showBiText;
          break;
        case TradingViewDrawingTool.chanSeg:
          _showSeg = !_showSeg;
          break;
        case TradingViewDrawingTool.chanSegText:
          _showSegText = !_showSegText;
          break;
        case TradingViewDrawingTool.chanZs:
          _showZs = !_showZs;
          break;
        case TradingViewDrawingTool.chanBiBsp:
          _showBiBsp = !_showBiBsp;
          break;
        case TradingViewDrawingTool.chanSegBsp:
          _showSegBsp = !_showSegBsp;
          break;
        case TradingViewDrawingTool.chanMergedBars:
          _showMergedBars = !_showMergedBars;
          break;
        default:
          break;
      }
    });
  }

'''
    if 'void _finishLoadVisual(' not in src:
        src, did, note = replace_once(src, '  Future<void> _load() async {\n', helpers + '  Future<void> _load() async {\n', 'page helper methods')
        changed |= did
        notes.append(note)
    else:
        notes.append('OK page helper methods')
    src, did, note = replace_once(
        src,
        '    setState(() => _loading = true);\n',
        '    _loadVisualTimer?.cancel();\n    setState(() {\n      _loading = true;\n      _loadVisualState = ChanLoadVisualState.loading;\n    });\n',
        'loading visual start',
    )
    changed |= did
    notes.append(note)
    src, did, note = replace_once(
        src,
        "        final name = _dataSource == 'csv'\n            ? (_localCsvName.isEmpty ? '本地CSV' : _localCsvName)\n            : '${symbol!.market}${symbol.code}';\n",
        '        final name = _stockDisplayName;\n',
        'status symbol display name',
    )
    changed |= did
    notes.append(note)
    src, did, note = replace_once(
        src,
        "      _showMessage('√ $_status');\n    } catch (e) {\n      if (mounted) _showMessage('× Python chan.py 引擎失败：$e');\n    } finally {\n",
        "      _showMessage('√ $_status');\n      _finishLoadVisual(ChanLoadVisualState.success);\n    } catch (e) {\n      if (mounted) {\n        _finishLoadVisual(ChanLoadVisualState.failure);\n        _showMessage('× Python chan.py 引擎失败：$e');\n      }\n    } finally {\n",
        'loading visual success/failure',
    )
    changed |= did
    notes.append(note)

    left_toolbar = r'''  Widget _buildLeftToolbar() {
    return MouseRegion(
      onEnter: (_) => _handleToolbarEnter(),
      onExit: (_) => _handleToolbarExit(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        color: const Color(0xFF131722),
        child: Column(
          children: [
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _toolbarExpanded = !_toolbarExpanded),
              child: SizedBox(
                width: 36,
                height: 30,
                child: Center(
                  child: Text(
                    _toolbarExpanded ? '<-' : '->',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
            if (_toolbarExpanded)
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      const Divider(height: 12, color: Colors.white12),
                      _toolIcon('数据/标的/周期/日期', Icons.search,
                          _loading ? null : _openDataPanel),
                      _toolIcon('CChanConfig 设置', Icons.tune,
                          _loading ? null : _openConfigPanel),
                      _toolIcon('本地CSV上传', Icons.upload_file,
                          _loading ? null : _pickCsv),
                      _toolIcon(
                          '一次性显示',
                          Icons.fullscreen,
                          _hasBars
                              ? () => setState(() {
                                    _mode = 'once';
                                    _cursor = _fullSnapshot.rawBars.length;
                                    _snapshot = _fullSnapshot;
                                  })
                              : null,
                          selected: _mode == 'once'),
                      _toolIcon(
                          '严格逐K',
                          Icons.play_circle_outline,
                          _hasBars
                              ? () => setState(() {
                                    _mode = 'step';
                                    _cursor = 0;
                                    _snapshot = _frames.isNotEmpty
                                        ? _frames.first
                                        : _sliceSnapshot(_fullSnapshot, 0);
                                  })
                              : null,
                          selected: _mode == 'step'),
                      const Divider(height: 18, color: Colors.white12),
                      _toolIcon(
                          '左右放大',
                          Icons.zoom_in,
                          _hasBars
                              ? () => setState(() => _windowSize =
                                  (_windowSize - 15).clamp(24, 360).toInt())
                              : null),
                      _toolIcon(
                          '左右缩小',
                          Icons.zoom_out,
                          _hasBars
                              ? () => setState(() => _windowSize =
                                  (_windowSize + 15).clamp(24, 360).toInt())
                              : null),
                      _toolIcon(
                          '上下放大',
                          Icons.keyboard_arrow_up,
                          _hasBars
                              ? () => setState(() => _priceScale =
                                  (_priceScale * 1.18).clamp(0.35, 5.0).toDouble())
                              : null),
                      _toolIcon(
                          '上下缩小',
                          Icons.keyboard_arrow_down,
                          _hasBars
                              ? () => setState(() => _priceScale =
                                  (_priceScale / 1.18).clamp(0.35, 5.0).toDouble())
                              : null),
                      _toolIcon(
                          '重置缩放',
                          Icons.center_focus_strong,
                          _hasBars
                              ? () => setState(() {
                                    _windowSize = 90;
                                    _priceScale = 1.0;
                                    _viewEndIndex = null;
                                  })
                              : null),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
'''
    src, did, note = replace_method(src, '  Widget _buildLeftToolbar() {', left_toolbar, 'left toolbar auto reveal')
    changed |= did
    notes.append(note)

    chart_panel = r'''  Widget _buildChartPanel() {
    final visualState = _loadVisualState;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: const Color(0xFF0B0D10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Stack(
            children: [
              Positioned.fill(
                child: OriginKlineChart(
                  snapshot: _snapshot,
                  symbolLabel: _stockDisplayName,
                  showFx: _showFx && _hasFx,
                  showFxLine: _showFxLine && _hasFxLine,
                  showFxText: _showFxText && _hasFx,
                  showBi: _showBi && _hasBi,
                  showBiText: _showBiText && _hasBi,
                  showSeg: _showSeg && _hasSeg,
                  showSegText: _showSegText && _hasSeg,
                  showZs: _showZs && _hasZs,
                  showBiBsp: _showBiBsp && _hasBiBsp,
                  showSegBsp: _showSegBsp && _hasSegBsp,
                  showMergedBars: _showMergedBars && _hasMergedBars,
                  drawingStorageKey: _drawingStorageKey,
                  windowSize: _windowSize,
                  priceScale: _priceScale,
                  viewEndIndex: _viewEndIndex,
                  crosshairIndex: _crosshairIndex,
                  isChanOverlayVisible: _isChanOverlayVisible,
                  onChanOverlayToggled: _toggleChanOverlayTool,
                  onCrosshairChanged: (i) => setState(() => _crosshairIndex = i),
                  onPanBars: _panChartByBars,
                  onWindowSizeChanged: (v) => setState(() => _windowSize = v),
                  onPriceScaleChanged: (v) => setState(() => _priceScale = v),
                ),
              ),
              if (visualState != null)
                Positioned.fill(child: ChanLoadingOverlay(state: visualState)),
            ],
          ),
        ),
      ),
    );
  }
'''
    src, did, note = replace_method(src, '  Widget _buildChartPanel() {', chart_panel, 'chart panel loading overlay')
    changed |= did
    notes.append(note)

    return src, changed, notes


def write_if_changed(path: Path, content: str, changed: bool, apply: bool):
    if apply and changed:
        path.write_text(content, encoding='utf-8')


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--check', action='store_true')
    group.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    for path in (PAGE, CHART, TOOL, TOOLBOX):
        if not path.exists():
            print(f'FAIL missing {path}')
            return 1
    all_notes = []
    any_changed = False
    for path, patcher in ((TOOL, patch_tool), (CHART, patch_chart), (PAGE, patch_page)):
        source = path.read_text(encoding='utf-8')
        target, changed, notes = patcher(source)
        any_changed |= changed
        all_notes.extend(f'{path}: {note}' for note in notes)
        write_if_changed(path, target, changed, args.apply)
    current_toolbox = TOOLBOX.read_text(encoding='utf-8')
    toolbox_changed = current_toolbox != TOOLBOX_CONTENT
    any_changed |= toolbox_changed
    all_notes.append(f'{TOOLBOX}: {"APPLY" if toolbox_changed else "OK"} replace toolbox content')
    if args.apply and toolbox_changed:
        TOOLBOX.write_text(TOOLBOX_CONTENT, encoding='utf-8')
    for note in all_notes:
        print(note)
    print(('UPDATED' if any_changed else 'NOOP already applied') if args.apply else ('PASS can apply' if any_changed else 'PASS already applied'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
