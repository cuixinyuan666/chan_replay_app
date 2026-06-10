import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/bsp.dart';
import '../../core/models/chan_snapshot.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import 'easy_tdx_indicator_painter.dart';
import 'origin_kline_chart.dart' as base;

class OriginKlineChart extends StatelessWidget {
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

  const OriginKlineChart({
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
  });

  bool get _showEasyTdxIndicators => isChanOverlayVisible?.call(TradingViewDrawingTool.easyTdxIndicators) ?? false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        base.OriginKlineChart(
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
          drawingObjects: drawingObjects,
          drawingStorageKey: drawingStorageKey,
          symbolLabel: symbolLabel,
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
        ),
        if (_showEasyTdxIndicators && snapshot.indicators.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _EasyTdxOverlayPainter(
                  snapshot: snapshot,
                  windowSize: windowSize,
                  priceScale: priceScale,
                  viewEndIndex: viewEndIndex,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EasyTdxOverlayPainter extends CustomPainter {
  static const double _topPad = 32;
  static const double _bottomPad = 28;
  static const double _leftPad = 4;
  static const double _rightPad = 58;

  final ChanSnapshot snapshot;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;

  const _EasyTdxOverlayPainter({
    required this.snapshot,
    required this.windowSize,
    required this.priceScale,
    required this.viewEndIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bars = snapshot.rawBars;
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;
    final rect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      math.max(0.0, size.width - _leftPad - _rightPad),
      math.max(0.0, size.height - _topPad - _bottomPad),
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    final end = (viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final start = math.max(0, end - windowSize + 1).toInt();
    final visible = bars.sublist(start, end + 1);
    final low = visible.map((e) => e.low).reduce(math.min);
    final high = visible.map((e) => e.high).reduce(math.max);
    final center = (high + low) / 2;
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final scaledRange = rawRange / priceScale.clamp(0.35, 5.0);
    final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);
    final minPrice = center - scaledRange / 2 - padding;
    final maxPrice = center + scaledRange / 2 + padding;
    final step = rect.width / math.max(1, visible.length);

    double priceToY(double price) => rect.bottom - (price - minPrice) / math.max(maxPrice - minPrice, 0.0000001) * rect.height;
    double rawToX(int rawIndex) => rect.left + (rawIndex - start + 0.5) * step;

    EasyTdxIndicatorPainter(
      snapshot: snapshot,
      chartRect: rect,
      startIndex: start,
      endIndex: end,
      rawToX: rawToX,
      priceToY: priceToY,
      enabledIndicators: const {'MA', 'BOLL'},
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _EasyTdxOverlayPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.windowSize != windowSize ||
        oldDelegate.priceScale != priceScale ||
        oldDelegate.viewEndIndex != viewEndIndex;
  }
}
