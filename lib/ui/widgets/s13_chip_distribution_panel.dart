import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/analysis/chip_online_replay_adapter.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';

/// S13 单股多级别复盘内嵌筹码 overlay。
///
/// 不再以独立右侧卡片显示，而是直接绘制在 K 线主图区右侧：
/// - 有 chip_tick_bins / chipTickBins 时，优先使用 a_replay_trainer.py 风格 p/s/b/w；
/// - 没有逐价桶时，使用 OHLCV 兜底；
/// - 使用 IgnorePointer，不拦截十字线、拖拽、画线工具等主图交互。
class S13ChipDistributionPanel extends StatelessWidget {
  static const double _topPad = 32;
  static const double _bottomPad = 28;
  static const double _leftPad = 4;
  static const double _rightPad = 58;
  static const double _subPanelHeight = 74;
  static const double _panelGap = 6;

  final ChanSnapshot? snapshot;
  final bool enabled;
  final bool isStepMode;
  final int stepIndex;
  final int? crosshairIndex;
  final int? visibleRightIndex;
  final int binCount;
  final double ageDecay;
  final int windowSize;
  final double priceScale;
  final bool showEasyTdxIndicators;
  final int easyTdxSubPanelCount;
  final VoidCallback? onClose;

  const S13ChipDistributionPanel({
    super.key,
    required this.snapshot,
    required this.enabled,
    required this.isStepMode,
    required this.stepIndex,
    required this.crosshairIndex,
    required this.visibleRightIndex,
    this.binCount = 80,
    this.ageDecay = 0.0,
    this.windowSize = 90,
    this.priceScale = 1.0,
    this.showEasyTdxIndicators = false,
    this.easyTdxSubPanelCount = 0,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final bars = ChipOnlineReplayAdapter.fromSnapshot(snapshot);
    final rawBars = snapshot?.rawBars ?? const <RawBar>[];
    final targetIndex = ChipOnlineReplayAdapter.resolveTargetIndex(
      total: bars.length,
      isStepMode: isStepMode,
      stepIndex: stepIndex,
      crosshairIndex: crosshairIndex,
      viewEndIndex: visibleRightIndex,
    );
    final result = const ChipDistributionEngine().calculate(
      bars,
      targetIndex: targetIndex,
      options: ChipDistributionOptions(
        binCount: binCount,
        lookback: 1000000,
        ageDecay: ageDecay,
      ),
    );
    final exactBarCount = bars.where((bar) => bar.hasExactChipBins).length;
    final targetPolicy = _targetPolicy(
      isStepMode: isStepMode,
      crosshairIndex: crosshairIndex,
      visibleRightIndex: visibleRightIndex,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _InChartChipDistributionPainter(
            rawBars: rawBars,
            result: result,
            exactBarCount: exactBarCount,
            targetPolicy: targetPolicy,
            windowSize: windowSize,
            priceScale: priceScale,
            viewEndIndex: visibleRightIndex,
            showEasyTdxIndicators: showEasyTdxIndicators,
            easyTdxSubPanelCount: easyTdxSubPanelCount,
          ),
        ),
      ),
    );
  }

  static String _targetPolicy({
    required bool isStepMode,
    required int? crosshairIndex,
    required int? visibleRightIndex,
  }) {
    if (isStepMode) return 'step';
    if (crosshairIndex != null) return '十字线';
    if (visibleRightIndex != null) return '右侧K';
    return '末K';
  }
}

class _InChartChipDistributionPainter extends CustomPainter {
  final List<RawBar> rawBars;
  final ChipDistributionResult result;
  final int exactBarCount;
  final String targetPolicy;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final bool showEasyTdxIndicators;
  final int easyTdxSubPanelCount;

  const _InChartChipDistributionPainter({
    required this.rawBars,
    required this.result,
    required this.exactBarCount,
    required this.targetPolicy,
    required this.windowSize,
    required this.priceScale,
    required this.viewEndIndex,
    required this.showEasyTdxIndicators,
    required this.easyTdxSubPanelCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rawBars.isEmpty || size.width <= 0 || size.height <= 0) return;
    final chart = _visibleChartMeta(size);
    if (chart == null || chart.rect.width <= 0 || chart.rect.height <= 0) return;

    final overlayWidth = math.min(190.0, math.max(72.0, chart.rect.width * 0.28));
    final overlayRight = chart.rect.right - 2;
    final overlayLeft = overlayRight - overlayWidth;
    final overlayRect = Rect.fromLTRB(
      overlayLeft,
      chart.rect.top + 2,
      overlayRight,
      chart.rect.bottom - 2,
    );

    _drawBackground(canvas, overlayRect);
    if (result.isEmpty) {
      _drawText(
        canvas,
        '筹码：暂无数据',
        Offset(overlayRect.left + 8, overlayRect.top + 8),
        const Color(0xCCFFFFFF),
        11,
      );
      return;
    }

    final nonZero = result.bins.where((bin) => bin.weight > 0).toList(growable: false);
    if (nonZero.isEmpty) return;
    final maxWeight = nonZero.map((bin) => bin.weight).fold<double>(0, math.max);
    if (maxWeight <= 0) return;

    final priceStep = result.bins.length >= 2
        ? (result.bins[1].price - result.bins[0].price).abs()
        : math.max(result.currentPrice.abs() * 0.002, 0.01);
    final minBarHeight = math.max(1.0, overlayRect.height / math.max(90, result.bins.length) * 0.72);

    final sellPaint = Paint()..color = const Color(0xFF26A69A).withValues(alpha: 0.36);
    final buyPaint = Paint()..color = const Color(0xFFEF5350).withValues(alpha: 0.38);
    final pocPaint = Paint()..color = const Color(0xFFFFC107).withValues(alpha: 0.58);
    final targetLinePaint = Paint()
      ..color = const Color(0xFF66BB6A).withValues(alpha: 0.70)
      ..strokeWidth = 1.0;
    final pocLinePaint = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: 0.58)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(chart.rect);
    for (final bin in result.bins) {
      if (bin.weight <= 0) continue;
      final y = chart.priceToY(bin.price);
      if (y < chart.rect.top - 2 || y > chart.rect.bottom + 2) continue;
      final yHigh = chart.priceToY(bin.price + priceStep / 2);
      final yLow = chart.priceToY(bin.price - priceStep / 2);
      final h = math.max(minBarHeight, (yLow - yHigh).abs() * 0.76);
      final totalW = overlayWidth * 0.92 * (bin.weight / maxWeight);
      final sellW = bin.weight <= 0 ? 0.0 : totalW * (bin.sellWeight / bin.weight);
      final buyW = math.max(0.0, totalW - sellW);
      final right = overlayRight - 4;
      final y0 = (y - h / 2).clamp(chart.rect.top, chart.rect.bottom).toDouble();
      final isPoc = (bin.price - result.pocPrice).abs() <= priceStep * 0.6;
      final firstPaint = isPoc ? pocPaint : sellPaint;
      final secondPaint = isPoc ? pocPaint : buyPaint;
      canvas.drawRect(Rect.fromLTWH(right - totalW, y0, sellW, h), firstPaint);
      canvas.drawRect(Rect.fromLTWH(right - totalW + sellW, y0, buyW, h), secondPaint);
    }

    final targetY = chart.priceToY(result.currentPrice);
    if (targetY >= chart.rect.top && targetY <= chart.rect.bottom) {
      canvas.drawLine(Offset(overlayLeft, targetY), Offset(overlayRight, targetY), targetLinePaint);
    }
    final pocY = chart.priceToY(result.pocPrice);
    if (pocY >= chart.rect.top && pocY <= chart.rect.bottom) {
      canvas.drawLine(Offset(overlayLeft, pocY), Offset(overlayRight, pocY), pocLinePaint);
    }
    canvas.restore();

    _drawHeader(canvas, chart.rect, overlayRect);
  }

  _ChipChartMeta? _visibleChartMeta(Size size) {
    final activeSubPanels = showEasyTdxIndicators ? easyTdxSubPanelCount.clamp(0, 4).toInt() : 0;
    final totalSubHeight = activeSubPanels == 0
        ? 0.0
        : activeSubPanels * S13ChipDistributionPanel._subPanelHeight +
            (activeSubPanels - 1) * S13ChipDistributionPanel._panelGap;
    final contentWidth = math.max(
      0.0,
      size.width - S13ChipDistributionPanel._leftPad - S13ChipDistributionPanel._rightPad,
    );
    final mainHeight = math.max(
      0.0,
      size.height -
          S13ChipDistributionPanel._topPad -
          S13ChipDistributionPanel._bottomPad -
          totalSubHeight -
          (activeSubPanels > 0 ? S13ChipDistributionPanel._panelGap : 0),
    );
    final rect = Rect.fromLTWH(
      S13ChipDistributionPanel._leftPad,
      S13ChipDistributionPanel._topPad,
      contentWidth,
      mainHeight,
    );
    if (rect.width <= 0 || rect.height <= 0) return null;

    final end = (viewEndIndex ?? rawBars.length - 1).clamp(0, rawBars.length - 1).toInt();
    final safeWindow = windowSize.clamp(24, 360).toInt();
    final start = math.max(0, end - safeWindow + 1).toInt();
    final visible = rawBars.sublist(start, end + 1);
    if (visible.isEmpty) return null;
    final low = visible.map((bar) => bar.low).reduce(math.min);
    final high = visible.map((bar) => bar.high).reduce(math.max);
    final center = (high + low) / 2;
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final scaledRange = rawRange / priceScale.clamp(0.35, 5.0);
    final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);
    final minPrice = center - scaledRange / 2 - padding;
    final maxPrice = center + scaledRange / 2 + padding;
    return _ChipChartMeta(rect: rect, minPrice: minPrice, maxPrice: maxPrice);
  }

  void _drawBackground(Canvas canvas, Rect rect) {
    final bgPaint = Paint()..color = const Color(0xFF111722).withValues(alpha: 0.16);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);
  }

  void _drawHeader(Canvas canvas, Rect chartRect, Rect overlayRect) {
    final exact = rawBars.isEmpty ? '-' : '$exactBarCount/${rawBars.length}';
    final line1 = '筹码 $targetPolicy  ${result.targetIndex + 1}/${rawBars.length}';
    final line2 = '精确桶 $exact  获利 ${(result.profitRatio * 100).toStringAsFixed(1)}%';
    final line3 = '均 ${result.averageCost.toStringAsFixed(2)}  峰 ${result.pocPrice.toStringAsFixed(2)}';
    final left = overlayRect.left + 8;
    final top = chartRect.top + 7;
    final badgeRect = Rect.fromLTWH(left - 6, top - 4, overlayRect.width - 10, 48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(7)),
      Paint()..color = const Color(0xCC0D1117).withValues(alpha: 0.54),
    );
    _drawText(canvas, line1, Offset(left, top), const Color(0xE6FFFFFF), 10.5);
    _drawText(canvas, line2, Offset(left, top + 15), const Color(0xCCFFFFFF), 10.0);
    _drawText(canvas, line3, Offset(left, top + 30), const Color(0xAAFFFFFF), 10.0);
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 178);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _InChartChipDistributionPainter oldDelegate) {
    return oldDelegate.rawBars != rawBars ||
        oldDelegate.result != result ||
        oldDelegate.exactBarCount != exactBarCount ||
        oldDelegate.targetPolicy != targetPolicy ||
        oldDelegate.windowSize != windowSize ||
        oldDelegate.priceScale != priceScale ||
        oldDelegate.viewEndIndex != viewEndIndex ||
        oldDelegate.showEasyTdxIndicators != showEasyTdxIndicators ||
        oldDelegate.easyTdxSubPanelCount != easyTdxSubPanelCount;
  }
}

class _ChipChartMeta {
  final Rect rect;
  final double minPrice;
  final double maxPrice;

  const _ChipChartMeta({
    required this.rect,
    required this.minPrice,
    required this.maxPrice,
  });

  double priceToY(double price) {
    final range = math.max(maxPrice - minPrice, 0.0000001);
    return rect.bottom - (price - minPrice) / range * rect.height;
  }
}
