import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/chan_snapshot.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import 'origin_kline_chart.dart' as origin;

/// Mouse/trackpad interaction adapter for [origin.OriginKlineChart].
///
/// The original chart renderer is intentionally kept unchanged. This adapter
/// owns only viewport interaction state and delegates painting, drawing tools,
/// indicators, and crosshair behavior to the existing chart.
///
/// Interaction policy:
/// - wheel: horizontal + vertical zoom, without artificial upper bounds;
/// - ctrl + wheel: vertical zoom only, without artificial upper bounds;
/// - ctrl + alt + wheel: horizontal zoom only, without artificial upper bounds;
/// - primary-button drag: visual x/y chart translation without boundary clamp;
/// - horizontal drag also forwards bar panning to the caller when possible.
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
  final bool showBiBsp;
  final bool showSegBsp;
  final bool showMergedBars;
  final bool showEasyTdxIndicators;
  final int easyTdxSubPanelCount;
  final Set<String> enabledEasyTdxIndicators;
  final List<DrawingObject> drawingObjects;
  final String drawingStorageKey;
  final String symbolLabel;
  final bool Function(TradingViewDrawingTool tool)? isChanOverlayVisible;
  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;
  final ValueListenable<int>? toolboxOpenSignal;
  final ValueListenable<TradingViewDrawingTool?>? toolboxSelectedToolSignal;
  final ValueChanged<TradingViewDrawingTool>? onToolboxQuickToolAdded;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final int? crosshairIndex;
  final ValueChanged<int>? onCrosshairChanged;
  final ValueChanged<int>? onPanBars;
  final ValueChanged<int>? onWindowSizeChanged;
  final ValueChanged<double>? onPriceScaleChanged;
  final ValueChanged<int>? onEasyTdxSubPanelCountChanged;
  final ValueChanged<String>? onEasyTdxIndicatorToggled;

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
    required this.showBiBsp,
    required this.showSegBsp,
    this.showMergedBars = false,
    this.showEasyTdxIndicators = false,
    this.easyTdxSubPanelCount = 2,
    this.enabledEasyTdxIndicators = const {'MA', 'BOLL', 'VOL', 'MACD'},
    this.drawingObjects = const [],
    this.drawingStorageKey = '',
    this.symbolLabel = '',
    this.isChanOverlayVisible,
    this.onChanOverlayToggled,
    this.toolboxOpenSignal,
    this.toolboxSelectedToolSignal,
    this.onToolboxQuickToolAdded,
    required this.windowSize,
    this.priceScale = 1.0,
    this.viewEndIndex,
    this.crosshairIndex,
    this.onCrosshairChanged,
    this.onPanBars,
    this.onWindowSizeChanged,
    this.onPriceScaleChanged,
    this.onEasyTdxSubPanelCountChanged,
    this.onEasyTdxIndicatorToggled,
  });

  @override
  State<OriginKlineChart> createState() => _OriginKlineChartState();
}

class _OriginKlineChartState extends State<OriginKlineChart> {
  static const double _minWindowSize = 0.05;
  static const double _minPriceScale = 0.000001;
  static const double _originMinPriceScale = 0.35;
  static const double _originMaxPriceScale = 5.0;
  static const double _leftPad = 4.0;
  static const double _rightPad = 58.0;

  late double _windowSize;
  late double _priceScale;
  Offset _chartOffset = Offset.zero;
  double _panRemainder = 0.0;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _windowSize = _safeWindowSize(widget.windowSize.toDouble());
    _priceScale = _safePriceScale(widget.priceScale);
  }

  @override
  void didUpdateWidget(covariant OriginKlineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameBarRange(oldWidget.snapshot, widget.snapshot)) {
      _windowSize = _safeWindowSize(widget.windowSize.toDouble());
      _priceScale = _safePriceScale(widget.priceScale);
      _chartOffset = Offset.zero;
      _panRemainder = 0.0;
      return;
    }
    if (oldWidget.windowSize != widget.windowSize &&
        widget.windowSize.round() != _paintWindowSize) {
      _windowSize = _safeWindowSize(widget.windowSize.toDouble());
    }
    if (oldWidget.priceScale != widget.priceScale &&
        (widget.priceScale - _priceScale).abs() > 0.000001) {
      _priceScale = _safePriceScale(widget.priceScale);
    }
  }

  bool _isSameBarRange(ChanSnapshot a, ChanSnapshot b) {
    final left = a.rawBars;
    final right = b.rawBars;
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    if (left.isEmpty) return true;
    return left.first.time == right.first.time &&
        left.last.time == right.last.time;
  }

  int get _paintWindowSize => math.max(1, _windowSize.round());

  double get _originPriceScale =>
      _priceScale.clamp(_originMinPriceScale, _originMaxPriceScale).toDouble();

  double get _extraScaleY {
    final base = _originPriceScale;
    if (base <= 0) return 1.0;
    return _safeVisualScale(_priceScale / base);
  }

  double get _extraScaleX {
    final bars = math.max(1.0, widget.snapshot.rawBars.length.toDouble());
    if (_windowSize < 1.0) return _safeVisualScale(1.0 / _windowSize);
    if (_windowSize > bars) return _safeVisualScale(bars / _windowSize);
    return 1.0;
  }

  double _safeVisualScale(double value) {
    if (!value.isFinite || value <= 0) return 1.0;
    return math.max(_minPriceScale, value);
  }

  double _safeWindowSize(double value) {
    if (!value.isFinite) return _minWindowSize;
    return math.max(_minWindowSize, value);
  }

  double _safePriceScale(double value) {
    if (!value.isFinite) return 1.0;
    return math.max(_minPriceScale, value);
  }

  bool get _isControlPressed {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
  }

  bool get _isAltPressed {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
  }

  void _handleWheel(PointerScrollEvent event) {
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    final zoomIn = dy < 0;
    final horizontalFactor = zoomIn ? 0.88 : 1.12;
    final verticalFactor = zoomIn ? 1.12 : 1 / 1.12;
    final ctrl = _isControlPressed;
    final alt = _isAltPressed;

    if (ctrl && alt) {
      _zoomHorizontal(horizontalFactor);
      return;
    }
    if (ctrl) {
      _zoomVertical(verticalFactor);
      return;
    }
    _zoomHorizontal(horizontalFactor);
    _zoomVertical(verticalFactor);
  }

  void _zoomHorizontal(double factor) {
    final next = _safeWindowSize(_windowSize * factor);
    if ((next - _windowSize).abs() <= 0.000001) return;
    setState(() => _windowSize = next);
    widget.onWindowSizeChanged?.call(_paintWindowSize);
  }

  void _zoomVertical(double factor) {
    final next = _safePriceScale(_priceScale * factor);
    if ((next - _priceScale).abs() <= 0.000001) return;
    setState(() => _priceScale = next);
    widget.onPriceScaleChanged?.call(next);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if ((event.buttons & kPrimaryMouseButton) == 0) return;
    final delta = event.delta;
    if (delta == Offset.zero) return;
    setState(() => _chartOffset += delta);
    _forwardHorizontalPan(delta.dx);
  }

  void _handlePointerUp(PointerEvent event) => _panRemainder = 0.0;

  void _forwardHorizontalPan(double dx) {
    final step = _estimatedBarStep;
    if (step <= 0 || dx.abs() <= 0.2) return;
    _panRemainder += -dx / step;
    final bars = _panRemainder.truncate();
    if (bars == 0) return;
    widget.onPanBars?.call(bars);
    _panRemainder -= bars;
  }

  double get _estimatedBarStep {
    final visibleCount = math.min(
      math.max(1.0, widget.snapshot.rawBars.length.toDouble()),
      math.max(1.0, _paintWindowSize.toDouble()),
    );
    final chartWidth = math.max(1.0, _lastSize.width - _leftPad - _rightPad);
    return chartWidth / visibleCount;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) _handleWheel(event);
        },
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerUp,
        child: ClipRect(
          child: Transform.translate(
            offset: _chartOffset,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(_extraScaleX, _extraScaleY, 1),
              child: origin.OriginKlineChart(
                snapshot: widget.snapshot,
                showFx: widget.showFx,
                showFxLine: widget.showFxLine,
                showFxText: widget.showFxText,
                showBi: widget.showBi,
                showBiText: widget.showBiText,
                showSeg: widget.showSeg,
                showSegText: widget.showSegText,
                showZs: widget.showZs,
                showBiBsp: widget.showBiBsp,
                showSegBsp: widget.showSegBsp,
                showMergedBars: widget.showMergedBars,
                showEasyTdxIndicators: widget.showEasyTdxIndicators,
                easyTdxSubPanelCount: widget.easyTdxSubPanelCount,
                enabledEasyTdxIndicators: widget.enabledEasyTdxIndicators,
                drawingObjects: widget.drawingObjects,
                drawingStorageKey: widget.drawingStorageKey,
                symbolLabel: widget.symbolLabel,
                isChanOverlayVisible: widget.isChanOverlayVisible,
                onChanOverlayToggled: widget.onChanOverlayToggled,
                toolboxOpenSignal: widget.toolboxOpenSignal,
                toolboxSelectedToolSignal: widget.toolboxSelectedToolSignal,
                onToolboxQuickToolAdded: widget.onToolboxQuickToolAdded,
                windowSize: _paintWindowSize,
                priceScale: _originPriceScale,
                viewEndIndex: widget.viewEndIndex,
                crosshairIndex: widget.crosshairIndex,
                onCrosshairChanged: widget.onCrosshairChanged,
                onPanBars: (_) {},
                onWindowSizeChanged: (_) {},
                onPriceScaleChanged: (_) {},
                onEasyTdxSubPanelCountChanged:
                    widget.onEasyTdxSubPanelCountChanged,
                onEasyTdxIndicatorToggled: widget.onEasyTdxIndicatorToggled,
              ),
            ),
          ),
        ),
      );
    });
  }
}
