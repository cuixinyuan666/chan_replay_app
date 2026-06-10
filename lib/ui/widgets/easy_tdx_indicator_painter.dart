import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/easy_tdx_indicator.dart';

class EasyTdxIndicatorPainter extends CustomPainter {
  final ChanSnapshot snapshot;
  final Rect chartRect;
  final int startIndex;
  final int endIndex;
  final double Function(int rawIndex) rawToX;
  final double Function(double price) priceToY;
  final Set<String> enabledIndicators;

  const EasyTdxIndicatorPainter({
    required this.snapshot,
    required this.chartRect,
    required this.startIndex,
    required this.endIndex,
    required this.rawToX,
    required this.priceToY,
    required this.enabledIndicators,
  });

  bool get enabled => enabledIndicators.contains('easy-tdx') || enabledIndicators.contains('EASY_TDX') || enabledIndicators.contains('easyTdxIndicators');

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshot.indicators.isEmpty || chartRect.isEmpty) return;
    canvas.save();
    canvas.clipRect(chartRect);
    if (_on('MA')) _drawMa(canvas);
    if (_on('BOLL')) _drawBoll(canvas);
    canvas.restore();
  }

  bool _on(String key) => enabledIndicators.contains(key) || enabledIndicators.contains(key.toLowerCase());

  void _drawMa(Canvas canvas) {
    final colors = <int, Color>{
      5: const Color(0xFFFFD54F),
      10: const Color(0xFF64B5F6),
      20: const Color(0xFFBA68C8),
      60: const Color(0xFFFF8A65),
    };
    final keys = snapshot.indicators.ma.keys.toList()..sort();
    for (final period in keys) {
      final rows = snapshot.indicators.ma[period] ?? const <EasyIndicatorPoint>[];
      _drawPointLine(
        canvas,
        rows,
        colors[period] ?? const Color(0xFFB0BEC5),
        strokeWidth: period <= 10 ? 1.05 : 0.95,
      );
    }
    _drawLegend(canvas, 'MA ${keys.join('/')}');
  }

  void _drawBoll(Canvas canvas) {
    final upper = <EasyIndicatorPoint>[];
    final mid = <EasyIndicatorPoint>[];
    final lower = <EasyIndicatorPoint>[];
    for (final row in snapshot.indicators.boll) {
      upper.add(EasyIndicatorPoint(time: row.time, rawIndex: row.rawIndex, value: row.upper));
      mid.add(EasyIndicatorPoint(time: row.time, rawIndex: row.rawIndex, value: row.mid));
      lower.add(EasyIndicatorPoint(time: row.time, rawIndex: row.rawIndex, value: row.lower));
    }
    _drawPointLine(canvas, upper, const Color(0xFF90CAF9), strokeWidth: 0.85);
    _drawPointLine(canvas, mid, const Color(0xFFE0E0E0), strokeWidth: 0.75);
    _drawPointLine(canvas, lower, const Color(0xFF90CAF9), strokeWidth: 0.85);
    _drawLegend(canvas, 'BOLL', dy: 15);
  }

  void _drawPointLine(Canvas canvas, List<EasyIndicatorPoint> rows, Color color, {double strokeWidth = 1.0}) {
    final path = Path();
    var started = false;
    for (final row in rows) {
      final value = row.value;
      if (value == null || row.rawIndex < startIndex || row.rawIndex > endIndex) {
        started = false;
        continue;
      }
      final p = Offset(
        rawToX(row.rawIndex).clamp(chartRect.left, chartRect.right).toDouble(),
        priceToY(value).clamp(chartRect.top, chartRect.bottom).toDouble(),
      );
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (!started && path.computeMetrics().isEmpty) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawLegend(Canvas canvas, String text, {double dy = 0}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 10.5)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: math.max(0, chartRect.width - 12));
    painter.paint(canvas, Offset(chartRect.left + 8, chartRect.top + 6 + dy));
  }

  @override
  bool shouldRepaint(covariant EasyTdxIndicatorPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.chartRect != chartRect ||
        oldDelegate.startIndex != startIndex ||
        oldDelegate.endIndex != endIndex ||
        oldDelegate.enabledIndicators != enabledIndicators;
  }
}
