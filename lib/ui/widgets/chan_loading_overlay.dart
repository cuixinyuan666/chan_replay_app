import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual states for the Chan-themed data loading overlay.
///
/// This widget is UI-only: it expresses loading/success/failure states with
/// intertwined lines and does not participate in chan.py calculation.
enum ChanLoadVisualState { loading, success, failure }

class ChanLoadingOverlay extends StatefulWidget {
  final ChanLoadVisualState state;
  final String? message;
  final DateTime? startedAt;
  final Duration? estimatedDuration;

  const ChanLoadingOverlay({
    super.key,
    required this.state,
    this.message,
    this.startedAt,
    this.estimatedDuration,
  });

  @override
  State<ChanLoadingOverlay> createState() => _ChanLoadingOverlayState();
}

class _ChanLoadingOverlayState extends State<ChanLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _drive();
  }

  @override
  void didUpdateWidget(covariant ChanLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _drive();
  }

  void _drive() {
    if (widget.state == ChanLoadVisualState.loading) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.message ??
        switch (widget.state) {
          ChanLoadVisualState.loading => '数据加载中',
          ChanLoadVisualState.success => '数据加载成功',
          ChanLoadVisualState.failure => '数据加载失败',
        };
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF05070A).withValues(alpha: 0.70),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final loadProgress = _loadProgress();
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _ChanLoadingPainter(
                      state: widget.state,
                      progress: _controller.value,
                      loadProgress: loadProgress,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: switch (widget.state) {
                        ChanLoadVisualState.loading => Colors.white70,
                        ChanLoadVisualState.success => const Color(0xFF8BE28B),
                        ChanLoadVisualState.failure => const Color(0xFFFF8A80),
                      },
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _loadProgress() {
    if (widget.state == ChanLoadVisualState.success) return 1.0;
    if (widget.state == ChanLoadVisualState.failure) return 1.0;
    final startedAt = widget.startedAt;
    final estimate = widget.estimatedDuration;
    if (startedAt == null || estimate == null || estimate.inMilliseconds <= 0) {
      return 0.08 + _controller.value * 0.18;
    }
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    final ratio = elapsedMs / estimate.inMilliseconds;
    final eased = 1 - math.exp(-ratio * 1.35);
    return eased.clamp(0.04, 0.96).toDouble();
  }
}

class _ChanLoadingPainter extends CustomPainter {
  final ChanLoadVisualState state;
  final double progress;
  final double loadProgress;

  const _ChanLoadingPainter({
    required this.state,
    required this.progress,
    required this.loadProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final width = math.min(size.width * 0.70, 520.0);
    final height = math.min(size.height * 0.30, 180.0);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final split = state == ChanLoadVisualState.loading
        ? 0.0
        : Curves.easeInOutCubic.transform(progress).clamp(0.0, 1.0);
    final phase =
        state == ChanLoadVisualState.loading ? progress * math.pi * 2 : 0.0;

    final paths = <_LineSpec>[
      const _LineSpec(Color(0xFF64B5F6), 0.0),
      const _LineSpec(Color(0xFFFFD54F), math.pi * 0.62),
      const _LineSpec(Color(0xFFAB47BC), math.pi * 1.25),
    ];

    for (final spec in paths) {
      final path = Path();
      final left = _halfPath(
        center: center,
        width: width,
        height: height,
        side: -1,
        phase: phase + spec.phase,
        split: split,
      );
      final right = _halfPath(
        center: center,
        width: width,
        height: height,
        side: 1,
        phase: phase + spec.phase,
        split: split,
      );
      path.addPath(left, Offset.zero);
      path.addPath(right, Offset.zero);

      glowPaint.color = spec.color.withValues(alpha: 0.22);
      canvas.drawPath(path, glowPaint);
      basePaint.color = spec.color.withValues(alpha: 0.92);
      canvas.drawPath(path, basePaint);
    }

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.52);
    canvas.drawCircle(
        center, 3.2 + math.sin(progress * math.pi * 2).abs() * 1.4, dotPaint);
    _drawSmartProgress(canvas, size);
  }

  void _drawSmartProgress(Canvas canvas, Size size) {
    final width = math.min(size.width * 0.62, 520.0);
    final left = (size.width - width) / 2;
    final top = size.height * 0.76;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, 7),
      const Radius.circular(99),
    );
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(track, trackPaint);

    final solid = state == ChanLoadVisualState.failure ? 1.0 : loadProgress;
    final ghost = state == ChanLoadVisualState.loading
        ? math.min(0.985,
            solid + 0.10 + 0.045 * math.sin(progress * math.pi * 2).abs())
        : 1.0;
    final ghostPaint = Paint()
      ..color = const Color(0xFF90CAF9).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width * ghost, 7),
        const Radius.circular(99),
      ),
      ghostPaint,
    );

    final solidColor = switch (state) {
      ChanLoadVisualState.loading => const Color(0xFFFFD54F),
      ChanLoadVisualState.success => const Color(0xFF8BE28B),
      ChanLoadVisualState.failure => const Color(0xFFFF8A80),
    };
    final solidPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          solidColor.withValues(alpha: 0.68),
          solidColor,
        ],
      ).createShader(Rect.fromLTWH(left, top, width, 7))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width * solid.clamp(0.0, 1.0), 7),
        const Radius.circular(99),
      ),
      solidPaint,
    );
  }

  Path _halfPath({
    required Offset center,
    required double width,
    required double height,
    required int side,
    required double phase,
    required double split,
  }) {
    final path = Path();
    const steps = 44;
    final half = width / 2;
    final terminalLift = switch (state) {
      ChanLoadVisualState.loading => 0.0,
      ChanLoadVisualState.success => -height * 0.52 * split,
      ChanLoadVisualState.failure => height * 0.52 * split,
    };
    final spread = half * 0.18 * split;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = center.dx + side * (t * half + spread * t);
      final wave = math.sin(t * math.pi * 3.0 + phase) * height * 0.18;
      final y = center.dy + wave + terminalLift * t;
      if (i == 0) {
        path.moveTo(center.dx + side * spread * 0.12, center.dy);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _ChanLoadingPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.progress != progress ||
        oldDelegate.loadProgress != loadProgress;
  }
}

class _LineSpec {
  final Color color;
  final double phase;

  const _LineSpec(this.color, this.phase);
}
