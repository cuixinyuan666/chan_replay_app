import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/recursive_seg.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import 'origin_kline_chart.dart' as base;

/// Display-only adapter for hichan2 recursive segment layers.
///
/// This widget does not calculate Chan structures. It converts backend-exported
/// `snapshot.recursiveSegLayers` rows into non-persistent drawing overlays and
/// delegates all actual K-line rendering to the original `OriginKlineChart`.
class RecursiveSegOriginKlineChart extends StatelessWidget {
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
        ...drawingObjects,
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

  List<DrawingObject> _recursiveSegDrawingObjects(ChanSnapshot snapshot) {
    final rows = <DrawingObject>[];
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    final minLayer = minRecursiveSegLayer.clamp(1, 99).toInt();
    final maxLayer = maxRecursiveSegLayer.clamp(minLayer, 99).toInt();
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
            DrawingAnchor.chart(rawIndex: seg.startRawIndex, price: seg.startPrice),
            DrawingAnchor.chart(rawIndex: seg.endRawIndex, price: seg.endPrice),
          ],
          style: _styleForLayer(layer, seg),
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

  DrawingStyle _styleForLayer(int layer, RecursiveSEG seg) {
    final strokeWidth = switch (layer) {
      2 => 2.2,
      3 => 2.8,
      4 => 3.4,
      _ => 2.0 + layer.clamp(1, 8).toDouble() * 0.35,
    };
    final opacity = seg.isSure ? 0.92 : 0.46;
    return DrawingStyle(
      colorValue: _colorValueForLayer(layer),
      strokeWidth: strokeWidth,
      opacity: opacity,
      dashed: !seg.isSure,
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

  String _symbolLabelWithRecursiveSegSummary(String baseLabel, ChanSnapshot snapshot) {
    final layerCounts = <String>[];
    final minLayer = minRecursiveSegLayer.clamp(1, 99).toInt();
    final maxLayer = maxRecursiveSegLayer.clamp(minLayer, 99).toInt();
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
