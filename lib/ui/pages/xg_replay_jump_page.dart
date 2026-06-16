import 'package:flutter/material.dart';

import '../../core/runtime/runtime_path.dart';
import '../../core/runtime/xg_replay_jump.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../widgets/origin_kline_chart.dart';

class XgReplayJumpPage extends StatefulWidget {
  final XgReplayJumpRequest request;
  final String baseUrl;

  const XgReplayJumpPage({super.key, required this.request, required this.baseUrl});

  @override
  State<XgReplayJumpPage> createState() => _XgReplayJumpPageState();
}

class _XgReplayJumpPageState extends State<XgReplayJumpPage> {
  PythonMultiLevelChanAnalysis? _analysis;
  String _status = 'loading';
  String _activeLevel = '';
  bool _loading = false;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;

  @override
  void initState() {
    super.initState();
    _activeLevel = widget.request.targetLevel;
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _status = 'loading ${widget.request.symbol}.${widget.request.market} ${widget.request.targetLevel} raw:${widget.request.rawIndex}';
    });
    final source = PythonMultiLevelChanAnalysisSource(baseUrl: widget.baseUrl);
    try {
      final analysis = await source.analyzeMulti(
        mode: widget.request.levels.length <= 1 ? 'once' : 'step',
        market: widget.request.market,
        code: widget.request.symbol,
        levels: widget.request.levels,
        adjust: 'QFQ',
        mainLevel: widget.request.levels.first,
        clockLevel: widget.request.levels.first,
        startDate: widget.request.startDate,
        endDate: widget.request.endDate,
        runtimePath: RuntimePathController.current,
        config: const {'bi_algo': 'normal', 'seg_algo': 'chan', 'zs_algo': 'normal', 'recursive_seg_max_level': 4},
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _locate();
        _status = 'loaded ${widget.request.symbol}.${widget.request.market} ${widget.request.targetLevel} raw:${widget.request.rawIndex}';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'load failed: $e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _locate() {
    final snap = _analysis?.snapshot.of(widget.request.targetLevel) ?? _analysis?.snapshot.of(_activeLevel);
    if (snap == null || snap.rawBars.isEmpty) return;
    _activeLevel = widget.request.targetLevel;
    var index = widget.request.rawIndex;
    for (var i = 0; i < snap.rawBars.length; i++) {
      if (snap.rawBars[i].index == widget.request.rawIndex) {
        index = i;
        break;
      }
    }
    final max = snap.rawBars.length - 1;
    _crosshairIndex = index.clamp(0, max).toInt();
    _viewEndIndex = (_crosshairIndex! + 35).clamp(0, max).toInt();
    _priceScale = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _analysis?.snapshot.of(_activeLevel);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        title: Text('选股跳转复盘 ${widget.request.symbol}.${widget.request.market} $_activeLevel raw:${widget.request.rawIndex}'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Align(alignment: Alignment.centerLeft, child: Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: snapshot == null || snapshot.rawBars.isEmpty
                    ? const Center(child: Text('等待加载多级别图表...', style: TextStyle(color: Colors.white60)))
                    : OriginKlineChart(
                        snapshot: snapshot,
                        showFx: true,
                        showFxLine: true,
                        showFxText: true,
                        showBi: true,
                        showBiText: false,
                        showSeg: true,
                        showSegText: true,
                        showZs: true,
                        showBiBsp: true,
                        showSegBsp: true,
                        showMergedBars: false,
                        showEasyTdxIndicators: true,
                        easyTdxSubPanelCount: 2,
                        drawingObjects: const [],
                        drawingStorageKey: 'xg_jump_${widget.request.symbol}_${widget.request.targetLevel}_${widget.request.rawIndex}',
                        symbolLabel: '${widget.request.symbol}.${widget.request.market} $_activeLevel',
                        windowSize: _windowSize,
                        priceScale: _priceScale,
                        viewEndIndex: _viewEndIndex,
                        crosshairIndex: _crosshairIndex,
                        onCrosshairChanged: (v) => setState(() => _crosshairIndex = v),
                        onPanBars: _panChartByBars,
                        onWindowSizeChanged: (v) => setState(() => _windowSize = v),
                        onPriceScaleChanged: (v) => setState(() => _priceScale = v),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _panChartByBars(int bars) {
    final snap = _analysis?.snapshot.of(_activeLevel);
    if (bars == 0 || snap == null || snap.rawBars.isEmpty) return;
    final maxEnd = snap.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }
}
