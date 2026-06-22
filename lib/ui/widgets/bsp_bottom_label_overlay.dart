import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/bsp_step_review.dart';

/// Paints BSP review labels at the bottom of the main K-line panel.
///
/// This overlay is intentionally independent from the Chan painter. It consumes
/// already frozen [BspBottomLabel] rows from the replay page and only maps
/// rawIndex -> viewport x coordinate, so it does not become another calculation
/// authority.
class BspBottomLabelOverlay extends StatelessWidget {
  final bool enabled;
  final List<BspBottomLabel> labels;
  final int totalBars;
  final int windowSize;
  final int? viewEndIndex;
  final int easySubPanelCount;

  const BspBottomLabelOverlay({
    super.key,
    required this.enabled,
    required this.labels,
    required this.totalBars,
    required this.windowSize,
    required this.viewEndIndex,
    required this.easySubPanelCount,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || labels.isEmpty || totalBars <= 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _BspBottomLabelPainter(
          labels: labels,
          totalBars: totalBars,
          windowSize: windowSize,
          viewEndIndex: viewEndIndex,
          easySubPanelCount: easySubPanelCount,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BspBottomLabelPainter extends CustomPainter {
  static const double _topPad = 32.0;
  static const double _bottomPad = 28.0;
  static const double _leftPad = 4.0;
  static const double _rightPad = 58.0;
  static const double _subPanelHeight = 74.0;
  static const double _panelGap = 6.0;
  static const double _labelHeight = 17.0;
  static const double _laneHeight = 18.0;

  final List<BspBottomLabel> labels;
  final int totalBars;
  final int windowSize;
  final int? viewEndIndex;
  final int easySubPanelCount;

  const _BspBottomLabelPainter({
    required this.labels,
    required this.totalBars,
    required this.windowSize,
    required this.viewEndIndex,
    required this.easySubPanelCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || totalBars <= 0) return;
    final rect = _mainRect(size);
    if (rect.width <= 0 || rect.height <= 0) return;

    final end = (viewEndIndex ?? totalBars - 1).clamp(0, totalBars - 1).toInt();
    final safeWindow = math.max(1, windowSize);
    final start = math.max(0, end - safeWindow + 1).toInt();
    final visibleCount = math.max(1, end - start + 1);
    final step = rect.width / visibleCount;
    double rawToX(int rawIndex) => rect.left + (rawIndex - start + 0.5) * step;

    final visible = labels
        .where((label) => label.rawIndex >= start && label.rawIndex <= end)
        .toList(growable: false)
      ..sort((a, b) {
        final rank = _levelRank(a.level).compareTo(_levelRank(b.level));
        if (rank != 0) return rank;
        if (a.rawIndex != b.rawIndex) return a.rawIndex.compareTo(b.rawIndex);
        return a.text.compareTo(b.text);
      });
    if (visible.isEmpty) return;

    for (final label in visible) {
      final x = rawToX(label.rawIndex).clamp(rect.left, rect.right).toDouble();
      final color = _labelColor(label);
      final painter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: color,
            fontSize: _fontSize(label.level),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final lane = _levelRank(label.level);
      final y = (rect.bottom - 22 - lane * _laneHeight)
          .clamp(rect.top + 4, rect.bottom - _labelHeight)
          .toDouble();
      final box = _clampBox(
        Rect.fromLTWH(
          x - painter.width / 2 - 5,
          y,
          painter.width + 10,
          _labelHeight,
        ),
        rect,
      );

      final bg = RRect.fromRectAndRadius(box, const Radius.circular(5));
      canvas.drawRRect(
        bg,
        Paint()
          ..color = const Color(0xDD0D1117)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        bg,
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..strokeWidth = _strokeWidth(label.level)
          ..style = PaintingStyle.stroke,
      );
      painter.paint(canvas, Offset(box.left + 5, box.top + 2));
    }
  }

  Rect _mainRect(Size size) {
    final subCount = easySubPanelCount.clamp(0, 4).toInt();
    final subHeight = subCount == 0
        ? 0.0
        : subCount * _subPanelHeight + (subCount - 1) * _panelGap;
    final mainHeight = math.max(
      0.0,
      size.height -
          _topPad -
          _bottomPad -
          subHeight -
          (subCount > 0 ? _panelGap : 0),
    );
    return Rect.fromLTWH(
      _leftPad,
      _topPad,
      math.max(0.0, size.width - _leftPad - _rightPad),
      mainHeight,
    );
  }

  Rect _clampBox(Rect box, Rect chartRect) {
    final dx = box.left < chartRect.left
        ? chartRect.left - box.left
        : (box.right > chartRect.right ? chartRect.right - box.right : 0.0);
    final minTop = chartRect.top + 4;
    final dy = box.top < minTop ? minTop - box.top : 0.0;
    return box.translate(dx, dy);
  }

  int _levelRank(String level) {
    final text = level.trim();
    if (text == '笔') return 0;
    if (text == '段') return 1;
    final match = RegExp(r'^(\d+)段$').firstMatch(text);
    if (match != null) return int.tryParse(match.group(1) ?? '') ?? 2;
    if (text.contains('段')) return 1;
    return 0;
  }

  double _fontSize(String level) => _levelRank(level) >= 2 ? 10.8 : 10.2;
  double _strokeWidth(String level) => _levelRank(level) >= 2 ? 1.15 : 0.9;

  Color _labelColor(BspBottomLabel label) {
    if (label.isBuy) return const Color(0xFFFF5252);
    return switch (_levelRank(label.level)) {
      0 => const Color(0xFFB3E5FC), // 笔卖点：淡蓝色
      1 => const Color(0xFF69F0AE), // 段卖点：绿色
      _ => const Color(0xFF40C4FF), // 2段/N段卖点：天蓝色
    };
  }

  @override
  bool shouldRepaint(covariant _BspBottomLabelPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.totalBars != totalBars ||
        oldDelegate.windowSize != windowSize ||
        oldDelegate.viewEndIndex != viewEndIndex ||
        oldDelegate.easySubPanelCount != easySubPanelCount;
  }
}
