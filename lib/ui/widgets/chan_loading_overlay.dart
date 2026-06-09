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

  const ChanLoadingOverlay({
    super.key,
    required this.state,
    this.message,
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
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _ChanLoadingPainter(
                      state: widget.state,
                      progress: _controller.value,
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
}

class _ChanLoadingPainter extends CustomPainter {
  final ChanLoadVisualState state;
  final double progress;

  const _ChanLoadingPainter({required this.state, required this.progress});

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
    final phase = state == ChanLoadVisualState.loading ? progress * math.pi * 2 : 0.0;

    final paths = <_LineSpec>[
      _LineSpec(const Color(0xFF64B5F6), 0.0),
      _LineSpec(const Color(0xFFFFD54F), math.pi * 0.62),
      _LineSpec(const Color(0xFFAB47BC), math.pi * 1.25),
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
    canvas.drawCircle(center, 3.2 + math.sin(progress * math.pi * 2).abs() * 1.4, dotPaint);
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
    return oldDelegate.state != state || oldDelegate.progress != progress;
  }
}

class _LineSpec {
  final Color color;
  final double phase;

  const _LineSpec(this.color, this.phase);
}
