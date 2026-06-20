import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/settings/level_promoter_settings.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import '../drawing/tradingview_toolbox_host.dart';
import 'origin_kline_chart_unlimited_interaction.dart' as base;

/// Display-only adapter for hichan2 recursive segment layers.
///
/// This widget does not calculate Chan structures. It converts backend-exported
/// `snapshot.recursiveSegLayers` / `snapshot.recursiveSegBsps` rows into
/// non-persistent drawing overlays and delegates actual K-line rendering to the
/// original `OriginKlineChart` via the real viewport interaction adapter.
class RecursiveSegOriginKlineChart extends StatefulWidget {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showFxLine;
  final bool showFxText;
  final bool showBi;
  final bool showBiText;
  final bool showSeg;
  final bool showSegText;
  final bool showZs;
  final bool showBiBsp;
  final bool showSegBsp;
  final bool showMergedBars;
  final bool showEasyTdxIndicators;
  final int easyTdxSubPanelCount;
  final Set<String> enabledEasyTdxIndicators;
  final List<DrawingObject> drawingObjects;
  final String drawingStorageKey;
  final String symbolLabel;
  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;
  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;
  final ValueListenable<int>? toolboxOpenSignal;
  final ValueListenable<TradingViewDrawingTool?>? toolboxSelectedToolSignal;
  final ValueChanged<TradingViewDrawingTool>? onToolboxQuickToolAdded;
  final int windowSize;
  final double priceScale;
  final double priceOffset;
  final int? viewEndIndex;
  final int? crosshairIndex;
  final ValueChanged<int>? onCrosshairChanged;
  final ValueChanged<int>? onPanBars;
  final ValueChanged<int>? onWindowSizeChanged;
  final ValueChanged<double>? onPriceScaleChanged;
  final ValueChanged<double>? onPriceOffsetChanged;
  final ValueChanged<int>? onEasyTdxSubPanelCountChanged;
  final ValueChanged<String>? onEasyTdxIndicatorToggled;
  final bool showRecursiveSegLayers;
  final bool showRecursiveSegBsp;
  final int minRecursiveSegLayer;
  final int? maxRecursiveSegLayer;

  const RecursiveSegOriginKlineChart({
    super.key,
    required this.snapshot,
    required this.showFx,
    this.showFxLine = true,
    this.showFxText = true,
    required this.showBi,
    this.showBiText = false,
    required this.showSeg,
    this.showSegText = true,
    required this.showZs,
    required this.showBiBsp,
    required this.showSegBsp,
    this.showMergedBars = false,
    this.showEasyTdxIndicators = false,
    this.easyTdxSubPanelCount = 2,
    this.enabledEasyTdxIndicators = const {'MA', 'BOLL', 'VOL', 'MACD'},
    this.drawingObjects = const [],
    this.drawingStorageKey = '',
    this.symbolLabel = '',
    this.isChanOverlayVisible,
    this.onChanOverlayToggled,
    this.toolboxOpenSignal,
    this.toolboxSelectedToolSignal,
    this.onToolboxQuickToolAdded,
    required this.windowSize,
    this.priceScale = 1.0,
    this.priceOffset = 0.0,
    this.viewEndIndex,
    this.crosshairIndex,
    this.onCrosshairChanged,
    this.onPanBars,
    this.onWindowSizeChanged,
    this.onPriceScaleChanged,
    this.onPriceOffsetChanged,
    this.onEasyTdxSubPanelCountChanged,
    this.onEasyTdxIndicatorToggled,
    this.showRecursiveSegLayers = true,
    this.showRecursiveSegBsp = true,
    this.minRecursiveSegLayer = 2,
    this.maxRecursiveSegLayer,
  });

  @override
  State<RecursiveSegOriginKlineChart> createState() =>
      _RecursiveSegOriginKlineChartState();

  int get _effectiveMaxRecursiveSegLayer {
    final explicit = maxRecursiveSegLayer;
    if (explicit != null && explicit >= 2) return explicit;
    return LevelPromoterSettings.currentMaxLayer;
  }

  List<DrawingObject> _recursiveSegDrawingObjects(ChanSnapshot snapshot) {
    final rows = <DrawingObject>[];
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final minLayer = minRecursiveSegLayer < 1 ? 1 : minRecursiveSegLayer;
    final maxLayer = _effectiveMaxRecursiveSegLayer < minLayer
        ? minLayer
        : _effectiveMaxRecursiveSegLayer;
    for (final entry in snapshot.recursiveSegLayers.entries) {
      final layer = entry.key;
      if (layer < minLayer || layer > maxLayer) continue;
      if (layer == 1) continue; // avoid duplicating the native SEG renderer
      for (final seg in entry.value) {
        if (!seg.isVisibleRangeValid) continue;
        rows.add(DrawingObject(
          id: 'hichan2_recursive_seg_L${layer}_${seg.index}_${seg.startRawIndex}_${seg.endRawIndex}',
          tool: TradingViewDrawingTool.trendLine,
          anchors: [
            DrawingAnchor.chart(
                rawIndex: seg.startRawIndex, price: seg.startPrice),
            DrawingAnchor.chart(rawIndex: seg.endRawIndex, price: seg.endPrice),
          ],
          style: _styleForLayer(layer: layer, isSure: seg.isSure),
          text: 'L$layer#${seg.index + 1}${seg.isSure ? '' : '?'}',
          locked: true,
          hidden: false,
          selected: false,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    return rows;
  }

  List<DrawingObject> _recursiveSegBspDrawingObjects(ChanSnapshot snapshot) {
    final rows = <DrawingObject>[];
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final minLayer = minRecursiveSegLayer < 1 ? 1 : minRecursiveSegLayer;
    final maxLayer = _effectiveMaxRecursiveSegLayer < minLayer
        ? minLayer
        : _effectiveMaxRecursiveSegLayer;

    if (snapshot.recursiveSegBsps.isNotEmpty) {
      for (final entry in snapshot.recursiveSegBsps.entries) {
        final layer = entry.key;
        if (layer < minLayer || layer > maxLayer) continue;
        for (final bsp in entry.value) {
          rows.add(DrawingObject(
            id: 'hichan2_seg${layer}_bsp_${bsp.index}_${bsp.rawIndex}',
            tool: TradingViewDrawingTool.priceLabel,
            anchors: [
              DrawingAnchor.chart(rawIndex: bsp.rawIndex, price: bsp.price)
            ],
            style: DrawingStyle(
              colorValue: _colorValueForLayer(layer),
              fontSize: 11.0,
              filled: true,
              fillColorValue: 0x33131722,
              fillOpacity: 0.25,
            ),
            text: bsp.type,
            locked: true,
            hidden: false,
            selected: false,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
      return rows;
    }

    // Backward compatible display fallback: older parsers may not expose
    // recursiveSegBsps yet, so the chart can still show segN endpoint labels
    // from already parsed recursiveSegLayers without changing chan.py data.
    for (final entry in snapshot.recursiveSegLayers.entries) {
      final layer = entry.key;
      if (layer < minLayer || layer > maxLayer || layer < 2) continue;
      for (final seg in entry.value) {
        if (!seg.isVisibleRangeValid) continue;
        final type = seg.isDown
            ? 'SEG${layer}_B'
            : seg.isUp
                ? 'SEG${layer}_S'
                : 'SEG${layer}_BSP';
        rows.add(DrawingObject(
          id: 'hichan2_seg${layer}_bsp_fallback_${seg.index}_${seg.endRawIndex}',
          tool: TradingViewDrawingTool.priceLabel,
          anchors: [
            DrawingAnchor.chart(rawIndex: seg.endRawIndex, price: seg.endPrice)
          ],
          style: DrawingStyle(
            colorValue: _colorValueForLayer(layer),
            fontSize: 11.0,
            filled: true,
            fillColorValue: 0x33131722,
            fillOpacity: 0.25,
          ),
          text: type,
          locked: true,
          hidden: false,
          selected: false,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }
    return rows;
  }

  DrawingStyle _styleForLayer({required int layer, required bool isSure}) {
    final strokeWidth = switch (layer) {
      2 => 2.2,
      3 => 2.8,
      4 => 3.4,
      _ => 2.0 +
          (layer < 1
                      ? 1
                      : layer > 24
                          ? 24
                          : layer)
                  .toDouble() *
              0.22,
    };
    final opacity = isSure ? 0.92 : 0.46;
    return DrawingStyle(
      colorValue: _colorValueForLayer(layer),
      strokeWidth: strokeWidth,
      opacity: opacity,
      dashed: !isSure,
    );
  }

  int _colorValueForLayer(int layer) {
    return switch (layer) {
      2 => 0xFF00E5FF,
      3 => 0xFFFFD54F,
      4 => 0xFFCE93D8,
      5 => 0xFFA5D6A7,
      6 => 0xFFFFAB91,
      _ => 0xFFFFFFFF,
    };
  }

  String _symbolLabelWithRecursiveSegSummary(
      String baseLabel, ChanSnapshot snapshot) {
    final layerCounts = <String>[];
    final minLayer = minRecursiveSegLayer < 1 ? 1 : minRecursiveSegLayer;
    final maxLayer = _effectiveMaxRecursiveSegLayer < minLayer
        ? minLayer
        : _effectiveMaxRecursiveSegLayer;
    for (var layer = minLayer; layer <= maxLayer; layer++) {
      final segCount = snapshot.recursiveSegLayers[layer]?.length ?? 0;
      final bspCount = snapshot.recursiveSegBsps[layer]?.length ?? segCount;
      if (segCount > 0 || bspCount > 0) {
        layerCounts.add('L$layer:$segCount/B$bspCount');
      }
    }
    if (layerCounts.isEmpty) return baseLabel;
    final prefix = baseLabel.trim();
    final suffix = '级别推进 ${layerCounts.join(' ')}';
    return prefix.isEmpty ? suffix : '$prefix | $suffix';
  }
}

class _RecursiveSegOriginKlineChartState
    extends State<RecursiveSegOriginKlineChart> {
  String _viewportScopeKey = '';
  final Set<TradingViewDrawingTool> _hiddenChanOverlays = {};
  final Set<String> _hiddenRecursiveOverlays = {};
  int? _stickyViewEndIndex;
  int? _stickyWindowSize;
  double? _stickyPriceScale;
  bool _parentViewportSyncPending = false;

  @override
  void initState() {
    super.initState();
    _resetStickyViewportForScope();
  }

  @override
  void didUpdateWidget(covariant RecursiveSegOriginKlineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextScope = _scopeKeyFor(widget);
    if (nextScope != _viewportScopeKey) {
      _resetStickyViewportForScope();
      _scheduleParentViewportSync();
      return;
    }
    if (widget.viewEndIndex != null) {
      _stickyViewEndIndex = _clampViewEnd(widget.viewEndIndex);
    }
    if (_isExplicitPriceScale(widget.priceScale)) {
      _stickyPriceScale = _safePriceScale(widget.priceScale);
    }
    _scheduleParentViewportSync();
  }

  String _scopeKeyFor(RecursiveSegOriginKlineChart widget) {
    final bars = widget.snapshot.rawBars;
    final first = bars.isEmpty ? 'empty' : bars.first.time.toIso8601String();
    return '${widget.drawingStorageKey}|${widget.symbolLabel}|$first';
  }

  void _resetStickyViewportForScope() {
    _viewportScopeKey = _scopeKeyFor(widget);
    _stickyViewEndIndex = _clampViewEnd(widget.viewEndIndex);
    _stickyWindowSize = null;
    _stickyPriceScale = _isExplicitPriceScale(widget.priceScale)
        ? _safePriceScale(widget.priceScale)
        : null;
  }

  int? _clampViewEnd(int? value) {
    final bars = widget.snapshot.rawBars;
    if (value == null || bars.isEmpty) return null;
    return value.clamp(0, bars.length - 1).toInt();
  }

  int _safeWindowSize(int value) => value < 1 ? 1 : value;

  bool _isExplicitPriceScale(double value) =>
      value.isFinite && (value - 1.0).abs() > 0.000001;

  double _safePriceScale(double value) {
    if (!value.isFinite || value <= 0) return 1.0;
    return value;
  }

  int? get _effectiveViewEndIndex =>
      _clampViewEnd(widget.viewEndIndex) ?? _clampViewEnd(_stickyViewEndIndex);

  int get _effectiveWindowSize => _stickyWindowSize == null
      ? _safeWindowSize(widget.windowSize)
      : _safeWindowSize(_stickyWindowSize!);

  double get _effectivePriceScale {
    if (_isExplicitPriceScale(widget.priceScale)) {
      return _safePriceScale(widget.priceScale);
    }
    return _stickyPriceScale ?? _safePriceScale(widget.priceScale);
  }

  void _scheduleParentViewportSync() {
    if (_parentViewportSyncPending) return;
    final hasStickyViewEnd = widget.viewEndIndex == null &&
        _stickyViewEndIndex != null &&
        widget.snapshot.rawBars.isNotEmpty;
    final hasStickyWindowSize = _stickyWindowSize != null &&
        _safeWindowSize(widget.windowSize) !=
            _safeWindowSize(_stickyWindowSize!);
    final hasStickyPriceScale = !_isExplicitPriceScale(widget.priceScale) &&
        _stickyPriceScale != null &&
        _isExplicitPriceScale(_stickyPriceScale!);
    if (!hasStickyViewEnd && !hasStickyWindowSize && !hasStickyPriceScale)
      return;

    _parentViewportSyncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _parentViewportSyncPending = false;
      if (!mounted) return;

      final bars = widget.snapshot.rawBars;
      if (widget.viewEndIndex == null &&
          _stickyViewEndIndex != null &&
          bars.isNotEmpty) {
        final max = bars.length - 1;
        final target = _clampViewEnd(_stickyViewEndIndex);
        if (target != null) {
          final delta = target - max;
          if (delta != 0) widget.onPanBars?.call(delta);
        }
      }

      if (_stickyWindowSize != null &&
          _safeWindowSize(widget.windowSize) !=
              _safeWindowSize(_stickyWindowSize!)) {
        widget.onWindowSizeChanged?.call(_safeWindowSize(_stickyWindowSize!));
      }

      if (!_isExplicitPriceScale(widget.priceScale) &&
          _stickyPriceScale != null &&
          _isExplicitPriceScale(_stickyPriceScale!)) {
        widget.onPriceScaleChanged?.call(_safePriceScale(_stickyPriceScale!));
      }
    });
  }

  void _handlePanBars(int bars) {
    final rawBars = widget.snapshot.rawBars;
    if (bars == 0 || rawBars.isEmpty) return;
    final max = rawBars.length - 1;
    final current = (_effectiveViewEndIndex ?? max).clamp(0, max).toInt();
    final next = (current + bars).clamp(0, max).toInt();
    if (next != current) {
      setState(() => _stickyViewEndIndex = next);
    }
    widget.onPanBars?.call(bars);
  }

  void _handleWindowSizeChanged(int value) {
    final safe = _safeWindowSize(value);
    setState(() => _stickyWindowSize = safe);
    widget.onWindowSizeChanged?.call(safe);
  }

  void _handlePriceScaleChanged(double value) {
    final safe = _safePriceScale(value);
    setState(() => _stickyPriceScale = safe);
    widget.onPriceScaleChanged?.call(safe);
  }

  @override
  Widget build(BuildContext context) {
    final recursiveEntries = _recursiveOverlayEntries();
    return base.OriginKlineChart(
      snapshot: widget.snapshot,
      showFx: _standardOverlayVisible(TradingViewDrawingTool.chanFx),
      showFxLine: _standardOverlayVisible(TradingViewDrawingTool.chanFxLine),
      showFxText: _standardOverlayVisible(TradingViewDrawingTool.chanFxText),
      showBi: _standardOverlayVisible(TradingViewDrawingTool.chanBi),
      showBiText: _standardOverlayVisible(TradingViewDrawingTool.chanBiText),
      showSeg: _standardOverlayVisible(TradingViewDrawingTool.chanSeg),
      showSegText: _standardOverlayVisible(TradingViewDrawingTool.chanSegText),
      showZs: _standardOverlayVisible(TradingViewDrawingTool.chanZs),
      showBiBsp: _standardOverlayVisible(TradingViewDrawingTool.chanBiBsp),
      showSegBsp: _standardOverlayVisible(TradingViewDrawingTool.chanSegBsp),
      showMergedBars:
          _standardOverlayVisible(TradingViewDrawingTool.chanMergedBars),
      showEasyTdxIndicators: widget.showEasyTdxIndicators,
      easyTdxSubPanelCount: widget.easyTdxSubPanelCount,
      enabledEasyTdxIndicators: widget.enabledEasyTdxIndicators,
      drawingObjects: [
        if (widget.showRecursiveSegLayers)
          ...widget._recursiveSegDrawingObjects(widget.snapshot).where(
              (object) => !_isRecursiveObjectHidden(object.id, bsp: false)),
        if (widget.showRecursiveSegBsp)
          ...widget._recursiveSegBspDrawingObjects(widget.snapshot).where(
              (object) => !_isRecursiveObjectHidden(object.id, bsp: true)),
        ...widget.drawingObjects,
      ],
      drawingStorageKey: widget.drawingStorageKey,
      symbolLabel: widget._symbolLabelWithRecursiveSegSummary(
        widget.symbolLabel,
        widget.snapshot,
      ),
      isChanOverlayVisible: _standardOverlayVisible,
      onChanOverlayToggled: _toggleStandardOverlay,
      additionalChanOverlays: recursiveEntries,
      toolboxOpenSignal: widget.toolboxOpenSignal,
      toolboxSelectedToolSignal: widget.toolboxSelectedToolSignal,
      onToolboxQuickToolAdded: widget.onToolboxQuickToolAdded,
      windowSize: _effectiveWindowSize,
      priceScale: _effectivePriceScale,
      priceOffset: widget.priceOffset,
      viewEndIndex: _effectiveViewEndIndex,
      crosshairIndex: widget.crosshairIndex,
      onCrosshairChanged: widget.onCrosshairChanged,
      onPanBars: _handlePanBars,
      onWindowSizeChanged: _handleWindowSizeChanged,
      onPriceScaleChanged: _handlePriceScaleChanged,
      onPriceOffsetChanged: widget.onPriceOffsetChanged,
      onEasyTdxSubPanelCountChanged: widget.onEasyTdxSubPanelCountChanged,
      onEasyTdxIndicatorToggled: widget.onEasyTdxIndicatorToggled,
    );
  }

  bool _standardOverlayVisible(TradingViewDrawingTool tool) {
    final external = widget.isChanOverlayVisible;
    if (external != null) return external(tool);
    if (_hiddenChanOverlays.contains(tool)) return false;
    return switch (tool) {
      TradingViewDrawingTool.chanFx => widget.showFx,
      TradingViewDrawingTool.chanFxLine => widget.showFxLine,
      TradingViewDrawingTool.chanFxText => widget.showFxText,
      TradingViewDrawingTool.chanBi => widget.showBi,
      TradingViewDrawingTool.chanBiText => widget.showBiText,
      TradingViewDrawingTool.chanSeg => widget.showSeg,
      TradingViewDrawingTool.chanSegText => widget.showSegText,
      TradingViewDrawingTool.chanZs => widget.showZs,
      TradingViewDrawingTool.chanBiBsp => widget.showBiBsp,
      TradingViewDrawingTool.chanSegBsp => widget.showSegBsp,
      TradingViewDrawingTool.chanMergedBars => widget.showMergedBars,
      TradingViewDrawingTool.easyTdxIndicators => widget.showEasyTdxIndicators,
      _ => true,
    };
  }

  void _toggleStandardOverlay(TradingViewDrawingTool tool) {
    if (widget.onChanOverlayToggled != null) {
      widget.onChanOverlayToggled!(tool);
      return;
    }
    setState(() {
      if (_standardOverlayVisible(tool)) {
        _hiddenChanOverlays.add(tool);
      } else {
        _hiddenChanOverlays.remove(tool);
      }
    });
  }

  List<ChanOverlayToggleEntry> _recursiveOverlayEntries() {
    final maxLayer = widget._effectiveMaxRecursiveSegLayer;
    final entries = <ChanOverlayToggleEntry>[];
    final minLayer =
        widget.minRecursiveSegLayer < 2 ? 2 : widget.minRecursiveSegLayer;
    for (var layer = minLayer; layer <= maxLayer; layer++) {
      final segId = 'seg_$layer';
      final bspId = 'seg_${layer}_bsp';
      final hasSeg =
          widget.snapshot.recursiveSegLayers[layer]?.isNotEmpty ?? false;
      final hasBsp =
          widget.snapshot.recursiveSegBsps[layer]?.isNotEmpty ?? hasSeg;
      entries.add(ChanOverlayToggleEntry(
        id: segId,
        label: '${layer}段',
        description: '显示级别推进器第$layer段线段',
        available: hasSeg,
        visible: widget.showRecursiveSegLayers &&
            hasSeg &&
            !_hiddenRecursiveOverlays.contains(segId),
        onToggle: () => _toggleRecursiveOverlay(segId),
      ));
      entries.add(ChanOverlayToggleEntry(
        id: bspId,
        label: '${layer}段买卖点',
        description: '显示后端返回的 seg$layer 买卖点',
        available: hasBsp,
        visible: widget.showRecursiveSegBsp &&
            hasBsp &&
            !_hiddenRecursiveOverlays.contains(bspId),
        onToggle: () => _toggleRecursiveOverlay(bspId),
      ));
    }
    return entries;
  }

  void _toggleRecursiveOverlay(String id) {
    setState(() {
      if (!_hiddenRecursiveOverlays.add(id))
        _hiddenRecursiveOverlays.remove(id);
    });
  }

  bool _isRecursiveObjectHidden(String objectId, {required bool bsp}) {
    final maxLayer = widget._effectiveMaxRecursiveSegLayer;
    for (var layer = 2; layer <= maxLayer; layer++) {
      final belongsToLayer = bsp
          ? objectId.contains('hichan2_seg${layer}_bsp_')
          : objectId.contains('_L${layer}_');
      if (belongsToLayer) {
        final id = bsp ? 'seg_${layer}_bsp' : 'seg_$layer';
        return _hiddenRecursiveOverlays.contains(id);
      }
    }
    return false;
  }
}
