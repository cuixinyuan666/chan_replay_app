import 'package:flutter/material.dart';

/// Preferred placement side for a chart label.
///
/// This helper is intentionally UI-only. It does not know anything about
/// chan.py, FX/BI/SEG/ZS/BSP semantics, or indicator calculation.
enum ChartLabelSide { top, bottom, right, inside }

/// Relative label importance. Higher priority labels get placed first and are
/// less likely to be hidden when the chart is dense.
enum ChartLabelPriority {
  grid,
  fx,
  zs,
  bi,
  seg,
  bsp,
  crosshair,
}

class ChartLabel {
  final String text;
  final Offset anchor;
  final ChartLabelSide side;
  final ChartLabelPriority priority;
  final int? rawIndex;
  final Color color;
  final double fontSize;
  final int visibleWhenWindowLe;
  final bool forceVisible;

  const ChartLabel({
    required this.text,
    required this.anchor,
    required this.side,
    required this.priority,
    this.rawIndex,
    required this.color,
    this.fontSize = 10,
    this.visibleWhenWindowLe = 360,
    this.forceVisible = false,
  });
}

class LaidOutChartLabel {
  final ChartLabel label;
  final Offset offset;
  final Size size;

  const LaidOutChartLabel({
    required this.label,
    required this.offset,
    required this.size,
  });

  Rect get rect => offset & size;
}

class ChartLabelLayout {
  final Rect chartRect;
  final int visibleCount;
  final List<Rect> _occupied = <Rect>[];

  ChartLabelLayout({
    required this.chartRect,
    required this.visibleCount,
    Iterable<Rect> reserved = const <Rect>[],
  }) {
    _occupied.addAll(reserved);
  }

  List<LaidOutChartLabel> layout(Iterable<ChartLabel> labels) {
    final ordered = labels
        .where(_passesDensityFilter)
        .toList(growable: false)
      ..sort(_comparePriorityThenIndex);

    final result = <LaidOutChartLabel>[];
    for (final label in ordered) {
      final textSize = _measureText(label.text, label.fontSize);
      final candidates = _candidatesFor(label, textSize);
      for (final candidate in candidates) {
        final rect = candidate & textSize;
        if (!_intersectsOccupied(rect) && _isUsefulRect(rect)) {
          _occupied.add(rect.inflate(2));
          result.add(LaidOutChartLabel(
            label: label,
            offset: candidate,
            size: textSize,
          ));
          break;
        }
      }
    }
    return result;
  }

  bool _passesDensityFilter(ChartLabel label) {
    if (label.forceVisible) return true;
    if (visibleCount <= label.visibleWhenWindowLe) return true;

    final rawIndex = label.rawIndex;
    if (rawIndex == null) return false;

    final step = visibleCount <= 360
        ? 2
        : visibleCount <= 720
            ? 4
            : 8;
    return rawIndex % step == 0 && label.priority.index >= ChartLabelPriority.bsp.index;
  }

  int _comparePriorityThenIndex(ChartLabel a, ChartLabel b) {
    final priority = b.priority.index.compareTo(a.priority.index);
    if (priority != 0) return priority;
    return (a.rawIndex ?? 0).compareTo(b.rawIndex ?? 0);
  }

  List<Offset> _candidatesFor(ChartLabel label, Size size) {
    final anchor = label.anchor;
    const gap = 4.0;
    final topCandidates = <Offset>[
      Offset(anchor.dx - size.width / 2, anchor.dy - size.height - 8),
      Offset(anchor.dx - size.width / 2, anchor.dy - size.height - 22),
      Offset(anchor.dx + 6, anchor.dy - size.height / 2),
    ];
    final bottomCandidates = <Offset>[
      Offset(anchor.dx - size.width / 2, anchor.dy + 8),
      Offset(anchor.dx - size.width / 2, anchor.dy + 22),
      Offset(anchor.dx + 6, anchor.dy - size.height / 2),
    ];
    final rightCandidates = <Offset>[
      Offset(anchor.dx + 6, anchor.dy - size.height / 2),
      Offset(anchor.dx + 6, anchor.dy - size.height - gap),
      Offset(anchor.dx + 6, anchor.dy + gap),
    ];
    final insideCandidates = <Offset>[
      Offset(anchor.dx + gap, anchor.dy + gap),
      Offset(anchor.dx + gap, anchor.dy - size.height - gap),
      Offset(anchor.dx - size.width - gap, anchor.dy + gap),
    ];

    final raw = switch (label.side) {
      ChartLabelSide.top => topCandidates,
      ChartLabelSide.bottom => bottomCandidates,
      ChartLabelSide.right => rightCandidates,
      ChartLabelSide.inside => insideCandidates,
    };
    return raw.map((candidate) => _clampToChart(candidate, size)).toList(growable: false);
  }

  Offset _clampToChart(Offset offset, Size size) {
    final minDx = chartRect.left;
    final maxDx = chartRect.right - size.width;
    final minDy = chartRect.top;
    final maxDy = chartRect.bottom - size.height;
    return Offset(
      offset.dx.clamp(minDx, maxDx).toDouble(),
      offset.dy.clamp(minDy, maxDy).toDouble(),
    );
  }

  bool _intersectsOccupied(Rect rect) {
    for (final occupied in _occupied) {
      if (rect.overlaps(occupied)) return true;
    }
    return false;
  }

  bool _isUsefulRect(Rect rect) {
    return rect.width > 0 &&
        rect.height > 0 &&
        rect.right >= chartRect.left &&
        rect.left <= chartRect.right &&
        rect.bottom >= chartRect.top &&
        rect.top <= chartRect.bottom;
  }

  Size _measureText(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.size;
  }
}

void paintLaidOutChartLabels(Canvas canvas, Iterable<LaidOutChartLabel> labels) {
  for (final item in labels) {
    final painter = TextPainter(
      text: TextSpan(
        text: item.label.text,
        style: TextStyle(
          color: item.label.color,
          fontSize: item.label.fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, item.offset);
  }
}
