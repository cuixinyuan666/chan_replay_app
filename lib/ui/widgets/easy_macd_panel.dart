import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/easy_tdx_indicator.dart';

class EasyMacdPanel extends StatelessWidget {
  final ChanSnapshot snapshot;
  final int windowSize;
  final int? viewEndIndex;

  const EasyMacdPanel({
    super.key,
    required this.snapshot,
    required this.windowSize,
    this.viewEndIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.rawBars.isEmpty) {
      return const Center(
        child: Text('暂无 MACD 数据', style: TextStyle(color: Colors.white54)),
      );
    }
    return CustomPaint(
      painter: _EasyMacdPainter(
        snapshot: snapshot,
        windowSize: windowSize,
        viewEndIndex: viewEndIndex,
      ),
      size: Size.infinite,
    );
  }
}

class _EasyMacdPainter extends CustomPainter {
  static const double _topPad = 12;
  static const double _bottomPad = 20;
  static const double _leftPad = 4;
  static const double _rightPad = 58;

  final ChanSnapshot snapshot;
  final int windowSize;
  final int? viewEndIndex;

  const _EasyMacdPainter({
    required this.snapshot,
    required this.windowSize,
    this.viewEndIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bars = snapshot.rawBars;
    final macd = snapshot.indicators.macd;
    final rect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      math.max(0.0, size.width - _leftPad - _rightPad),
      math.max(0.0, size.height - _topPad - _bottomPad),
    );
    if (bars.isEmpty || macd.isEmpty || rect.width <= 0 || rect.height <= 0) {
      _drawText(canvas, 'MACD：暂无 easy-tdx 指标数据', const Offset(8, 8), 11, Colors.white54);
      return;
    }

    final end = (viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final start = math.max(0, end - windowSize + 1).toInt();
    final visible = macd
        .where((e) => e.rawIndex >= start && e.rawIndex <= end)
        .toList()
      ..sort((a, b) => a.rawIndex.compareTo(b.rawIndex));
    if (visible.isEmpty) {
      _drawText(canvas, 'MACD：当前窗口无指标数据', const Offset(8, 8), 11, Colors.white54);
      return;
    }

    final values = <double>[];
    for (final p in visible) {
      if (p.dif != null) values.add(p.dif!);
      if (p.dea != null) values.add(p.dea!);
      if (p.hist != null) values.add(p.hist!);
    }
    if (values.isEmpty) {
      _drawText(canvas, 'MACD：指标值为空', const Offset(8, 8), 11, Colors.white54);
      return;
    }
    final maxAbs = math.max(values.map((e) => e.abs()).reduce(math.max), 0.000001);
    final minVal = -maxAbs * 1.18;
    final maxVal = maxAbs * 1.18;
    final step = rect.width / math.max(1, end - start + 1);

    double rawToX(int rawIndex) => rect.left + (rawIndex - start + 0.5) * step;
    double valueToY(double value) => rect.bottom - (value - minVal) / math.max(maxVal - minVal, 0.000001) * rect.height;

    _drawGrid(canvas, rect, minVal, maxVal, valueToY);
    _drawHist(canvas, rect, visible, rawToX, valueToY, step);
    _drawLine(canvas, rect, visible, rawToX, valueToY, (p) => p.dif, const Color(0xFFFFD54F));
    _drawLine(canvas, rect, visible, rawToX, valueToY, (p) => p.dea, const Color(0xFF42A5F5));
    _drawText(canvas, 'MACD(easy-tdx)  DIF  DEA  HIST', Offset(rect.left + 6, 0), 11, Colors.white70);
  }

  void _drawGrid(Canvas canvas, Rect rect, double minVal, double maxVal, double Function(double) valueToY) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.7;
    for (var i = 0; i <= 2; i++) {
      final y = rect.top + rect.height * i / 2;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      final label = (maxVal - (maxVal - minVal) * i / 2).toStringAsFixed(2);
      _drawText(canvas, label, Offset(rect.right + 5, y - 7), 10, Colors.white38);
    }
    final zeroY = valueToY(0).clamp(rect.top, rect.bottom).toDouble();
    canvas.drawLine(
      Offset(rect.left, zeroY),
      Offset(rect.right, zeroY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 0.8,
    );
  }

  void _drawHist(
    Canvas canvas,
    Rect rect,
    List<EasyMacdPoint> visible,
    double Function(int) rawToX,
    double Function(double) valueToY,
    double step,
  ) {
    final width = math.max(1.0, math.min(step * 0.62, step - 1));
    final zeroY = valueToY(0).clamp(rect.top, rect.bottom).toDouble();
    for (final p in visible) {
      final hist = p.hist;
      if (hist == null) continue;
      final x = rawToX(p.rawIndex);
      final y = valueToY(hist).clamp(rect.top, rect.bottom).toDouble();
      final paint = Paint()
        ..color = (hist >= 0 ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withValues(alpha: 0.72);
      canvas.drawRect(
        Rect.fromLTRB(x - width / 2, math.min(y, zeroY), x + width / 2, math.max(y, zeroY)),
        paint,
      );
    }
  }

  void _drawLine(
    Canvas canvas,
    Rect rect,
    List<EasyMacdPoint> visible,
    double Function(int) rawToX,
    double Function(double) valueToY,
    double? Function(EasyMacdPoint) pick,
    Color color,
  ) {
    final path = Path();
    var hasPoint = false;
    for (final p in visible) {
      final value = pick(p);
      if (value == null) continue;
      final x = rawToX(p.rawIndex).clamp(rect.left, rect.right).toDouble();
      final y = valueToY(value).clamp(rect.top, rect.bottom).toDouble();
      if (!hasPoint) {
        path.moveTo(x, y);
        hasPoint = true;
      } else {
        path.lineTo(x, y);
      }
    }
    if (!hasPoint) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.15
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, double size, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 520);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _EasyMacdPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.windowSize != windowSize ||
      oldDelegate.viewEndIndex != viewEndIndex;
}
