import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/models/multi_level_view_state.dart';
import '../../core/models/replay_clock_mode.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../widgets/multi_level_layer_status_panel.dart';
import '../widgets/multi_level_switcher.dart';
import '../widgets/origin_kline_chart.dart';

class MultiLevelReplayPage extends StatefulWidget {
  const MultiLevelReplayPage({super.key});

  @override
  State<MultiLevelReplayPage> createState() => _MultiLevelReplayPageState();
}

class _MultiLevelReplayPageState extends State<MultiLevelReplayPage> {
  final _backendUrlController = TextEditingController(text: 'http://127.0.0.1:8000');
  final _symbolController = TextEditingController(text: '600340');
  final _marketController = TextEditingController(text: 'SH');
  final _levelsController = TextEditingController(text: 'DAILY,MIN30,MIN5');

  PythonMultiLevelChanAnalysis? _analysis;
  MultiLevelViewState _viewState = MultiLevelViewState.disabled();
  bool _loading = false;
  String _mode = 'step';
  int _count = 160;
  int _frameIndex = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  String _status = 'multi-level step replay not loaded';
  Timer? _initialLoadTimer;

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
    _levelsController.dispose();
    super.dispose();
  }

  MultiLevelChanSnapshot? get _full => _analysis?.snapshot;

  MultiLevelChanSnapshot? get _current {
    final analysis = _analysis;
    if (analysis == null) return null;
    if (_mode == 'step' && analysis.frames.isNotEmpty) {
      final idx = _frameIndex.clamp(0, analysis.frames.length - 1).toInt();
      return analysis.frames[idx];
    }
    return analysis.snapshot;
  }

  String get _activeLevel {
    final full = _full;
    if (full == null) return '';
    final active = _viewState.activeLevel.trim().toUpperCase();
    return full.snapshots.containsKey(active) ? active : full.safeActiveLevel;
  }

  List<String> get _levels => [
        for (final part in _levelsController.text.replaceAll('，', ',').split(','))
          if (part.trim().isNotEmpty) part.trim().toUpperCase(),
      ];

  Future<void> _load() async {
    if (_loading) return;
    final levels = _levels;
    if (levels.isEmpty) {
      _showMessage('lv_list is empty');
      return;
    }
    setState(() {
      _loading = true;
      _status = 'loading analyze_multi...';
    });
    final source = PythonMultiLevelChanAnalysisSource(
      baseUrl: _backendUrlController.text.trim(),
    );
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
        config: const {
          'bi_algo': 'normal',
          'seg_algo': 'chan',
          'zs_algo': 'normal',
          'max_step_frames': 120,
        },
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
        _status = _buildStatus(analysis, snapshot: _mode == 'step' && analysis.frames.isNotEmpty ? analysis.frames.first : analysis.snapshot);
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

  @override
  Widget build(BuildContext context) {
    final full = _full;
    final current = _current;
    final activeLevel = _activeLevel;
    final snapshot = current?.of(activeLevel);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                if (_analysis != null) _manualP0Panel(_analysis!),
                if (_analysis != null && _analysis!.frames.isNotEmpty) _stepControls(_analysis!),
                if (full != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(48, 8, 12, 8),
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
                Expanded(
                  child: snapshot == null || snapshot.rawBars.isEmpty
                      ? const Center(
                          child: Text(
                            'Load analyze_multi to show multi-level chart.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        )
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
                        ),
                ),
              ],
            ),
            if (full != null)
              Positioned(
                right: 12,
                top: _analysis == null
                    ? 118
                    : (_analysis!.frames.isNotEmpty ? 230 : 170),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: MultiLevelLayerStatusPanel(
                    fullSnapshot: full,
                    currentSnapshot: current ?? full,
                    activeLevel: activeLevel,
                    clockMode: _viewState.clockMode,
                    compact: true,
                  ),
                ),
              ),
            if (_loading)
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

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(48, 10, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF111722),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree, color: Color(0xFFFFD54F), size: 18),
              const SizedBox(width: 8),
              const Text('Multi-level replay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const Spacer(),
              _modeChip('once', 'once'),
              const SizedBox(width: 6),
              _modeChip('step', 'step'),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: _loading ? null : _load, child: const Text('Load')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _input(_backendUrlController, 'backend', 190),
              const SizedBox(width: 8),
              _input(_symbolController, 'symbol', 96),
              const SizedBox(width: 8),
              _input(_marketController, 'market', 70),
              const SizedBox(width: 8),
              _input(_levelsController, 'lv_list', 190),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextFormField(
                  initialValue: '$_count',
                  enabled: !_loading,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  keyboardType: TextInputType.number,
                  decoration: _decoration('count'),
                  onChanged: (v) => _count = int.tryParse(v.trim()) ?? _count,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _manualP0Panel(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    final native = meta['native_cchan_lv_list'];
    final relationMode = meta['level_relation_mode'];
    final fallback = meta['fallback_to_bridge'];
    final nativeFailure = meta['native_failure'];
    final relationsLength = analysis.snapshot.relations.length;
    final framesLength = analysis.frames.length;
    final okNative = native == true && relationMode == 'chan_parent_child' && fallback != true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(48, 8, 12, 0),
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
          _diagChip('manual P0', okNative ? 'native once ok' : 'needs check', okNative),
          _diagChip('native_cchan_lv_list', '$native', native == true),
          _diagChip('level_relation_mode', '$relationMode', relationMode == 'chan_parent_child'),
          _diagChip('fallback_to_bridge', '${fallback ?? false}', fallback != true),
          _diagChip('relations.length', '$relationsLength', relationsLength > 0),
          _diagChip('frames.length', '$framesLength', _mode != 'step' || framesLength > 0),
          if (nativeFailure != null) _diagChip('native_failure', '$nativeFailure', false),
          _copyP0Button(analysis),
          if (_mode == 'step') _copyStepButton(analysis),
        ],
      ),
    );
  }

  Widget _stepControls(PythonMultiLevelChanAnalysis analysis) {
    final frames = analysis.frames;
    if (frames.isEmpty) return const SizedBox.shrink();
    final safeIndex = _frameIndex.clamp(0, frames.length - 1).toInt();
    final frame = frames[safeIndex];
    final meta = frame.meta;
    final cursor = meta['cursor'] ?? meta['frame_index'] ?? safeIndex;
    final currentTime = meta['current_time'] ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(48, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x222A5CAA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x668AB4FF)),
      ),
      child: Row(
        children: [
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
          const SizedBox(width: 8),
          Text(
            'frame ${safeIndex + 1}/${frames.length} cursor:$cursor $currentTime',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 8),
          _copyStepButton(analysis),
        ],
      ),
    );
  }

  Widget _copyP0Button(PythonMultiLevelChanAnalysis analysis) {
    return OutlinedButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: _buildP0DiagnosticText(analysis)));
        _showMessage('P0 diagnostics copied');
      },
      icon: const Icon(Icons.copy, size: 14),
      label: const Text('Copy P0'),
      style: _copyButtonStyle(),
    );
  }

  Widget _copyStepButton(PythonMultiLevelChanAnalysis analysis) {
    return OutlinedButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: _buildStepDiagnosticText(analysis)));
        _showMessage('Step diagnostics copied');
      },
      icon: const Icon(Icons.copy, size: 14),
      label: const Text('Copy Step'),
      style: _copyButtonStyle(),
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
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _modeChip(String value, String label) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _loading ? null : (_) => setState(() {
        _mode = value;
        _frameIndex = 0;
      }),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
    );
  }

  Widget _input(TextEditingController controller, String label, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: !_loading,
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  void _setFrameIndex(int next) {
    final analysis = _analysis;
    if (analysis == null || analysis.frames.isEmpty) return;
    final safe = next.clamp(0, analysis.frames.length - 1).toInt();
    setState(() {
      _frameIndex = safe;
      _viewEndIndex = null;
      _crosshairIndex = null;
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

  String _buildStatus(PythonMultiLevelChanAnalysis analysis, {MultiLevelChanSnapshot? snapshot}) {
    final snap = snapshot ?? analysis.snapshot;
    final meta = analysis.meta;
    final native = meta['native_cchan_lv_list'];
    final fallback = meta['fallback_to_bridge'];
    final relationMode = meta['level_relation_mode'];
    return 'analyze_multi ${_mode.toUpperCase()} native:$native relation:$relationMode fallback:${fallback ?? false} relations:${snap.relations.length} frames:${analysis.frames.length} ${_buildCompactLevelSummary(snap)}';
  }

  String _buildCompactLevelSummary(MultiLevelChanSnapshot snapshot) {
    final parts = <String>[];
    for (final level in snapshot.levels) {
      final s = snapshot.of(level);
      if (s != null) parts.add('$level K:${s.rawBars.length} BI:${s.bis.length}');
    }
    return parts.join(' | ');
  }

  String _buildLevelSummary(MultiLevelChanSnapshot snapshot) {
    final parts = <String>[];
    for (final level in snapshot.levels) {
      final s = snapshot.of(level);
      if (s == null) continue;
      parts.add('$level K:${s.rawBars.length} BI:${s.bis.length} FX:${s.fxs.length} SEG:${s.segs.length} ZS:${s.zss.length} BSP:${s.bsps.length}');
    }
    return parts.join(' | ');
  }

  String _buildP0DiagnosticText(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    final snapshot = analysis.snapshot;
    return [
      'manual P0 diagnostics',
      'status_summary: ${_buildStatus(analysis)}',
      'level_summary: ${_buildLevelSummary(snapshot)}',
      'mode: $_mode',
      'symbol: ${_symbolController.text.trim()}',
      'market: ${_marketController.text.trim().toUpperCase()}',
      'levels: ${snapshot.levels.join(',')}',
      'native_cchan_lv_list: ${meta['native_cchan_lv_list']}',
      'level_relation_mode: ${meta['level_relation_mode']}',
      'fallback_to_bridge: ${meta['fallback_to_bridge'] ?? false}',
      'native_failure: ${meta['native_failure'] ?? ''}',
      'relations.length: ${snapshot.relations.length}',
      'frames.length: ${analysis.frames.length}',
      'source: ${meta['source'] ?? ''}',
      'native_step_frames: ${meta['native_step_frames'] ?? false}',
      'native_step_frames_total: ${meta['native_step_frames_total'] ?? ''}',
      'native_step_frames_returned: ${meta['native_step_frames_returned'] ?? ''}',
      'native_step_frames_limit: ${meta['native_step_frames_limit'] ?? ''}',
      'native_step_frames_truncated: ${meta['native_step_frames_truncated'] ?? ''}',
      'native_data_window: ${meta['native_data_window'] ?? ''}',
      'native_csv_time_policy: ${meta['native_csv_time_policy'] ?? ''}',
    ].join('\n');
  }

  String _buildStepDiagnosticText(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    final frames = analysis.frames;
    final safeIndex = frames.isEmpty ? 0 : _frameIndex.clamp(0, frames.length - 1).toInt();
    final frame = frames.isEmpty ? analysis.snapshot : frames[safeIndex];
    final frameMeta = frame.meta;
    return [
      'manual step diagnostics',
      'button: Copy Step',
      'copy_step_visible: true',
      'step_controls_visible: ${frames.isNotEmpty}',
      'mode: $_mode',
      'symbol: ${_symbolController.text.trim()}',
      'market: ${_marketController.text.trim().toUpperCase()}',
      'levels: ${analysis.snapshot.levels.join(',')}',
      'frame.index.local: $safeIndex',
      'frame.number.local: ${frames.isEmpty ? 0 : safeIndex + 1}/${frames.length}',
      'frame.cursor.native: ${frameMeta['cursor'] ?? frameMeta['frame_index'] ?? ''}',
      'frame.current_time: ${frameMeta['current_time'] ?? ''}',
      'native_cchan_lv_list: ${meta['native_cchan_lv_list']}',
      'level_relation_mode: ${meta['level_relation_mode']}',
      'fallback_to_bridge: ${meta['fallback_to_bridge'] ?? false}',
      'native_failure: ${meta['native_failure'] ?? ''}',
      'native_step_frames: ${meta['native_step_frames'] ?? false}',
      'native_step_frames_total: ${meta['native_step_frames_total'] ?? ''}',
      'native_step_frames_returned: ${meta['native_step_frames_returned'] ?? ''}',
      'native_step_frames_limit: ${meta['native_step_frames_limit'] ?? ''}',
      'native_step_frames_truncated: ${meta['native_step_frames_truncated'] ?? ''}',
      'frames.length: ${frames.length}',
      'frame.relations.length: ${frame.relations.length}',
      'status_summary.current_frame: ${_buildStatus(analysis, snapshot: frame)}',
      'level_summary.current_frame: ${_buildLevelSummary(frame)}',
      'level_summary.final: ${_buildLevelSummary(analysis.snapshot)}',
      'native_data_window: ${meta['native_data_window'] ?? ''}',
    ].join('\n');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}
