import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/fx.dart';
import '../../core/models/raw_bar.dart';

class KlineChart extends StatefulWidget {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showBi;
  final bool showZs;
  final int windowSize;
  final int? viewEndIndex;
  final int? crosshairIndex;
  final ValueChanged<int>? onCrosshairChanged;
  final ValueChanged<int>? onPanBars;
  final ValueChanged<int>? onWindowSizeChanged;

  const KlineChart({
    super.key,
    required this.snapshot,
    required this.showFx,
    required this.showBi,
    required this.showZs,
    required this.windowSize,
    this.viewEndIndex,
    this.crosshairIndex,
    this.onCrosshairChanged,
    this.onPanBars,
    this.onWindowSizeChanged,
  });

  @override
  State<KlineChart> createState() => _KlineChartState();
}

class _KlineChartState extends State<KlineChart> {
  int? _scaleStartWindow;
  double _panRemainder = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _updateCrosshair(details.localPosition, size),
          onLongPressStart: (details) =>
              _updateCrosshair(details.localPosition, size),
          onLongPressMoveUpdate: (details) =>
              _updateCrosshair(details.localPosition, size),
          onScaleStart: (_) {
            _scaleStartWindow = widget.windowSize;
            _panRemainder = 0;
          },
          onScaleUpdate: (details) {
            if (widget.snapshot.rawBars.isEmpty) return;
            if ((details.scale - 1).abs() > 0.03) {
              final base = _scaleStartWindow ?? widget.windowSize;
              final next = (base / details.scale).round().clamp(30, 260).toInt();
              if (next != widget.windowSize) {
                widget.onWindowSizeChanged?.call(next);
              }
              return;
            }

            final visible = _visibleMeta(size);
            if (visible == null || visible.step <= 0) return;
            _panRemainder += -details.focalPointDelta.dx / visible.step;
            final bars = _panRemainder.truncate();
            if (bars != 0) {
              widget.onPanBars?.call(bars);
              _panRemainder -= bars;
            }
          },
          child: CustomPaint(
            painter: KlinePainter(
              snapshot: widget.snapshot,
              showFx: widget.showFx,
              showBi: widget.showBi,
              showZs: widget.showZs,
              windowSize: widget.windowSize,
              viewEndIndex: widget.viewEndIndex,
              crosshairIndex: widget.crosshairIndex,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void _updateCrosshair(Offset localPosition, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null) return;
    if (!meta.chartRect.contains(localPosition)) return;
    final local = ((localPosition.dx - meta.chartRect.left) / meta.step).floor();
    final rawIndex = (meta.startIndex + local)
        .clamp(meta.startIndex, meta.endIndex)
        .toInt();
    widget.onCrosshairChanged?.call(rawIndex);
  }

  _VisibleMeta? _visibleMeta(Size size) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return null;

    final chartRect = KlinePainter.chartRectFor(size);
    final endIndex = (widget.viewEndIndex ?? bars.length - 1)
        .clamp(0, bars.length - 1)
        .toInt();
    final startIndex = math.max(0, endIndex - widget.windowSize + 1).toInt();
    final count = math.max(1, endIndex - startIndex + 1).toInt();
    final step = chartRect.width / count;
    return _VisibleMeta(
      chartRect: chartRect,
      startIndex: startIndex,
      endIndex: endIndex,
      step: step,
    );
  }
}

class _VisibleMeta {
  final Rect chartRect;
  final int startIndex;
  final int endIndex;
  final double step;

  const _VisibleMeta({
    required this.chartRect,
    required this.startIndex,
    required this.endIndex,
    required this.step,
  });
}

class KlinePainter extends CustomPainter {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showBi;
  final bool showZs;
  final int windowSize;
  final int? viewEndIndex;
  final int? crosshairIndex;

  KlinePainter({
    required this.snapshot,
    required this.showFx,
    required this.showBi,
    required this.showZs,
    required this.windowSize,
    this.viewEndIndex,
    this.crosshairIndex,
  });

  static const double _topPad = 24;
  static const double _bottomPad = 28;
  static const double _leftPad = 8;
  static const double _rightPad = 62;

  static Rect chartRectFor(Size size) {
    return Rect.fromLTWH(
      _leftPad,
      _topPad,
      math.max(0.0, size.width - _leftPad - _rightPad),
      math.max(0.0, size.height - _topPad - _bottomPad),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bars = snapshot.rawBars;
    if (bars.isEmpty) {
      _drawEmpty(canvas, size);
      return;
    }

    final endIndex = (viewEndIndex ?? bars.length - 1)
        .clamp(0, bars.length - 1)
        .toInt();
    final startIndex = math.max(0, endIndex - windowSize + 1).toInt();
    final visible = bars.sublist(startIndex, endIndex + 1);
    final chartRect = chartRectFor(size);
    if (chartRect.width <= 0 || chartRect.height <= 0) return;

    final low = visible.map((e) => e.low).reduce(math.min);
    final high = visible.map((e) => e.high).reduce(math.max);
    final padding = math.max((high - low) * 0.08, high.abs() * 0.001);
    final minPrice = low - padding;
    final maxPrice = high + padding;

    double priceToY(double price) {
      if ((maxPrice - minPrice).abs() < 1e-9) return chartRect.center.dy;
      return chartRect.bottom -
          (price - minPrice) / (maxPrice - minPrice) * chartRect.height;
    }

    final count = visible.length;
    final step = chartRect.width / math.max(1, count).toDouble();
    double rawToX(int rawIndex) {
      final local = rawIndex - startIndex;
      return chartRect.left + (local + 0.5) * step;
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B0D10));
    _drawGrid(canvas, chartRect, minPrice, maxPrice, priceToY);
    _drawCandles(canvas, visible, chartRect, step, priceToY);

    if (showZs) {
      _drawZs(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);
    }
    if (showBi) {
      _drawBi(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);
    }
    if (showFx) {
      _drawFx(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);
    }

    _drawLastPrice(canvas, chartRect, visible.last.close, priceToY);
    _drawTimeAxis(canvas, chartRect, visible, step);
    _drawHeader(canvas, size, visible.last.time, bars.length, snapshot);

    final cross = crosshairIndex;
    if (cross != null && cross >= startIndex && cross <= endIndex) {
      _drawCrosshair(canvas, chartRect, bars[cross], rawToX, priceToY);
    }
  }

  void _drawEmpty(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B0D10));
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
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, borderPaint);

    for (var i = 0; i <= 5; i++) {
      final y = rect.top + rect.height / 5 * i;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
      final price = maxPrice - (maxPrice - minPrice) / 5 * i;
      _drawText(canvas, price.toStringAsFixed(2), Offset(rect.right + 6, y - 8),
          11, Colors.white54);
    }

    for (var i = 1; i < 5; i++) {
      final x = rect.left + rect.width / 5 * i;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
  }

  void _drawCandles(
    Canvas canvas,
    List<RawBar> bars,
    Rect rect,
    double step,
    double Function(double) priceToY,
  ) {
    final upPaint = Paint()..color = const Color(0xFFEF5350);
    final downPaint = Paint()..color = const Color(0xFF26A69A);
    final wickPaint = Paint()..strokeWidth = 1;
    final candleWidth = math.max(1.5, math.min(14.0, step * 0.62));

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
      final x1 = rawToX(bi.startRawIndex).clamp(rect.left, rect.right).toDouble();
      final x2 = rawToX(bi.endRawIndex).clamp(rect.left, rect.right).toDouble();
      final y1 = priceToY(bi.startPrice).clamp(rect.top, rect.bottom).toDouble();
      final y2 = priceToY(bi.endPrice).clamp(rect.top, rect.bottom).toDouble();
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
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
      ..color = const Color(0xFF2962FF).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF5B8DFF).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (final zs in snapshot.zss) {
      if (zs.endRawIndex < startRaw || zs.startRawIndex > endRaw) continue;
      final left = rawToX(math.max(zs.startRawIndex, startRaw).toInt())
          .clamp(rect.left, rect.right)
          .toDouble();
      final right = rawToX(math.min(zs.endRawIndex, endRaw).toInt())
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

  void _drawLastPrice(
    Canvas canvas,
    Rect rect,
    double close,
    double Function(double) priceToY,
  ) {
    final y = priceToY(close).clamp(rect.top, rect.bottom).toDouble();
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), linePaint);

    final labelRect = Rect.fromLTWH(rect.right + 2, y - 10, 56, 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF2962FF),
    );
    _drawText(canvas, close.toStringAsFixed(2), Offset(labelRect.left + 4, y - 7),
        11, Colors.white);
  }

  void _drawTimeAxis(Canvas canvas, Rect rect, List<RawBar> visible, double step) {
    if (visible.isEmpty) return;
    final labelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final n = math.min(4, visible.length - 1).toInt();
    if (n <= 0) return;
    for (var i = 0; i <= n; i++) {
      final idx = (i * (visible.length - 1) / n).round();
      final x = rect.left + (idx + 0.5) * step;
      canvas.drawLine(Offset(x, rect.bottom), Offset(x, rect.bottom + 4), labelPaint);
      _drawText(canvas, _fmtDate(visible[idx].time), Offset(x - 30, rect.bottom + 7),
          10, Colors.white38);
    }
  }

  void _drawCrosshair(
    Canvas canvas,
    Rect rect,
    RawBar bar,
    double Function(int) rawToX,
    double Function(double) priceToY,
  ) {
    final x = rawToX(bar.index).clamp(rect.left, rect.right).toDouble();
    final y = priceToY(bar.close).clamp(rect.top, rect.bottom).toDouble();
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);

    final label =
        '${_fmtDate(bar.time)}  O:${bar.open.toStringAsFixed(2)} H:${bar.high.toStringAsFixed(2)} L:${bar.low.toStringAsFixed(2)} C:${bar.close.toStringAsFixed(2)} V:${bar.volume.toStringAsFixed(0)}';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 12);
    final box = Rect.fromLTWH(rect.left + 8, rect.top + 8, tp.width + 12, 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = const Color(0xDD131722),
    );
    tp.paint(canvas, Offset(box.left + 6, box.top + 5));
  }

  void _drawHeader(Canvas canvas, Size size, DateTime time, int count,
      ChanSnapshot snapshot) {
    final text =
        'K:$count  合并:${snapshot.mergedBars.length}  分型:${snapshot.fxs.length}  笔:${snapshot.bis.length}  中枢:${snapshot.zss.length}  ${_fmtDate(time)}';
    _drawText(canvas, text, const Offset(10, 4), 12, Colors.white70);
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
        oldDelegate.windowSize != windowSize ||
        oldDelegate.viewEndIndex != viewEndIndex ||
        oldDelegate.crosshairIndex != crosshairIndex;
  }
}
