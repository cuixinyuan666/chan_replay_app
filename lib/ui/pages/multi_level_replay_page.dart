import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/models/multi_level_view_state.dart';
import '../../core/models/replay_clock_mode.dart';
import '../../core/runtime/runtime_path.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import '../widgets/multi_level_interval_signal_panel.dart';
import '../widgets/multi_level_relation_panel.dart';
import '../widgets/multi_level_switcher.dart';
import '../widgets/origin_kline_chart.dart';

class MultiLevelReplayPage extends StatefulWidget {
  const MultiLevelReplayPage({super.key});

  @override
  State<MultiLevelReplayPage> createState() => _MultiLevelReplayPageState();
}

class _MultiLevelReplayPageState extends State<MultiLevelReplayPage> {
  static const List<String> _levelOptions = [
    'DAILY',
    'MIN60',
    'MIN30',
    'MIN15',
    'MIN5',
    'MIN1',
  ];
  static const List<int> _countOptions = [40, 80, 120, 220, 600, 900];
  static const List<int> _maxStepFrameOptions = [24, 40, 60, 120, 391, 1000];

  final _backendUrlController = TextEditingController(text: 'app-managed bundled Python');
  final _symbolController = TextEditingController(text: '600340');
  final _marketController = TextEditingController(text: 'SH');
  final _startController = TextEditingController(text: '2025-09-01');
  final _endController = TextEditingController(text: '2025-10-20');

  PythonMultiLevelChanAnalysis? _analysis;
  PythonMultiLevelChanAnalysis? _signalScanAnalysis;
  MultiLevelViewState _viewState = MultiLevelViewState.disabled();
  MultiLevelStrategySignalSelection? _selectedStrategySignal;
  bool _loading = false;
  bool _signalScanLoading = false;
  bool _chromeExpanded = false;
  bool _relationPanelExpanded = false;
  bool _signalPanelExpanded = false;
  String _mode = 'step';
  int _count = 220;
  int _maxStepFrames = 60;
  int _frameIndex = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  String _status = 'multi-level candidate-date step replay not loaded';
  String _signalScanStatus = 'signal scan not run';
  Timer? _initialLoadTimer;
  final List<String> _selectedLevels = ['DAILY', 'MIN30', 'MIN5'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoadTimer = Timer(const Duration(milliseconds: 360), () {
        if (mounted && !_loading && _analysis == null) _load();
      });
    });
  }

  @override
  void dispose() {
    _initialLoadTimer?.cancel();
    _backendUrlController.dispose();
    _symbolController.dispose();
    _marketController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  MultiLevelChanSnapshot? get _full => _analysis?.snapshot;
  bool get _stepFramesEmpty => _mode == 'step' && _analysis != null && _analysis!.frames.isEmpty;

  List<String> get _levels => [
        for (final level in _levelOptions)
          if (_selectedLevels.contains(level)) level,
      ];

  MultiLevelChanSnapshot? get _current {
    final analysis = _analysis;
    if (analysis == null) return null;
    if (_mode == 'step') {
      if (analysis.frames.isEmpty) return null;
      final idx = _frameIndex.clamp(0, analysis.frames.length - 1).toInt();
      return analysis.frames[idx];
    }
    return analysis.snapshot;
  }

  MultiLevelChanSnapshot? get _signalSnapshot => _signalScanAnalysis?.snapshot ?? _current;

  String get _activeLevel {
    final full = _full;
    if (full == null) return '';
    final active = _viewState.activeLevel.trim().toUpperCase();
    return full.snapshots.containsKey(active) ? active : full.safeActiveLevel;
  }

  DateTime? _dateOrNull(TextEditingController controller, String label) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text.replaceAll('/', '-'));
    if (parsed == null) throw FormatException('$label must be yyyy-MM-dd, current=$text');
    return parsed;
  }

  Map<String, dynamic> _requestConfig({required bool step}) {
    return {
      'bi_algo': 'normal',
      'seg_algo': 'chan',
      'zs_algo': 'normal',
      if (step) 'max_step_frames': _maxStepFrames,
    };
  }

  Future<void> _load() async {
    if (_loading || _signalScanLoading) return;
    final levels = _levels;
    if (levels.isEmpty) {
      _showMessage('请选择至少一个级别');
      return;
    }
    if (_mode == 'step' && _count > 1000) {
      _showMessage('step replay count=$_count 太大；请缩小 step 验证范围。');
      return;
    }
    late final DateTime? startDate;
    late final DateTime? endDate;
    try {
      startDate = _dateOrNull(_startController, 'start');
      endDate = _dateOrNull(_endController, 'end');
    } catch (e) {
      _showMessage('$e');
      return;
    }

    setState(() {
      _loading = true;
      _chromeExpanded = false;
      _relationPanelExpanded = false;
      _signalPanelExpanded = false;
      _signalScanAnalysis = null;
      _selectedStrategySignal = null;
      _signalScanStatus = 'signal scan not run';
      _status = 'loading analyze_multi ${_mode.toUpperCase()} window:${_startController.text}~${_endController.text}...';
    });

    final source = PythonMultiLevelChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    try {
      final analysis = await source.analyzeMulti(
        mode: _mode,
        market: _marketController.text.trim().toUpperCase(),
        code: _symbolController.text.trim(),
        levels: levels,
        adjust: 'QFQ',
        mainLevel: levels.first,
        clockLevel: levels.first,
        count: _count,
        startDate: startDate,
        endDate: endDate,
        runtimePath: RuntimePathController.current,
        config: _requestConfig(step: _mode == 'step'),
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _frameIndex = 0;
        _viewState = MultiLevelViewState.fromSnapshot(
          analysis.snapshot,
          clockMode: _mode == 'step' ? ReplayClockMode.strictMainLevel : ReplayClockMode.once,
        );
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        _status = _mode == 'step' && analysis.frames.isEmpty
            ? _blockedStatus(analysis)
            : _buildStatus(
                analysis,
                snapshot: _mode == 'step' && analysis.frames.isNotEmpty ? analysis.frames.first : analysis.snapshot,
              );
      });
      _showMessage(_status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'multi-level load failed: $e');
      _showMessage(_status);
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanSignals() async {
    if (_loading || _signalScanLoading) return;
    final levels = _levels;
    if (levels.isEmpty) {
      _showMessage('请选择至少一个级别');
      return;
    }
    late final DateTime? startDate;
    late final DateTime? endDate;
    try {
      startDate = _dateOrNull(_startController, 'start');
      endDate = _dateOrNull(_endController, 'end');
    } catch (e) {
      _showMessage('$e');
      return;
    }

    setState(() {
      _signalScanLoading = true;
      _chromeExpanded = true;
      _signalPanelExpanded = true;
      _selectedStrategySignal = null;
      _signalScanStatus = 'scanning once count=$_count window:${_startController.text}~${_endController.text}...';
    });
    final source = PythonMultiLevelChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    try {
      final scan = await source.analyzeMulti(
        mode: 'once',
        market: _marketController.text.trim().toUpperCase(),
        code: _symbolController.text.trim(),
        levels: levels,
        adjust: 'QFQ',
        mainLevel: levels.first,
        clockLevel: levels.first,
        count: _count,
        startDate: startDate,
        endDate: endDate,
        runtimePath: RuntimePathController.current,
        config: _requestConfig(step: false),
      );
      if (!mounted) return;
      setState(() {
        _signalScanAnalysis = scan;
        _signalPanelExpanded = true;
        _signalScanStatus = 'signal scan done: once count=$_count ${_buildCompactLevelSummary(scan.snapshot)}';
      });
      _showMessage(_signalScanStatus);
    } catch (e) {
      if (!mounted) return;
      setState(() => _signalScanStatus = 'signal scan failed: $e');
      _showMessage(_signalScanStatus);
    } finally {
      source.close();
      if (mounted) setState(() => _signalScanLoading = false);
    }
  }

  Future<void> _loadCandidateWindow() async {
    setState(() {
      _mode = 'once';
      _count = 900;
      _maxStepFrames = 391;
      _startController.text = '2022-01-01';
      _endController.text = '2025-12-31';
      _selectedLevels
        ..clear()
        ..addAll(['DAILY', 'MIN30', 'MIN5']);
      _status = 'S7 matched-sample window set, loading once snapshot...';
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final full = _full;
    final current = _current;
    final signalSnapshot = _signalSnapshot;
    final activeLevel = _activeLevel;
    final snapshot = current?.of(activeLevel);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              top: _chromeExpanded ? 122 : 48,
              child: _chartSurface(snapshot, activeLevel),
            ),
            Positioned(left: 0, right: 0, top: 0, child: _header()),
            if (_chromeExpanded && current != null)
              Positioned(
                left: 48,
                right: 12,
                top: 126,
                child: _floatingPanels(
                  full: full,
                  current: current,
                  signalSnapshot: signalSnapshot,
                  activeLevel: activeLevel,
                ),
              ),
            if (_loading || _signalScanLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chartSurface(dynamic snapshot, String activeLevel) {
    if (_stepFramesEmpty) return _strictStepBlockedPanel();
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      return const Center(
        child: Text('Load analyze_multi to show multi-level chart.', style: TextStyle(color: Colors.white60)),
      );
    }
    return OriginKlineChart(
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
      drawingObjects: _strategySignalDrawingObjects(activeLevel),
      drawingStorageKey: 'multi_${_symbolController.text}_$activeLevel',
      symbolLabel: '${_symbolController.text} $activeLevel',
      windowSize: _windowSize,
      priceScale: _priceScale,
      viewEndIndex: _viewEndIndex,
      crosshairIndex: _crosshairIndex,
      onCrosshairChanged: (v) => setState(() => _crosshairIndex = v),
      onPanBars: _panChartByBars,
      onWindowSizeChanged: (v) => setState(() => _windowSize = v),
      onPriceScaleChanged: (v) => setState(() => _priceScale = v),
    );
  }

  Widget _floatingPanels({
    required MultiLevelChanSnapshot? full,
    required MultiLevelChanSnapshot current,
    required MultiLevelChanSnapshot? signalSnapshot,
    required String activeLevel,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xDD0D1117),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (full != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: MultiLevelSwitcher(
                      levels: full.levels,
                      activeLevel: activeLevel,
                      onChanged: (level) => setState(() {
                        _viewState = _viewState.withActiveLevel(level);
                        _viewEndIndex = null;
                        _crosshairIndex = null;
                      }),
                    ),
                  ),
                if (_analysis != null) _manualP0Panel(_analysis!),
                if (_analysis != null && _analysis!.frames.isNotEmpty) _stepControls(_analysis!),
                _analysisToolStrip(current, signalSnapshot),
                if (_relationPanelExpanded && current.relations.isNotEmpty)
                  MultiLevelRelationPanel(
                    snapshot: current,
                    mode: _mode,
                    frameIndex: _mode == 'step' && _analysis?.frames.isNotEmpty == true ? _frameIndex : null,
                    frameCount: _mode == 'step' ? _analysis?.frames.length : null,
                    symbol: _symbolController.text.trim(),
                    onLocate: _locateRelationTarget,
                  ),
                if (signalSnapshot != null && _signalPanelExpanded)
                  MultiLevelIntervalSignalPanel(
                    snapshot: signalSnapshot,
                    mode: _signalScanAnalysis == null ? _mode : 'signal_scan_once',
                    frameIndex: _signalScanAnalysis == null && _mode == 'step' && _analysis?.frames.isNotEmpty == true
                        ? _frameIndex
                        : null,
                    frameCount: _signalScanAnalysis == null && _mode == 'step' ? _analysis?.frames.length : null,
                    symbol: _symbolController.text.trim(),
                    onSelectedSignalChanged: (signal) => setState(() => _selectedStrategySignal = signal),
                    onJumpToSignal: _locateStrategySignal,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final statusText = _status.length > 120 ? '${_status.substring(0, 120)}…' : _status;
    return Material(
      color: const Color(0xEE111722),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 6, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree, color: Color(0xFFFFD54F), size: 18),
                const SizedBox(width: 8),
                const Text('Multi-level replay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _diagChip('chart', _chromeExpanded ? 'overlay panels' : 'focus', !_chromeExpanded),
                if (_selectedStrategySignal != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _diagChip('selected_signal', _selectedStrategySignal!.ruleModeName, true),
                  ),
                const Spacer(),
                Text(statusText, style: const TextStyle(color: Colors.white60, fontSize: 11), overflow: TextOverflow.ellipsis),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _chromeExpanded ? '收起控制区，最大化K线图' : '展开控制/信号浮层',
                  onPressed: () => setState(() => _chromeExpanded = !_chromeExpanded),
                  icon: Icon(_chromeExpanded ? Icons.fullscreen : Icons.tune, color: Colors.white70, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                ElevatedButton(onPressed: _loading ? null : _load, child: const Text('Load')),
              ],
            ),
            if (_chromeExpanded) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _input(_backendUrlController, 'backend', 190, enabled: false),
                  _input(_symbolController, 'symbol', 96),
                  _input(_marketController, 'market', 70),
                  _input(_startController, 'start', 112),
                  _input(_endController, 'end', 112),
                  _dropdownInt('count', _count, _countOptions, (v) => setState(() => _count = v)),
                  _dropdownInt('step frames', _maxStepFrames, _maxStepFrameOptions, (v) => setState(() => _maxStepFrames = v)),
                  _modeChip('once', 'once'),
                  _modeChip('step', 'step'),
                  OutlinedButton.icon(
                    onPressed: (_loading || _signalScanLoading) ? null : _loadCandidateWindow,
                    icon: const Icon(Icons.event_available, size: 14),
                    label: const Text('S7样本窗口'),
                    style: _copyButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: _signalScanLoading ? null : _scanSignals,
                    icon: const Icon(Icons.search, size: 14),
                    label: Text(_signalScanLoading ? '扫描中' : 'Scan Signal($_count)'),
                    style: _copyButtonStyle(),
                  ),
                  for (final level in _levelOptions) _levelChip(level),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _analysisToolStrip(MultiLevelChanSnapshot current, MultiLevelChanSnapshot? signalSnapshot) {
    final relationCount = current.relations.length;
    final usingScan = _signalScanAnalysis != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1A8AB4FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x448AB4FF)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('工具面板', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          _diagChip('relations', '$relationCount', relationCount > 0),
          _diagChip('signal_source', usingScan ? 'scan once' : 'current frame', true),
          OutlinedButton.icon(
            onPressed: relationCount == 0 ? null : () => setState(() => _relationPanelExpanded = !_relationPanelExpanded),
            icon: Icon(_relationPanelExpanded ? Icons.expand_less : Icons.account_tree, size: 14),
            label: Text(_relationPanelExpanded ? '收起关系' : '关系定位'),
            style: _copyButtonStyle(),
          ),
          OutlinedButton.icon(
            onPressed: signalSnapshot == null ? null : () => setState(() => _signalPanelExpanded = !_signalPanelExpanded),
            icon: Icon(_signalPanelExpanded ? Icons.expand_less : Icons.radar, size: 14),
            label: Text(_signalPanelExpanded ? '收起信号' : '区间信号'),
            style: _copyButtonStyle(),
          ),
          if (_selectedStrategySignal != null)
            OutlinedButton.icon(
              onPressed: () => _locateStrategySignal(_selectedStrategySignal!),
              icon: const Icon(Icons.my_location, size: 14),
              label: const Text('定位选中信号'),
              style: _copyButtonStyle(),
            ),
          _diagChip('window', '${_startController.text}~${_endController.text}', true),
          _diagChip('scan', _signalScanStatus, usingScan),
        ],
      ),
    );
  }

  Widget _manualP0Panel(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    final okNative = meta['native_cchan_lv_list'] == true && meta['level_relation_mode'] == 'chan_parent_child' && meta['fallback_to_bridge'] != true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: okNative ? const Color(0x332E7D32) : const Color(0x33424242),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: okNative ? const Color(0xFF66BB6A) : Colors.white24),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _diagChip('manual P0', okNative ? 'native ok' : 'needs check', okNative),
          _diagChip('native_cchan_lv_list', '${meta['native_cchan_lv_list']}', meta['native_cchan_lv_list'] == true),
          _diagChip('level_relation_mode', '${meta['level_relation_mode']}', meta['level_relation_mode'] == 'chan_parent_child'),
          _diagChip('fallback_to_bridge', '${meta['fallback_to_bridge'] ?? false}', meta['fallback_to_bridge'] != true),
          _diagChip('relations.length', '${analysis.snapshot.relations.length}', analysis.snapshot.relations.isNotEmpty),
          _diagChip('frames.length', '${analysis.frames.length}', _mode != 'step' || analysis.frames.isNotEmpty),
          _copyButton('Copy P0', _buildP0DiagnosticText(analysis)),
          if (_mode == 'step') _copyButton('Copy Step', _buildStepDiagnosticText(analysis)),
        ],
      ),
    );
  }

  Widget _stepControls(PythonMultiLevelChanAnalysis analysis) {
    final frames = analysis.frames;
    if (frames.isEmpty) return const SizedBox.shrink();
    final safeIndex = _frameIndex.clamp(0, frames.length - 1).toInt();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x222A5CAA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x668AB4FF)),
      ),
      child: Row(children: [
        IconButton(
          tooltip: '上一帧',
          onPressed: safeIndex <= 0 ? null : () => _setFrameIndex(safeIndex - 1),
          icon: const Icon(Icons.skip_previous, color: Colors.white70),
        ),
        Expanded(
          child: Slider(
            value: safeIndex.toDouble(),
            min: 0,
            max: (frames.length - 1).toDouble(),
            divisions: frames.length > 1 ? frames.length - 1 : 1,
            label: '${safeIndex + 1}/${frames.length}',
            onChanged: (v) => _setFrameIndex(v.round()),
          ),
        ),
        IconButton(
          tooltip: '下一帧',
          onPressed: safeIndex >= frames.length - 1 ? null : () => _setFrameIndex(safeIndex + 1),
          icon: const Icon(Icons.skip_next, color: Colors.white70),
        ),
        _diagChip('frame', '${safeIndex + 1}/${frames.length}', true),
      ]),
    );
  }

  List<DrawingObject> _strategySignalDrawingObjects(String activeLevel) {
    final signal = _selectedStrategySignal;
    if (signal == null) return const [];
    final now = DateTime.now();
    final objects = <DrawingObject>[];
    void addMarker({required String level, required int rawIndex, required double price, required String label, required int color}) {
      if (level != activeLevel) return;
      objects.add(DrawingObject(
        id: '${signal.markerId}_${level}_$rawIndex',
        tool: TradingViewDrawingTool.priceLabel,
        anchors: [DrawingAnchor.chart(rawIndex: rawIndex, price: price)],
        style: DrawingStyle(colorValue: color, fontSize: 12.0, filled: true, fillColorValue: 0x332962FF, fillOpacity: 0.22),
        text: label,
        locked: true,
        createdAt: now,
        updatedAt: now,
      ));
    }
    addMarker(level: signal.highLevel, rawIndex: signal.highRawIndex, price: signal.highPrice, label: 'S7 HIGH ${signal.ruleModeName}', color: 0xFFFFD54F);
    addMarker(level: signal.lowLevel, rawIndex: signal.lowRawIndex, price: signal.lowPrice, label: 'S7 LOW ${signal.state}', color: 0xFF66BB6A);
    return objects;
  }

  void _locateStrategySignal(MultiLevelStrategySignalSelection signal) {
    final current = _signalScanAnalysis?.snapshot ?? _current ?? _full;
    final levelSnapshot = current?.of(signal.lowLevel) ?? _full?.of(signal.lowLevel);
    if (levelSnapshot == null || levelSnapshot.rawBars.isEmpty) return;
    final lowRawIndex = signal.lowRawIndex;
    final highRawIndex = signal.highRawIndex;
    final endIndex = _barListIndexForRawIndex(levelSnapshot, lowRawIndex);
    setState(() {
      _selectedStrategySignal = signal;
      _chromeExpanded = false;
      _viewState = _viewState.withActiveLevel(signal.lowLevel);
      _viewEndIndex = endIndex.clamp(0, levelSnapshot.rawBars.length - 1).toInt();
      _crosshairIndex = _viewEndIndex;
      _windowSize = _windowSize.clamp(60, 180).toInt();
      _status = 'S7 signal locate ${signal.ruleModeName} ${signal.lowLevel} raw:$lowRawIndex highRaw:$highRawIndex marker:s7_strategy_signal_marker';
    });
  }

  void _locateRelationTarget(RelationLocateRequest request) {
    final current = _current;
    final levelSnapshot = current?.of(request.level) ?? _full?.of(request.level);
    if (levelSnapshot == null || levelSnapshot.rawBars.isEmpty) return;
    final endIndex = _barListIndexForRawIndex(levelSnapshot, request.endRawIndex);
    final startIndex = _barListIndexForRawIndex(levelSnapshot, request.startRawIndex);
    final rangeWidth = (endIndex - startIndex).abs() + 18;
    setState(() {
      _chromeExpanded = false;
      _viewState = _viewState.withActiveLevel(request.level);
      _viewEndIndex = endIndex.clamp(0, levelSnapshot.rawBars.length - 1).toInt();
      if (rangeWidth > _windowSize) _windowSize = rangeWidth.clamp(30, 260).toInt();
      _crosshairIndex = _viewEndIndex;
      _status = 'relation locate ${request.level} raw:${request.startRawIndex}-${request.endRawIndex}';
    });
  }

  int _barListIndexForRawIndex(dynamic snapshot, int rawIndex) {
    final bars = snapshot.rawBars;
    for (var i = 0; i < bars.length; i++) {
      if (bars[i].index == rawIndex) return i;
    }
    if (rawIndex >= 0 && rawIndex < bars.length) return rawIndex;
    return bars.isEmpty ? 0 : bars.length - 1;
  }

  void _setFrameIndex(int next) {
    final analysis = _analysis;
    if (analysis == null || analysis.frames.isEmpty) return;
    final safe = next.clamp(0, analysis.frames.length - 1).toInt();
    setState(() {
      _frameIndex = safe;
      _viewEndIndex = null;
      _crosshairIndex = null;
      _selectedStrategySignal = null;
      _status = _buildStatus(analysis, snapshot: analysis.frames[safe]);
    });
  }

  void _panChartByBars(int bars) {
    final snapshot = _current?.of(_activeLevel);
    if (bars == 0 || snapshot == null || snapshot.rawBars.isEmpty) return;
    final maxEnd = snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  Widget _strictStepBlockedPanel() {
    return const Center(
      child: Text(
        'Strict step blocked: frames.length = 0. 不用最终完整快照伪装逐K结果。',
        style: TextStyle(color: Color(0xFFFFB74D), fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _modeChip(String value, String label) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _loading ? null : (_) => setState(() => _mode = value),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
    );
  }

  Widget _levelChip(String level) {
    final selected = _selectedLevels.contains(level);
    return FilterChip(
      label: Text(level),
      selected: selected,
      onSelected: _loading || _signalScanLoading
          ? null
          : (v) => setState(() {
                if (v) {
                  if (!_selectedLevels.contains(level)) _selectedLevels.add(level);
                } else if (_selectedLevels.length > 1) {
                  _selectedLevels.remove(level);
                }
              }),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
    );
  }

  Widget _dropdownInt(String label, int value, List<int> options, ValueChanged<int> onChanged) {
    return SizedBox(
      width: label == 'step frames' ? 130 : 96,
      child: DropdownButtonFormField<int>(
        value: value,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _decoration(label),
        items: [for (final option in options) DropdownMenuItem<int>(value: option, child: Text('$option'))],
        onChanged: (_loading || _signalScanLoading)
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    );
  }

  Widget _input(TextEditingController controller, String label, double width, {bool enabled = true}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled && !_loading && !_signalScanLoading,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _decoration(label),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF1C2330),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
    );
  }

  ButtonStyle _copyButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF8AB4FF),
      side: const BorderSide(color: Color(0x668AB4FF)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    );
  }

  Widget _diagChip(String label, String value, bool ok) {
    final color = ok ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text('$label: $value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _copyButton(String label, String text) {
    return OutlinedButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: text));
        _showMessage('$label copied');
      },
      icon: const Icon(Icons.copy, size: 14),
      label: Text(label),
      style: _copyButtonStyle(),
    );
  }

  String _blockedStatus(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    return 'analyze_multi STEP strict_step_blocked:true native:${meta['native_cchan_lv_list']} relation:${meta['level_relation_mode']} fallback:${meta['fallback_to_bridge'] ?? false} frames:0';
  }

  String _buildStatus(PythonMultiLevelChanAnalysis analysis, {MultiLevelChanSnapshot? snapshot}) {
    final snap = snapshot ?? analysis.snapshot;
    final meta = analysis.meta;
    return 'analyze_multi ${_mode.toUpperCase()} native:${meta['native_cchan_lv_list']} relation:${meta['level_relation_mode']} fallback:${meta['fallback_to_bridge'] ?? false} runtime_path:${_runtimePathText(analysis)} relations:${snap.relations.length} frames:${analysis.frames.length} window:${_startController.text}~${_endController.text} ${_buildCompactLevelSummary(snap)}';
  }

  String _buildCompactLevelSummary(MultiLevelChanSnapshot snapshot) {
    return [
      for (final level in snapshot.levels)
        if (snapshot.of(level) != null) '$level K:${snapshot.of(level)!.rawBars.length} BI:${snapshot.of(level)!.bis.length}'
    ].join(' | ');
  }

  String _buildLevelSummary(MultiLevelChanSnapshot snapshot) {
    return [
      for (final level in snapshot.levels)
        if (snapshot.of(level) != null)
          '$level K:${snapshot.of(level)!.rawBars.length} BI:${snapshot.of(level)!.bis.length} FX:${snapshot.of(level)!.fxs.length} SEG:${snapshot.of(level)!.segs.length} ZS:${snapshot.of(level)!.zss.length} BSP:${snapshot.of(level)!.bsps.length}'
    ].join(' | ');
  }

  String _runtimePathText(PythonMultiLevelChanAnalysis analysis) {
    final raw = '${analysis.meta['runtime_path'] ?? analysis.snapshot.meta['runtime_path'] ?? RuntimePathController.current.wireName}'.trim();
    return raw == 'slow_path' ? 'slow_path' : 'high_speed';
  }

  String _buildP0DiagnosticText(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    return [
      'manual P0 diagnostics',
      'status_summary: ${_stepFramesEmpty ? _blockedStatus(analysis) : _buildStatus(analysis)}',
      'level_summary: ${_buildLevelSummary(analysis.snapshot)}',
      'mode: $_mode',
      'symbol: ${_symbolController.text.trim()}',
      'market: ${_marketController.text.trim().toUpperCase()}',
      'levels: ${analysis.snapshot.levels.join(',')}',
      'selected_lv_list: ${_levels.join(',')}',
      'count: $_count',
      'max_step_frames: $_maxStepFrames',
      'start: ${_startController.text.trim()}',
      'end: ${_endController.text.trim()}',
      'runtime_path: ${_runtimePathText(analysis)}',
      'native_cchan_lv_list: ${meta['native_cchan_lv_list']}',
      'level_relation_mode: ${meta['level_relation_mode']}',
      'fallback_to_bridge: ${meta['fallback_to_bridge'] ?? false}',
      'relations.length: ${analysis.snapshot.relations.length}',
      'frames.length: ${analysis.frames.length}',
      'status: ok',
    ].join('\n');
  }

  String _buildStepDiagnosticText(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    return [
      'manual step diagnostics',
      'frame_source: native_step_frame',
      'final_snapshot_rendered_as_step: false',
      'mode: $_mode',
      'frame.index.local: $_frameIndex',
      'frame.count.local: ${analysis.frames.length}',
      'step_frame_format: ${meta['step_frame_format'] ?? analysis.snapshot.meta['step_frame_format'] ?? ''}',
      'frames_total: ${meta['frames_total'] ?? analysis.snapshot.meta['frames_total'] ?? ''}',
      'frames_returned: ${meta['frames_returned'] ?? analysis.snapshot.meta['frames_returned'] ?? ''}',
      'compact_validation_status: ${meta['compact_validation_status'] ?? analysis.snapshot.meta['compact_validation_status'] ?? ''}',
      'compact_validation_mismatch_count: ${meta['compact_validation_mismatch_count'] ?? analysis.snapshot.meta['compact_validation_mismatch_count'] ?? ''}',
      'status: ok',
    ].join('\n');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }
}
