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
/// The original renderer is kept unchanged. This adapter owns viewport gestures
/// and clips the moved chart to the plot area. Fixed chart chrome is painted
/// above it, while `symbolLabel` is drawn by this adapter so it never enters the
/// movable layer.
///
/// Interaction policy:
/// - wheel: horizontal + vertical zoom, without artificial upper bounds;
/// - ctrl + wheel: vertical zoom only, without artificial upper bounds;
/// - ctrl + alt + wheel: horizontal zoom only, without artificial upper bounds;
/// - primary-button drag: locks to the dominant axis for the current drag and
///   moves only plot content, without boundary clamp.
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

enum _DragAxis { horizontal, vertical }

class _OriginKlineChartState extends State<OriginKlineChart> {
  static const double _minWindowSize = 0.05;
  static const double _minPriceScale = 0.000001;
  static const double _originMinPriceScale = 0.35;
  static const double _originMaxPriceScale = 5.0;
  static const double _topPad = 32.0;
  static const double _bottomPad = 28.0;
  static const double _leftPad = 4.0;
  static const double _rightPad = 58.0;
  static const double _subPanelHeight = 74.0;
  static const double _panelGap = 6.0;
  static const double _fixedMainLabelBand = 28.0;
  static const double _dragAxisLockThreshold = 2.0;

  late double _windowSize;
  late double _priceScale;
  Offset _chartOffset = Offset.zero;
  _DragAxis? _dragAxis;

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
      _dragAxis = null;
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

  int get _activeSubPanelCount {
    if (!widget.showEasyTdxIndicators || widget.snapshot.indicators.isEmpty) {
      return 0;
    }
    return widget.easyTdxSubPanelCount.clamp(0, 4).toInt();
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

  void _handlePointerDown(PointerDownEvent event) {
    if ((event.buttons & kPrimaryMouseButton) != 0) _dragAxis = null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if ((event.buttons & kPrimaryMouseButton) == 0) return;
    final delta = event.delta;
    if (delta == Offset.zero) return;
    final axis = _dragAxis ?? _resolveDragAxis(delta);
    if (axis == null) return;
    _dragAxis = axis;
    final lockedDelta = switch (axis) {
      _DragAxis.horizontal => Offset(delta.dx, 0),
      _DragAxis.vertical => Offset(0, delta.dy),
    };
    if (lockedDelta == Offset.zero) return;
    setState(() => _chartOffset += lockedDelta);
  }

  void _handlePointerEnd(PointerEvent event) {
    _dragAxis = null;
  }

  _DragAxis? _resolveDragAxis(Offset delta) {
    if (delta.distance < _dragAxisLockThreshold) return null;
    return delta.dx.abs() >= delta.dy.abs()
        ? _DragAxis.horizontal
        : _DragAxis.vertical;
  }

  _ChartRects _chartRectsFor(Size size) {
    final safeSubPanelCount = _activeSubPanelCount;
    final totalSubHeight = safeSubPanelCount == 0
        ? 0.0
        : safeSubPanelCount * _subPanelHeight +
            (safeSubPanelCount - 1) * _panelGap;
    final contentWidth = math.max(0.0, size.width - _leftPad - _rightPad);
    final mainHeight = math.max(
      0.0,
      size.height -
          _topPad -
          _bottomPad -
          totalSubHeight -
          (safeSubPanelCount > 0 ? _panelGap : 0),
    );
    final mainRect = Rect.fromLTWH(_leftPad, _topPad, contentWidth, mainHeight);
    final fullPlotRects = <Rect>[mainRect];
    final movableSourceRects = <Rect>[];
    final movableMainTop = mainRect.top + _fixedMainLabelBand;
    if (mainRect.width > 0 && mainRect.bottom > movableMainTop) {
      movableSourceRects.add(Rect.fromLTRB(
        mainRect.left,
        movableMainTop,
        mainRect.right,
        mainRect.bottom,
      ));
    }
    var top = mainRect.bottom + _panelGap;
    for (var i = 0; i < safeSubPanelCount; i++) {
      final rect = Rect.fromLTWH(_leftPad, top, contentWidth, _subPanelHeight);
      fullPlotRects.add(rect);
      movableSourceRects.add(rect);
      top += _subPanelHeight + _panelGap;
    }
    return _ChartRects(
      fullPlotRects:
          fullPlotRects.where((r) => r.width > 0 && r.height > 0).toList(),
      movableSourceRects: movableSourceRects
          .where((r) => r.width > 0 && r.height > 0)
          .toList(),
      mainRect: mainRect,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final rects = _chartRectsFor(size);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) _handleWheel(event);
        },
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ClipPath(
              clipper: _RectListClipper(rects.fullPlotRects),
              child: Transform.translate(
                offset: _chartOffset,
                child: Transform(
                  alignment: Alignment.center,
                  transform:
                      Matrix4.diagonal3Values(_extraScaleX, _extraScaleY, 1),
                  child: ClipPath(
                    clipper: _RectListClipper(rects.movableSourceRects),
                    child: _originChart(
                      symbolLabel: '',
                      drawingStorageKey: widget.drawingStorageKey,
                      drawingObjects: widget.drawingObjects,
                      toolboxOpenSignal: widget.toolboxOpenSignal,
                      toolboxSelectedToolSignal: widget.toolboxSelectedToolSignal,
                      onToolboxQuickToolAdded: widget.onToolboxQuickToolAdded,
                      onCrosshairChanged: widget.onCrosshairChanged,
                      onEasyTdxSubPanelCountChanged:
                          widget.onEasyTdxSubPanelCountChanged,
                      onEasyTdxIndicatorToggled: widget.onEasyTdxIndicatorToggled,
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: ClipPath(
                clipper: _AxisChromeClipper(rects.fullPlotRects),
                child: _originChart(
                  symbolLabel: '',
                  drawingStorageKey:
                      '${widget.drawingStorageKey}__fixed_axis_chrome',
                  drawingObjects: const <DrawingObject>[],
                  toolboxOpenSignal: null,
                  toolboxSelectedToolSignal: null,
                  onToolboxQuickToolAdded: null,
                  onCrosshairChanged: null,
                  onEasyTdxSubPanelCountChanged: null,
                  onEasyTdxIndicatorToggled: null,
                ),
              ),
            ),
            _fixedSymbolLabel(rects.mainRect),
          ],
        ),
      );
    });
  }

  Widget _fixedSymbolLabel(Rect mainRect) {
    final label = widget.symbolLabel.trim();
    if (label.isEmpty || mainRect.width <= 0 || mainRect.height <= 0) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: mainRect.left + 12,
      top: mainRect.top + 10,
      child: IgnorePointer(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _originChart({
    required String symbolLabel,
    required String drawingStorageKey,
    required List<DrawingObject> drawingObjects,
    required ValueListenable<int>? toolboxOpenSignal,
    required ValueListenable<TradingViewDrawingTool?>? toolboxSelectedToolSignal,
    required ValueChanged<TradingViewDrawingTool>? onToolboxQuickToolAdded,
    required ValueChanged<int>? onCrosshairChanged,
    required ValueChanged<int>? onEasyTdxSubPanelCountChanged,
    required ValueChanged<String>? onEasyTdxIndicatorToggled,
  }) {
    return origin.OriginKlineChart(
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
      drawingObjects: drawingObjects,
      drawingStorageKey: drawingStorageKey,
      symbolLabel: symbolLabel,
      isChanOverlayVisible: widget.isChanOverlayVisible,
      onChanOverlayToggled: widget.onChanOverlayToggled,
      toolboxOpenSignal: toolboxOpenSignal,
      toolboxSelectedToolSignal: toolboxSelectedToolSignal,
      onToolboxQuickToolAdded: onToolboxQuickToolAdded,
      windowSize: _paintWindowSize,
      priceScale: _originPriceScale,
      viewEndIndex: widget.viewEndIndex,
      crosshairIndex: widget.crosshairIndex,
      onCrosshairChanged: onCrosshairChanged,
      onPanBars: (_) {},
      onWindowSizeChanged: (_) {},
      onPriceScaleChanged: (_) {},
      onEasyTdxSubPanelCountChanged: onEasyTdxSubPanelCountChanged,
      onEasyTdxIndicatorToggled: onEasyTdxIndicatorToggled,
    );
  }
}

class _ChartRects {
  final List<Rect> fullPlotRects;
  final List<Rect> movableSourceRects;
  final Rect mainRect;

  const _ChartRects({
    required this.fullPlotRects,
    required this.movableSourceRects,
    required this.mainRect,
  });
}

class _RectListClipper extends CustomClipper<Path> {
  final List<Rect> rects;

  const _RectListClipper(this.rects);

  @override
  Path getClip(Size size) {
    final path = Path();
    for (final rect in rects) {
      path.addRect(rect);
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _RectListClipper oldClipper) => true;
}

class _AxisChromeClipper extends CustomClipper<Path> {
  final List<Rect> plotRects;

  const _AxisChromeClipper(this.plotRects);

  @override
  Path getClip(Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final rect in plotRects) {
      path.addRect(rect);
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _AxisChromeClipper oldClipper) => true;
}
