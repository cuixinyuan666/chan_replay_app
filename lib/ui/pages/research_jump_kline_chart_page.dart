import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/services/replay_analysis_store.dart';
import '../../data/chan_snapshot_json_parser.dart';
import '../../data/multi_level_chan_analysis_parser.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import '../widgets/recursive_seg_origin_kline_chart.dart';

class ResearchJumpKlineChartPage extends StatefulWidget {
  final KlineLocationRequest request;

  const ResearchJumpKlineChartPage({
    super.key,
    required this.request,
  });

  @override
  State<ResearchJumpKlineChartPage> createState() =>
      _ResearchJumpKlineChartPageState();
}

class _ResearchJumpKlineChartPageState extends State<ResearchJumpKlineChartPage> {
  late _ParsedResearchJump _parsed;
  int? _viewEndIndex;
  int? _crosshairIndex;
  int _windowSize = 90;
  double _priceScale = 1.0;
  double _priceOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _parsed = _parse(widget.request);
    _resetViewport();
  }

  @override
  void didUpdateWidget(covariant ResearchJumpKlineChartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.nonce != widget.request.nonce) {
      _parsed = _parse(widget.request);
      _resetViewport();
    }
  }

  void _resetViewport() {
    final snapshot = _parsed.snapshot;
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      _viewEndIndex = null;
      _crosshairIndex = null;
      _windowSize = 90;
      return;
    }
    final resultStart = _barListIndexForRawIndex(
      snapshot,
      widget.request.visibleStartRawIndex ?? widget.request.rawIndex,
    );
    final resultEnd = _barListIndexForRawIndex(
      snapshot,
      widget.request.visibleEndRawIndex ?? widget.request.rawIndex,
    );
    final start = resultStart <= resultEnd ? resultStart : resultEnd;
    final end = resultStart <= resultEnd ? resultEnd : resultStart;
    final max = snapshot.rawBars.length - 1;
    final intervalSize = (end - start + 1).clamp(1, snapshot.rawBars.length).toInt();
    final paddedSize = intervalSize < 24 ? 24 : intervalSize;
    _windowSize = paddedSize.clamp(1, snapshot.rawBars.length).toInt();
    _viewEndIndex = end.clamp(0, max).toInt();
    _crosshairIndex = _barListIndexForRawIndex(snapshot, widget.request.rawIndex)
        .clamp(0, max)
        .toInt();
    _priceScale = 1.0;
    _priceOffset = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _parsed.snapshot;
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      return _errorView(_parsed.error ?? '研究结果没有可显示的K线数据');
    }
    final label = widget.request.label.trim().isEmpty
        ? '研究/回测跳转'
        : widget.request.label.trim();
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: RecursiveSegOriginKlineChart(
                snapshot: snapshot,
                showFx: true,
                showBi: true,
                showSeg: true,
                showZs: true,
                showBiBsp: true,
                showSegBsp: true,
                showMergedBars: false,
                showEasyTdxIndicators: false,
                drawingObjects: _jumpDrawingObjects(snapshot, label),
                drawingStorageKey:
                    'research_jump_${widget.request.market}_${widget.request.symbol}_${widget.request.level}_${widget.request.nonce}',
                symbolLabel:
                    '${widget.request.market}${widget.request.symbol} ${widget.request.level} ${widget.request.mode}',
                windowSize: _windowSize,
                viewEndIndex: _viewEndIndex,
                crosshairIndex: _crosshairIndex,
                priceScale: _priceScale,
                priceOffset: _priceOffset,
                onCrosshairChanged: (index) => setState(() => _crosshairIndex = index),
                onPanBars: (delta) => setState(() {
                  final max = snapshot.rawBars.length - 1;
                  final current = _viewEndIndex ?? max;
                  _viewEndIndex = (current + delta).clamp(0, max).toInt();
                }),
                onWindowSizeChanged: (next) => setState(() {
                  _windowSize = next.clamp(1, snapshot.rawBars.length).toInt();
                }),
                onPriceScaleChanged: (next) => setState(() => _priceScale = next),
                onPriceOffsetChanged: (next) => setState(() => _priceOffset = next),
                showRecursiveSegLayers: true,
                showRecursiveSegZs: true,
                showRecursiveSegBsp: true,
                minRecursiveSegLayer: 2,
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _JumpBadge(
                label: label,
                mode: widget.request.mode,
                source: widget.request.source,
                rawIndex: widget.request.rawIndex,
                frameIndex: _parsed.frameIndex,
                window: _windowText(snapshot),
                onReset: () => setState(_resetViewport),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(message, style: const TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }

  _ParsedResearchJump _parse(KlineLocationRequest request) {
    final payload = request.analysisPayload;
    if (payload == null) {
      return const _ParsedResearchJump(error: '定位请求没有携带研究/回测 analysis payload');
    }
    try {
      final decoded = Map<String, dynamic>.from(payload);
      final finalSnapshot = MultiLevelChanAnalysisParser.parseSnapshot(
        decoded,
        parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
      );
      if (finalSnapshot == null) {
        return const _ParsedResearchJump(error: '无法解析研究/回测 analysis payload');
      }
      final level = _resolveLevel(finalSnapshot, request.level);
      if (request.mode.toLowerCase() == 'step') {
        final frameResult = _parseStepFrame(decoded, finalSnapshot, level, request.rawIndex, request.frameIndex);
        if (frameResult.snapshot != null) return frameResult;
      }
      return _ParsedResearchJump(snapshot: finalSnapshot.of(level), frameIndex: -1);
    } catch (error) {
      return _ParsedResearchJump(error: '解析研究/回测K线失败：$error');
    }
  }

  _ParsedResearchJump _parseStepFrame(
    Map<String, dynamic> decoded,
    MultiLevelChanSnapshot finalSnapshot,
    String level,
    int rawIndex,
    int? preferredFrameIndex,
  ) {
    final rawFrames = decoded['frames'];
    if (rawFrames is! List || rawFrames.isEmpty) {
      return const _ParsedResearchJump(error: 'step 模式 payload 没有 frames');
    }
    final targetBarIndex = _barListIndexForRawIndex(finalSnapshot.of(level), rawIndex);
    int selected = (preferredFrameIndex ?? -1).clamp(-1, rawFrames.length - 1).toInt();
    if (selected < 0) {
      for (var i = 0; i < rawFrames.length; i++) {
        final visible = _frameVisibleCount(rawFrames[i], level);
        if (visible != null && visible > targetBarIndex) {
          selected = i;
          break;
        }
      }
    }
    if (selected < 0) selected = rawFrames.length - 1;
    final frame = _frameWithAccumulatedHistory(rawFrames, selected);
    final parsed = MultiLevelChanAnalysisParser.parseFrame(
      frame,
      baseLevels: decoded['levels'],
      parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
    );
    if (parsed == null) {
      return const _ParsedResearchJump(error: '无法解析 step frame');
    }
    final frameLevel = _resolveLevel(parsed, level);
    return _ParsedResearchJump(snapshot: parsed.of(frameLevel), frameIndex: selected);
  }

  Map<String, dynamic> _frameWithAccumulatedHistory(List<dynamic> frames, int index) {
    final raw = frames[index];
    final frame = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final rawLevels = frame['levels'];
    if (rawLevels is! Map) return frame;
    Map<String, dynamic>? previous;
    if (index > 0) previous = _frameWithAccumulatedHistory(frames, index - 1);
    final previousLevels = previous?['levels'];
    final nextLevels = <String, dynamic>{};
    for (final entry in rawLevels.entries) {
      final levelName = '${entry.key}';
      final source = entry.value;
      if (source is! Map) {
        nextLevels[levelName] = source;
        continue;
      }
      final payload = Map<String, dynamic>.from(source);
      final isSeed = payload['bsp_history_seed'] == true || index == 0;
      if (!isSeed && previousLevels is Map) {
        final previousRaw = previousLevels[levelName] ?? previousLevels[entry.key];
        final previousPayload = previousRaw is Map ? previousRaw : const {};
        final baseHistory = previousPayload['bsp_history'] ?? previousPayload['bsp'];
        final baseDelta = payload['bsp_delta'] ?? payload['bsp_history'] ?? payload['bsp'];
        payload['bsp_history'] = <dynamic>[
          if (baseHistory is List) ...baseHistory,
          if (baseDelta is List) ...baseDelta,
        ];
        payload['bsp'] = payload['bsp_history'];

        final previousRecursive = previousPayload['seg_bsp_history_layers'];
        final deltaRecursive = payload['seg_bsp_delta_layers'] ?? payload['seg_bsp_history_layers'];
        final layerNames = <String>{
          if (previousRecursive is Map) for (final key in previousRecursive.keys) '$key',
          if (deltaRecursive is Map) for (final key in deltaRecursive.keys) '$key',
        };
        final mergedRecursive = <String, dynamic>{};
        for (final layer in layerNames) {
          final before = previousRecursive is Map
              ? previousRecursive[layer] ?? previousRecursive[int.tryParse(layer)]
              : null;
          final delta = deltaRecursive is Map
              ? deltaRecursive[layer] ?? deltaRecursive[int.tryParse(layer)]
              : null;
          mergedRecursive[layer] = <dynamic>[
            if (before is List) ...before,
            if (delta is List) ...delta,
          ];
        }
        payload['seg_bsp_history_layers'] = mergedRecursive;
      }
      nextLevels[levelName] = payload;
    }
    frame['levels'] = nextLevels;
    return frame;
  }

  int? _frameVisibleCount(Object? frame, String level) {
    if (frame is! Map) return null;
    final levels = frame['levels'];
    if (levels is! Map) return null;
    final levelPayload = levels[level] ?? levels[level.toUpperCase()] ?? levels[level.toLowerCase()];
    if (levelPayload is! Map) return null;
    final visible = levelPayload['visible_count'];
    if (visible is num) return visible.toInt();
    return int.tryParse('$visible');
  }

  String _resolveLevel(MultiLevelChanSnapshot snapshot, String requested) {
    final level = requested.trim().toUpperCase();
    return snapshot.snapshots.containsKey(level) ? level : snapshot.safeActiveLevel;
  }

  int _barListIndexForRawIndex(ChanSnapshot? snapshot, int rawIndex) {
    if (snapshot == null || snapshot.rawBars.isEmpty) return 0;
    for (var i = 0; i < snapshot.rawBars.length; i++) {
      if (snapshot.rawBars[i].index == rawIndex) return i;
    }
    return rawIndex.clamp(0, snapshot.rawBars.length - 1).toInt();
  }

  List<DrawingObject> _jumpDrawingObjects(ChanSnapshot snapshot, String label) {
    final barIndex = _barListIndexForRawIndex(snapshot, widget.request.rawIndex);
    final raw = snapshot.rawBars[barIndex];
    final minLow = snapshot.rawBars.map((bar) => bar.low).reduce((a, b) => a < b ? a : b);
    final maxHigh = snapshot.rawBars.map((bar) => bar.high).reduce((a, b) => a > b ? a : b);
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    return [
      DrawingObject(
        id: 'research_jump_marker_${widget.request.nonce}_${widget.request.rawIndex}',
        tool: TradingViewDrawingTool.verticalLine,
        anchors: [
          DrawingAnchor.chart(rawIndex: raw.index, price: minLow),
          DrawingAnchor.chart(rawIndex: raw.index, price: maxHigh),
        ],
        style: const DrawingStyle(
          colorValue: 0xFFFFD54F,
          strokeWidth: 2.4,
          opacity: 0.96,
          dashed: true,
          fontSize: 12,
        ),
        text: '📍$label',
        locked: true,
        createdAt: now,
        updatedAt: now,
      ),
      DrawingObject(
        id: 'research_jump_flag_${widget.request.nonce}_${widget.request.rawIndex}',
        tool: TradingViewDrawingTool.iconFlag,
        anchors: [
          DrawingAnchor.chart(rawIndex: raw.index, price: raw.high),
        ],
        style: const DrawingStyle(
          colorValue: 0xFFFFD54F,
          strokeWidth: 2.0,
          opacity: 1.0,
          fontSize: 14,
        ),
        text: label,
        locked: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  String _windowText(ChanSnapshot snapshot) {
    if (snapshot.rawBars.isEmpty) return '--';
    final max = snapshot.rawBars.length - 1;
    final end = (_viewEndIndex ?? max).clamp(0, max).toInt();
    final start = (end - _windowSize + 1).clamp(0, end).toInt();
    return '${snapshot.rawBars[start].time} ~ ${snapshot.rawBars[end].time}';
  }
}

class _ParsedResearchJump {
  final ChanSnapshot? snapshot;
  final int? frameIndex;
  final String? error;

  const _ParsedResearchJump({this.snapshot, this.frameIndex, this.error});
}

class _JumpBadge extends StatelessWidget {
  final String label;
  final String mode;
  final String source;
  final int rawIndex;
  final int? frameIndex;
  final String window;
  final VoidCallback onReset;

  const _JumpBadge({
    required this.label,
    required this.mode,
    required this.source,
    required this.rawIndex,
    required this.frameIndex,
    required this.window,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66FFD54F)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_pin, color: Color(0xFFFFD54F), size: 20),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'mode=$mode raw=$rawIndex frame=${frameIndex == null || frameIndex! < 0 ? 'final' : frameIndex! + 1} source=${source.isEmpty ? 'research/backtest' : source}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text('window=$window', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              tooltip: '回到跳转区间',
              onPressed: onReset,
              icon: const Icon(Icons.center_focus_strong, color: Colors.white70, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
