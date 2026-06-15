import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';

class ChipDistributionPage extends StatefulWidget {
  const ChipDistributionPage({super.key});

  @override
  State<ChipDistributionPage> createState() => _ChipDistributionPageState();
}

class _ChipDistributionPageState extends State<ChipDistributionPage> {
  static final List<ChipDistributionBar> _demoBars = _buildDemoBars();
  final ChipDistributionEngine _engine = const ChipDistributionEngine();

  int _targetIndex = _demoBars.length - 1;
  int _lookback = 120;
  int _binCount = 80;
  double _ageDecay = 0.006;

  ChipDistributionResult get _result => _engine.calculate(
        _demoBars,
        targetIndex: _targetIndex,
        options: ChipDistributionOptions(
          binCount: _binCount,
          lookback: _lookback,
          ageDecay: _ageDecay,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(context),
              const SizedBox(height: 12),
              _buildControlCard(result),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: result.isEmpty
                        ? const Center(child: Text('暂无可计算筹码数据'))
                        : CustomPaint(
                            painter: _ChipDistributionPainter(result),
                            child: const SizedBox.expand(),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildPolicyText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.stacked_bar_chart, color: Color(0xFF8AB4FF)),
        const SizedBox(width: 8),
        Text(
          '筹码分布',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const Spacer(),
        const Tooltip(
          message: '当前页面为独立筹码分布研究页，不改写复盘页和 chan.py 结构。',
          child: Icon(Icons.info_outline, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildControlCard(ChipDistributionResult result) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                _MetricChip(label: '目标K线', value: '${result.targetIndex + 1}/${_demoBars.length}'),
                _MetricChip(label: '现价', value: result.currentPrice.toStringAsFixed(2)),
                _MetricChip(label: '平均成本', value: result.averageCost.toStringAsFixed(2)),
                _MetricChip(label: '峰值价位', value: result.pocPrice.toStringAsFixed(2)),
                _MetricChip(label: '获利筹码', value: '${(result.profitRatio * 100).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            _LabeledSlider(
              label: '目标K线',
              value: _targetIndex.toDouble(),
              min: 0,
              max: (_demoBars.length - 1).toDouble(),
              divisions: _demoBars.length - 1,
              display: '${_targetIndex + 1}',
              onChanged: (v) => setState(() => _targetIndex = v.round()),
            ),
            _LabeledSlider(
              label: '回看K数',
              value: _lookback.toDouble(),
              min: 20,
              max: _demoBars.length.toDouble(),
              divisions: math.max(1, _demoBars.length - 20),
              display: '$_lookback',
              onChanged: (v) => setState(() => _lookback = v.round()),
            ),
            _LabeledSlider(
              label: '价格桶数',
              value: _binCount.toDouble(),
              min: 24,
              max: 160,
              divisions: 136,
              display: '$_binCount',
              onChanged: (v) => setState(() => _binCount = v.round()),
            ),
            _LabeledSlider(
              label: '旧筹码衰减',
              value: _ageDecay,
              min: 0,
              max: 0.03,
              divisions: 30,
              display: _ageDecay.toStringAsFixed(3),
              onChanged: (v) => setState(() => _ageDecay = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyText() {
    return const Text(
      '计算口径：只使用目标K线及其以前数据；逐价成交量优先，缺失时以OHLCV三角分摊兜底；该页不提供交易建议。',
      style: TextStyle(color: Colors.white54, fontSize: 12),
    );
  }

  static List<ChipDistributionBar> _buildDemoBars() {
    final out = <ChipDistributionBar>[];
    var close = 10.0;
    for (var i = 0; i < 180; i++) {
      final wave = math.sin(i / 8.0) * 0.18 + math.cos(i / 19.0) * 0.12;
      final drift = i * 0.006;
      final open = close;
      close = (10.0 + drift + wave).clamp(8.0, 18.0).toDouble();
      final high = math.max(open, close) + 0.08 + (i % 5) * 0.01;
      final low = math.min(open, close) - 0.08 - (i % 7) * 0.008;
      final volume = 8000.0 + (i % 17) * 450.0 + math.max(0, math.sin(i / 5.0)) * 3000.0;
      out.add(ChipDistributionBar(
        index: i,
        time: DateTime(2026, 1, 1).add(Duration(days: i)),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ));
    }
    return out;
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0D10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Text('$label: $value', style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 54,
          child: Text(display, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }
}

class _ChipDistributionPainter extends CustomPainter {
  final ChipDistributionResult result;

  const _ChipDistributionPainter(this.result);

  @override
  void paint(Canvas canvas, Size size) {
    final bins = result.bins.where((b) => b.weight > 0).toList(growable: false);
    if (bins.isEmpty || size.width <= 0 || size.height <= 0) return;

    final minPrice = result.bins.first.price;
    final maxPrice = result.bins.last.price;
    final maxRatio = bins.map((b) => b.ratio).fold<double>(0, math.max);
    final chartLeft = 72.0;
    final chartRight = size.width - 18.0;
    final chartTop = 14.0;
    final chartBottom = size.height - 24.0;
    final chartWidth = math.max(1.0, chartRight - chartLeft);
    final chartHeight = math.max(1.0, chartBottom - chartTop);

    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(Offset(chartLeft, chartTop), Offset(chartLeft, chartBottom), axisPaint);
    canvas.drawLine(Offset(chartLeft, chartBottom), Offset(chartRight, chartBottom), axisPaint);

    final barPaint = Paint()..color = const Color(0xFF42A5F5).withOpacity(0.70);
    final pocPaint = Paint()..color = const Color(0xFFFFB300).withOpacity(0.90);
    final currentPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..strokeWidth = 1.4;

    final barGap = chartHeight / result.bins.length;
    for (var i = 0; i < result.bins.length; i++) {
      final bin = result.bins[i];
      final y = chartBottom - (i + 0.5) * barGap;
      final w = maxRatio <= 0 ? 0.0 : chartWidth * (bin.ratio / maxRatio);
      final paint = (bin.price - result.pocPrice).abs() <= (maxPrice - minPrice) / result.bins.length
          ? pocPaint
          : barPaint;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chartLeft, y - math.max(1.0, barGap * 0.34), w, math.max(1.0, barGap * 0.68)),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    final currentY = _priceToY(result.currentPrice, minPrice, maxPrice, chartTop, chartBottom);
    canvas.drawLine(Offset(chartLeft, currentY), Offset(chartRight, currentY), currentPaint);
    _drawText(canvas, '现价 ${result.currentPrice.toStringAsFixed(2)}', Offset(chartRight - 94, currentY - 18), const Color(0xFF66BB6A));
    _drawText(canvas, '价格', Offset(18, chartTop), Colors.white54);
    _drawText(canvas, maxPrice.toStringAsFixed(2), Offset(12, chartTop + 4), Colors.white70);
    _drawText(canvas, minPrice.toStringAsFixed(2), Offset(12, chartBottom - 18), Colors.white70);
    _drawText(canvas, '筹码权重', Offset(chartLeft, size.height - 18), Colors.white54);
  }

  double _priceToY(double price, double minPrice, double maxPrice, double top, double bottom) {
    if ((maxPrice - minPrice).abs() < 1e-9) return (top + bottom) / 2;
    final t = ((price - minPrice) / (maxPrice - minPrice)).clamp(0.0, 1.0).toDouble();
    return bottom - (bottom - top) * t;
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 160);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ChipDistributionPainter oldDelegate) => oldDelegate.result != result;
}
