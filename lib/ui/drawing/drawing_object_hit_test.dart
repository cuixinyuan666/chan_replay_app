import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'drawing_object.dart';
import 'tradingview_drawing_tool.dart';

/// Hit testing for user-created drawing objects.
///
/// This file only works with DrawingObject geometry. It must not calculate or
/// infer any Chan theory element.
class DrawingObjectHitTest {
  const DrawingObjectHitTest._();

  static DrawingObject? hitTest({
    required List<DrawingObject> objects,
    required Offset point,
    required Rect chartRect,
    required int startRawIndex,
    required int endRawIndex,
    required double Function(int rawIndex) rawToX,
    required double Function(double price) priceToY,
    double tolerance = 8,
  }) {
    for (final object in objects.reversed) {
      if (object.hidden || object.isChanOverlay) continue;
      if (!_isVisible(object, startRawIndex, endRawIndex)) continue;
      if (_hitObject(object, point, chartRect, rawToX, priceToY, tolerance)) return object;
    }
    return null;
  }

  static bool _isVisible(DrawingObject object, int startRawIndex, int endRawIndex) {
    final anchors = object.anchors.where((e) => e.isChart && e.rawIndex != null);
    if (anchors.isEmpty) return true;
    final minRaw = anchors.map((e) => e.rawIndex!).reduce(math.min);
    final maxRaw = anchors.map((e) => e.rawIndex!).reduce(math.max);
    return maxRaw >= startRawIndex && minRaw <= endRawIndex;
  }

  static bool _hitObject(
    DrawingObject object,
    Offset point,
    Rect chartRect,
    double Function(int rawIndex) rawToX,
    double Function(double price) priceToY,
    double tolerance,
  ) {
    switch (object.tool) {
      case TradingViewDrawingTool.trendLine:
      case TradingViewDrawingTool.infoLine:
      case TradingViewDrawingTool.arrow:
        final points = _points(object, rawToX, priceToY);
        return points.length >= 2 && _distanceToSegment(point, _clamp(points[0], chartRect), _clamp(points[1], chartRect)) <= tolerance;
      case TradingViewDrawingTool.horizontalLine:
      case TradingViewDrawingTool.horizontalRay:
        final anchor = _firstChartAnchor(object);
        if (anchor == null || anchor.price == null) return false;
        final y = priceToY(anchor.price!).clamp(chartRect.top, chartRect.bottom).toDouble();
        if ((point.dy - y).abs() > tolerance) return false;
        if (object.tool == TradingViewDrawingTool.horizontalRay && anchor.rawIndex != null) {
          final startX = rawToX(anchor.rawIndex!).clamp(chartRect.left, chartRect.right).toDouble();
          return point.dx >= startX - tolerance && point.dx <= chartRect.right + tolerance;
        }
        return point.dx >= chartRect.left - tolerance && point.dx <= chartRect.right + tolerance;
      case TradingViewDrawingTool.verticalLine:
        final anchor = _firstChartAnchor(object);
        if (anchor == null || anchor.rawIndex == null) return false;
        final x = rawToX(anchor.rawIndex!).clamp(chartRect.left, chartRect.right).toDouble();
        return (point.dx - x).abs() <= tolerance && point.dy >= chartRect.top - tolerance && point.dy <= chartRect.bottom + tolerance;
      case TradingViewDrawingTool.rectangle:
      case TradingViewDrawingTool.ruler:
      case TradingViewDrawingTool.dateRange:
      case TradingViewDrawingTool.priceRange:
      case TradingViewDrawingTool.dateAndPriceRange:
        final points = _points(object, rawToX, priceToY);
        if (points.length < 2) return false;
        final rect = Rect.fromPoints(_clamp(points[0], chartRect), _clamp(points[1], chartRect)).inflate(tolerance);
        if (!rect.contains(point)) return false;
        if (object.tool == TradingViewDrawingTool.rectangle) {
          final inner = rect.deflate(tolerance * 1.8);
          return !inner.contains(point) || object.style.filled;
        }
        return true;
      case TradingViewDrawingTool.text:
      case TradingViewDrawingTool.anchoredText:
      case TradingViewDrawingTool.note:
      case TradingViewDrawingTool.priceLabel:
      case TradingViewDrawingTool.priceNote:
        final p = _firstPoint(object, rawToX, priceToY);
        if (p == null) return false;
        final text = object.text.isEmpty ? TradingViewDrawingToolRegistry.metaOf(object.tool).label : object.text;
        final width = (text.length * object.style.fontSize * 0.62).clamp(28.0, 260.0).toDouble();
        final height = (object.style.fontSize * 1.6).clamp(18.0, 48.0).toDouble();
        return Rect.fromLTWH(p.dx - tolerance, p.dy - tolerance, width + tolerance * 2, height + tolerance * 2).contains(point);
      default:
        return false;
    }
  }

  static List<Offset> _points(
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
    final points = _points(object, rawToX, priceToY);
    return points.isEmpty ? null : points.first;
  }

  static DrawingAnchor? _firstChartAnchor(DrawingObject object) {
    for (final anchor in object.anchors) {
      if (anchor.isChart) return anchor;
    }
    return null;
  }

  static Offset _clamp(Offset p, Rect rect) {
    return Offset(p.dx.clamp(rect.left, rect.right).toDouble(), p.dy.clamp(rect.top, rect.bottom).toDouble());
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 <= 0) return (p - a).distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / ab2).clamp(0.0, 1.0).toDouble();
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }
}
