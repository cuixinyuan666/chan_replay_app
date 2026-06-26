import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/analysis/chip_online_replay_adapter.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/settings/chip_distribution_settings.dart';

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
  final int? binCount;
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
    this.binCount,
    this.ageDecay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChipDistributionSettings>(
      valueListenable: ChipDistributionSettingsController.selected,
      builder: (context, settings, _) {
        final effectiveBinCount = binCount ?? settings.priceBucketCount;
        return _buildPanel(context, effectiveBinCount);
      },
    );
  }

  Widget _buildPanel(BuildContext context, int effectiveBinCount) {
    final snapshot = this.snapshot;
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          if (enabled) _chipDistributionLayer(snapshot, effectiveBinCount),
        ],
      ),
    );
  }

  Widget _chipDistributionLayer(ChanSnapshot snapshot, int effectiveBinCount) {
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
        binCount: effectiveBinCount,
        lookback: 1000000,
        ageDecay: ageDecay,
      ),
    );
    final incrementalResult = _calculateIncrementalResult(
      bars: bars,
      rawBars: snapshot.rawBars,
      targetIndex: targetIndex,
      binCount: effectiveBinCount,
    );

    return IgnorePointer(
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
        final chartMin = center - scaledRange / 2 - padding;
        final chartMax = center + scaledRange / 2 + padding;
        final chipPrices = result.bins
            .where((bin) => bin.weight > 0 && bin.price.isFinite)
            .map((bin) => bin.price)
            .toList(growable: false);
        final chipMin =
            chipPrices.isEmpty ? chartMin : chipPrices.reduce(math.min);
        final chipMax =
            chipPrices.isEmpty ? chartMax : chipPrices.reduce(math.max);
        final plotMin = math.min(chartMin, chipMin);
        final plotMax = math.max(chartMax, chipMax);
        final plotPadding =
            math.max((plotMax - plotMin).abs() * 0.025, high.abs() * 0.001);

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
                  incrementalResult: incrementalResult,
                  minPrice: plotMin - plotPadding,
                  maxPrice: plotMax + plotPadding,
                ),
                child: SizedBox.expand(
                  child: Stack(children: <Widget>[
                    Positioned(
                      top: 5,
                      left: 7,
                      child: Text('筹码分布 · $effectiveBinCount桶',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10.5)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  ChipDistributionResult? _calculateIncrementalResult({
    required List<ChipDistributionBar> bars,
    required List rawBars,
    required int targetIndex,
    required int binCount,
  }) {
    if (bars.length < 2 || targetIndex <= 0 || rawBars.isEmpty) return null;
    final first = rawBars.first;
    final chipTickBins = first.chipTickBins;
    if (chipTickBins is! Map ||
        chipTickBins['source'] != 'backend_chip_history_seed') {
      return null;
    }
    final scoped = bars.sublist(1, targetIndex + 1);
    if (scoped.isEmpty) return null;
    final result = const ChipDistributionEngine().calculate(
      scoped,
      targetIndex: scoped.length - 1,
      options: ChipDistributionOptions(
        binCount: binCount,
        lookback: 1000000,
        ageDecay: 0,
      ),
    );
    return result.isEmpty ? null : result;
  }
}

class PriceBucketCountControl extends StatelessWidget {
  final int value;
  final bool overlayChrome;

  const PriceBucketCountControl({
    super.key,
    required this.value,
    this.overlayChrome = true,
  });

  static const String _tooltip =
      '价格桶数：把当前价格区间切成多少个价格层来统计筹码。只在这个小界面内响应鼠标，K线图主体仍可正常拖拽和缩放。';

  void _setValue(int value) {
    ChipDistributionSettingsController.setPriceBucketCount(
      value.clamp(24, 160).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      onPointerMove: (_) {},
      onPointerSignal: (_) {},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Tooltip(
                  message: _tooltip,
                  waitDuration: Duration(milliseconds: 250),
                  child: Text(
                    '价格桶数',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 24,
                max: 160,
                divisions: 136,
                label: '$value',
                onChanged: (next) => _setValue(next.round()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _BucketStepButton(
                  tooltip: '减少价格桶数',
                  icon: Icons.remove,
                  onPressed: () => _setValue(value - 1),
                ),
                const Text(
                  '仅此控件响应操作',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
                _BucketStepButton(
                  tooltip: '增加价格桶数',
                  icon: Icons.add,
                  onPressed: () => _setValue(value + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!overlayChrome) return content;
    return Material(
      color: Colors.black.withValues(alpha: 0.64),
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: content,
      ),
    );
  }
}

class _BucketStepButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _BucketStepButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white12),
          ),
          child: Icon(icon, color: Colors.white70, size: 15),
        ),
      ),
    );
  }
}

class _EmbeddedChipPainter extends CustomPainter {
  final ChipDistributionResult result;
  final ChipDistributionResult? incrementalResult;
  final double minPrice;
  final double maxPrice;

  const _EmbeddedChipPainter(
    this.result, {
    this.incrementalResult,
    required this.minPrice,
    required this.maxPrice,
  });

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
    _paintIncremental(canvas, size);
    final currentY = _priceToY(result.currentPrice, size);
    canvas.drawLine(
        Offset(0, currentY),
        Offset(size.width, currentY),
        Paint()
          ..color = const Color(0xFFE8F5E9)
          ..strokeWidth = 1.4);
    final label = result.currentPrice.toStringAsFixed(2);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFFE8F5E9),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelY = (currentY - textPainter.height - 2)
        .clamp(1.0, math.max(1.0, size.height - textPainter.height - 1))
        .toDouble();
    textPainter.paint(
        canvas, Offset(size.width - textPainter.width - 4, labelY));
    canvas.restore();
  }

  void _paintIncremental(Canvas canvas, Size size) {
    final dynamicResult = incrementalResult;
    if (dynamicResult == null || dynamicResult.isEmpty) return;
    final dynamicBins =
        dynamicResult.bins.where((bin) => bin.weight > 0).toList();
    if (dynamicBins.isEmpty) return;
    final maxRatio = dynamicBins.map((bin) => bin.ratio).reduce(math.max);
    if (maxRatio <= 0) return;
    final step = dynamicResult.bins.length < 2
        ? 0.01
        : (dynamicResult.bins.last.price - dynamicResult.bins.first.price) /
            (dynamicResult.bins.length - 1);
    final paint = Paint()..color = const Color(0xCC42A5F5);
    for (final bin in dynamicBins) {
      final y = _priceToY(bin.price, size);
      final h = math.max(
          1.25,
          (_priceToY(bin.price - step / 2, size) -
                      _priceToY(bin.price + step / 2, size))
                  .abs() *
              .9);
      final totalWidth = size.width * 0.44 * bin.ratio / maxRatio;
      canvas.drawRect(
        Rect.fromLTWH(size.width - totalWidth, y - h / 2, totalWidth, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmbeddedChipPainter oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.incrementalResult != incrementalResult ||
      oldDelegate.minPrice != minPrice ||
      oldDelegate.maxPrice != maxPrice;
}
