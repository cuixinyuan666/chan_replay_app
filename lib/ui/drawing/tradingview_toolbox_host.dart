import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tradingview_drawing_tool.dart';

const Duration _tooltipWait = Duration(seconds: 3);

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
  final ValueChanged<TradingViewDrawingTool>? onQuickToolAdded;
  final ValueListenable<int>? openSignal;
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
    this.onQuickToolAdded,
    this.openSignal,
    this.drawingCount = 0,
  });

  @override
  State<TradingViewToolboxHost> createState() => _TradingViewToolboxHostState();
}

class _TradingViewToolboxHostState extends State<TradingViewToolboxHost> {
  bool _open = false;
  TradingViewDrawingTool _localSelectedTool = TradingViewDrawingTool.cursor;
  final List<TradingViewDrawingTool> _quickTools = [];

  TradingViewDrawingTool get _effectiveSelectedTool =>
      widget.selectedTool ?? _localSelectedTool;

  @override
  void initState() {
    super.initState();
    widget.openSignal?.addListener(_handleOpenSignal);
  }

  @override
  void didUpdateWidget(covariant TradingViewToolboxHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openSignal != widget.openSignal) {
      oldWidget.openSignal?.removeListener(_handleOpenSignal);
      widget.openSignal?.addListener(_handleOpenSignal);
    }
  }

  @override
  void dispose() {
    widget.openSignal?.removeListener(_handleOpenSignal);
    super.dispose();
  }

  void _handleOpenSignal() {
    if (mounted) setState(() => _open = true);
  }

  void _selectTool(TradingViewDrawingTool tool) {
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
  }

  void _addQuickTool(TradingViewDrawingTool tool) {
    if (_quickTools.contains(tool)) return;
    setState(() => _quickTools.add(tool));
  }

  void _removeQuickTool(TradingViewDrawingTool tool) {
    setState(() => _quickTools.remove(tool));
  }

  void _handleQuickToolAdded(TradingViewDrawingTool tool) {
    final external = widget.onQuickToolAdded;
    if (external != null) {
      external(tool);
      return;
    }
    _addQuickTool(tool);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _effectiveSelectedTool;
    final hasExternalButton = widget.openSignal != null;
    final hasExternalQuickRail = widget.onQuickToolAdded != null;
    return Stack(
      children: [
        widget.child,
        if (!hasExternalQuickRail)
          Positioned(
            left: hasExternalButton ? 54 : 8,
            top: 8,
            bottom: 12,
            child: _QuickToolRail(
              tools: _quickTools,
              selectedTool: selected,
              onAcceptTool: _addQuickTool,
              onRemoveTool: _removeQuickTool,
              onSelected: _selectTool,
            ),
          ),
        if (!hasExternalButton)
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
            left: hasExternalButton ? 92 : 8,
            top: 52,
            bottom: 12,
            width: 372,
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
              onSelected: _selectTool,
              onQuickToolAdded: _handleQuickToolAdded,
            ),
          ),
      ],
    );
  }
}

class _QuickToolRail extends StatelessWidget {
  final List<TradingViewDrawingTool> tools;
  final TradingViewDrawingTool selectedTool;
  final ValueChanged<TradingViewDrawingTool> onAcceptTool;
  final ValueChanged<TradingViewDrawingTool> onRemoveTool;
  final ValueChanged<TradingViewDrawingTool> onSelected;

  const _QuickToolRail({
    required this.tools,
    required this.selectedTool,
    required this.onAcceptTool,
    required this.onRemoveTool,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<TradingViewDrawingTool>(
      onAcceptWithDetails: (details) => onAcceptTool(details.data),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xEE1E3A8A) : const Color(0xCC131722),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? const Color(0xFF8AB4FF) : Colors.white12,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                waitDuration: _tooltipWait,
                message: '拖拽 TV 工具到这里，形成左侧快捷工具栏',
                child: Icon(active ? Icons.add_circle : Icons.push_pin_outlined,
                    size: 18, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              for (final tool in tools)
                _QuickToolButton(
                  tool: tool,
                  selected: selectedTool == tool,
                  onSelected: onSelected,
                  onRemove: onRemoveTool,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickToolButton extends StatelessWidget {
  final TradingViewDrawingTool tool;
  final bool selected;
  final ValueChanged<TradingViewDrawingTool> onSelected;
  final ValueChanged<TradingViewDrawingTool> onRemove;

  const _QuickToolButton({
    required this.tool,
    required this.selected,
    required this.onSelected,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final meta = TradingViewDrawingToolRegistry.metaOf(tool);
    return Tooltip(
      waitDuration: _tooltipWait,
      message: '${meta.label}\n右键/长按移出快捷栏',
      child: GestureDetector(
        onTap: () => onSelected(tool),
        onLongPress: () => onRemove(tool),
        onSecondaryTap: () => onRemove(tool),
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2962FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_toolIcon(tool), size: 17, color: Colors.white70),
        ),
      ),
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
        waitDuration: _tooltipWait,
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

class _ToolboxPanel extends StatefulWidget {
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
  final ValueChanged<TradingViewDrawingTool> onQuickToolAdded;

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
    required this.onQuickToolAdded,
  });

  @override
  State<_ToolboxPanel> createState() => _ToolboxPanelState();
}

class _ToolboxPanelState extends State<_ToolboxPanel> {
  final ScrollController _scrollController = ScrollController();
  final List<TradingViewDrawingGroup> _groupOrder = [];
  final Map<TradingViewDrawingGroup, List<TradingViewDrawingToolMeta>> _toolOrder = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureOrder(Map<TradingViewDrawingGroup, List<TradingViewDrawingToolMeta>> grouped) {
    if (_groupOrder.isEmpty) {
      _groupOrder.add(TradingViewDrawingGroup.chanOverlay);
      _groupOrder.addAll(grouped.keys.where((g) => g != TradingViewDrawingGroup.chanOverlay));
    } else {
      for (final group in grouped.keys) {
        if (!_groupOrder.contains(group)) _groupOrder.add(group);
      }
      _groupOrder.removeWhere((group) => !grouped.containsKey(group));
    }
    for (final entry in grouped.entries) {
      final current = _toolOrder.putIfAbsent(entry.key, () => [...entry.value]);
      for (final meta in entry.value) {
        if (!current.any((item) => item.tool == meta.tool)) current.add(meta);
      }
      current.removeWhere((item) => !entry.value.any((meta) => meta.tool == item.tool));
    }
  }

  void _showGuide() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        title: const Text('TV 工具箱操作说明', style: TextStyle(color: Colors.white)),
        content: const Text(
          '1. 拖拽分类标题可调整分类顺序。\n'
          '2. 拖拽组内工具可调整该组工具顺序。\n'
          '3. 长按/拖拽工具到左侧快捷栏，可固定为快捷按钮。\n'
          '4. 缠论叠加只控制后端/Vespa 返回元素的显示，不在前端重算。\n'
          '5. 工具提示需鼠标停留 3 秒才显示，以减少滚动卡顿。',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = TradingViewDrawingToolRegistry.byGroup();
    _ensureOrder(grouped);
    return Material(
      elevation: 18,
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF2131722),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: const [
            BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x99000000)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '操作说明',
                    onPressed: _showGuide,
                    icon: const Icon(Icons.error_outline, size: 19),
                    visualDensity: VisualDensity.compact,
                    color: Colors.amberAccent,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'TradingView 画线工具箱',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: '导入画线 JSON',
                    onPressed: widget.onImportDrawings,
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                    disabledColor: Colors.white24,
                  ),
                  IconButton(
                    tooltip: widget.canExportDrawings ? '导出画线 JSON' : '暂无手动画线可导出',
                    onPressed: widget.canExportDrawings ? widget.onExportDrawings : null,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                    disabledColor: Colors.white24,
                  ),
                  IconButton(
                    tooltip: widget.drawingCount > 0 ? '清空手动画线' : '暂无手动画线',
                    onPressed: widget.drawingCount > 0 ? widget.onClearDrawings : null,
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                    disabledColor: Colors.white24,
                  ),
                  IconButton(
                    tooltip: '关闭工具箱',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: RawScrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                thickness: 8,
                radius: const Radius.circular(8),
                child: ReorderableListView.builder(
                  scrollController: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 640,
                  buildDefaultDragHandles: true,
                  padding: const EdgeInsets.only(bottom: 10),
                  itemCount: _groupOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _groupOrder.removeAt(oldIndex);
                      _groupOrder.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final group = _groupOrder[index];
                    final tools = _toolOrder[group] ?? const <TradingViewDrawingToolMeta>[];
                    return _ToolGroupTile(
                      key: ValueKey('group_${group.name}'),
                      group: group,
                      tools: tools,
                      selectedTool: widget.selectedTool,
                      hasBars: widget.hasBars,
                      hasChanSnapshot: widget.hasChanSnapshot,
                      isToolAvailable: widget.isToolAvailable,
                      isChanOverlayVisible: widget.isChanOverlayVisible,
                      onChanOverlayToggled: widget.onChanOverlayToggled,
                      onSelected: widget.onSelected,
                      onQuickToolAdded: widget.onQuickToolAdded,
                      onToolReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final list = _toolOrder[group];
                          if (list == null) return;
                          final item = list.removeAt(oldIndex);
                          list.insert(newIndex, item);
                        });
                      },
                    );
                  },
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
  final ValueChanged<TradingViewDrawingTool> onQuickToolAdded;
  final ReorderCallback onToolReorder;

  const _ToolGroupTile({
    super.key,
    required this.group,
    required this.tools,
    required this.selectedTool,
    required this.hasBars,
    required this.hasChanSnapshot,
    required this.isToolAvailable,
    required this.isChanOverlayVisible,
    required this.onChanOverlayToggled,
    required this.onSelected,
    required this.onQuickToolAdded,
    required this.onToolReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      waitDuration: _tooltipWait,
      message: '拖拽分类标题可改变分类顺序',
      child: ExpansionTile(
        key: PageStorageKey('tv_tool_group_${group.name}'),
        maintainState: true,
        initiallyExpanded: group == TradingViewDrawingGroup.chanOverlay ||
            group == TradingViewDrawingGroup.lines,
        leading: Icon(_groupIcon(group), color: Colors.white70, size: 18),
        title: Text(_groupLabel(group),
            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        collapsedIconColor: Colors.white54,
        iconColor: Colors.white70,
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            itemCount: tools.length,
            onReorder: onToolReorder,
            itemBuilder: (context, index) {
              final meta = tools[index];
              return _ToolTile(
                key: ValueKey('tool_${meta.tool.name}'),
                meta: meta,
                selected: selectedTool == meta.tool,
                disabledReason: _disabledReason(meta),
                isChanOverlayVisible: isChanOverlayVisible,
                onChanOverlayToggled: onChanOverlayToggled,
                onSelected: onSelected,
                onQuickToolAdded: onQuickToolAdded,
              );
            },
          ),
        ],
      ),
    );
  }

  String? _disabledReason(TradingViewDrawingToolMeta meta) {
    if (meta.requiresChanSnapshot && !hasChanSnapshot) return '需要先加载 Python chan.py/Vespa 快照结果';
    if (meta.minPoints > 0 && !hasBars) return '需要先加载K线后才能绑定时间/价格坐标';
    final isAvailable = isToolAvailable?.call(meta.tool) ?? true;
    if (!isAvailable) return '当前后端快照未返回${meta.label}数据';
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
  final ValueChanged<TradingViewDrawingTool> onQuickToolAdded;

  const _ToolTile({
    super.key,
    required this.meta,
    required this.selected,
    required this.disabledReason,
    required this.isChanOverlayVisible,
    required this.onChanOverlayToggled,
    required this.onSelected,
    required this.onQuickToolAdded,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = disabledReason == null;
    final subtitle = disabledReason ?? meta.description;
    final isChanSwitch = meta.group == TradingViewDrawingGroup.chanOverlay &&
        meta.maxPoints == 0 &&
        onChanOverlayToggled != null;
    final visible = isChanOverlayVisible?.call(meta.tool) ?? selected;
    final tile = Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: Tooltip(
        waitDuration: _tooltipWait,
        message: enabled
            ? '${meta.description}\n拖拽到左侧快捷栏可固定工具；拖拽列表项可改变顺序。'
            : '${meta.label}：$disabledReason',
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
              style: TextStyle(color: enabled ? Colors.white : Colors.white60, fontSize: 13)),
          subtitle: Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: enabled ? 0.50 : 0.36), fontSize: 11)),
          trailing: isChanSwitch
              ? Switch.adaptive(
                  value: visible,
                  onChanged: enabled ? (_) => onChanOverlayToggled?.call(meta.tool) : null,
                )
              : Text(_pointLabel(meta), style: const TextStyle(color: Colors.white30, fontSize: 10)),
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
    return LongPressDraggable<TradingViewDrawingTool>(
      data: meta.tool,
      delay: const Duration(milliseconds: 220),
      feedback: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEE1E3A8A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_toolIcon(meta.tool), size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(meta.label, style: const TextStyle(color: Colors.white)),
            ]),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      onDragCompleted: () => onQuickToolAdded(meta.tool),
      child: tile,
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
    TradingViewDrawingTool.abcdPattern => Icons.abc,
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
