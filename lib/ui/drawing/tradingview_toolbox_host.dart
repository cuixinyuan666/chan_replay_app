import 'package:flutter/material.dart';

import 'tradingview_drawing_tool.dart';

class TradingViewToolboxHost extends StatefulWidget {
  final Widget child;
  final bool hasBars;
  final bool hasChanSnapshot;
  final TradingViewDrawingTool? selectedTool;
  final ValueChanged<TradingViewDrawingTool>? onSelected;
  final VoidCallback? onClearDrawings;
  final int drawingCount;

  const TradingViewToolboxHost({
    super.key,
    required this.child,
    this.hasBars = false,
    this.hasChanSnapshot = false,
    this.selectedTool,
    this.onSelected,
    this.onClearDrawings,
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
          left: 52,
          top: 48,
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
            left: 52,
            top: 92,
            bottom: 12,
            width: 336,
            child: _ToolboxPanel(
              selectedTool: selected,
              hasBars: widget.hasBars,
              hasChanSnapshot: widget.hasChanSnapshot,
              drawingCount: widget.drawingCount,
              onClearDrawings: widget.onClearDrawings,
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
  final int drawingCount;
  final VoidCallback? onClearDrawings;
  final VoidCallback onClose;
  final ValueChanged<TradingViewDrawingTool> onSelected;

  const _ToolboxPanel({
    required this.selectedTool,
    required this.hasBars,
    required this.hasChanSnapshot,
    required this.drawingCount,
    required this.onClearDrawings,
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
                '选择工具后在K线图上点击创建锚点。缠论叠加只显示 Vespa/chan.py 或后端结果，不在前端重算。',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.35),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  for (final entry in grouped.entries)
                    _ToolGroupTile(
                      group: entry.key,
                      tools: entry.value,
                      selectedTool: selectedTool,
                      hasBars: hasBars,
                      hasChanSnapshot: hasChanSnapshot,
                      onSelected: onSelected,
                    ),
                ],
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
  final ValueChanged<TradingViewDrawingTool> onSelected;

  const _ToolGroupTile({
    required this.group,
    required this.tools,
    required this.selectedTool,
    required this.hasBars,
    required this.hasChanSnapshot,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
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
    return null;
  }
}

class _ToolTile extends StatelessWidget {
  final TradingViewDrawingToolMeta meta;
  final bool selected;
  final String? disabledReason;
  final ValueChanged<TradingViewDrawingTool> onSelected;

  const _ToolTile({
    required this.meta,
    required this.selected,
    required this.disabledReason,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = disabledReason == null;
    final subtitle = disabledReason ?? meta.description;
    return Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: Tooltip(
        message: enabled ? meta.description : '${meta.label}：$disabledReason',
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          enabled: enabled,
          selected: selected,
          selectedTileColor: const Color(0x332962FF),
          leading: Icon(_toolIcon(meta.tool),
              size: 18,
              color: selected ? const Color(0xFF8AB4FF) : Colors.white60),
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
          trailing: Text(_pointLabel(meta),
              style: const TextStyle(color: Colors.white30, fontSize: 10)),
          onTap: enabled ? () => onSelected(meta.tool) : null,
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
    TradingViewDrawingTool.horizontalLine ||
    TradingViewDrawingTool.horizontalRay =>
      Icons.horizontal_rule,
    TradingViewDrawingTool.verticalLine => Icons.vertical_align_center,
    TradingViewDrawingTool.rectangle ||
    TradingViewDrawingTool.rotatedRectangle =>
      Icons.crop_square,
    TradingViewDrawingTool.text ||
    TradingViewDrawingTool.anchoredText =>
      Icons.title,
    TradingViewDrawingTool.longPosition => Icons.trending_up,
    TradingViewDrawingTool.shortPosition => Icons.trending_down,
    TradingViewDrawingTool.chanFx ||
    TradingViewDrawingTool.chanFxLine =>
      Icons.trip_origin,
    TradingViewDrawingTool.chanBi ||
    TradingViewDrawingTool.chanBiText =>
      Icons.show_chart,
    TradingViewDrawingTool.chanSeg ||
    TradingViewDrawingTool.chanSegText =>
      Icons.multiline_chart,
    TradingViewDrawingTool.chanZs => Icons.crop_square,
    TradingViewDrawingTool.chanBiBsp ||
    TradingViewDrawingTool.chanSegBsp =>
      Icons.sell,
    TradingViewDrawingTool.chanMergedBars => Icons.view_week,
    _ => Icons.architecture,
  };
}

String _pointLabel(TradingViewDrawingToolMeta meta) {
  if (meta.maxPoints == 0) return '开关';
  if (meta.maxPoints < 0) return '${meta.minPoints}+点';
  if (meta.minPoints == meta.maxPoints) return '${meta.minPoints}点';
  return '${meta.minPoints}-${meta.maxPoints}点';
}
