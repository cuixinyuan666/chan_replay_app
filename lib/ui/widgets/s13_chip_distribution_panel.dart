import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/analysis/chip_online_replay_adapter.dart';
import '../../core/models/chan_snapshot.dart';

/// S13 单股多级别复盘内嵌筹码面板。
///
/// 当前阶段只使用在线 analyze_multi 已经返回到前端的 ChanSnapshot.rawBars，
/// 不读取离线分笔文件；若后端在线返回 chip_tick_bins，可继续通过同一引擎消费。
class S13ChipDistributionPanel extends StatelessWidget {
  static const double _chartTopPad = 32.0;
  static const double _chartRightPad = 58.0;
  static const double _chartBottomPad = 28.0;
  static const double _embeddedGap = 8.0;

  final ChanSnapshot? snapshot;
  final bool enabled;
  final bool isStepMode;
  final int stepIndex;
  final int? crosshairIndex;
  final int? visibleRightIndex;
  final int binCount;
  final double ageDecay;
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
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
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
    final targetPolicy = _targetPolicy(
      isStepMode: isStepMode,
      crosshairIndex: crosshairIndex,
      visibleRightIndex: visibleRightIndex,
    );

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size.width <= 180 || size.height <= 180) {
            return const SizedBox.shrink();
          }

          final right = size.width > 420
              ? _chartRightPad + _embeddedGap
              : _embeddedGap;
          final top = _chartTopPad + _embeddedGap;
          final bottom = _chartBottomPad + _embeddedGap;
          final maxWidth = math.max(140.0, size.width - right - _embeddedGap);
          final width = math.min(
            maxWidth,
            size.width >= 900 ? 286.0 : math.max(190.0, size.width * 0.28),
          );
          final availableHeight = size.height - top - bottom;
          if (availableHeight <= 140) return const SizedBox.shrink();
          final height = math.min(360.0, availableHeight);

          return Stack(
            children: <Widget>[
              Positioned(
                right: right,
                top: top,
                width: width,
                height: height,
                child: _ChipDistributionCard(
                  result: result,
                  barsLength: bars.length,
                  targetPolicy: targetPolicy,
                  onClose: onClose,
                ),
              ),
            ],
          );
        },
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

class _ChipDistributionCard extends StatelessWidget {
  final ChipDistributionResult result;
  final int barsLength;
  final String targetPolicy;
  final VoidCallback? onClose;

  const _ChipDistributionCard({
    required this.result,
    required this.barsLength,
    required this.targetPolicy,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD8111722),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.stacked_bar_chart,
                      color: Color(0xFF8AB4FF), size: 17),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '筹码分布',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: '关闭筹码面板',
                      onPressed: onClose,
                      icon: const Icon(Icons.close, size: 15),
                      color: Colors.white54,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 26, height: 26),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: <Widget>[
                  _miniMetric('来源', targetPolicy),
                  _miniMetric(
                      '目标',
                      barsLength <= 0
                          ? '-'
                          : '${result.targetIndex + 1}/$barsLength'),
                  _miniMetric('现价', result.currentPrice.toStringAsFixed(2)),
                  _miniMetric('均价', result.averageCost.toStringAsFixed(2)),
                  _miniMetric('峰值', result.pocPrice.toStringAsFixed(2)),
                  _miniMetric('获利',
                      '${(result.profitRatio * 100).toStringAsFixed(1)}%'),
                ],
              ),
              const SizedBox(height: 7),
              Expanded(
                child: result.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无在线K线',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      )
                    : CustomPaint(
                        painter: _CompactChipDistributionPainter(result),
                        child: const SizedBox.expand(),
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                '在线 rawBars；只算目标K及以前。',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.46), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          '$label:$value',
          style: const TextStyle(color: Colors.white70, fontSize: 10.2),
        ),
      );
}

class _CompactChipDistributionPainter extends CustomPainter {
  final ChipDistributionResult result;

  const _CompactChipDistributionPainter(this.result);

  @override
  void paint(Canvas canvas, Size size) {
    if (result.bins.isEmpty || size.width <= 0 || size.height <= 0) return;
    final nonZero =
        result.bins.where((b) => b.weight > 0).toList(growable: false);
    if (nonZero.isEmpty) return;

    final minPrice = result.bins.first.price;
    final maxPrice = result.bins.last.price;
    final maxRatio = nonZero.map((b) => b.ratio).fold<double>(0, math.max);
    final left = 50.0;
    final right = size.width - 10.0;
    final top = 8.0;
    final bottom = size.height - 18.0;
    final width = math.max(1.0, right - left);
    final height = math.max(1.0, bottom - top);
    final gap = height / result.bins.length;

    final sellPaint = Paint()
      ..color = const Color(0xFF26A69A).withValues(alpha: 0.68);
    final buyPaint = Paint()
      ..color = const Color(0xFFEF5350).withValues(alpha: 0.68);
    final pocPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.88);
    final currentPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 1.2;

    for (var i = 0; i < result.bins.length; i++) {
      final bin = result.bins[i];
      if (bin.weight <= 0) continue;
      final y = bottom - (i + 0.5) * gap;
      final totalW = maxRatio <= 0 ? 0.0 : width * (bin.ratio / maxRatio);
      final sellW =
          bin.weight <= 0 ? 0.0 : totalW * (bin.sellWeight / bin.weight);
      final buyW = math.max(0.0, totalW - sellW);
      final h = math.max(1.0, gap * 0.68);
      final y0 = y - h / 2;
      final isPoc = (bin.price - result.pocPrice).abs() <=
          (maxPrice - minPrice) / result.bins.length;
      canvas.drawRect(
          Rect.fromLTWH(left, y0, sellW, h), isPoc ? pocPaint : sellPaint);
      canvas.drawRect(Rect.fromLTWH(left + sellW, y0, buyW, h),
          isPoc ? pocPaint : buyPaint);
    }

    final currentY =
        _priceToY(result.currentPrice, minPrice, maxPrice, top, bottom);
    canvas.drawLine(Offset(left, currentY), Offset(right, currentY), currentPaint);
    _drawText(
        canvas, maxPrice.toStringAsFixed(2), Offset(4, top), Colors.white54);
    _drawText(canvas, minPrice.toStringAsFixed(2), Offset(4, bottom - 12),
        Colors.white54);
    _drawText(canvas, '现价', Offset(right - 28, currentY - 14),
        const Color(0xFF66BB6A));
  }

  double _priceToY(
      double price, double minPrice, double maxPrice, double top, double bottom) {
    if ((maxPrice - minPrice).abs() < 1e-9) return (top + bottom) / 2;
    final t =
        ((price - minPrice) / (maxPrice - minPrice)).clamp(0.0, 1.0).toDouble();
    return bottom - (bottom - top) * t;
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 80);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CompactChipDistributionPainter oldDelegate) =>
      oldDelegate.result != result;
}
