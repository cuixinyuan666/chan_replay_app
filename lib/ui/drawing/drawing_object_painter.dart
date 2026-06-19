import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'drawing_object.dart';
import 'tradingview_drawing_tool.dart';

/// Paints user-created TradingView-style drawings over the K-line chart.
///
/// This painter only consumes DrawingObject data. It does not calculate any Chan
/// theory structure and must stay independent from Vespa/chan.py logic.
class DrawingObjectPainter {
  const DrawingObjectPainter._();

  static void paintObjects({
    required Canvas canvas,
    required Rect chartRect,
    required List<DrawingObject> objects,
    required int startRawIndex,
    required int endRawIndex,
    required double Function(int rawIndex) rawToX,
    required double Function(double price) priceToY,
  }) {
    for (final object in objects) {
      if (object.hidden || object.isChanOverlay) continue;
      if (!_isVisible(object, startRawIndex, endRawIndex)) continue;
      _paintObject(
        canvas: canvas,
        chartRect: chartRect,
        object: object,
        rawToX: rawToX,
        priceToY: priceToY,
      );
    }
  }

  static bool _isVisible(
      DrawingObject object, int startRawIndex, int endRawIndex) {
    final chartAnchors = object.anchors
        .where((anchor) => anchor.isChart && anchor.rawIndex != null);
    if (chartAnchors.isEmpty) return true;
    final minRaw = chartAnchors.map((e) => e.rawIndex!).reduce(math.min);
    final maxRaw = chartAnchors.map((e) => e.rawIndex!).reduce(math.max);
    return maxRaw >= startRawIndex && minRaw <= endRawIndex;
  }

  static void _paintObject({
    required Canvas canvas,
    required Rect chartRect,
    required DrawingObject object,
    required double Function(int rawIndex) rawToX,
    required double Function(double price) priceToY,
  }) {
    switch (object.tool) {
      case TradingViewDrawingTool.trendLine:
      case TradingViewDrawingTool.infoLine:
      case TradingViewDrawingTool.arrow:
        _drawLine(canvas, chartRect, object, rawToX, priceToY,
            arrow: object.tool == TradingViewDrawingTool.arrow);
        return;
      case TradingViewDrawingTool.horizontalLine:
      case TradingViewDrawingTool.horizontalRay:
        _drawHorizontal(canvas, chartRect, object, rawToX, priceToY,
            ray: object.tool == TradingViewDrawingTool.horizontalRay);
        return;
      case TradingViewDrawingTool.verticalLine:
        _drawVertical(canvas, chartRect, object, rawToX);
        return;
      case TradingViewDrawingTool.rectangle:
        _drawRectangle(canvas, chartRect, object, rawToX, priceToY);
        return;
      case TradingViewDrawingTool.ellipse:
        _drawEllipse(canvas, chartRect, object, rawToX, priceToY,
            forceCircle: false);
        return;
      case TradingViewDrawingTool.circle:
        _drawEllipse(canvas, chartRect, object, rawToX, priceToY,
            forceCircle: true);
        return;
      case TradingViewDrawingTool.iconCircle:
        _drawCircleMarker(canvas, chartRect, object, rawToX, priceToY);
        return;
      case TradingViewDrawingTool.text:
      case TradingViewDrawingTool.anchoredText:
      case TradingViewDrawingTool.note:
      case TradingViewDrawingTool.priceLabel:
      case TradingViewDrawingTool.priceNote:
        _drawText(canvas, chartRect, object, rawToX, priceToY);
        return;
      case TradingViewDrawingTool.ruler:
      case TradingViewDrawingTool.dateRange:
      case TradingViewDrawingTool.priceRange:
      case TradingViewDrawingTool.dateAndPriceRange:
        _drawMeasure(canvas, chartRect, object, rawToX, priceToY);
        return;
      default:
        return;
    }
  }

  static void _drawLine(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY, {
    bool arrow = false,
  }) {
    final points = _chartPoints(object, rawToX, priceToY);
    if (points.length < 2) return;
    final clipped = _clipSegmentToRect(points[0], points[1], chartRect);
    if (clipped == null) return;
    final paint = _linePaint(object);
    _drawStyledLine(
        canvas, clipped.start, clipped.end, paint, object.style.dashed);
    if (arrow) _drawArrowHead(canvas, clipped.start, clipped.end, paint);
    if (object.selected) {
      _drawHandles(
        canvas,
        [_clamp(points[0], chartRect), _clamp(points[1], chartRect)],
      );
    }
  }

  static void _drawHorizontal(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY, {
    required bool ray,
  }) {
    final anchor = _firstChartAnchor(object);
    if (anchor == null || anchor.price == null) return;
    final y = priceToY(anchor.price!)
        .clamp(chartRect.top, chartRect.bottom)
        .toDouble();
    final startX = ray && anchor.rawIndex != null
        ? rawToX(anchor.rawIndex!)
            .clamp(chartRect.left, chartRect.right)
            .toDouble()
        : chartRect.left;
    final p1 = Offset(startX, y);
    final p2 = Offset(chartRect.right, y);
    _drawStyledLine(canvas, p1, p2, _linePaint(object), object.style.dashed);
    if (object.selected) _drawHandles(canvas, [p1]);
  }

  static void _drawVertical(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
  ) {
    final anchor = _firstChartAnchor(object);
    if (anchor == null || anchor.rawIndex == null) return;
    final x = rawToX(anchor.rawIndex!)
        .clamp(chartRect.left, chartRect.right)
        .toDouble();
    final p1 = Offset(x, chartRect.top);
    final p2 = Offset(x, chartRect.bottom);
    _drawStyledLine(canvas, p1, p2, _linePaint(object), object.style.dashed);
    if (object.selected) _drawHandles(canvas, [Offset(x, chartRect.center.dy)]);
  }

  static void _drawRectangle(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY,
  ) {
    final points = _chartPoints(object, rawToX, priceToY);
    if (points.length < 2) return;
    final p1 = _clamp(points[0], chartRect);
    final p2 = _clamp(points[1], chartRect);
    final rect = Rect.fromPoints(p1, p2);
    if (object.style.filled) {
      canvas.drawRect(
          rect,
          Paint()
            ..color = object.style.fillColor
            ..style = PaintingStyle.fill);
    }
    canvas.drawRect(rect, _linePaint(object)..style = PaintingStyle.stroke);
    if (object.selected) _drawHandles(canvas, [p1, p2]);
  }

  static void _drawEllipse(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY, {
    required bool forceCircle,
  }) {
    final points = _chartPoints(object, rawToX, priceToY);
    if (points.length < 2) return;
    final p1 = _clamp(points[0], chartRect);
    final p2 = _clamp(points[1], chartRect);
    var rect = Rect.fromPoints(p1, p2);
    if (forceCircle) {
      final radius = math.min(rect.width.abs(), rect.height.abs()) / 2;
      rect =
          Rect.fromCircle(center: rect.center, radius: math.max(2.0, radius));
    }
    if (object.style.filled) {
      canvas.drawOval(
          rect,
          Paint()
            ..color = object.style.fillColor
            ..style = PaintingStyle.fill);
    }
    canvas.drawOval(rect, _linePaint(object)..style = PaintingStyle.stroke);
    if (object.selected) _drawHandles(canvas, [p1, p2]);
  }

  static void _drawText(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY,
  ) {
    final p = _firstPoint(object, rawToX, priceToY);
    if (p == null) return;
    final text = object.text.isEmpty
        ? TradingViewDrawingToolRegistry.metaOf(object.tool).label
        : object.text;
    final offset = _clamp(p, chartRect);
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: object.style.color, fontSize: object.style.fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: math.max(80, chartRect.width * 0.45));
    final box = Rect.fromLTWH(
        offset.dx - 3, offset.dy - 2, painter.width + 6, painter.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      Paint()..color = const Color(0xCC131722),
    );
    painter.paint(canvas, Offset(offset.dx, offset.dy));
    if (object.selected) _drawHandles(canvas, [offset]);
  }

  static void _drawCircleMarker(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY,
  ) {
    final point = _firstPoint(object, rawToX, priceToY);
    if (point == null || !chartRect.inflate(6).contains(point)) return;
    final center = _clamp(point, chartRect);
    final fill = Paint()
      ..color = const Color(0xFF111722)
      ..style = PaintingStyle.fill;
    final stroke = _linePaint(object)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, object.style.strokeWidth);
    canvas.drawCircle(center, 4.2, fill);
    canvas.drawCircle(center, 4.2, stroke);
    if (object.text.isEmpty) return;
    final label = TextPainter(
      text: TextSpan(
        text: object.text,
        style: TextStyle(
          color: object.style.color,
          fontSize: object.style.fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    label.paint(
      canvas,
      Offset(center.dx - label.width - 8, center.dy - label.height / 2),
    );
  }

  static void _drawMeasure(
    Canvas canvas,
    Rect chartRect,
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY,
  ) {
    final anchors = object.anchors
        .where((e) => e.isChart && e.rawIndex != null && e.price != null)
        .toList(growable: false);
    if (anchors.length < 2) return;
    final p1 = _clamp(
        Offset(rawToX(anchors[0].rawIndex!), priceToY(anchors[0].price!)),
        chartRect);
    final p2 = _clamp(
        Offset(rawToX(anchors[1].rawIndex!), priceToY(anchors[1].price!)),
        chartRect);
    final rect = Rect.fromPoints(p1, p2);
    final paint = _linePaint(object);
    canvas.drawRect(
        rect,
        Paint()
          ..color = object.style.fillColor
          ..style = PaintingStyle.fill);
    canvas.drawRect(rect, paint..style = PaintingStyle.stroke);
    _drawStyledLine(canvas, p1, p2, _linePaint(object), object.style.dashed);

    final rawDelta = (anchors[1].rawIndex! - anchors[0].rawIndex!).abs();
    final priceDelta = anchors[1].price! - anchors[0].price!;
    final pct =
        anchors[0].price == 0 ? 0.0 : priceDelta / anchors[0].price! * 100;
    final label =
        '${rawDelta}K  Δ${priceDelta.toStringAsFixed(2)}  ${pct.toStringAsFixed(2)}%';
    final labelOffset =
        Offset(rect.left + 4, math.max(chartRect.top + 2, rect.top - 18));
    _paintSmallLabel(canvas, label, labelOffset, object.style.color);
    if (object.selected) _drawHandles(canvas, [p1, p2]);
  }

  static List<Offset> _chartPoints(
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY,
  ) {
    return [
      for (final anchor in object.anchors)
        if (anchor.isChart && anchor.rawIndex != null && anchor.price != null)
          Offset(rawToX(anchor.rawIndex!), priceToY(anchor.price!))
        else if (anchor.isScreen && anchor.dx != null && anchor.dy != null)
          Offset(anchor.dx!, anchor.dy!),
    ];
  }

  static Offset? _firstPoint(
    DrawingObject object,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY,
  ) {
    final points = _chartPoints(object, rawToX, priceToY);
    return points.isEmpty ? null : points.first;
  }

  static DrawingAnchor? _firstChartAnchor(DrawingObject object) {
    for (final anchor in object.anchors) {
      if (anchor.isChart) return anchor;
    }
    return null;
  }

  static Paint _linePaint(DrawingObject object) {
    return Paint()
      ..color = object.style.color
      ..strokeWidth = object.selected
          ? object.style.strokeWidth + 0.8
          : object.style.strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
  }

  static Offset _clamp(Offset p, Rect rect) {
    return Offset(
      p.dx.clamp(rect.left, rect.right).toDouble(),
      p.dy.clamp(rect.top, rect.bottom).toDouble(),
    );
  }

  static _ClippedSegment? _clipSegmentToRect(Offset a, Offset b, Rect rect) {
    if (rect.isEmpty) return null;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    var t0 = 0.0;
    var t1 = 1.0;

    bool clip(double p, double q) {
      const eps = 1e-9;
      if (p.abs() < eps) return q >= 0;
      final r = q / p;
      if (p < 0) {
        if (r > t1) return false;
        if (r > t0) t0 = r;
      } else {
        if (r < t0) return false;
        if (r < t1) t1 = r;
      }
      return true;
    }

    if (!clip(-dx, a.dx - rect.left)) return null;
    if (!clip(dx, rect.right - a.dx)) return null;
    if (!clip(-dy, a.dy - rect.top)) return null;
    if (!clip(dy, rect.bottom - a.dy)) return null;

    return _ClippedSegment(
      _clamp(Offset(a.dx + dx * t0, a.dy + dy * t0), rect),
      _clamp(Offset(a.dx + dx * t1, a.dy + dy * t1), rect),
    );
  }

  static void _drawStyledLine(
      Canvas canvas, Offset a, Offset b, Paint paint, bool dashed) {
    if (!dashed) {
      canvas.drawLine(a, b, paint);
      return;
    }
    const dash = 6.0;
    const gap = 4.0;
    final delta = b - a;
    final distance = delta.distance;
    if (distance <= 0) return;
    final direction = delta / distance;
    var current = 0.0;
    while (current < distance) {
      final next = math.min(current + dash, distance);
      canvas.drawLine(a + direction * current, a + direction * next, paint);
      current = next + gap;
    }
  }

  static void _drawArrowHead(
      Canvas canvas, Offset from, Offset to, Paint paint) {
    final delta = to - from;
    if (delta.distance <= 0) return;
    final angle = math.atan2(delta.dy, delta.dx);
    const size = 9.0;
    final p1 = to -
        Offset(math.cos(angle - math.pi / 6) * size,
            math.sin(angle - math.pi / 6) * size);
    final p2 = to -
        Offset(math.cos(angle + math.pi / 6) * size,
            math.sin(angle + math.pi / 6) * size);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill);
  }

  static void _drawHandles(Canvas canvas, List<Offset> points) {
    final fill = Paint()..color = const Color(0xFF2962FF);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final point in points) {
      canvas.drawCircle(point, 4.2, fill);
      canvas.drawCircle(point, 4.2, stroke);
    }
  }

  static void _paintSmallLabel(
      Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 11)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 220);
    final box = Rect.fromLTWH(
        offset.dx - 3, offset.dy - 2, painter.width + 6, painter.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      Paint()..color = const Color(0xDD0B0D10),
    );
    painter.paint(canvas, offset);
  }
}

class _ClippedSegment {
  final Offset start;
  final Offset end;

  const _ClippedSegment(this.start, this.end);
}
