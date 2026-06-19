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
/// This adapter deliberately does not use visual-only Transform based zoom/pan.
/// The previous implementation moved a rendered chart bitmap while the original
/// painter, axes, crosshair, S13 marker overlay and chip distribution still used
/// the old viewport. That made the chart feel detached and caused overlays to
/// drift away from the candles.
///
/// This version keeps a single rendered chart and translates user input into the
/// existing viewport callbacks:
/// - wheel: anchored horizontal zoom + vertical zoom;
/// - ctrl + wheel: vertical zoom only;
/// - ctrl + alt + wheel: anchored horizontal zoom only;
/// - primary-button horizontal drag: real bar-window panning through onPanBars;
/// - primary-button vertical drag: real price-scale adjustment through
///   onPriceScaleChanged.
/// - middle-button vertical drag: translate the price viewport up or down.
///
/// The original renderer remains the single source of truth for coordinates.
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
  final double priceOffset;
  final int? viewEndIndex;
  final int? crosshairIndex;
  final ValueChanged<int>? onCrosshairChanged;
  final ValueChanged<int>? onPanBars;
  final ValueChanged<int>? onWindowSizeChanged;
  final ValueChanged<double>? onPriceScaleChanged;
  final ValueChanged<double>? onPriceOffsetChanged;
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
    this.priceOffset = 0.0,
    this.viewEndIndex,
    this.crosshairIndex,
    this.onCrosshairChanged,
    this.onPanBars,
    this.onWindowSizeChanged,
    this.onPriceScaleChanged,
    this.onPriceOffsetChanged,
    this.onEasyTdxSubPanelCountChanged,
    this.onEasyTdxIndicatorToggled,
  });

  @override
  State<OriginKlineChart> createState() => _OriginKlineChartState();
}

enum _DragAxis { horizontal, vertical }

class _OriginKlineChartState extends State<OriginKlineChart> {
  static const int _minWindowSize = 1;
  static const double _minPriceScale = 0.000001;
  static const double _topPad = 32.0;
  static const double _bottomPad = 28.0;
  static const double _leftPad = 4.0;
  static const double _rightPad = 58.0;
  static const double _subPanelHeight = 74.0;
  static const double _panelGap = 6.0;
  static const double _dragAxisLockThreshold = 3.5;

  _DragAxis? _dragAxis;
  double _panRemainder = 0.0;
  bool _dragSessionActive = false;
  bool _middleDragSession = false;
  TradingViewDrawingTool _selectedTool = TradingViewDrawingTool.cursor;

  @override
  void initState() {
    super.initState();
    _selectedTool = widget.toolboxSelectedToolSignal?.value ??
        TradingViewDrawingTool.cursor;
    widget.toolboxSelectedToolSignal?.addListener(_handleToolSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant OriginKlineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.toolboxSelectedToolSignal !=
        widget.toolboxSelectedToolSignal) {
      oldWidget.toolboxSelectedToolSignal
          ?.removeListener(_handleToolSelectionChanged);
      _selectedTool = widget.toolboxSelectedToolSignal?.value ??
          TradingViewDrawingTool.cursor;
      widget.toolboxSelectedToolSignal
          ?.addListener(_handleToolSelectionChanged);
      _clearDragState();
    }
  }

  @override
  void dispose() {
    widget.toolboxSelectedToolSignal
        ?.removeListener(_handleToolSelectionChanged);
    super.dispose();
  }

  void _handleToolSelectionChanged() {
    final next = widget.toolboxSelectedToolSignal?.value ??
        TradingViewDrawingTool.cursor;
    if (next == _selectedTool) return;
    setState(() => _selectedTool = next);
    _clearDragState();
  }

  bool get _isViewportDragEnabled =>
      _selectedTool == TradingViewDrawingTool.cursor ||
      _selectedTool == TradingViewDrawingTool.crosshair;

  int get _safeWindowSize => math.max(_minWindowSize, widget.windowSize);

  int get _currentEndIndex {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty) return 0;
    return (widget.viewEndIndex ?? bars.length - 1)
        .clamp(0, bars.length - 1)
        .toInt();
  }

  int get _currentStartIndex {
    final end = _currentEndIndex;
    return math.max(0, end - _safeWindowSize + 1).toInt();
  }

  double get _safePriceScale {
    final scale = widget.priceScale;
    if (!scale.isFinite) return 1.0;
    return math.max(_minPriceScale, scale);
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

  int get _activeSubPanelCount {
    if (!widget.showEasyTdxIndicators || widget.snapshot.indicators.isEmpty) {
      return 0;
    }
    return widget.easyTdxSubPanelCount.clamp(0, 4).toInt();
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
    return _ChartRects(
      mainRect: Rect.fromLTWH(_leftPad, _topPad, contentWidth, mainHeight),
    );
  }

  void _handleWheel(PointerScrollEvent event, _ChartRects rects) {
    final dy = event.scrollDelta.dy;
    if (dy == 0 || !rects.mainRect.contains(event.localPosition)) return;

    final zoomIn = dy < 0;
    final horizontalFactor = zoomIn ? 0.88 : 1.12;
    final verticalFactor = zoomIn ? 1.12 : 1 / 1.12;
    final ctrl = _isControlPressed;
    final alt = _isAltPressed;

    if (ctrl && alt) {
      _zoomHorizontal(horizontalFactor, rects.mainRect, event.localPosition);
      return;
    }
    if (ctrl) {
      _zoomVertical(verticalFactor);
      return;
    }
    _zoomHorizontal(horizontalFactor, rects.mainRect, event.localPosition);
    _zoomVertical(verticalFactor);
  }

  void _zoomHorizontal(double factor, Rect mainRect, Offset localPosition) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty || mainRect.width <= 0) return;
    final nextWindow = math.max(
      _minWindowSize,
      (_safeWindowSize * factor).round(),
    );
    if (nextWindow == _safeWindowSize) return;

    final oldStart = _currentStartIndex;
    final oldEnd = _currentEndIndex;
    final oldVisibleCount = math.max(1, oldEnd - oldStart + 1);
    final fraction = ((localPosition.dx - mainRect.left) / mainRect.width)
        .clamp(0.0, 1.0)
        .toDouble();
    final anchorRaw = oldStart + fraction * math.max(0, oldVisibleCount - 1);
    final nextVisibleCount = math.min(nextWindow, bars.length);
    final nextEnd =
        (anchorRaw + (1 - fraction) * math.max(0, nextVisibleCount - 1))
            .round()
            .clamp(0, bars.length - 1)
            .toInt();
    final deltaEnd = nextEnd - oldEnd;

    widget.onWindowSizeChanged?.call(nextWindow);
    if (deltaEnd != 0) widget.onPanBars?.call(deltaEnd);
  }

  void _zoomVertical(double factor) {
    final next = math.max(_minPriceScale, _safePriceScale * factor);
    if ((next - _safePriceScale).abs() <= 0.000001) return;
    widget.onPriceScaleChanged?.call(next);
  }

  void _handlePointerDown(PointerDownEvent event, _ChartRects rects) {
    _clearDragState();
    if (!_isViewportDragEnabled) return;
    final middle = (event.buttons & kMiddleMouseButton) != 0;
    if (!middle && (event.buttons & kPrimaryMouseButton) == 0) return;
    if (!rects.mainRect.contains(event.localPosition)) return;
    _dragSessionActive = true;
    _middleDragSession = middle;
  }

  void _handlePointerMove(PointerMoveEvent event, _ChartRects rects) {
    if (!_dragSessionActive || !_isViewportDragEnabled) return;
    final requiredButton =
        _middleDragSession ? kMiddleMouseButton : kPrimaryMouseButton;
    if ((event.buttons & requiredButton) == 0) {
      _clearDragState();
      return;
    }
    final delta = event.delta;
    if (delta == Offset.zero) return;
    if (_middleDragSession) {
      _translatePriceViewport(delta.dy, rects.mainRect);
      return;
    }
    final axis = _dragAxis ?? _resolveDragAxis(delta);
    if (axis == null) return;
    _dragAxis = axis;

    switch (axis) {
      case _DragAxis.horizontal:
        _panHorizontal(delta.dx, rects.mainRect);
        break;
      case _DragAxis.vertical:
        _scalePriceByVerticalDrag(delta.dy);
        break;
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _clearDragState();
  }

  void _clearDragState() {
    _dragAxis = null;
    _panRemainder = 0.0;
    _dragSessionActive = false;
    _middleDragSession = false;
  }

  _DragAxis? _resolveDragAxis(Offset delta) {
    if (delta.distance < _dragAxisLockThreshold) return null;
    return delta.dx.abs() >= delta.dy.abs()
        ? _DragAxis.horizontal
        : _DragAxis.vertical;
  }

  void _panHorizontal(double dx, Rect mainRect) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty || mainRect.width <= 0) return;
    final visibleCount = math.max(1, _currentEndIndex - _currentStartIndex + 1);
    final step = mainRect.width / visibleCount;
    if (step <= 0 || !step.isFinite) return;
    _panRemainder += -dx / step;
    final panBars = _panRemainder.truncate();
    if (panBars == 0) return;
    widget.onPanBars?.call(panBars);
    _panRemainder -= panBars;
  }

  void _scalePriceByVerticalDrag(double dy) {
    if (dy.abs() <= 0.2) return;
    final factor = 1 + (-dy / 240);
    if (!factor.isFinite || factor <= 0) return;
    _zoomVertical(factor);
  }

  void _translatePriceViewport(double dy, Rect mainRect) {
    if (dy.abs() <= 0.2 || mainRect.height <= 0) return;
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty) return;
    final visible = bars.sublist(_currentStartIndex, _currentEndIndex + 1);
    final low = visible.map((bar) => bar.low).reduce(math.min);
    final high = visible.map((bar) => bar.high).reduce(math.max);
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final displayedRange = rawRange / _safePriceScale.clamp(0.35, 5.0);
    final next = widget.priceOffset + dy / mainRect.height * displayedRange;
    if (next.isFinite) widget.onPriceOffsetChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final rects = _chartRectsFor(size);
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) _handleWheel(event, rects);
        },
        onPointerDown: (event) => _handlePointerDown(event, rects),
        onPointerMove: (event) => _handlePointerMove(event, rects),
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
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
          windowSize: _safeWindowSize,
          priceScale: _safePriceScale,
          priceOffset: widget.priceOffset,
          viewEndIndex: widget.viewEndIndex,
          crosshairIndex: widget.crosshairIndex,
          onCrosshairChanged: widget.onCrosshairChanged,
          // Viewport is owned by this adapter. Keep the child renderer from
          // applying a second gesture update while still letting it handle
          // drawing tools, crosshair, labels and EasyTDX panel controls.
          onPanBars: (_) {},
          onWindowSizeChanged: (_) {},
          onPriceScaleChanged: (_) {},
          onEasyTdxSubPanelCountChanged: widget.onEasyTdxSubPanelCountChanged,
          onEasyTdxIndicatorToggled: widget.onEasyTdxIndicatorToggled,
        ),
      );
    });
  }
}

class _ChartRects {
  final Rect mainRect;

  const _ChartRects({required this.mainRect});
}
