import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tradingview_drawing_tool.dart';

const Duration _tooltipWait = Duration(seconds: 3);

const List<String> _defaultIndicatorKeys = [
  'MA',
  'BOLL',
  'VOL',
  'MACD',
  'amount',
  'turnover',
  'KDJ',
  'RSI',
  'DMI',
  'ATR',
  'WR',
  'CCI',
  'BIAS',
  'OBV',
  'PSY',
  'TRIX',
  'DPO',
  'MTM',
  'ROC',
  'EXPMA',
  'BBI',
  'DFMA',
  'CR',
  'KTN',
  'XSII',
  'VR',
  'EMV',
  'MASS',
  'MFI',
  'BRAR',
  'ASI',
  'ZHUOYAO',
  'BIAS_SIGNAL',
  'TAQ',
];

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
  final int easyTdxSubPanelCount;
  final Set<String> enabledEasyTdxIndicators;
  final ValueChanged<int>? onEasyTdxSubPanelCountChanged;
  final ValueChanged<String>? onEasyTdxIndicatorToggled;
  final List<String> indicatorKeys;

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
    this.easyTdxSubPanelCount = 2,
    this.enabledEasyTdxIndicators = const {'MA', 'BOLL', 'VOL', 'MACD'},
    this.onEasyTdxSubPanelCountChanged,
    this.onEasyTdxIndicatorToggled,
    this.indicatorKeys = _defaultIndicatorKeys,
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
              easyTdxSubPanelCount: widget.easyTdxSubPanelCount,
              enabledIndicators: widget.enabledEasyTdxIndicators,
              onSubPanelCountChanged: widget.onEasyTdxSubPanelCountChanged,
              onIndicatorToggled: widget.onEasyTdxIndicatorToggled,
              indicatorKeys: widget.indicatorKeys,
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
                color: active ? const Color(0xFF8AB4FF) : Colors.white12),
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
                Tooltip(
                  waitDuration: _tooltipWait,
                  message:
                      '${TradingViewDrawingToolRegistry.metaOf(tool).label}\n右键/长按移出快捷栏',
                  child: GestureDetector(
                    onTap: () => onSelected(tool),
                    onLongPress: () => onRemoveTool(tool),
                    onSecondaryTap: () => onRemoveTool(tool),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(bottom: 5),
                      decoration: BoxDecoration(
                        color: selectedTool == tool
                            ? const Color(0xFF2962FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_toolIcon(tool),
                          size: 17, color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
  final ValueChanged<TradingViewDrawingTool> onQuickToolAdded;
  final int easyTdxSubPanelCount;
  final Set<String> enabledIndicators;
  final ValueChanged<int>? onSubPanelCountChanged;
  final ValueChanged<String>? onIndicatorToggled;
  final List<String> indicatorKeys;

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
    required this.easyTdxSubPanelCount,
    required this.enabledIndicators,
    required this.onSubPanelCountChanged,
    required this.onIndicatorToggled,
    required this.indicatorKeys,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = TradingViewDrawingToolRegistry.byGroup();
    final groups = <TradingViewDrawingGroup>[
      TradingViewDrawingGroup.chanOverlay,
      ...grouped.keys.where((g) => g != TradingViewDrawingGroup.chanOverlay),
    ];
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
                  IconButton(
                    tooltip: '操作说明',
                    onPressed: () => _showGuide(context),
                    icon: const Icon(Icons.error_outline, size: 19),
                    visualDensity: VisualDensity.compact,
                    color: Colors.amberAccent,
                  ),
                  const SizedBox(width: 4),
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
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: RawScrollbar(
                thumbVisibility: true,
                interactive: true,
                thickness: 8,
                radius: const Radius.circular(8),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 10),
                  children: [
                    for (final group in groups)
                      _ToolGroupTile(
                        key: PageStorageKey('tv_tool_group_${group.name}'),
                        group: group,
                        tools: grouped[group] ??
                            const <TradingViewDrawingToolMeta>[],
                        selectedTool: selectedTool,
                        hasBars: hasBars,
                        hasChanSnapshot: hasChanSnapshot,
                        isToolAvailable: isToolAvailable,
                        isChanOverlayVisible: isChanOverlayVisible,
                        onChanOverlayToggled: onChanOverlayToggled,
                        onSelected: onSelected,
                        onQuickToolAdded: onQuickToolAdded,
                        indicatorKeys: indicatorKeys,
                        enabledIndicators: enabledIndicators,
                        onIndicatorToggled: onIndicatorToggled,
                        easyTdxSubPanelCount: easyTdxSubPanelCount,
                        onSubPanelCountChanged: onSubPanelCountChanged,
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

  void _showGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        title: const Text('TV 工具箱操作说明', style: TextStyle(color: Colors.white)),
        content: const Text(
          '1. 缠论叠加来自后端/Vespa。\n2. easy-tdx 指标来自展示层，不参与 chan.py 缠论结构计算。\n3. 指标开关使用页面统一状态，避免按钮亮但图不变。\n4. 副图数量可用 + / - 调整。',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了')),
        ],
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
  final List<String> indicatorKeys;
  final Set<String> enabledIndicators;
  final ValueChanged<String>? onIndicatorToggled;
  final int easyTdxSubPanelCount;
  final ValueChanged<int>? onSubPanelCountChanged;

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
    required this.indicatorKeys,
    required this.enabledIndicators,
    required this.onIndicatorToggled,
    required this.easyTdxSubPanelCount,
    required this.onSubPanelCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      maintainState: true,
      initiallyExpanded: group == TradingViewDrawingGroup.chanOverlay ||
          group == TradingViewDrawingGroup.lines,
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
            key: ValueKey('tool_${meta.tool.name}'),
            meta: meta,
            selected: selectedTool == meta.tool,
            disabledReason: _disabledReason(meta),
            isChanOverlayVisible: isChanOverlayVisible,
            onChanOverlayToggled: onChanOverlayToggled,
            onSelected: onSelected,
            onQuickToolAdded: onQuickToolAdded,
            indicatorKeys: indicatorKeys,
            enabledIndicators: enabledIndicators,
            onIndicatorToggled: onIndicatorToggled,
            easyTdxSubPanelCount: easyTdxSubPanelCount,
            onSubPanelCountChanged: onSubPanelCountChanged,
          ),
      ],
    );
  }

  String? _disabledReason(TradingViewDrawingToolMeta meta) {
    if (!hasBars) return '当前没有K线数据';
    if (meta.requiresChanSnapshot && !hasChanSnapshot) return '当前没有后端快照';
    final isAvailable = isToolAvailable?.call(meta.tool) ?? true;
    if (!isAvailable && meta.tool != TradingViewDrawingTool.easyTdxIndicators) {
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
  final ValueChanged<TradingViewDrawingTool> onQuickToolAdded;
  final List<String> indicatorKeys;
  final Set<String> enabledIndicators;
  final ValueChanged<String>? onIndicatorToggled;
  final int easyTdxSubPanelCount;
  final ValueChanged<int>? onSubPanelCountChanged;

  const _ToolTile({
    super.key,
    required this.meta,
    required this.selected,
    required this.disabledReason,
    required this.isChanOverlayVisible,
    required this.onChanOverlayToggled,
    required this.onSelected,
    required this.onQuickToolAdded,
    required this.indicatorKeys,
    required this.enabledIndicators,
    required this.onIndicatorToggled,
    required this.easyTdxSubPanelCount,
    required this.onSubPanelCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = disabledReason == null;
    final isEasyIndicator =
        meta.tool == TradingViewDrawingTool.easyTdxIndicators;
    final isChanSwitch = meta.group == TradingViewDrawingGroup.chanOverlay &&
        meta.maxPoints == 0 &&
        onChanOverlayToggled != null;
    final visible = isChanOverlayVisible?.call(meta.tool) ?? selected;
    final active = selected || (isChanSwitch && visible);

    final tile = Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: Tooltip(
        waitDuration: _tooltipWait,
        message: enabled
            ? '${meta.description}\n拖拽到左侧快捷栏可固定工具。'
            : '${meta.label}：$disabledReason',
        child: Column(
          children: [
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              enabled: enabled,
              selected: active,
              selectedTileColor: const Color(0x332962FF),
              leading: Icon(_toolIcon(meta.tool),
                  size: 18,
                  color: active ? const Color(0xFF8AB4FF) : Colors.white60),
              title: Text(meta.label,
                  style: TextStyle(
                      color: enabled ? Colors.white : Colors.white60,
                      fontSize: 13)),
              subtitle: Text(disabledReason ?? meta.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color:
                          Colors.white.withValues(alpha: enabled ? 0.50 : 0.36),
                      fontSize: 11)),
              trailing: isChanSwitch
                  ? Switch.adaptive(
                      value: visible,
                      onChanged: enabled
                          ? (_) => onChanOverlayToggled?.call(meta.tool)
                          : null,
                    )
                  : Text(_pointLabel(meta),
                      style:
                          const TextStyle(color: Colors.white30, fontSize: 10)),
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
            if (isEasyIndicator)
              _EasyIndicatorControls(
                enabled: enabled,
                keys: indicatorKeys,
                enabledIndicators: enabledIndicators,
                panelCount: easyTdxSubPanelCount,
                onIndicatorToggled: onIndicatorToggled,
                onPanelCountChanged: onSubPanelCountChanged,
              ),
          ],
        ),
      ),
    );

    return Draggable<TradingViewDrawingTool>(
      data: meta.tool,
      feedback: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: const Color(0xEE1E3A8A),
              borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_toolIcon(meta.tool), size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(meta.label, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _EasyIndicatorControls extends StatelessWidget {
  final bool enabled;
  final List<String> keys;
  final Set<String> enabledIndicators;
  final int panelCount;
  final ValueChanged<String>? onIndicatorToggled;
  final ValueChanged<int>? onPanelCountChanged;

  const _EasyIndicatorControls({
    required this.enabled,
    required this.keys,
    required this.enabledIndicators,
    required this.panelCount,
    required this.onIndicatorToggled,
    required this.onPanelCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('副图数量',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              IconButton(
                tooltip: '减少副图',
                onPressed: enabled && onPanelCountChanged != null
                    ? () => onPanelCountChanged!(
                        (panelCount - 1).clamp(0, 4).toInt())
                    : null,
                icon: const Icon(Icons.remove_circle_outline, size: 16),
                visualDensity: VisualDensity.compact,
                color: Colors.white70,
                disabledColor: Colors.white24,
              ),
              Text('$panelCount',
                  style:
                      const TextStyle(color: Color(0xFF8AB4FF), fontSize: 12)),
              IconButton(
                tooltip: '增加副图',
                onPressed: enabled && onPanelCountChanged != null
                    ? () => onPanelCountChanged!(
                        (panelCount + 1).clamp(0, 4).toInt())
                    : null,
                icon: const Icon(Icons.add_circle_outline, size: 16),
                visualDensity: VisualDensity.compact,
                color: Colors.white70,
                disabledColor: Colors.white24,
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in keys)
                FilterChip(
                  label: Text(key, style: const TextStyle(fontSize: 11)),
                  selected: enabledIndicators.contains(key),
                  onSelected: enabled && onIndicatorToggled != null
                      ? (_) => onIndicatorToggled!(key)
                      : null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _groupLabel(TradingViewDrawingGroup group) => switch (group) {
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

IconData _groupIcon(TradingViewDrawingGroup group) => switch (group) {
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

IconData _toolIcon(TradingViewDrawingTool tool) => switch (tool) {
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
      TradingViewDrawingTool.horizontalLine => Icons.horizontal_rule,
      TradingViewDrawingTool.horizontalRay => Icons.east,
      TradingViewDrawingTool.verticalLine => Icons.vertical_align_center,
      TradingViewDrawingTool.brush => Icons.brush,
      TradingViewDrawingTool.highlighter => Icons.highlight,
      TradingViewDrawingTool.arrow => Icons.arrow_forward,
      TradingViewDrawingTool.rectangle => Icons.rectangle_outlined,
      TradingViewDrawingTool.ellipse => Icons.circle_outlined,
      TradingViewDrawingTool.text => Icons.title,
      TradingViewDrawingTool.note => Icons.notes,
      TradingViewDrawingTool.priceLabel => Icons.label,
      TradingViewDrawingTool.flagMark => Icons.flag,
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
      TradingViewDrawingTool.easyTdxIndicators => Icons.query_stats,
      _ => Icons.architecture,
    };

String _pointLabel(TradingViewDrawingToolMeta meta) {
  if (meta.maxPoints == 0) return '开关';
  if (meta.maxPoints < 0) return '${meta.minPoints}+点';
  if (meta.minPoints == meta.maxPoints) return '${meta.minPoints}点';
  return '${meta.minPoints}-${meta.maxPoints}点';
}
