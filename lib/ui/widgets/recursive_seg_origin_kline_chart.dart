import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import 'origin_kline_chart.dart' as base;

/// Display-only adapter for hichan2 recursive segment layers.
///
/// This widget does not calculate Chan structures. It converts backend-exported
/// `snapshot.recursiveSegLayers` rows into non-persistent drawing overlays and
/// delegates all actual K-line rendering to the original `OriginKlineChart`.
class RecursiveSegOriginKlineChart extends StatelessWidget {
  static const _rhythmStylePalette = <int>[
    0xFF66BB6A,
    0xFFEF5350,
    0xFF42A5F5,
    0xFFFFD54F,
    0xFFAB47BC,
    0xFF26C6DA,
    0xFFFF8A65,
    0xFF9CCC65,
    0xFF5C6BC0,
    0xFFFF7043,
    0xFF26A69A,
    0xFFD4E157,
  ];

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
  final int? viewEndIndex;
  final int? crosshairIndex;
  final ValueChanged<int>? onCrosshairChanged;
  final ValueChanged<int>? onPanBars;
  final ValueChanged<int>? onWindowSizeChanged;
  final ValueChanged<double>? onPriceScaleChanged;
  final ValueChanged<int>? onEasyTdxSubPanelCountChanged;
  final ValueChanged<String>? onEasyTdxIndicatorToggled;
  final bool showRecursiveSegLayers;
  final int minRecursiveSegLayer;
  final int maxRecursiveSegLayer;

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
    this.viewEndIndex,
    this.crosshairIndex,
    this.onCrosshairChanged,
    this.onPanBars,
    this.onWindowSizeChanged,
    this.onPriceScaleChanged,
    this.onEasyTdxSubPanelCountChanged,
    this.onEasyTdxIndicatorToggled,
    this.showRecursiveSegLayers = true,
    this.minRecursiveSegLayer = 2,
    this.maxRecursiveSegLayer = 4,
  });

  @override
  Widget build(BuildContext context) {
    final visibleStyledDrawingObjects =
        _visibleStyledExternalDrawingObjects(snapshot, drawingObjects);
    return base.OriginKlineChart(
      snapshot: snapshot,
      showFx: showFx,
      showFxLine: showFxLine,
      showFxText: showFxText,
      showBi: showBi,
      showBiText: showBiText,
      showSeg: showSeg,
      showSegText: showSegText,
      showZs: showZs,
      showBiBsp: showBiBsp,
      showSegBsp: showSegBsp,
      showMergedBars: showMergedBars,
      showEasyTdxIndicators: showEasyTdxIndicators,
      easyTdxSubPanelCount: easyTdxSubPanelCount,
      enabledEasyTdxIndicators: enabledEasyTdxIndicators,
      drawingObjects: [
        if (showRecursiveSegLayers) ..._recursiveSegDrawingObjects(snapshot),
        ...visibleStyledDrawingObjects,
      ],
      drawingStorageKey: drawingStorageKey,
      symbolLabel: _symbolLabelWithRecursiveSegSummary(symbolLabel, snapshot),
      isChanOverlayVisible: isChanOverlayVisible,
      onChanOverlayToggled: onChanOverlayToggled,
      toolboxOpenSignal: toolboxOpenSignal,
      toolboxSelectedToolSignal: toolboxSelectedToolSignal,
      onToolboxQuickToolAdded: onToolboxQuickToolAdded,
      windowSize: windowSize,
      priceScale: priceScale,
      viewEndIndex: viewEndIndex,
      crosshairIndex: crosshairIndex,
      onCrosshairChanged: onCrosshairChanged,
      onPanBars: onPanBars,
      onWindowSizeChanged: onWindowSizeChanged,
      onPriceScaleChanged: onPriceScaleChanged,
      onEasyTdxSubPanelCountChanged: onEasyTdxSubPanelCountChanged,
      onEasyTdxIndicatorToggled: onEasyTdxIndicatorToggled,
    );
  }

  List<DrawingObject> _visibleStyledExternalDrawingObjects(
    ChanSnapshot snapshot,
    List<DrawingObject> objects,
  ) {
    if (objects.isEmpty) return const <DrawingObject>[];
    final range = _visibleRhythmRawIndexRange(snapshot);
    final visible = <DrawingObject>[];
    for (final object in objects) {
      if (!_isAutoRhythmOverlay(object)) {
        visible.add(object);
        continue;
      }
      if (!_drawingObjectIntersectsRange(object, range)) continue;
      visible.add(_styleRhythmOverlay(object));
    }
    return visible;
  }

  bool _isAutoRhythmOverlay(DrawingObject object) {
    return object.id.startsWith('auto_') &&
        (object.tool == TradingViewDrawingTool.trendLine ||
            object.tool == TradingViewDrawingTool.priceLabel);
  }

  _RhythmViewportRange _visibleRhythmRawIndexRange(ChanSnapshot snapshot) {
    if (snapshot.rawBars.isEmpty) {
      return const _RhythmViewportRange(0, 0x3fffffff);
    }
    final maxRaw = snapshot.rawBars.length - 1;
    final safeWindow = windowSize < 1 ? 1 : windowSize;
    final end = viewEndIndex == null
        ? maxRaw
        : _clampInt(viewEndIndex!, 0, maxRaw);
    final start = _clampInt(end - safeWindow + 1, 0, maxRaw);
    final margin = _clampInt((safeWindow / 3).ceil(), 8, 80);
    return _RhythmViewportRange(
      _clampInt(start - margin, 0, maxRaw),
      _clampInt(end + margin, 0, maxRaw),
    );
  }

  bool _drawingObjectIntersectsRange(
    DrawingObject object,
    _RhythmViewportRange range,
  ) {
    final rawIndexes = <int>[
      for (final anchor in object.anchors)
        if (anchor.isChart && anchor.rawIndex != null) anchor.rawIndex!,
    ];
    if (rawIndexes.isEmpty) return true;
    var minRaw = rawIndexes.first;
    var maxRaw = rawIndexes.first;
    for (final raw in rawIndexes.skip(1)) {
      if (raw < minRaw) minRaw = raw;
      if (raw > maxRaw) maxRaw = raw;
    }
    return minRaw <= range.endRawIndex && maxRaw >= range.startRawIndex;
  }

  DrawingObject _styleRhythmOverlay(DrawingObject object) {
    if (object.tool != TradingViewDrawingTool.trendLine) return object;
    final leftRawIndex = _leftAnchorRawIndex(object);
    if (leftRawIndex == null) return object;
    final slot = _rhythmStyleSlot(leftRawIndex);
    return object.copyWith(style: _styleRhythmLine(slot, object.style));
  }

  int? _leftAnchorRawIndex(DrawingObject object) {
    for (final anchor in object.anchors) {
      if (anchor.isChart && anchor.rawIndex != null) return anchor.rawIndex;
    }
    return null;
  }

  int _rhythmStyleSlot(int leftRawIndex) {
    final size = _rhythmStylePalette.length * 2;
    return leftRawIndex.abs() % size;
  }

  DrawingStyle _styleRhythmLine(int slot, DrawingStyle baseStyle) {
    final color = _rhythmStylePalette[slot % _rhythmStylePalette.length];
    final dashed = slot >= _rhythmStylePalette.length;
    final strokeWidth = 1.25 + (slot % 3) * 0.25;
    return baseStyle.copyWith(
      colorValue: color,
      strokeWidth: strokeWidth,
      opacity: 0.88,
      dashed: dashed,
      fontSize: 11,
    );
  }

  int _clampInt(int value, int min, int max) {
    if (max < min) return min;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  List<DrawingObject> _recursiveSegDrawingObjects(ChanSnapshot snapshot) {
    final rows = <DrawingObject>[];
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final minLayer = minRecursiveSegLayer < 1 ? 1 : minRecursiveSegLayer;
    final maxLayer =
        maxRecursiveSegLayer < minLayer ? minLayer : maxRecursiveSegLayer;
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
              rawIndex: seg.startRawIndex,
              price: seg.startPrice,
            ),
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

  DrawingStyle _styleForLayer({required int layer, required bool isSure}) {
    final strokeWidth = switch (layer) {
      2 => 2.2,
      3 => 2.8,
      4 => 3.4,
      _ => 2.0 + (layer < 1 ? 1 : layer > 8 ? 8 : layer).toDouble() * 0.35,
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
      _ => 0xFFFFFFFF,
    };
  }

  String _symbolLabelWithRecursiveSegSummary(
    String baseLabel,
    ChanSnapshot snapshot,
  ) {
    final layerCounts = <String>[];
    final minLayer = minRecursiveSegLayer < 1 ? 1 : minRecursiveSegLayer;
    final maxLayer =
        maxRecursiveSegLayer < minLayer ? minLayer : maxRecursiveSegLayer;
    for (var layer = minLayer; layer <= maxLayer; layer++) {
      final count = snapshot.recursiveSegLayers[layer]?.length ?? 0;
      if (count > 0) layerCounts.add('L$layer:$count');
    }
    if (layerCounts.isEmpty) return baseLabel;
    final prefix = baseLabel.trim();
    final suffix = '递归段 ${layerCounts.join(' ')}';
    return prefix.isEmpty ? suffix : '$prefix | $suffix';
  }
}

class _RhythmViewportRange {
  final int startRawIndex;
  final int endRawIndex;

  const _RhythmViewportRange(this.startRawIndex, this.endRawIndex);
}
