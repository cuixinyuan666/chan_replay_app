#!/usr/bin/env python3
"""Apply UI interaction optimizations for OriginReplayPageV2.

This patch helper updates the large Flutter page/chart/toolbox files without
requiring manual editing.

Covers:
- Chan-themed loading / success / failure overlay.
- Default symbol 600340 and current-date end date.
- Symbol-name label routed through ChartLabelLayout.
- Left toolbar auto reveal / delayed collapse and aligned toggle button.
- Move drawing import/export controls into the TradingView toolbox.
- Move Chan overlay visibility toggles into the TradingView toolbox.
- Remove Chan overlay toggles from the left toolbar.
- Add smoother toolbox scrolling and more distinct toolbox icons.

Run:
  python tools/patch_ui_interaction_optimizations.py --check
  python tools/patch_ui_interaction_optimizations.py --apply

Then:
  flutter pub get
  flutter analyze
"""
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

PAGE = Path("lib/ui/pages/origin_replay_page_v2.dart")
CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
TOOLBOX = Path("lib/ui/drawing/tradingview_toolbox_host.dart")


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


def replace_all(source: str, old: str, new: str, label: str) -> tuple[str, bool, str]:
    if old not in source:
        return source, False, f"already applied: {label}"
    return source.replace(old, new), True, f"applied: {label}"


def replace_method(source: str, signature: str, new_method: str, label: str) -> tuple[str, bool, str]:
    if new_method in source:
        return source, False, f"already applied: {label}"
    start = source.find(signature)
    if start < 0:
        raise ValueError(f"method anchor not found: {label}")
    open_brace = source.find("{", start)
    if open_brace < 0:
        raise ValueError(f"method open brace not found: {label}")
    depth = 0
    end = -1
    for i in range(open_brace, len(source)):
        ch = source[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end < 0:
        raise ValueError(f"method close brace not found: {label}")
    return source[:start] + new_method + source[end:], True, f"applied: {label}"


def patch_page(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []

    replacements = [
        (
            "import '../widgets/origin_kline_chart.dart';\n",
            "import '../widgets/chan_loading_overlay.dart';\nimport '../widgets/origin_kline_chart.dart';\n",
            "loading overlay import",
        ),
        (
            "  static final DateTime _defaultEndDate = DateTime(2026, 6, 6);\n",
            "  static final DateTime _defaultEndDate = DateTime.now();\n",
            "current default end date",
        ),
        (
            "  final TextEditingController _stockCodeController =\n      TextEditingController(text: '000001');\n",
            "  final TextEditingController _stockCodeController =\n      TextEditingController(text: '600340');\n",
            "default symbol 600340",
        ),
        (
            "  Timer? _timer;\n",
            "  Timer? _timer;\n  Timer? _toolbarCollapseTimer;\n  Timer? _loadVisualTimer;\n  ChanLoadVisualState? _loadVisualState;\n  bool _toolbarHovering = false;\n",
            "UI timers and visual state",
        ),
        (
            "  @override\n  void dispose() {\n    _timer?.cancel();\n",
            "  @override\n  void initState() {\n    super.initState();\n    WidgetsBinding.instance.addPostFrameCallback((_) {\n      Future<void>.delayed(const Duration(milliseconds: 320), () {\n        if (mounted) _load();\n      });\n    });\n  }\n\n  @override\n  void dispose() {\n    _timer?.cancel();\n    _toolbarCollapseTimer?.cancel();\n    _loadVisualTimer?.cancel();\n",
            "auto initial load and timers dispose",
        ),
        (
            "    setState(() => _loading = true);\n",
            "    _loadVisualTimer?.cancel();\n    setState(() {\n      _loading = true;\n      _loadVisualState = ChanLoadVisualState.loading;\n    });\n",
            "loading visual start",
        ),
        (
            "      _showMessage('√ $_status');\n    } catch (e) {\n      if (mounted) _showMessage('× Python chan.py 引擎失败：$e');\n    } finally {\n",
            "      _showMessage('√ $_status');\n      _finishLoadVisual(ChanLoadVisualState.success);\n    } catch (e) {\n      if (mounted) {\n        _finishLoadVisual(ChanLoadVisualState.failure);\n        _showMessage('× Python chan.py 引擎失败：$e');\n      }\n    } finally {\n",
            "loading visual success/failure",
        ),
    ]
    for old, new, label in replacements:
        source, did, note = replace_once(source, old, new, label)
        changed |= did
        notes.append(note)

    helper_anchor = "  Future<void> _pickCsv() async {\n"
    helper_code = """  void _finishLoadVisual(ChanLoadVisualState state) {
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
      if (mounted && !_toolbarHovering) {
        setState(() => _toolbarExpanded = false);
      }
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
        case TradingViewDrawingTool.chanFxLine:
          _showFxLine = !_showFxLine;
        case TradingViewDrawingTool.chanBi:
          _showBi = !_showBi;
        case TradingViewDrawingTool.chanBiText:
          _showBiText = !_showBiText;
        case TradingViewDrawingTool.chanSeg:
          _showSeg = !_showSeg;
        case TradingViewDrawingTool.chanSegText:
          _showSegText = !_showSegText;
        case TradingViewDrawingTool.chanZs:
          _showZs = !_showZs;
        case TradingViewDrawingTool.chanBiBsp:
          _showBiBsp = !_showBiBsp;
        case TradingViewDrawingTool.chanSegBsp:
          _showSegBsp = !_showSegBsp;
        case TradingViewDrawingTool.chanMergedBars:
          _showMergedBars = !_showMergedBars;
        default:
          break;
      }
    });
  }

"""
    source, did, note = replace_once(source, helper_anchor, helper_code + helper_anchor, "page helper methods")
    changed |= did
    notes.append(note)

    source, did, note = replace_once(
        source,
        "        final name = _dataSource == 'csv'\n            ? (_localCsvName.isEmpty ? '本地CSV' : _localCsvName)\n            : '${symbol!.market}${symbol.code}';\n",
        "        final name = _stockDisplayName;\n",
        "status uses stock display name",
    )
    changed |= did
    notes.append(note)

    new_left_toolbar = """  Widget _buildLeftToolbar() {
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
"""
    source, did, note = replace_method(source, "  Widget _buildLeftToolbar() {", new_left_toolbar, "left toolbar auto collapse")
    changed |= did
    notes.append(note)

    new_chart_panel = """  Widget _buildChartPanel() {
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
"""
    source, did, note = replace_method(source, "  Widget _buildChartPanel() {", new_chart_panel, "chart panel loading overlay and symbol label")
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
            "chart public fields",
        ),
        (
            "    this.drawingStorageKey = '',\n",
            "    this.drawingStorageKey = '',\n    this.symbolLabel = '',\n    this.isChanOverlayVisible,\n    this.onChanOverlayToggled,\n",
            "chart constructor params",
        ),
        (
            "      onClearDrawings: _drawings.objects.isEmpty\n          ? null\n          : () {\n              _setDrawings(const DrawingObjectCollection());\n              _showDrawMessage('已清空手动画线');\n            },\n",
            "      onClearDrawings: _drawings.objects.isEmpty\n          ? null\n          : () {\n              _setDrawings(const DrawingObjectCollection());\n              _showDrawMessage('已清空手动画线');\n            },\n      onImportDrawings: _importDrawings,\n      onExportDrawings: _exportDrawings,\n      canExportDrawings: _drawings.objects.isNotEmpty,\n      isChanOverlayVisible: widget.isChanOverlayVisible,\n      onChanOverlayToggled: widget.onChanOverlayToggled,\n",
            "toolbox drawing import/export callbacks",
        ),
        (
            "          Positioned(\n              left: 52,\n              bottom: 8,\n              child: _DrawingPersistenceBar(\n                  drawingCount: _drawings.objects.length,\n                  onImport: _importDrawings,\n                  onExport:\n                      _drawings.objects.isEmpty ? null : _exportDrawings)),\n",
            "",
            "remove floating drawing import/export bar",
        ),
        (
            "                    snapshot: widget.snapshot,\n",
            "                    snapshot: widget.snapshot,\n                    symbolLabel: widget.symbolLabel,\n",
            "painter symbol label arg",
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
            "symbol name chart label",
        ),
    ]
    for old, new, label in replacements:
        source, did, note = replace_once(source, old, new, label)
        changed |= did
        notes.append(note)
    return PatchResult(source, changed, notes)


def patch_toolbox(source: str) -> PatchResult:
    changed = False
    notes: list[str] = []
    replacements = [
        (
            "  final VoidCallback? onClearDrawings;\n  final int drawingCount;\n",
            "  final VoidCallback? onClearDrawings;\n  final VoidCallback? onImportDrawings;\n  final VoidCallback? onExportDrawings;\n  final bool canExportDrawings;\n  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n  final int drawingCount;\n",
            "toolbox public fields",
        ),
        (
            "    this.onClearDrawings,\n    this.drawingCount = 0,\n",
            "    this.onClearDrawings,\n    this.onImportDrawings,\n    this.onExportDrawings,\n    this.canExportDrawings = false,\n    this.isChanOverlayVisible,\n    this.onChanOverlayToggled,\n    this.drawingCount = 0,\n",
            "toolbox constructor params",
        ),
        (
            "           left: 52,\n           top: 48,\n",
            "           left: 8,\n           top: 8,\n",
            "toolbox button moved left",
        ),
        (
            "             left: 52,\n             top: 92,\n",
            "             left: 8,\n             top: 52,\n",
            "toolbox panel moved left",
        ),
        (
            "               drawingCount: widget.drawingCount,\n               onClearDrawings: widget.onClearDrawings,\n",
            "               drawingCount: widget.drawingCount,\n               onClearDrawings: widget.onClearDrawings,\n               onImportDrawings: widget.onImportDrawings,\n               onExportDrawings: widget.onExportDrawings,\n               canExportDrawings: widget.canExportDrawings,\n               isChanOverlayVisible: widget.isChanOverlayVisible,\n               onChanOverlayToggled: widget.onChanOverlayToggled,\n",
            "toolbox panel callback args",
        ),
        (
            "  final VoidCallback? onClearDrawings;\n  final VoidCallback onClose;\n",
            "  final VoidCallback? onClearDrawings;\n  final VoidCallback? onImportDrawings;\n  final VoidCallback? onExportDrawings;\n  final bool canExportDrawings;\n  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n  final VoidCallback onClose;\n",
            "panel fields",
        ),
        (
            "    required this.onClearDrawings,\n    required this.onClose,\n",
            "    required this.onClearDrawings,\n    required this.onImportDrawings,\n    required this.onExportDrawings,\n    required this.canExportDrawings,\n    required this.isChanOverlayVisible,\n    required this.onChanOverlayToggled,\n    required this.onClose,\n",
            "panel constructor params",
        ),
        (
            "                  IconButton(\n                    tooltip: drawingCount > 0 ? '清空手动画线' : '暂无手动画线',\n",
            "                  IconButton(\n                    tooltip: '导入画线 JSON',\n                    onPressed: onImportDrawings,\n                    icon: const Icon(Icons.file_upload_outlined, size: 18),\n                    visualDensity: VisualDensity.compact,\n                    color: Colors.white70,\n                    disabledColor: Colors.white24,\n                  ),\n                  IconButton(\n                    tooltip: canExportDrawings ? '导出画线 JSON' : '暂无手动画线可导出',\n                    onPressed: canExportDrawings ? onExportDrawings : null,\n                    icon: const Icon(Icons.file_download_outlined, size: 18),\n                    visualDensity: VisualDensity.compact,\n                    color: Colors.white70,\n                    disabledColor: Colors.white24,\n                  ),\n                  IconButton(\n                    tooltip: drawingCount > 0 ? '清空手动画线' : '暂无手动画线',\n",
            "toolbox import/export buttons",
        ),
        (
            "               child: ListView(\n                 padding: const EdgeInsets.only(bottom: 10),\n",
            "               child: Scrollbar(\n                 thumbVisibility: true,\n                 child: ListView(\n                   physics: const ClampingScrollPhysics(),\n                   cacheExtent: 640,\n                   keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,\n                   padding: const EdgeInsets.only(bottom: 10),\n",
            "toolbox scroll wrapper open",
        ),
        (
            "                 ],\n               ),\n",
            "                   ],\n                 ),\n               ),\n",
            "toolbox scroll wrapper close",
        ),
        (
            "                       onSelected: onSelected,\n",
            "                       isChanOverlayVisible: isChanOverlayVisible,\n                       onChanOverlayToggled: onChanOverlayToggled,\n                       onSelected: onSelected,\n",
            "group tile overlay callbacks",
        ),
        (
            "  final ValueChanged<TradingViewDrawingTool> onSelected;\n",
            "  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n  final ValueChanged<TradingViewDrawingTool> onSelected;\n",
            "group tile fields",
        ),
        (
            "    required this.isToolAvailable,\n    required this.onSelected,\n",
            "    required this.isToolAvailable,\n    required this.isChanOverlayVisible,\n    required this.onChanOverlayToggled,\n    required this.onSelected,\n",
            "group tile constructor params",
        ),
        (
            "             disabledReason: _disabledReason(meta),\n             onSelected: onSelected,\n",
            "             disabledReason: _disabledReason(meta),\n             isChanOverlayVisible: isChanOverlayVisible,\n             onChanOverlayToggled: onChanOverlayToggled,\n             onSelected: onSelected,\n",
            "tool tile overlay callbacks",
        ),
        (
            "  final ValueChanged<TradingViewDrawingTool> onSelected;\n",
            "  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;\n  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n  final ValueChanged<TradingViewDrawingTool> onSelected;\n",
            "tool tile fields",
        ),
        (
            "    required this.disabledReason,\n    required this.onSelected,\n",
            "    required this.disabledReason,\n    required this.isChanOverlayVisible,\n    required this.onChanOverlayToggled,\n    required this.onSelected,\n",
            "tool tile constructor params",
        ),
    ]
    for old, new, label in replacements:
        source, did, note = replace_once(source, old, new, label)
        changed |= did
        notes.append(note)

    old_build = """  @override
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
"""
    new_build = """  @override
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
"""
    source, did, note = replace_once(source, old_build, new_build, "tool tile switch build")
    changed |= did
    notes.append(note)

    old_icon = """IconData _toolIcon(TradingViewDrawingTool tool) {
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
"""
    new_icon = """IconData _toolIcon(TradingViewDrawingTool tool) {
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
"""
    source, did, note = replace_once(source, old_icon, new_icon, "unique toolbox icons")
    changed |= did
    notes.append(note)

    return PatchResult(source, changed, notes)


def apply_file(path: Path, patcher) -> tuple[bool, list[str]]:
    source = path.read_text(encoding="utf-8")
    result = patcher(source)
    if result.changed:
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

    try:
        changes: list[bool] = []
        notes: list[str] = []
        for path, patcher in (
            (PAGE, patch_page),
            (CHART, patch_chart),
            (TOOLBOX, patch_toolbox),
        ):
            source = path.read_text(encoding="utf-8")
            result = patcher(source)
            changes.append(result.changed)
            notes.extend(f"{path}: {note}" for note in result.notes)
            if args.apply and result.changed:
                path.write_text(result.content, encoding="utf-8")
    except ValueError as exc:
        print(f"FAIL: {exc}")
        return 1

    for note in notes:
        print(note)
    if args.check:
        print("PASS: UI optimization patch anchors are valid" if any(changes) else "PASS: UI optimization patch already applied")
        return 0
    print("UPDATED" if any(changes) else "NOOP: patch already applied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
