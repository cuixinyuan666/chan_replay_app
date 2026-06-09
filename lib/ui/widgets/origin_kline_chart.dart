import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/models/bsp.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/fx.dart';
import '../../core/models/raw_bar.dart';
import '../drawing/drawing_object.dart';
import '../drawing/drawing_object_hit_test.dart';
import '../drawing/drawing_object_painter.dart';
import '../drawing/drawing_object_persistence.dart';
import '../drawing/tradingview_drawing_tool.dart';
import '../drawing/tradingview_toolbox_host.dart';

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
  final List<DrawingObject> drawingObjects;
  final String drawingStorageKey;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final int? crosshairIndex;
  final ValueChanged<int>? onCrosshairChanged;
  final ValueChanged<int>? onPanBars;
  final ValueChanged<int>? onWindowSizeChanged;
  final ValueChanged<double>? onPriceScaleChanged;

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
    this.drawingObjects = const [],
    this.drawingStorageKey = '',
    required this.windowSize,
    this.priceScale = 1.0,
    this.viewEndIndex,
    this.crosshairIndex,
    this.onCrosshairChanged,
    this.onPanBars,
    this.onWindowSizeChanged,
    this.onPriceScaleChanged,
  });

  @override
  State<OriginKlineChart> createState() => _OriginKlineChartState();
}

class _OriginKlineChartState extends State<OriginKlineChart> {
  static const Set<TradingViewDrawingTool> _interactiveDrawingTools = {
    TradingViewDrawingTool.trendLine,
    TradingViewDrawingTool.infoLine,
    TradingViewDrawingTool.arrow,
    TradingViewDrawingTool.horizontalLine,
    TradingViewDrawingTool.horizontalRay,
    TradingViewDrawingTool.verticalLine,
    TradingViewDrawingTool.rectangle,
    TradingViewDrawingTool.text,
    TradingViewDrawingTool.anchoredText,
    TradingViewDrawingTool.note,
    TradingViewDrawingTool.priceLabel,
    TradingViewDrawingTool.priceNote,
    TradingViewDrawingTool.ruler,
    TradingViewDrawingTool.dateRange,
    TradingViewDrawingTool.priceRange,
    TradingViewDrawingTool.dateAndPriceRange,
  };

  int? _scaleStartWindow;
  double _panRemainder = 0;
  int _drawingSeq = 0;
  TradingViewDrawingTool _selectedDrawingTool = TradingViewDrawingTool.cursor;
  DrawingObjectCollection _drawings = const DrawingObjectCollection();
  List<DrawingAnchor> _pendingAnchors = const [];
  _DrawingDragState? _dragState;
  String _loadedStorageKey = '';

  String get _effectiveStorageKey {
    final explicit = widget.drawingStorageKey.trim();
    if (explicit.isNotEmpty) return explicit;
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty) return 'empty';
    return 'snapshot_${bars.length}_${bars.first.time.toIso8601String()}_${bars.last.time.toIso8601String()}';
  }

  List<DrawingObject> get _effectiveDrawingObjects {
    if (widget.drawingObjects.isEmpty) return _drawings.objects;
    return [...widget.drawingObjects, ..._drawings.objects];
  }

  DrawingObject? get _selectedDrawing {
    for (final object in _drawings.objects) {
      if (object.selected) return object;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadPersistedDrawings();
  }

  @override
  void didUpdateWidget(covariant OriginKlineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_effectiveStorageKey != _loadedStorageKey) _loadPersistedDrawings();
  }

  @override
  Widget build(BuildContext context) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty) {
      return const Center(child: Text('暂无K线数据', style: TextStyle(color: Colors.white70)));
    }
    final selectedDrawing = _selectedDrawing;
    return TradingViewToolboxHost(
      hasBars: bars.isNotEmpty,
      hasChanSnapshot: widget.snapshot.rawBars.isNotEmpty,
      selectedTool: _selectedDrawingTool,
      drawingCount: _drawings.objects.length,
      onSelected: _selectDrawingTool,
      onClearDrawings: _drawings.objects.isEmpty
          ? null
          : () {
              _setDrawings(const DrawingObjectCollection());
              _showDrawMessage('已清空手动画线');
            },
      child: Stack(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) _handleWheel(event, size);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handleTap(details.localPosition, size),
                onLongPressStart: (details) => _updateCrosshair(details.localPosition, size),
                onLongPressMoveUpdate: (details) => _updateCrosshair(details.localPosition, size),
                onScaleStart: (details) {
                  _scaleStartWindow = widget.windowSize;
                  _panRemainder = 0;
                  if (!_interactiveDrawingTools.contains(_selectedDrawingTool)) {
                    _startDrawingDrag(details.localFocalPoint, size);
                  }
                },
                onScaleUpdate: (details) => _handleScale(details, size),
                onScaleEnd: (_) => _endDrawingDrag(),
                child: CustomPaint(
                  painter: _OriginChartPainter(
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
                    drawingObjects: _effectiveDrawingObjects,
                    windowSize: widget.windowSize,
                    priceScale: widget.priceScale,
                    viewEndIndex: widget.viewEndIndex,
                    crosshairIndex: widget.crosshairIndex,
                  ),
                  size: Size.infinite,
                ),
              ),
            );
          }),
          Positioned(left: 52, bottom: 8, child: _DrawingPersistenceBar(drawingCount: _drawings.objects.length, onImport: _importDrawings, onExport: _drawings.objects.isEmpty ? null : _exportDrawings)),
          if (selectedDrawing != null) Positioned(right: 68, top: 8, child: _SelectedDrawingBar(object: selectedDrawing, onDelete: _deleteSelectedDrawing, onToggleLock: _toggleSelectedDrawingLock, onToggleHidden: _toggleSelectedDrawingHidden, onCancel: _clearDrawingSelection)),
        ],
      ),
    );
  }

  Future<void> _loadPersistedDrawings() async {
    final key = _effectiveStorageKey;
    _loadedStorageKey = key;
    final objects = await DrawingObjectPersistence.load(key);
    if (!mounted || key != _effectiveStorageKey) return;
    setState(() {
      _drawings = DrawingObjectCollection(objects: objects.map((e) => e.selectOnly(false)).toList(growable: false));
      _pendingAnchors = const [];
      _dragState = null;
    });
  }

  void _setDrawings(DrawingObjectCollection next, {bool persist = true}) {
    setState(() {
      _drawings = next;
      _pendingAnchors = const [];
      _dragState = null;
    });
    if (persist) _persistDrawings();
  }

  Future<void> _persistDrawings() async {
    try {
      await DrawingObjectPersistence.save(_effectiveStorageKey, _drawings.objects);
    } catch (e) {
      _showDrawMessage('画线自动保存失败：$e');
    }
  }

  Future<void> _importDrawings() async {
    try {
      final objects = await DrawingObjectPersistence.importFromFile();
      if (objects == null) return;
      _setDrawings(DrawingObjectCollection(objects: objects.map((e) => e.selectOnly(false)).toList(growable: false)));
      _showDrawMessage('已导入 ${objects.length} 个手动画线对象');
    } catch (e) {
      _showDrawMessage('导入画线失败：$e');
    }
  }

  Future<void> _exportDrawings() async {
    if (_drawings.objects.isEmpty) {
      _showDrawMessage('暂无手动画线可导出');
      return;
    }
    try {
      final path = await DrawingObjectPersistence.exportToFile(storageKey: _effectiveStorageKey, objects: _drawings.objects);
      if (path != null) _showDrawMessage('已导出手动画线 JSON');
    } catch (e) {
      _showDrawMessage('导出画线失败：$e');
    }
  }

  void _selectDrawingTool(TradingViewDrawingTool tool) {
    setState(() {
      _selectedDrawingTool = tool;
      _pendingAnchors = const [];
      _dragState = null;
    });
  }

  void _handleTap(Offset p, Size size) {
    if (!_interactiveDrawingTools.contains(_selectedDrawingTool)) {
      final hit = _hitTestDrawing(p, size);
      if (hit != null) {
        _selectExistingDrawing(hit);
        return;
      }
      _clearDrawingSelection(updateStateOnly: true);
      _updateCrosshair(p, size);
      return;
    }
    final anchor = _chartAnchorAt(p, size);
    if (anchor == null) return;
    final meta = TradingViewDrawingToolRegistry.metaOf(_selectedDrawingTool);
    if (meta.requiresChanSnapshot || meta.minPoints <= 0) {
      _updateCrosshair(p, size);
      return;
    }
    final needed = math.max(1, meta.minPoints);
    final anchors = [..._pendingAnchors, anchor];
    if (anchors.length < needed) {
      setState(() => _pendingAnchors = anchors);
      _showDrawMessage('${meta.label}：已记录第 ${anchors.length}/$needed 个锚点，请继续点击');
      return;
    }

    final now = DateTime.now();
    final object = DrawingObject(
      id: 'draw_${now.microsecondsSinceEpoch}_${_drawingSeq++}',
      tool: _selectedDrawingTool,
      anchors: anchors.take(needed).toList(growable: false),
      style: _defaultStyleFor(_selectedDrawingTool),
      text: _defaultTextFor(_selectedDrawingTool, anchor),
      selected: true,
      createdAt: now,
      updatedAt: now,
    );
    _setDrawings(_drawings.clearSelection().upsert(object));
    _showDrawMessage('已创建：${meta.label}');
  }

  DrawingObject? _hitTestDrawing(Offset p, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null || !meta.chartRect.contains(p)) return null;
    return DrawingObjectHitTest.hitTest(objects: _drawings.objects, point: p, chartRect: meta.chartRect, startRawIndex: meta.startIndex, endRawIndex: meta.endIndex, rawToX: meta.rawToX, priceToY: meta.priceToY);
  }

  void _selectExistingDrawing(DrawingObject object) {
    setState(() {
      _drawings = _drawings.select(object.id);
      _pendingAnchors = const [];
      _dragState = null;
    });
    final meta = TradingViewDrawingToolRegistry.metaOf(object.tool);
    _showDrawMessage('已选中：${meta.label}${object.locked ? '（已锁定）' : ''}');
  }

  void _clearDrawingSelection({bool updateStateOnly = false}) {
    final hasSelected = _selectedDrawing != null;
    if (!hasSelected) return;
    setState(() {
      _drawings = _drawings.clearSelection();
      _pendingAnchors = const [];
      _dragState = null;
    });
    if (!updateStateOnly) _showDrawMessage('已取消选择');
  }

  void _deleteSelectedDrawing() {
    final selected = _selectedDrawing;
    if (selected == null || selected.locked) return;
    _setDrawings(_drawings.remove(selected.id));
    _showDrawMessage('已删除手动画线');
  }

  void _toggleSelectedDrawingLock() {
    final selected = _selectedDrawing;
    if (selected == null) return;
    final next = selected.lock(!selected.locked);
    _setDrawings(_drawings.upsert(next));
    _showDrawMessage(next.locked ? '已锁定对象' : '已解锁对象');
  }

  void _toggleSelectedDrawingHidden() {
    final selected = _selectedDrawing;
    if (selected == null) return;
    final next = selected.hide(!selected.hidden);
    _setDrawings(_drawings.upsert(next));
    _showDrawMessage(next.hidden ? '已隐藏对象，可在当前浮条恢复' : '已恢复显示对象');
  }

  void _startDrawingDrag(Offset p, Size size) {
    final selected = _selectedDrawing;
    final meta = _visibleMeta(size);
    final pointerAnchor = _chartAnchorAt(p, size);
    if (selected == null || meta == null || pointerAnchor == null || selected.locked || selected.hidden) {
      _dragState = null;
      return;
    }
    final handleIndex = _hitDrawingHandle(selected, p, meta);
    if (handleIndex != null) {
      _dragState = _DrawingDragState(object: selected, mode: _DrawingDragMode.anchor, anchorIndex: handleIndex, startPointerAnchor: pointerAnchor);
      return;
    }
    final bodyHit = DrawingObjectHitTest.hitTest(objects: [selected], point: p, chartRect: meta.chartRect, startRawIndex: meta.startIndex, endRawIndex: meta.endIndex, rawToX: meta.rawToX, priceToY: meta.priceToY, tolerance: 10);
    if (bodyHit != null) {
      _dragState = _DrawingDragState(object: selected, mode: _DrawingDragMode.body, startPointerAnchor: pointerAnchor);
      return;
    }
    _dragState = null;
  }

  void _updateDrawingDrag(Offset p, Size size) {
    final state = _dragState;
    if (state == null) return;
    final pointerAnchor = _chartAnchorAt(p, size);
    if (pointerAnchor == null) return;
    final nextAnchors = switch (state.mode) {
      _DrawingDragMode.anchor => _anchorsWithMovedHandle(state.object, state.anchorIndex ?? 0, pointerAnchor),
      _DrawingDragMode.body => _anchorsWithMovedBody(state.object, state.startPointerAnchor, pointerAnchor),
    };
    DrawingObject? current;
    for (final object in _drawings.objects) {
      if (object.id == state.object.id) {
        current = object;
        break;
      }
    }
    if (current == null || current.locked) return;
    setState(() {
      _drawings = _drawings.upsert(current!.copyWith(anchors: nextAnchors, selected: true, updatedAt: DateTime.now()));
    });
  }

  void _endDrawingDrag() {
    if (_dragState == null) return;
    _dragState = null;
    _persistDrawings();
  }

  int? _hitDrawingHandle(DrawingObject object, Offset p, _VisibleMeta meta) {
    for (var i = 0; i < object.anchors.length; i++) {
      final anchor = object.anchors[i];
      if (!anchor.isChart || anchor.rawIndex == null || anchor.price == null) continue;
      final handle = Offset(meta.rawToX(anchor.rawIndex!), meta.priceToY(anchor.price!));
      if ((p - handle).distance <= 12) return i;
    }
    return null;
  }

  List<DrawingAnchor> _anchorsWithMovedHandle(DrawingObject object, int index, DrawingAnchor pointerAnchor) => [for (var i = 0; i < object.anchors.length; i++) if (i == index && object.anchors[i].isChart) pointerAnchor else object.anchors[i]];

  List<DrawingAnchor> _anchorsWithMovedBody(DrawingObject object, DrawingAnchor startPointerAnchor, DrawingAnchor pointerAnchor) {
    final deltaRaw = (pointerAnchor.rawIndex ?? 0) - (startPointerAnchor.rawIndex ?? 0);
    final deltaPrice = (pointerAnchor.price ?? 0) - (startPointerAnchor.price ?? 0);
    final maxRaw = math.max(0, widget.snapshot.rawBars.length - 1);
    return [for (final anchor in object.anchors) if (anchor.isChart && anchor.rawIndex != null && anchor.price != null) DrawingAnchor.chart(rawIndex: (anchor.rawIndex! + deltaRaw).clamp(0, maxRaw).toInt(), price: anchor.price! + deltaPrice) else anchor];
  }

  DrawingAnchor? _chartAnchorAt(Offset p, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null || !meta.chartRect.contains(p)) return null;
    return meta.anchorAt(p);
  }

  DrawingStyle _defaultStyleFor(TradingViewDrawingTool tool) {
    final isMeasure = tool == TradingViewDrawingTool.ruler || tool == TradingViewDrawingTool.dateRange || tool == TradingViewDrawingTool.priceRange || tool == TradingViewDrawingTool.dateAndPriceRange;
    return switch (tool) {
      TradingViewDrawingTool.rectangle => const DrawingStyle(colorValue: 0xFF82B1FF, strokeWidth: 1.2, filled: true, fillColorValue: 0x332962FF, fillOpacity: 0.18),
      TradingViewDrawingTool.horizontalLine || TradingViewDrawingTool.horizontalRay => const DrawingStyle(colorValue: 0xFFFFD54F, strokeWidth: 1.2, dashed: true),
      TradingViewDrawingTool.verticalLine => const DrawingStyle(colorValue: 0xFFB0BEC5, strokeWidth: 1.1, dashed: true),
      TradingViewDrawingTool.text || TradingViewDrawingTool.anchoredText || TradingViewDrawingTool.note || TradingViewDrawingTool.priceLabel || TradingViewDrawingTool.priceNote => const DrawingStyle(colorValue: 0xFFFFFFFF, fontSize: 12.5),
      _ when isMeasure => const DrawingStyle(colorValue: 0xFF90CAF9, strokeWidth: 1.1, filled: true, fillColorValue: 0x2242A5F5, fillOpacity: 0.16, dashed: true),
      _ => const DrawingStyle(colorValue: 0xFFFFFFFF, strokeWidth: 1.35),
    };
  }

  String _defaultTextFor(TradingViewDrawingTool tool, DrawingAnchor anchor) => switch (tool) { TradingViewDrawingTool.priceLabel || TradingViewDrawingTool.priceNote => anchor.price?.toStringAsFixed(2) ?? '价格', TradingViewDrawingTool.text || TradingViewDrawingTool.anchoredText => '文本', TradingViewDrawingTool.note => '备注', _ => '' };

  void _showDrawMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1E3A8A)));
  }

  void _handleWheel(PointerScrollEvent event, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null || !meta.chartRect.contains(event.localPosition) || event.scrollDelta.dy == 0) return;
    final factor = event.scrollDelta.dy < 0 ? 0.88 : 1.12;
    final nextWindow = (widget.windowSize * factor).round().clamp(24, 360).toInt();
    if (nextWindow != widget.windowSize) widget.onWindowSizeChanged?.call(nextWindow);
  }

  void _handleScale(ScaleUpdateDetails details, Size size) {
    if (_dragState != null) {
      _updateDrawingDrag(details.localFocalPoint, size);
      return;
    }
    if ((details.scale - 1).abs() > 0.03) {
      final nextWindow = ((_scaleStartWindow ?? widget.windowSize) / details.scale).round().clamp(24, 360).toInt();
      if (nextWindow != widget.windowSize) widget.onWindowSizeChanged?.call(nextWindow);
      return;
    }
    final dx = details.focalPointDelta.dx;
    final dy = details.focalPointDelta.dy;
    if (details.pointerCount == 1 && dy.abs() > dx.abs() * 1.4 && dy.abs() > 1.5) {
      widget.onPriceScaleChanged?.call((widget.priceScale * (1 + (-dy / 240))).clamp(0.35, 5.0).toDouble());
      return;
    }
    final visible = _visibleMeta(size);
    if (visible == null || visible.step <= 0 || dx.abs() <= 0.2) return;
    _panRemainder += -dx / visible.step;
    final panBars = _panRemainder.truncate();
    if (panBars != 0) {
      widget.onPanBars?.call(panBars);
      _panRemainder -= panBars;
    }
  }

  void _updateCrosshair(Offset p, Size size) {
    final meta = _visibleMeta(size);
    if (meta == null || !meta.chartRect.contains(p)) return;
    final local = ((p.dx - meta.chartRect.left) / meta.step).floor();
    widget.onCrosshairChanged?.call((meta.startIndex + local).clamp(meta.startIndex, meta.endIndex).toInt());
  }

  _VisibleMeta? _visibleMeta(Size size) {
    final bars = widget.snapshot.rawBars;
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return null;
    final rect = _OriginChartPainter.chartRectFor(size);
    if (rect.width <= 0 || rect.height <= 0) return null;
    final end = (widget.viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final start = math.max(0, end - widget.windowSize + 1).toInt();
    final visible = bars.sublist(start, end + 1);
    final low = visible.map((e) => e.low).reduce(math.min);
    final high = visible.map((e) => e.high).reduce(math.max);
    final center = (high + low) / 2;
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final scaledRange = rawRange / widget.priceScale.clamp(0.35, 5.0);
    final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);
    final minPrice = center - scaledRange / 2 - padding;
    final maxPrice = center + scaledRange / 2 + padding;
    return _VisibleMeta(rect, start, end, rect.width / math.max(1, end - start + 1), minPrice, maxPrice);
  }
}

enum _DrawingDragMode { anchor, body }

class _DrawingDragState {
  final DrawingObject object;
  final _DrawingDragMode mode;
  final int? anchorIndex;
  final DrawingAnchor startPointerAnchor;
  const _DrawingDragState({required this.object, required this.mode, required this.startPointerAnchor, this.anchorIndex});
}

class _DrawingPersistenceBar extends StatelessWidget {
  final int drawingCount;
  final VoidCallback onImport;
  final VoidCallback? onExport;
  const _DrawingPersistenceBar({required this.drawingCount, required this.onImport, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCC1F2937),
      borderRadius: BorderRadius.circular(8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _miniButton('导入画线 JSON', Icons.file_open, onImport),
        _miniButton(drawingCount > 0 ? '导出画线 JSON' : '暂无画线可导出', Icons.ios_share, onExport),
      ]),
    );
  }

  Widget _miniButton(String tooltip, IconData icon, VoidCallback? onPressed) => Tooltip(message: tooltip, child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 16), color: Colors.white70, disabledColor: Colors.white24, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 30, height: 30)));
}

class _SelectedDrawingBar extends StatelessWidget {
  final DrawingObject object;
  final VoidCallback onDelete;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleHidden;
  final VoidCallback onCancel;
  const _SelectedDrawingBar({required this.object, required this.onDelete, required this.onToggleLock, required this.onToggleHidden, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final meta = TradingViewDrawingToolRegistry.metaOf(object.tool);
    return Material(
      color: const Color(0xEE1F2937),
      elevation: 12,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${meta.label}${object.locked ? '（锁）' : ''}${object.hidden ? '（隐藏）' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
          _miniButton(object.locked ? '解锁' : '锁定', object.locked ? Icons.lock_open : Icons.lock, onToggleLock),
          _miniButton(object.hidden ? '恢复显示' : '隐藏', object.hidden ? Icons.visibility : Icons.visibility_off, onToggleHidden),
          _miniButton('删除', Icons.delete_outline, object.locked ? null : onDelete),
          _miniButton('取消选择', Icons.close, onCancel),
        ]),
      ),
    );
  }

  Widget _miniButton(String tooltip, IconData icon, VoidCallback? onPressed) => Tooltip(message: onPressed == null ? '$tooltip（已锁定）' : tooltip, child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 16), color: Colors.white70, disabledColor: Colors.white24, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 28, height: 28)));
}

class _VisibleMeta {
  final Rect chartRect;
  final int startIndex;
  final int endIndex;
  final double step;
  final double minPrice;
  final double maxPrice;
  const _VisibleMeta(this.chartRect, this.startIndex, this.endIndex, this.step, this.minPrice, this.maxPrice);
  double rawToX(int rawIndex) => chartRect.left + (rawIndex - startIndex + 0.5) * step;
  double priceToY(double price) => chartRect.bottom - (price - minPrice) / math.max(maxPrice - minPrice, 0.0000001) * chartRect.height;
  DrawingAnchor anchorAt(Offset p) => DrawingAnchor.chart(rawIndex: (startIndex + ((p.dx - chartRect.left) / step).floor()).clamp(startIndex, endIndex).toInt(), price: priceAtY(p.dy));
  double priceAtY(double y) => minPrice + (chartRect.bottom - y.clamp(chartRect.top, chartRect.bottom).toDouble()) / chartRect.height * math.max(maxPrice - minPrice, 0.0000001);
}

class _OriginChartPainter extends CustomPainter {
  static const double _topPad = 32;
  static const double _bottomPad = 28;
  static const double _leftPad = 4;
  static const double _rightPad = 58;

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
  final List<DrawingObject> drawingObjects;
  final int windowSize;
  final double priceScale;
  final int? viewEndIndex;
  final int? crosshairIndex;

  _OriginChartPainter({required this.snapshot, required this.showFx, required this.showFxLine, required this.showFxText, required this.showBi, required this.showBiText, required this.showSeg, required this.showSegText, required this.showZs, required this.showBiBsp, required this.showSegBsp, required this.showMergedBars, required this.drawingObjects, required this.windowSize, required this.priceScale, this.viewEndIndex, this.crosshairIndex});

  static Rect chartRectFor(Size size) => Rect.fromLTWH(_leftPad, _topPad, math.max(0.0, size.width - _leftPad - _rightPad), math.max(0.0, size.height - _topPad - _bottomPad));

  @override
  void paint(Canvas canvas, Size size) {
    final bars = snapshot.rawBars;
    if (bars.isEmpty) return;
    final rect = chartRectFor(size);
    if (rect.width <= 0 || rect.height <= 0) return;
    final end = (viewEndIndex ?? bars.length - 1).clamp(0, bars.length - 1).toInt();
    final start = math.max(0, end - windowSize + 1).toInt();
    final visible = bars.sublist(start, end + 1);
    final low = visible.map((e) => e.low).reduce(math.min);
    final high = visible.map((e) => e.high).reduce(math.max);
    final center = (high + low) / 2;
    final rawRange = math.max(high - low, high.abs() * 0.002);
    final scaledRange = rawRange / priceScale.clamp(0.35, 5.0);
    final padding = math.max(scaledRange * 0.08, high.abs() * 0.001);
    final minPrice = center - scaledRange / 2 - padding;
    final maxPrice = center + scaledRange / 2 + padding;
    double priceToY(double price) => rect.bottom - (price - minPrice) / (maxPrice - minPrice) * rect.height;
    final step = rect.width / math.max(1, visible.length);
    double rawToX(int rawIndex) => rect.left + (rawIndex - start + 0.5) * step;

    _drawGrid(canvas, rect, minPrice, maxPrice, visible);
    _drawCandles(canvas, rect, visible, rawToX, priceToY, step);
    if (showMergedBars) _drawMergedBars(canvas, rect, start, end, rawToX, priceToY, step);
    if (showZs) _drawZs(canvas, rect, start, end, rawToX, priceToY);
    if (showFxLine) _drawFxLine(canvas, rect, start, end, rawToX, priceToY);
    if (showBi) _drawBi(canvas, rect, start, end, rawToX, priceToY);
    if (showSeg) _drawSeg(canvas, rect, start, end, rawToX, priceToY);
    if (showBiBsp || showSegBsp) _drawBsp(canvas, rect, start, end, rawToX, priceToY);
    if (showFx) _drawFx(canvas, rect, start, end, rawToX, priceToY);
    DrawingObjectPainter.paintObjects(canvas: canvas, chartRect: rect, objects: drawingObjects, startRawIndex: start, endRawIndex: end, rawToX: rawToX, priceToY: priceToY);
    final cross = crosshairIndex;
    if (cross != null && cross >= start && cross <= end) {
      _drawCrosshair(canvas, rect, bars[cross], rawToX, priceToY);
    } else {
      final biBspCnt = snapshot.bsps.where(_isBiBsp).length;
      final segBspCnt = snapshot.bsps.where(_isSegBsp).length;
      _drawText(canvas, 'chan.py ${_fmtDate(visible.last.time)} | K:${bars.length} MB:${snapshot.mergedBars.length} FX:${snapshot.fxs.length} BI:${snapshot.bis.length} SEG:${snapshot.segs.length} ZS:${snapshot.zss.length} BSP:${snapshot.bsps.length} 笔BSP:$biBspCnt 段BSP:$segBspCnt', const Offset(8, 4), 11, Colors.white70);
    }
  }

  void _drawGrid(Canvas canvas, Rect rect, double minPrice, double maxPrice, List<RawBar> visible) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 0.7;
    for (var i = 0; i <= 4; i++) {
      final y = rect.top + rect.height * i / 4;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
      _drawText(canvas, (maxPrice - (maxPrice - minPrice) * i / 4).toStringAsFixed(2), Offset(rect.right + 5, y - 7), 10, Colors.white54);
    }
    _drawText(canvas, _fmtDate(visible.first.time), Offset(rect.left, rect.bottom + 6), 10, Colors.white38);
    _drawText(canvas, _fmtDate(visible.last.time), Offset(rect.right - 62, rect.bottom + 6), 10, Colors.white38);
  }

  void _drawCandles(Canvas canvas, Rect rect, List<RawBar> visible, double Function(int) rawToX, double Function(double) priceToY, double step) {
    final up = Paint()..color = const Color(0xFF26A69A);
    final down = Paint()..color = const Color(0xFFEF5350);
    final wick = Paint()..strokeWidth = math.max(1.0, step * 0.08);
    final bodyWidth = math.max(1.0, math.min(step * 0.68, step - 1));
    for (final bar in visible) {
      final x = rawToX(bar.index);
      final paint = bar.close >= bar.open ? up : down;
      wick.color = paint.color;
      canvas.drawLine(Offset(x, priceToY(bar.high).clamp(rect.top, rect.bottom).toDouble()), Offset(x, priceToY(bar.low).clamp(rect.top, rect.bottom).toDouble()), wick);
      final openY = priceToY(bar.open).clamp(rect.top, rect.bottom).toDouble();
      final closeY = priceToY(bar.close).clamp(rect.top, rect.bottom).toDouble();
      canvas.drawRect(Rect.fromLTRB(x - bodyWidth / 2, math.min(openY, closeY), x + bodyWidth / 2, math.max(math.min(openY, closeY) + 1, math.max(openY, closeY))), paint);
    }
  }

  void _drawMergedBars(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY, double step) {
    final stroke = Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.72)..style = PaintingStyle.stroke..strokeWidth = math.max(1.0, step * 0.05);
    for (final merged in snapshot.mergedBars) {
      if (merged.endRawIndex < start || merged.startRawIndex > end) continue;
      final leftRaw = math.max(merged.startRawIndex, start);
      final rightRaw = math.min(merged.endRawIndex, end);
      final left = (rawToX(leftRaw) - step * 0.44).clamp(rect.left, rect.right).toDouble();
      final right = (rawToX(rightRaw) + step * 0.44).clamp(rect.left, rect.right).toDouble();
      if (right <= left) continue;
      final top = priceToY(merged.high).clamp(rect.top, rect.bottom).toDouble();
      final bottom = priceToY(merged.low).clamp(rect.top, rect.bottom).toDouble();
      canvas.drawRect(Rect.fromLTRB(left, math.min(top, bottom), right, math.max(top, bottom)), stroke);
    }
  }

  void _drawFxLine(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    final rows = snapshot.fxs.where((e) => e.rawIndex >= start && e.rawIndex <= end).toList()..sort((a, b) => a.rawIndex.compareTo(b.rawIndex));
    if (rows.length < 2) return;
    final path = Path();
    for (var i = 0; i < rows.length; i++) {
      final p = Offset(rawToX(rows[i].rawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(rows[i].price).clamp(rect.top, rect.bottom).toDouble());
      if (i == 0) path.moveTo(p.dx, p.dy); else path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.46)..strokeWidth = 1.15..style = PaintingStyle.stroke);
  }

  void _drawFx(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    for (final fx in snapshot.fxs) {
      if (fx.rawIndex < start || fx.rawIndex > end) continue;
      final color = fx.type == FxType.top ? const Color(0xFFFFCA28) : const Color(0xFF42A5F5);
      final p = Offset(rawToX(fx.rawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(fx.price).clamp(rect.top, rect.bottom).toDouble());
      canvas.drawCircle(p, 4, Paint()..color = color);
      if (showFxText) _drawText(canvas, fx.isTop ? '顶' : '底', Offset(p.dx - 6, p.dy + (fx.isTop ? -20 : 8)), 11, color);
    }
  }

  void _drawBi(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    final paint = Paint()..color = const Color(0xFFE53935)..strokeWidth = 1.45;
    for (final bi in snapshot.bis) {
      if (bi.endRawIndex < start || bi.startRawIndex > end) continue;
      final p1 = Offset(rawToX(bi.startRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(bi.startPrice).clamp(rect.top, rect.bottom).toDouble());
      final p2 = Offset(rawToX(bi.endRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(bi.endPrice).clamp(rect.top, rect.bottom).toDouble());
      canvas.drawLine(p1, p2, paint);
      if (showBiText) _drawText(canvas, 'B${bi.index + 1}', Offset(p2.dx - 12, p2.dy + (bi.isUp ? -18 : 6)), 10, const Color(0xFFFF8A80));
    }
  }

  void _drawSeg(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    for (final seg in snapshot.segs) {
      if (seg.endRawIndex < start || seg.startRawIndex > end) continue;
      final paint = Paint()..color = (seg.isSure ? const Color(0xFF00E676) : const Color(0xFFB2FF59)).withValues(alpha: seg.isSure ? 0.92 : 0.62)..strokeWidth = seg.isSure ? 2.6 : 1.6;
      final p1 = Offset(rawToX(seg.startRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(seg.startPrice).clamp(rect.top, rect.bottom).toDouble());
      final p2 = Offset(rawToX(seg.endRawIndex).clamp(rect.left, rect.right).toDouble(), priceToY(seg.endPrice).clamp(rect.top, rect.bottom).toDouble());
      canvas.drawLine(p1, p2, paint);
      if (showSegText) _drawText(canvas, 'S${seg.index + 1}${seg.isSure ? '' : '?'}', Offset(p2.dx - 14, p2.dy + (seg.isUp ? -20 : 8)), 10, Colors.white70);
    }
  }

  void _drawZs(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    final fill = Paint()..color = const Color(0xFF2962FF).withValues(alpha: 0.10)..style = PaintingStyle.fill;
    final stroke = Paint()..color = const Color(0xFF5B8DFF).withValues(alpha: 0.85)..style = PaintingStyle.stroke..strokeWidth = 1.1;
    for (final zs in snapshot.zss) {
      if (zs.endRawIndex < start || zs.startRawIndex > end) continue;
      final left = rawToX(zs.startRawIndex).clamp(rect.left, rect.right).toDouble();
      final right = rawToX(zs.endRawIndex).clamp(rect.left, rect.right).toDouble();
      final top = priceToY(zs.zg).clamp(rect.top, rect.bottom).toDouble();
      final bottom = priceToY(zs.zd).clamp(rect.top, rect.bottom).toDouble();
      final area = Rect.fromLTRB(math.min(left, right), math.min(top, bottom), math.max(left, right), math.max(top, bottom));
      canvas.drawRect(area, fill);
      canvas.drawRect(area, stroke);
      _drawText(canvas, 'ZS${zs.index + 1}', Offset(area.left + 3, area.top + 3), 10, const Color(0xFF82B1FF));
    }
  }

  void _drawBsp(Canvas canvas, Rect rect, int start, int end, double Function(int) rawToX, double Function(double) priceToY) {
    for (final bsp in snapshot.bsps) {
      if (bsp.rawIndex < start || bsp.rawIndex > end) continue;
      final isSegLevel = _isSegBsp(bsp);
      if (isSegLevel && !showSegBsp) continue;
      if (!isSegLevel && !showBiBsp) continue;
      final color = bsp.isSell ? const Color(0xFFFF7043) : const Color(0xFF00E676);
      final x = rawToX(bsp.rawIndex).clamp(rect.left, rect.right).toDouble();
      final y = priceToY(bsp.price).clamp(rect.top, rect.bottom).toDouble();
      final halfWidth = isSegLevel ? 8.0 : 6.0;
      final tipOffset = isSegLevel ? 9.0 : 7.0;
      final baseOffset = isSegLevel ? 6.0 : 5.0;
      final path = Path();
      if (bsp.isSell) { path.moveTo(x, y - tipOffset); path.lineTo(x - halfWidth, y + baseOffset); path.lineTo(x + halfWidth, y + baseOffset); } else { path.moveTo(x, y + tipOffset); path.lineTo(x - halfWidth, y - baseOffset); path.lineTo(x + halfWidth, y - baseOffset); }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
      _drawText(canvas, '${isSegLevel ? '段' : '笔'}${bsp.type}', Offset(x + 5, y + (bsp.isSell ? -20 : 8)), isSegLevel ? 10.5 : 9, color);
    }
  }

  bool _isSegBsp(BspPoint bsp) { final level = bsp.level.trim().toLowerCase(); return level == 'seg' || level == 'segment' || level.contains('seg'); }
  bool _isBiBsp(BspPoint bsp) { final level = bsp.level.trim().toLowerCase(); return level.isEmpty || level == 'bi' || (!level.contains('seg') && level != 'segment'); }

  void _drawCrosshair(Canvas canvas, Rect rect, RawBar bar, double Function(int) rawToX, double Function(double) priceToY) { final x = rawToX(bar.index).clamp(rect.left, rect.right).toDouble(); final y = priceToY(bar.close).clamp(rect.top, rect.bottom).toDouble(); final paint = Paint()..color = Colors.white.withValues(alpha: 0.52)..strokeWidth = 0.8; canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint); canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint); _drawText(canvas, 'O:${bar.open.toStringAsFixed(2)} H:${bar.high.toStringAsFixed(2)} L:${bar.low.toStringAsFixed(2)} C:${bar.close.toStringAsFixed(2)} V:${bar.volume.toStringAsFixed(0)}', Offset(rect.left + 6, rect.top - 20), 11, Colors.white); }
  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color) { final painter = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)), textDirection: TextDirection.ltr, maxLines: 1)..layout(maxWidth: 520); painter.paint(canvas, offset); }
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  @override
  bool shouldRepaint(covariant _OriginChartPainter oldDelegate) => true;
}
