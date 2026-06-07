import 'dart:math' as math;

import 'package:candlesticks/candlesticks.dart';
import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/fx.dart';
import '../../core/models/raw_bar.dart';

class KlineChart extends StatefulWidget {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showFxLine;
  final bool showFxText;
  final bool showBi;
  final bool showBiText;
  final bool showSeg;
  final bool showSegText;
  final bool showZs;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final int? crosshairIndex;
  final ValueChanged<int>? onCrosshairChanged;
  final ValueChanged<int>? onPanBars;
  final ValueChanged<int>? onWindowSizeChanged;
  final ValueChanged<double>? onPriceScaleChanged;

  const KlineChart({
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
  State<KlineChart> createState() => _KlineChartState();
}

class _KlineChartState extends State<KlineChart> {
  int? _scaleStartWindow;
  double _panRemainder = 0;

  @override
  Widget build(BuildContext context) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty) {
      return const Center(
        child: Text('暂无K线数据', style: TextStyle(color: Colors.white70)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final meta = _visibleMeta(size);
        if (meta == null) return const SizedBox.expand();
        final visibleBars = bars.sublist(meta.startIndex, meta.endIndex + 1);
        final candles = visibleBars.reversed.map(_toCandle).toList(growable: false);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _updateCrosshair(details.localPosition, size),
          onLongPressStart: (details) => _updateCrosshair(details.localPosition, size),
          onLongPressMoveUpdate: (details) => _updateCrosshair(details.localPosition, size),
          onScaleStart: (_) {
            _scaleStartWindow = widget.windowSize;
            _panRemainder = 0;
          },
          onScaleUpdate: (details) {
            if (widget.snapshot.rawBars.isEmpty) return;
            if ((details.scale - 1).abs() > 0.03) {
              final baseWindow = _scaleStartWindow ?? widget.windowSize;
              final nextWindow = (baseWindow / details.scale).round().clamp(24, 360).toInt();
              if (nextWindow != widget.windowSize) widget.onWindowSizeChanged?.call(nextWindow);
              return;
            }
            if (details.pointerCount == 1 && details.focalPointDelta.dy.abs() > 1.5) {
              final factor = 1 + (-details.focalPointDelta.dy / 240.0);
              final nextPrice = (widget.priceScale * factor).clamp(0.35, 5.0).toDouble();
              widget.onPriceScaleChanged?.call(nextPrice);
            }
            final visible = _visibleMeta(size);
            if (visible == null || visible.step <= 0) return;
            _panRemainder += -details.focalPointDelta.dx / visible.step;
            final panBars = _panRemainder.truncate();
            if (panBars != 0) {
              widget.onPanBars?.call(panBars);
              _panRemainder -= panBars;
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: Candlesticks(
                  candles: candles,
                  loadingWidget: const Center(
                    child: Text('暂无K线数据', style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _ChanOverlayPainter(
                    snapshot: widget.snapshot,
                    showFx: widget.showFx,
                    showFxLine: widget.showFxLine,
                    showFxText: widget.showFxText,
                    showBi: widget.showBi,
                    showBiText: widget.showBiText,
                    showSeg: widget.showSeg,
                    showSegText: widget.showSegText,
                    showZs: widget.showZs,
                    windowSize: widget.windowSize,
                    priceScale: widget.priceScale,
                    viewEndIndex: widget.viewEndIndex,
                    crosshairIndex: widget.crosshairIndex,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Candle _toCandle(RawBar bar) {
    return Candle(
      date: bar.time,
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
      volume: bar.volume,
    );
  }

  void _updateCrosshair(Offset localPosition, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null || !meta.chartRect.contains(localPosition)) return;
    final local = ((localPosition.dx - meta.chartRect.left) / meta.step).floor();
    final rawIndex = (meta.startIndex + local).clamp(meta.startIndex, meta.endIndex).toInt();
    widget.onCrosshairChanged?.call(rawIndex);
  }

  _VisibleMeta? _visibleMeta(Size size) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return null;
    final chartRect = _ChanOverlayPainter.chartRectFor(size);
    final endIndex = (widget.viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final startIndex = math.max(0, endIndex - widget.windowSize + 1).toInt();
    final count = math.max(1, endIndex - startIndex + 1).toInt();
    return _VisibleMeta(
      chartRect: chartRect,
      startIndex: startIndex,
      endIndex: endIndex,
      step: chartRect.width / count,
    );
  }
}

class _VisibleMeta {
  final Rect chartRect;
  final int startIndex;
  final int endIndex;
  final double step;

  const _VisibleMeta({required this.chartRect, required this.startIndex, required this.endIndex, required this.step});
}

class _ChanOverlayPainter extends CustomPainter {
  final ChanSnapshot snapshot;
  final bool showFx;
  final bool showFxLine;
  final bool showFxText;
  final bool showBi;
  final bool showBiText;
  final bool showSeg;
  final bool showSegText;
  final bool showZs;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final int? crosshairIndex;

  _ChanOverlayPainter({
    required this.snapshot,
    required this.showFx,
    required this.showFxLine,
    required this.showFxText,
    required this.showBi,
    required this.showBiText,
    required this.showSeg,
    required this.showSegText,
    required this.showZs,
    required this.windowSize,
    required this.priceScale,
    this.viewEndIndex,
    this.crosshairIndex,
  });

  static const double _topPad = 32;
  static const double _bottomPad = 28;
  static const double _leftPad = 4;
  static const double _rightPad = 58;

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
    if (bars.isEmpty) return;

    final endIndex = (viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final startIndex = math.max(0, endIndex - windowSize + 1).toInt();
    final visible = bars.sublist(startIndex, endIndex + 1);
    final chartRect = chartRectFor(size);
    if (chartRect.width <= 0 || chartRect.height <= 0) return;

    final low = visible.map((e) => e.low).reduce(math.min);
    final high = visible.map((e) => e.high).reduce(math.max);
    final center = (high + low) / 2;
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final scaledRange = rawRange / priceScale.clamp(0.35, 5.0).toDouble();
    final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);
    final minPrice = center - scaledRange / 2 - padding;
    final maxPrice = center + scaledRange / 2 + padding;

    double priceToY(double price) {
      if ((maxPrice - minPrice).abs() < 1e-9) return chartRect.center.dy;
      return chartRect.bottom - (price - minPrice) / (maxPrice - minPrice) * chartRect.height;
    }

    final count = visible.length;
    final step = chartRect.width / math.max(1, count).toDouble();
    double rawToX(int rawIndex) => chartRect.left + (rawIndex - startIndex + 0.5) * step;

    if (showZs) _drawZs(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);
    if (showFxLine) _drawFxConnectLine(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);
    if (showBi) _drawBi(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);
    if (showSeg) _drawSeg(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);
    if (showFx) _drawFx(canvas, chartRect, startIndex, endIndex, rawToX, priceToY);

    final cross = crosshairIndex;
    if (cross != null && cross >= startIndex && cross <= endIndex) {
      _drawCrosshair(canvas, chartRect, bars[cross], rawToX, priceToY);
    } else {
      _drawHeader(canvas, visible.last.time, bars.length, snapshot);
    }
  }

  void _drawFxConnectLine(Canvas canvas, Rect rect, int startRaw, int endRaw, double Function(int) rawToX, double Function(double) priceToY) {
    final visibleFx = snapshot.fxs.where((fx) => fx.rawIndex >= startRaw && fx.rawIndex <= endRaw).toList()
      ..sort((a, b) => a.rawIndex.compareTo(b.rawIndex));
    if (visibleFx.length < 2) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.46)
      ..strokeWidth = 1.15
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    for (final fx in visibleFx) {
      final x = rawToX(fx.rawIndex).clamp(rect.left, rect.right).toDouble();
      final y = priceToY(fx.price).clamp(rect.top, rect.bottom).toDouble();
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawFx(Canvas canvas, Rect rect, int startRaw, int endRaw, double Function(int) rawToX, double Function(double) priceToY) {
    final topPaint = Paint()..color = const Color(0xFFFFCA28);
    final bottomPaint = Paint()..color = const Color(0xFF42A5F5);
    for (final fx in snapshot.fxs) {
      if (fx.rawIndex < startRaw || fx.rawIndex > endRaw) continue;
      final x = rawToX(fx.rawIndex).clamp(rect.left, rect.right).toDouble();
      final y = priceToY(fx.price).clamp(rect.top, rect.bottom).toDouble();
      final paint = fx.type == FxType.top ? topPaint : bottomPaint;
      canvas.drawCircle(Offset(x, y), 4, paint);
      if (showFxText) {
        _drawText(canvas, fx.type == FxType.top ? '顶' : '底', Offset(x - 6, y + (fx.isTop ? -20 : 8)), 11, paint.color);
      }
    }
  }

  void _drawBi(Canvas canvas, Rect rect, int startRaw, int endRaw, double Function(int) rawToX, double Function(double) priceToY) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 1.45;
    for (final bi in snapshot.bis) {
      if (bi.endRawIndex < startRaw || bi.startRawIndex > endRaw) continue;
      final x1 = rawToX(bi.startRawIndex).clamp(rect.left, rect.right).toDouble();
      final x2 = rawToX(bi.endRawIndex).clamp(rect.left, rect.right).toDouble();
      final y1 = priceToY(bi.startPrice).clamp(rect.top, rect.bottom).toDouble();
      final y2 = priceToY(bi.endPrice).clamp(rect.top, rect.bottom).toDouble();
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      if (showBiText) {
        _drawText(canvas, 'B${bi.index + 1}', Offset(x2 - 12, y2 + (bi.isUp ? -18 : 6)), 10, const Color(0xFFFF8A80));
      }
    }
  }

  void _drawSeg(Canvas canvas, Rect rect, int startRaw, int endRaw, double Function(int) rawToX, double Function(double) priceToY) {
    for (final seg in snapshot.segs) {
      if (seg.endRawIndex < startRaw || seg.startRawIndex > endRaw) continue;
      final paint = Paint()
        ..color = (seg.isSure ? const Color(0xFF00E676) : const Color(0xFFB2FF59)).withValues(alpha: seg.isSure ? 0.92 : 0.62)
        ..strokeWidth = seg.isSure ? 2.6 : 1.6
        ..style = PaintingStyle.stroke;
      final x1 = rawToX(seg.startRawIndex).clamp(rect.left, rect.right).toDouble();
      final x2 = rawToX(seg.endRawIndex).clamp(rect.left, rect.right).toDouble();
      final y1 = priceToY(seg.startPrice).clamp(rect.top, rect.bottom).toDouble();
      final y2 = priceToY(seg.endPrice).clamp(rect.top, rect.bottom).toDouble();
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      if (showSegText) {
        _drawText(canvas, 'S${seg.index + 1}${seg.isSure ? '' : '?'}', Offset(x2 - 14, y2 + (seg.isUp ? -20 : 8)), 10, Colors.white70);
      }
    }
  }

  void _drawZs(Canvas canvas, Rect rect, int startRaw, int endRaw, double Function(int) rawToX, double Function(double) priceToY) {
    final fill = Paint()
      ..color = const Color(0xFF2962FF).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF5B8DFF).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (final zs in snapshot.zss) {
      if (zs.endRawIndex < startRaw || zs.startRawIndex > endRaw) continue;
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

  void _drawHeader(Canvas canvas, DateTime latest, int total, ChanSnapshot snapshot) {
    final text = 'Candlesticks ${latest.toIso8601String().substring(0, 10)} | K:$total FX:${snapshot.fxs.length} BI:${snapshot.bis.length} SEG:${snapshot.segs.length} ZS:${snapshot.zss.length}';
    _drawText(canvas, text, const Offset(8, 4), 11, Colors.white70);
  }

  void _drawCrosshair(Canvas canvas, Rect rect, RawBar bar, double Function(int) rawToX, double Function(double) priceToY) {
    final x = rawToX(bar.index).clamp(rect.left, rect.right).toDouble();
    final y = priceToY(bar.close).clamp(rect.top, rect.bottom).toDouble();
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.52)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    final label = 'O:${bar.open.toStringAsFixed(2)} H:${bar.high.toStringAsFixed(2)} L:${bar.low.toStringAsFixed(2)} C:${bar.close.toStringAsFixed(2)} V:${bar.volume.toStringAsFixed(0)}';
    _drawText(canvas, label, Offset(rect.left + 6, rect.top - 20), 11, Colors.white);
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ChanOverlayPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot ||
        oldDelegate.showFx != showFx ||
        oldDelegate.showFxLine != showFxLine ||
        oldDelegate.showFxText != showFxText ||
        oldDelegate.showBi != showBi ||
        oldDelegate.showBiText != showBiText ||
        oldDelegate.showSeg != showSeg ||
        oldDelegate.showSegText != showSegText ||
        oldDelegate.showZs != showZs ||
        oldDelegate.windowSize != windowSize ||
        oldDelegate.priceScale != priceScale ||
        oldDelegate.viewEndIndex != viewEndIndex ||
        oldDelegate.crosshairIndex != crosshairIndex;
  }
}
