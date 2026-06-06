import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/fx.dart';

class KlineChart extends StatelessWidget {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showBi;
  final bool showZs;
  final int windowSize;

  const KlineChart({
    super.key,
    required this.snapshot,
    required this.showFx,
    required this.showBi,
    required this.showZs,
    required this.windowSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: KlinePainter(
        snapshot: snapshot,
        showFx: showFx,
        showBi: showBi,
        showZs: showZs,
        windowSize: windowSize,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class KlinePainter extends CustomPainter {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showBi;
  final bool showZs;
  final int windowSize;

  KlinePainter({
    required this.snapshot,
    required this.showFx,
    required this.showBi,
    required this.showZs,
    required this.windowSize,
  });

  static const double _topPad = 18;
  static const double _bottomPad = 24;
  static const double _leftPad = 8;
  static const double _rightPad = 58;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = snapshot.rawBars;
    if (bars.isEmpty) {
      _drawEmpty(canvas, size);
      return;
    }

    final startIndex = math.max(0, bars.length - windowSize);
    final visible = bars.sublist(startIndex);
    final chartRect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      size.width - _leftPad - _rightPad,
      size.height - _topPad - _bottomPad,
    );

    final low = visible.map((e) => e.low).reduce(math.min);
    final high = visible.map((e) => e.high).reduce(math.max);
    final padding = (high - low) * 0.08;
    final minPrice = low - padding;
    final maxPrice = high + padding;

    double priceToY(double price) {
      if ((maxPrice - minPrice).abs() < 1e-9) return chartRect.center.dy;
      return chartRect.bottom -
          (price - minPrice) / (maxPrice - minPrice) * chartRect.height;
    }

    final count = visible.length;
    final step = chartRect.width / math.max(1, count);
    double rawToX(int rawIndex) {
      final local = rawIndex - startIndex;
      return chartRect.left + (local + 0.5) * step;
    }

    _drawGrid(canvas, chartRect, minPrice, maxPrice, priceToY);
    _drawCandles(canvas, visible, chartRect, step, priceToY);

    if (showZs) {
      _drawZs(canvas, chartRect, startIndex, bars.length - 1, rawToX, priceToY);
    }
    if (showBi) {
      _drawBi(canvas, chartRect, startIndex, bars.length - 1, rawToX, priceToY);
    }
    if (showFx) {
      _drawFx(canvas, chartRect, startIndex, bars.length - 1, rawToX, priceToY);
    }

    _drawHeader(canvas, size, visible.last.time, bars.length, snapshot);
  }

  void _drawEmpty(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: const TextSpan(
          text: '暂无K线数据',
          style: TextStyle(color: Colors.white70, fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas,
        Offset((size.width - painter.width) / 2,
            (size.height - painter.height) / 2));
  }

  void _drawGrid(
    Canvas canvas,
    Rect rect,
    double minPrice,
    double maxPrice,
    double Function(double) priceToY,
  ) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, borderPaint);

    for (var i = 0; i <= 4; i++) {
      final y = rect.top + rect.height / 4 * i;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      final price = maxPrice - (maxPrice - minPrice) / 4 * i;
      _drawText(canvas, price.toStringAsFixed(2), Offset(rect.right + 6, y - 8),
          11, Colors.white54);
    }
  }

  void _drawCandles(
    Canvas canvas,
    List<dynamic> bars,
    Rect rect,
    double step,
    double Function(double) priceToY,
  ) {
    final upPaint = Paint()..color = const Color(0xFFEF5350);
    final downPaint = Paint()..color = const Color(0xFF26A69A);
    final wickPaint = Paint()..strokeWidth = 1;
    final candleWidth = math.max(2.0, step * 0.58);

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final x = rect.left + (i + 0.5) * step;
      final isUp = bar.close >= bar.open;
      final paint = isUp ? upPaint : downPaint;
      wickPaint.color = paint.color;

      final highY = priceToY(bar.high);
      final lowY = priceToY(bar.low);
      final openY = priceToY(bar.open);
      final closeY = priceToY(bar.close);
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      final top = math.min(openY, closeY);
      final bottom = math.max(openY, closeY);
      final rectBody = Rect.fromLTRB(
        x - candleWidth / 2,
        top,
        x + candleWidth / 2,
        math.max(bottom, top + 1),
      );
      canvas.drawRect(rectBody, paint);
    }
  }

  void _drawFx(
    Canvas canvas,
    Rect rect,
    int startRaw,
    int endRaw,
    double Function(int) rawToX,
    double Function(double) priceToY,
  ) {
    final topPaint = Paint()..color = const Color(0xFFFFCA28);
    final bottomPaint = Paint()..color = const Color(0xFF42A5F5);
    for (final fx in snapshot.fxs) {
      if (fx.rawIndex < startRaw || fx.rawIndex > endRaw) continue;
      final x = rawToX(fx.rawIndex);
      final y = priceToY(fx.price);
      final paint = fx.type == FxType.top ? topPaint : bottomPaint;
      canvas.drawCircle(Offset(x, y), 4, paint);
      _drawText(canvas, fx.type == FxType.top ? '顶' : '底',
          Offset(x - 6, y + (fx.isTop ? -20 : 8)), 11, paint.color);
    }
  }

  void _drawBi(
    Canvas canvas,
    Rect rect,
    int startRaw,
    int endRaw,
    double Function(int) rawToX,
    double Function(double) priceToY,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 1.8;
    for (final bi in snapshot.bis) {
      if (bi.endRawIndex < startRaw || bi.startRawIndex > endRaw) continue;
      final x1 = rawToX(bi.startRawIndex).clamp(rect.left, rect.right);
      final x2 = rawToX(bi.endRawIndex).clamp(rect.left, rect.right);
      final y1 = priceToY(bi.startPrice).clamp(rect.top, rect.bottom);
      final y2 = priceToY(bi.endPrice).clamp(rect.top, rect.bottom);
      canvas.drawLine(Offset(x1.toDouble(), y1.toDouble()),
          Offset(x2.toDouble(), y2.toDouble()), paint);
    }
  }

  void _drawZs(
    Canvas canvas,
    Rect rect,
    int startRaw,
    int endRaw,
    double Function(int) rawToX,
    double Function(double) priceToY,
  ) {
    final fill = Paint()
      ..color = const Color(0xFF9C27B0).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFAB47BC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final zs in snapshot.zss) {
      if (zs.endRawIndex < startRaw || zs.startRawIndex > endRaw) continue;
      final left = rawToX(math.max(zs.startRawIndex, startRaw))
          .clamp(rect.left, rect.right)
          .toDouble();
      final right = rawToX(math.min(zs.endRawIndex, endRaw))
          .clamp(rect.left, rect.right)
          .toDouble();
      final top = priceToY(zs.zg).clamp(rect.top, rect.bottom).toDouble();
      final bottom = priceToY(zs.zd).clamp(rect.top, rect.bottom).toDouble();
      final r = Rect.fromLTRB(
          left, top, math.max(left + 1, right), math.max(top + 1, bottom));
      canvas.drawRect(r, fill);
      canvas.drawRect(r, stroke);
      _drawText(canvas, 'ZS${zs.index + 1}', Offset(left + 3, top + 3), 10,
          Colors.white70);
    }
  }

  void _drawHeader(Canvas canvas, Size size, DateTime time, int count,
      ChanSnapshot snapshot) {
    final text =
        'K:$count  合并:${snapshot.mergedBars.length}  分型:${snapshot.fxs.length}  笔:${snapshot.bis.length}  中枢:${snapshot.zss.length}  ${_fmtDate(time)}';
    _drawText(canvas, text, const Offset(10, 2), 12, Colors.white70);
  }

  void _drawText(
      Canvas canvas, String text, Offset offset, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  bool shouldRepaint(covariant KlinePainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.showFx != showFx ||
        oldDelegate.showBi != showBi ||
        oldDelegate.showZs != showZs ||
        oldDelegate.windowSize != windowSize;
  }
}
