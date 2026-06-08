import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/models/bsp.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/fx.dart';
import '../../core/models/raw_bar.dart';

class OriginKlineChart extends StatefulWidget {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showFxLine;
  final bool showFxText;
  final bool showBi;
  final bool showBiText;
  final bool showSeg;
  final bool showSegText;
  final bool showZs;
  final bool showBsp;
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
    required this.showBsp,
    required this.windowSize,
    this.priceScale = 1.0,
    this.viewEndIndex,
    this.crosshairIndex,
    this.onCrosshairChanged,
    this.onPanBars,
    this.onWindowSizeChanged,
    this.onPriceScaleChanged,
  });

  @override
  State<OriginKlineChart> createState() => _OriginKlineChartState();
}

class _OriginKlineChartState extends State<OriginKlineChart> {
  int? _scaleStartWindow;
  double _panRemainder = 0;

  @override
  Widget build(BuildContext context) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty) {
      return const Center(child: Text('暂无K线数据', style: TextStyle(color: Colors.white70)));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) _handleWheel(event, size);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _updateCrosshair(details.localPosition, size),
          onLongPressStart: (details) => _updateCrosshair(details.localPosition, size),
          onLongPressMoveUpdate: (details) => _updateCrosshair(details.localPosition, size),
          onScaleStart: (_) {
            _scaleStartWindow = widget.windowSize;
            _panRemainder = 0;
          },
          onScaleUpdate: (details) => _handleScale(details, size),
          child: CustomPaint(
            painter: _OriginChartPainter(
              snapshot: widget.snapshot,
              showFx: widget.showFx,
              showFxLine: widget.showFxLine,
              showFxText: widget.showFxText,
              showBi: widget.showBi,
              showBiText: widget.showBiText,
              showSeg: widget.showSeg,
              showSegText: widget.showSegText,
              showZs: widget.showZs,
              showBsp: widget.showBsp,
              windowSize: widget.windowSize,
              priceScale: widget.priceScale,
              viewEndIndex: widget.viewEndIndex,
              crosshairIndex: widget.crosshairIndex,
            ),
            size: Size.infinite,
          ),
        ),
      );
    });
  }

  void _handleWheel(PointerScrollEvent event, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null || !meta.chartRect.contains(event.localPosition) || event.scrollDelta.dy == 0) return;
    final factor = event.scrollDelta.dy < 0 ? 0.88 : 1.12;
    final nextWindow = (widget.windowSize * factor).round().clamp(24, 360).toInt();
    if (nextWindow != widget.windowSize) widget.onWindowSizeChanged?.call(nextWindow);
  }

  void _handleScale(ScaleUpdateDetails details, Size size) {
    if ((details.scale - 1).abs() > 0.03) {
      final nextWindow = ((_scaleStartWindow ?? widget.windowSize) / details.scale).round().clamp(24, 360).toInt();
      if (nextWindow != widget.windowSize) widget.onWindowSizeChanged?.call(nextWindow);
      return;
    }
    final dx = details.focalPointDelta.dx;
    final dy = details.focalPointDelta.dy;
    if (details.pointerCount == 1 && dy.abs() > dx.abs() * 1.4 && dy.abs() > 1.5) {
      widget.onPriceScaleChanged?.call((widget.priceScale * (1 + (-dy / 240))).clamp(0.35, 5.0).toDouble());
      return;
    }
    final visible = _visibleMeta(size);
    if (visible == null || visible.step <= 0 || dx.abs() <= 0.2) return;
    _panRemainder += -dx / visible.step;
    final panBars = _panRemainder.truncate();
    if (panBars != 0) {
      widget.onPanBars?.call(panBars);
      _panRemainder -= panBars;
    }
  }

  void _updateCrosshair(Offset p, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null || !meta.chartRect.contains(p)) return;
    final local = ((p.dx - meta.chartRect.left) / meta.step).floor();
    widget.onCrosshairChanged?.call((meta.startIndex + local).clamp(meta.startIndex, meta.endIndex).toInt());
  }

  _VisibleMeta? _visibleMeta(Size size) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return null;
    final rect = _OriginChartPainter.chartRectFor(size);
    final end = (widget.viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final start = math.max(0, end - widget.windowSize + 1).toInt();
    return _VisibleMeta(rect, start, end, rect.width / math.max(1, end - start + 1));
  }
}

class _VisibleMeta {
  final Rect chartRect;
  final int startIndex;
  final int endIndex;
  final double step;
  const _VisibleMeta(this.chartRect, this.startIndex, this.endIndex, this.step);
}

class _OriginChartPainter extends CustomPainter {
  static const double _topPad = 32;
  static const double _bottomPad = 28;
  static const double _leftPad = 4;
  static const double _rightPad = 58;

  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showFxLine;
  final bool showFxText;
  final bool showBi;
  final bool showBiText;
  final bool showSeg;
  final bool showSegText;
  final bool showZs;
  final bool showBsp;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final int? crosshairIndex;

  _OriginChartPainter({
    required this.snapshot,
    required this.showFx,
    required this.showFxLine,
    required this.showFxText,
    required this.showBi,
    required this.showBiText,
    required this.showSeg,
    required this.showSegText,
    required this.showZs,
    required this.showBsp,
    required this.windowSize,
    required this.priceScale,
    this.viewEndIndex,
    this.crosshairIndex,
  });

  static Rect chartRectFor(Size size) => Rect.fromLTWH(_leftPad, _topPad, math.max(0, size.width - _leftPad - _rightPad), math.max(0, size.height - _topPad - _bottomPad));

  @override
  void paint(Canvas canvas, Size size) {
    final bars = snapshot.rawBars;
    if (bars.isEmpty) return;
    final rect = chartRectFor(size);
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
    double priceToY(double price) => rect.bottom - (price - minPrice) / (maxPrice - minPrice) * rect.height;
    final step = rect.width / math.max(1, visible.length);
    double rawToX(int rawIndex) => rect.left + (rawIndex - start + 0.5) * step;

    _drawGrid(canvas, rect, minPrice, maxPrice, visible);
    _drawCandles(canvas, rect, visible, rawToX, priceToY, step);
    if (showZs) _drawZs(canvas, rect, start, end, rawToX, priceToY);
    if (showFxLine) _drawFxLine(canvas, rect, start, end, rawToX, priceToY);
    if (showBi) _drawBi(canvas, rect, start, end, rawToX, priceToY);
    if (showSeg) _drawSeg(canvas, rect, start, end, rawToX, priceToY);
    if (showBsp) _drawBsp(canvas, rect, start, end, rawToX, priceToY);
    if (showFx) _drawFx(canvas, rect, start, end, rawToX, priceToY);
    final cross = crosshairIndex;
    if (cross != null && cross >= start && cross <= end) {
      _drawCrosshair(canvas, rect, bars[cross], rawToX, priceToY);
    } else {
      _drawText(canvas, 'chan.py ${_fmtDate(visible.last.time)} | K:${bars.length} MB:${snapshot.mergedBars.length} FX:${snapshot.fxs.length} BI:${snapshot.bis.length} SEG:${snapshot.segs.length} ZS:${snapshot.zss.length} BSP:${snapshot.bsps.length}', const Offset(8, 4), 11, Colors.white70);
    }
  }

  void _drawGrid(Canvas canvas, Rect rect, double minPrice, double maxPrice, List<RawBar> visible) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 0.7;
    for (var i = 0; i <= 4; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
      _drawText(canvas, (maxPrice - (maxPrice - minPrice) * i / 4).toStringAsFixed(2), Offset(rect.right + 5, y - 7), 10, Colors.white54);
    }
    _drawText(canvas, _fmtDate(visible.first.time), Offset(rect.left, rect.bottom + 6), 10, Colors.white38);
    _drawText(canvas, _fmtDate(visible.last.time), Offset(rect.right - 62, rect.bottom + 6), 10, Colors.white38);
  }

  void _drawCandles(Canvas canvas, Rect rect, List<RawBar> visible, double Function(int) rawToX, double Function(double) priceToY, double step) {
    final up = Paint()..color = const Color(0xFF26A69A);
    final down = Paint()..color = const Color(0xFFEF5350);
    final wick = Paint()..strokeWidth = math.max(1.0, step * 0.08);
    final bodyWidth = math.max(1.0, math.min(step * 0.68, step - 1));
    for (final bar in visible) {
      final x = rawToX(bar.index);
      final paint = bar.close >= bar.open ? up : down;
      wick.color = paint.color;
      canvas.drawLine(Offset(x, priceToY(bar.high).clamp(rect.top, rect.bottom).toDouble()), Offset(x, priceToY(bar.low).clamp(rect.top, rect.bottom).toDouble()), wick);
      final openY = priceToY(bar.open).clamp(rect.top, rect.bottom).toDouble();
      final closeY = priceToY(bar.close).clamp(rect.top, rect.bottom).toDouble();
      canvas.drawRect(Rect.fromLTRB(x - bodyWidth / 2, math.min(openY, closeY), x + bodyWidth / 2, math.max(math.min(openY, closeY) + 1, math.max(openY, closeY))), paint);
    }
  }

  void _drawFxLine(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    final rows = snapshot.fxs.where((e) => e.rawIndex >= start && e.rawIndex <= end).toList()..sort((a, b) => a.rawIndex.compareTo(b.rawIndex));
    if (rows.length < 2) return;
    final path = Path();
    for (var i = 0; i < rows.length; i++) {
      final p = Offset(rawToX(rows[i].rawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(rows[i].price).clamp(rect.top, rect.bottom).toDouble());
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.46)..strokeWidth = 1.15..style = PaintingStyle.stroke);
  }

  void _drawFx(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    for (final fx in snapshot.fxs) {
      if (fx.rawIndex < start || fx.rawIndex > end) continue;
      final color = fx.type == FxType.top ? const Color(0xFFFFCA28) : const Color(0xFF42A5F5);
      final p = Offset(rawToX(fx.rawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(fx.price).clamp(rect.top, rect.bottom).toDouble());
      canvas.drawCircle(p, 4, Paint()..color = color);
      if (showFxText) _drawText(canvas, fx.isTop ? '顶' : '底', Offset(p.dx - 6, p.dy + (fx.isTop ? -20 : 8)), 11, color);
    }
  }

  void _drawBi(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    final paint = Paint()..color = const Color(0xFFE53935)..strokeWidth = 1.45;
    for (final bi in snapshot.bis) {
      if (bi.endRawIndex < start || bi.startRawIndex > end) continue;
      final p1 = Offset(rawToX(bi.startRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(bi.startPrice).clamp(rect.top, rect.bottom).toDouble());
      final p2 = Offset(rawToX(bi.endRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(bi.endPrice).clamp(rect.top, rect.bottom).toDouble());
      canvas.drawLine(p1, p2, paint);
      if (showBiText) _drawText(canvas, 'B${bi.index + 1}', Offset(p2.dx - 12, p2.dy + (bi.isUp ? -18 : 6)), 10, const Color(0xFFFF8A80));
    }
  }

  void _drawSeg(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    for (final seg in snapshot.segs) {
      if (seg.endRawIndex < start || seg.startRawIndex > end) continue;
      final paint = Paint()..color = (seg.isSure ? const Color(0xFF00E676) : const Color(0xFFB2FF59)).withValues(alpha: seg.isSure ? 0.92 : 0.62)..strokeWidth = seg.isSure ? 2.6 : 1.6;
      final p1 = Offset(rawToX(seg.startRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(seg.startPrice).clamp(rect.top, rect.bottom).toDouble());
      final p2 = Offset(rawToX(seg.endRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(seg.endPrice).clamp(rect.top, rect.bottom).toDouble());
      canvas.drawLine(p1, p2, paint);
      if (showSegText) _drawText(canvas, 'S${seg.index + 1}${seg.isSure ? '' : '?'}', Offset(p2.dx - 14, p2.dy + (seg.isUp ? -20 : 8)), 10, Colors.white70);
    }
  }

  void _drawZs(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    final fill = Paint()..color = const Color(0xFF2962FF).withValues(alpha: 0.10)..style = PaintingStyle.fill;
    final stroke = Paint()..color = const Color(0xFF5B8DFF).withValues(alpha: 0.85)..style = PaintingStyle.stroke..strokeWidth = 1.1;
    for (final zs in snapshot.zss) {
      if (zs.endRawIndex < start || zs.startRawIndex > end) continue;
      final left = rawToX(zs.startRawIndex).clamp(rect.left, rect.right).toDouble();
      final right = rawToX(zs.endRawIndex).clamp(rect.left, rect.right).toDouble();
      final top = priceToY(zs.zg).clamp(rect.top, rect.bottom).toDouble();
      final bottom = priceToY(zs.zd).clamp(rect.top, rect.bottom).toDouble();
      final area = Rect.fromLTRB(math.min(left, right), math.min(top, bottom), math.max(left, right), math.max(top, bottom));
      canvas.drawRect(area, fill);
      canvas.drawRect(area, stroke);
      _drawText(canvas, 'ZS${zs.index + 1}', Offset(area.left + 3, area.top + 3), 10, const Color(0xFF82B1FF));
    }
  }

  void _drawBsp(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    for (final bsp in snapshot.bsps) {
      if (bsp.rawIndex < start || bsp.rawIndex > end) continue;
      final color = bsp.isSell ? const Color(0xFFFF7043) : const Color(0xFF00E676);
      final x = rawToX(bsp.rawIndex).clamp(rect.left, rect.right).toDouble();
      final y = priceToY(bsp.price).clamp(rect.top, rect.bottom).toDouble();
      final path = Path();
      if (bsp.isSell) {
        path.moveTo(x, y - 7); path.lineTo(x - 6, y + 5); path.lineTo(x + 6, y + 5);
      } else {
        path.moveTo(x, y + 7); path.lineTo(x - 6, y - 5); path.lineTo(x + 6, y - 5);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
      _drawText(canvas, bsp.type, Offset(x + 5, y + (bsp.isSell ? -18 : 8)), 9, color);
    }
  }

  void _drawCrosshair(Canvas canvas, Rect rect, RawBar bar, double Function(int) rawToX, double Function(double) priceToY) {
    final x = rawToX(bar.index).clamp(rect.left, rect.right).toDouble();
    final y = priceToY(bar.close).clamp(rect.top, rect.bottom).toDouble();
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.52)..strokeWidth = 0.8;
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    _drawText(canvas, 'O:${bar.open.toStringAsFixed(2)} H:${bar.high.toStringAsFixed(2)} L:${bar.low.toStringAsFixed(2)} C:${bar.close.toStringAsFixed(2)} V:${bar.volume.toStringAsFixed(0)}', Offset(rect.left + 6, rect.top - 20), 11, Colors.white);
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color) {
    final painter = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: 520);
    painter.paint(canvas, offset);
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(covariant _OriginChartPainter old) => true;
}
