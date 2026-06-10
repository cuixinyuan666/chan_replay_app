import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/easy_tdx_indicator.dart';
import '../../core/models/raw_bar.dart';

class OriginIndicatorPane extends StatelessWidget {
  final ChanSnapshot snapshot;
  final bool showVol;
  final bool showMacd;
  final int windowSize;
  final int? viewEndIndex;
  final int? crosshairIndex;

  const OriginIndicatorPane({
    super.key,
    required this.snapshot,
    this.showVol = true,
    this.showMacd = false,
    required this.windowSize,
    this.viewEndIndex,
    this.crosshairIndex,
  });

  bool get hasVisiblePane => showVol || showMacd;

  @override
  Widget build(BuildContext context) {
    if (snapshot.rawBars.isEmpty || !hasVisiblePane) return const SizedBox.shrink();
    return SizedBox.expand(
      child: CustomPaint(
        painter: _OriginIndicatorPanePainter(
          snapshot: snapshot,
          showVol: showVol,
          showMacd: showMacd,
          windowSize: windowSize,
          viewEndIndex: viewEndIndex,
          crosshairIndex: crosshairIndex,
        ),
      ),
    );
  }
}

class _OriginIndicatorPanePainter extends CustomPainter {
  static const double _topPad = 18;
  static const double _bottomPad = 12;
  static const double _leftPad = 4;
  static const double _rightPad = 58;
  static const double _paneGap = 8;

  final ChanSnapshot snapshot;
  final bool showVol;
  final bool showMacd;
  final int windowSize;
  final int? viewEndIndex;
  final int? crosshairIndex;

  _OriginIndicatorPanePainter({
    required this.snapshot,
    required this.showVol,
    required this.showMacd,
    required this.windowSize,
    required this.viewEndIndex,
    required this.crosshairIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bars = snapshot.rawBars;
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;
    final panes = <_PaneSpec>[
      if (showVol) const _PaneSpec('VOL', _PaneKind.vol),
      if (showMacd) const _PaneSpec('MACD', _PaneKind.macd),
    ];
    if (panes.isEmpty) return;

    final end = (viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final start = math.max(0, end - windowSize + 1).toInt();
    final visible = bars.sublist(start, end + 1);
    if (visible.isEmpty) return;
    final chartWidth = math.max(0.0, size.width - _leftPad - _rightPad);
    final availableHeight = math.max(0.0, size.height - _topPad - _bottomPad - _paneGap * (panes.length - 1));
    if (chartWidth <= 0 || availableHeight <= 0) return;
    final paneHeight = availableHeight / panes.length;
    final step = chartWidth / math.max(1, visible.length);
    double rawToX(int rawIndex) => _leftPad + (rawIndex - start + 0.5) * step;

    final volByRaw = <int, double?>{
      for (final point in snapshot.indicators.vol) point.rawIndex: point.value,
    };
    final macdByRaw = <int, EasyMacdPoint>{
      for (final point in snapshot.indicators.macd) point.rawIndex: point,
    };

    for (var i = 0; i < panes.length; i++) {
      final top = _topPad + i * (paneHeight + _paneGap);
      final rect = Rect.fromLTWH(_leftPad, top, chartWidth, paneHeight);
      _drawPaneFrame(canvas, rect, panes[i].label);
      switch (panes[i].kind) {
        case _PaneKind.vol:
          _drawVol(canvas, rect, visible, volByRaw, rawToX, step);
          break;
        case _PaneKind.macd:
          _drawMacd(canvas, rect, visible, macdByRaw, rawToX, step);
          break;
      }
    }

    final cross = crosshairIndex;
    if (cross != null && cross >= start && cross <= end) {
      final x = rawToX(cross).clamp(_leftPad, _leftPad + chartWidth).toDouble();
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(x, _topPad), Offset(x, size.height - _bottomPad), paint);
      final vol = volByRaw[cross];
      final macd = macdByRaw[cross];
      final parts = <String>[
        if (showVol) 'VOL:${_fmt(vol)}',
        if (showMacd) 'DIF:${_fmt(macd?.dif)} DEA:${_fmt(macd?.dea)} HIST:${_fmt(macd?.hist)}',
      ];
      _drawText(canvas, parts.join('  '), const Offset(_leftPad + 6, 2), 11, Colors.white70, maxWidth: size.width - 12);
    } else {
      final parts = <String>[
        if (showVol) 'VOL:${snapshot.indicators.vol.length}',
        if (showMacd) 'MACD:${snapshot.indicators.macd.length}',
      ];
      _drawText(canvas, parts.join('  |  '), const Offset(_leftPad + 6, 2), 11, Colors.white54, maxWidth: size.width - 12);
    }
  }

  void _drawPaneFrame(Canvas canvas, Rect rect, String label) {
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.6;
    canvas.drawRect(rect, border);
    canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), grid);
    _drawText(canvas, label, Offset(rect.left + 4, rect.top + 3), 10, Colors.white54, maxWidth: 120);
  }

  void _drawVol(
    Canvas canvas,
    Rect rect,
    List<RawBar> visible,
    Map<int, double?> volByRaw,
    double Function(int) rawToX,
    double step,
  ) {
    final values = [
      for (final bar in visible) volByRaw[bar.index],
    ].whereType<double>().toList(growable: false);
    final maxVol = values.isEmpty ? 0.0 : values.reduce(math.max);
    if (maxVol <= 0) {
      _drawText(canvas, '无 VOL 指标数据', Offset(rect.left + 6, rect.center.dy - 7), 11, Colors.white38, maxWidth: rect.width);
      return;
    }
    final up = Paint()..color = const Color(0xFF26A69A).withValues(alpha: 0.70);
    final down = Paint()..color = const Color(0xFFEF5350).withValues(alpha: 0.70);
    final barWidth = math.max(1.0, math.min(step * 0.66, step - 1));
    for (final bar in visible) {
      final vol = volByRaw[bar.index];
      if (vol == null || vol <= 0) continue;
      final x = rawToX(bar.index);
      final top = rect.bottom - (vol / maxVol).clamp(0.0, 1.0) * rect.height;
      final paint = bar.close >= bar.open ? up : down;
      canvas.drawRect(Rect.fromLTRB(x - barWidth / 2, top, x + barWidth / 2, rect.bottom), paint);
    }
    _drawText(canvas, _fmt(maxVol), Offset(rect.right + 5, rect.top - 1), 10, Colors.white38, maxWidth: _rightPad - 8);
  }

  void _drawMacd(
    Canvas canvas,
    Rect rect,
    List<RawBar> visible,
    Map<int, EasyMacdPoint> macdByRaw,
    double Function(int) rawToX,
    double step,
  ) {
    final rows = [
      for (final bar in visible)
        if (macdByRaw[bar.index] != null) macdByRaw[bar.index]!,
    ];
    final values = <double>[
      for (final row in rows) ...[
        if (row.dif != null) row.dif!,
        if (row.dea != null) row.dea!,
        if (row.hist != null) row.hist!,
      ],
    ];
    if (values.isEmpty) {
      _drawText(canvas, '无 MACD 指标数据', Offset(rect.left + 6, rect.center.dy - 7), 11, Colors.white38, maxWidth: rect.width);
      return;
    }
    final maxAbs = values.map((e) => e.abs()).reduce(math.max);
    if (maxAbs <= 0) return;
    double valueToY(double value) => rect.center.dy - value / maxAbs * rect.height * 0.46;
    final zeroPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(rect.left, rect.center.dy), Offset(rect.right, rect.center.dy), zeroPaint);

    final pos = Paint()..color = const Color(0xFF26A69A).withValues(alpha: 0.72);
    final neg = Paint()..color = const Color(0xFFEF5350).withValues(alpha: 0.72);
    final histWidth = math.max(1.0, math.min(step * 0.56, step - 1));
    for (final row in rows) {
      final hist = row.hist;
      if (hist == null) continue;
      final x = rawToX(row.rawIndex);
      final y = valueToY(hist);
      canvas.drawRect(
        Rect.fromLTRB(x - histWidth / 2, math.min(y, rect.center.dy), x + histWidth / 2, math.max(y, rect.center.dy)),
        hist >= 0 ? pos : neg,
      );
    }
    _drawLine(canvas, rows, rawToX, valueToY, (row) => row.dif, const Color(0xFFFFD54F));
    _drawLine(canvas, rows, rawToX, valueToY, (row) => row.dea, const Color(0xFF90CAF9));
    _drawText(canvas, '±${_fmt(maxAbs)}', Offset(rect.right + 5, rect.top - 1), 10, Colors.white38, maxWidth: _rightPad - 8);
  }

  void _drawLine(
    Canvas canvas,
    List<EasyMacdPoint> rows,
    double Function(int) rawToX,
    double Function(double) valueToY,
    double? Function(EasyMacdPoint row) valueOf,
    Color color,
  ) {
    final path = Path();
    var started = false;
    for (final row in rows) {
      final value = valueOf(row);
      if (value == null) {
        started = false;
        continue;
      }
      final p = Offset(rawToX(row.rawIndex), valueToY(value));
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.86)
        ..strokeWidth = 1.05
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color, {double maxWidth = 520}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  String _fmt(Object? value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    if (n == null) return '--';
    if (n.abs() >= 100000000) return '${(n / 100000000).toStringAsFixed(2)}亿';
    if (n.abs() >= 10000) return '${(n / 10000).toStringAsFixed(2)}万';
    if (n.abs() >= 100) return n.toStringAsFixed(2);
    return n.toStringAsFixed(4);
  }

  @override
  bool shouldRepaint(covariant _OriginIndicatorPanePainter oldDelegate) =>
      oldDelegate.snapshot != snapshot ||
      oldDelegate.showVol != showVol ||
      oldDelegate.showMacd != showMacd ||
      oldDelegate.windowSize != windowSize ||
      oldDelegate.viewEndIndex != viewEndIndex ||
      oldDelegate.crosshairIndex != crosshairIndex;
}

enum _PaneKind { vol, macd }

class _PaneSpec {
  final String label;
  final _PaneKind kind;

  const _PaneSpec(this.label, this.kind);
}
