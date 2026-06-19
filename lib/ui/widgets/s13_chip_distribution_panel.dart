import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/analysis/chip_online_replay_adapter.dart';
import '../../core/models/chan_snapshot.dart';

/// Chip distribution embedded at the right edge of the main K-line pane.
/// It deliberately reuses the same visible price range as the candle painter.
class S13ChipDistributionPanel extends StatelessWidget {
  final ChanSnapshot? snapshot;
  final bool enabled;
  final bool isStepMode;
  final int stepIndex;
  final int? crosshairIndex;
  final int? visibleRightIndex;
  final int windowSize;
  final double priceScale;
  final double priceOffset;
  final int easySubPanelCount;
  final int binCount;
  final double ageDecay;

  const S13ChipDistributionPanel({
    super.key,
    required this.snapshot,
    required this.enabled,
    required this.isStepMode,
    required this.stepIndex,
    required this.crosshairIndex,
    required this.visibleRightIndex,
    required this.windowSize,
    required this.priceScale,
    required this.priceOffset,
    this.easySubPanelCount = 0,
    this.binCount = 80,
    this.ageDecay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = this.snapshot;
    if (!enabled || snapshot == null || snapshot.rawBars.isEmpty) {
      return const SizedBox.shrink();
    }
    final bars = ChipOnlineReplayAdapter.fromSnapshot(snapshot);
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

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 900
              ? 286.0
              : math.max(190.0, constraints.maxWidth * 0.28);
          final subPanels = easySubPanelCount.clamp(0, 4).toInt();
          final subHeight = subPanels == 0
              ? 0.0
              : subPanels * 74.0 + (subPanels - 1) * 6.0 + 6.0;
          final end = (visibleRightIndex ?? snapshot.rawBars.length - 1)
              .clamp(0, snapshot.rawBars.length - 1)
              .toInt();
          final start = math.max(0, end - windowSize + 1).toInt();
          final visible = snapshot.rawBars.sublist(start, end + 1);
          final low = visible.map((bar) => bar.low).reduce(math.min);
          final high = visible.map((bar) => bar.high).reduce(math.max);
          final center = (high + low) / 2 + priceOffset;
          final rawRange = math.max(high - low, high.abs() * 0.002);
          final scaledRange = rawRange / priceScale.clamp(0.35, 5.0);
          final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);

          return Stack(children: <Widget>[
            Positioned(
              top: 32,
              bottom: 28 + subHeight,
              right: 58,
              width: width,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0x52111722),
                ),
                child: CustomPaint(
                  painter: _EmbeddedChipPainter(
                    result,
                    minPrice: center - scaledRange / 2 - padding,
                    maxPrice: center + scaledRange / 2 + padding,
                  ),
                  child: const Stack(children: <Widget>[
                    Positioned(
                      top: 5,
                      left: 7,
                      child: Text('筹码分布',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 10.5)),
                    ),
                  ]),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

class _EmbeddedChipPainter extends CustomPainter {
  final ChipDistributionResult result;
  final double minPrice;
  final double maxPrice;

  const _EmbeddedChipPainter(this.result,
      {required this.minPrice, required this.maxPrice});

  double _priceToY(double price, Size size) {
    if ((maxPrice - minPrice).abs() < 1e-9) return size.height / 2;
    return size.height -
        (price - minPrice) / (maxPrice - minPrice) * size.height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bins = result.bins.where((bin) => bin.weight > 0).toList();
    if (bins.isEmpty || size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final maxRatio = bins.map((bin) => bin.ratio).reduce(math.max);
    final step = result.bins.length < 2
        ? 0.01
        : (result.bins.last.price - result.bins.first.price) /
            (result.bins.length - 1);
    final sellPaint = Paint()..color = const Color(0xAA26A69A);
    final buyPaint = Paint()..color = const Color(0xAAEF5350);
    final pocPaint = Paint()..color = const Color(0xDDEFB300);
    for (final bin in bins) {
      final y = _priceToY(bin.price, size);
      final h = math.max(
          1.0,
          (_priceToY(bin.price - step / 2, size) -
                      _priceToY(bin.price + step / 2, size))
                  .abs() *
              .68);
      final totalWidth =
          maxRatio <= 0 ? 0.0 : size.width * bin.ratio / maxRatio;
      final sellWidth = totalWidth * bin.sellWeight / bin.weight;
      final buyWidth = totalWidth - sellWidth;
      final isPoc = (bin.price - result.pocPrice).abs() <= step.abs();
      final paint = isPoc ? pocPaint : sellPaint;
      canvas.drawRect(
          Rect.fromLTWH(size.width - totalWidth, y - h / 2, sellWidth, h),
          paint);
      canvas.drawRect(
          Rect.fromLTWH(size.width - buyWidth, y - h / 2, buyWidth, h),
          isPoc ? pocPaint : buyPaint);
    }
    final currentY = _priceToY(result.currentPrice, size);
    canvas.drawLine(
        Offset(0, currentY),
        Offset(size.width, currentY),
        Paint()
          ..color = const Color(0xFF66BB6A)
          ..strokeWidth = 1.1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmbeddedChipPainter oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.minPrice != minPrice ||
      oldDelegate.maxPrice != maxPrice;
}
