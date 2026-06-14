import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/runtime/runtime_path.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../widgets/origin_kline_chart.dart';

class S12SingleStockReplayPage extends StatefulWidget {
  const S12SingleStockReplayPage({super.key});

  @override
  State<S12SingleStockReplayPage> createState() => _S12SingleStockReplayPageState();
}

class _S12SingleStockReplayPageState extends State<S12SingleStockReplayPage> {
  static const List<String> _levelOptions = <String>['DAILY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1'];
  static const Set<String> _levelOptionSet = <String>{'DAILY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1'};
  static const List<int> _countOptions = <int>[80, 120, 220, 600, 900];
  static const List<int> _stepFrameOptions = <int>[24, 40, 60, 120, 391];

  final TextEditingController _backendUrlController = TextEditingController(text: 'app-managed bundled Python');
  final TextEditingController _symbolController = TextEditingController(text: '600340');
  final TextEditingController _marketController = TextEditingController(text: 'SH');
  final TextEditingController _startController = TextEditingController(text: '2022-01-01');
  final TextEditingController _endController = TextEditingController(text: '2025-12-31');

  final List<String> _selectedLevels = <String>['DAILY', 'MIN30', 'MIN5'];
  final Set<String> _enabledEasyTdxIndicators = <String>{};

  PythonMultiLevelChanAnalysis? _analysis;
  Map<String, _TemporalEvidence> _temporalEvidence = <String, _TemporalEvidence>{};
  _TemporalSummary _temporalSummary = _TemporalSummary.empty();
  String _mode = 'once';
  String _activeLevel = 'DAILY';
  String _status = 'S12 single-stock replay not loaded; default uses proven S8/S11 once window';
  String _lastLevelValidation = '级别组合待校验';
  bool _loading = false;
  int _count = 900;
  int _maxStepFrames = 60;
  int _frameIndex = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  Timer? _initialLoadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoadTimer = Timer(const Duration(milliseconds: 380), () {
        if (mounted && !_loading && _analysis == null) _loadReplay();
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

  List<String> get _normalizedLevels => <String>[
        for (final level in _levelOptions)
          if (_selectedLevels.map((v) => v.trim().toUpperCase()).contains(level)) level,
      ];

  MultiLevelChanSnapshot? get _currentSnapshot {
    final analysis = _analysis;
    if (analysis == null) return null;
    if (_mode == 'step') {
      if (analysis.frames.isEmpty) return null;
      return analysis.frames[_frameIndex.clamp(0, analysis.frames.length - 1).toInt()];
    }
    return analysis.snapshot;
  }

  dynamic get _activeSnapshot {
    final current = _currentSnapshot;
    if (current == null) return null;
    final level = current.snapshots.containsKey(_activeLevel) ? _activeLevel : current.safeActiveLevel;
    return current.of(level);
  }

  _LevelValidationResult _validateSelectedLevels() {
    final raw = [for (final level in _selectedLevels) level.trim().toUpperCase()];
    final normalized = _normalizedLevels;
    if (raw.isEmpty) return _LevelValidationResult(false, normalized, '级别组合无效：至少选择两个级别');
    final unsupported = raw.where((level) => !_levelOptionSet.contains(level)).toList(growable: false);
    if (unsupported.isNotEmpty) return _LevelValidationResult(false, normalized, '级别组合无效：不支持 ${unsupported.join(',')}');
    if (raw.toSet().length != raw.length) return _LevelValidationResult(false, normalized, '级别组合无效：存在重复级别');
    if (normalized.length < 2) return _LevelValidationResult(false, normalized, '级别组合无效：至少选择两个级别');
    if (normalized.length != raw.length) return _LevelValidationResult(true, normalized, '级别组合已归一化：${normalized.join(',')}');
    return _LevelValidationResult(true, normalized, '级别组合有效：${normalized.join(',')}');
  }

  DateTime? _dateOrNull(TextEditingController controller, String label) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text.replaceAll('/', '-'));
    if (parsed == null) throw FormatException('$label must be yyyy-MM-dd, current=$text');
    return parsed;
  }

  Future<void> _loadReplay() async {
    if (_loading) return;
    final levelValidation = _validateSelectedLevels();
    setState(() => _lastLevelValidation = levelValidation.message);
    if (!levelValidation.ok) {
      _showMessage(levelValidation.message);
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
      _status = 'S12 loading analyze_multi ${_mode.toUpperCase()} levels:${levelValidation.normalizedLevels.join(',')} runtime:${RuntimePathController.current.wireName}';
    });
    final source = PythonMultiLevelChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    try {
      final analysis = await source.analyzeMulti(
        mode: _mode,
        market: _marketController.text.trim().toUpperCase(),
        code: _symbolController.text.trim(),
        levels: levelValidation.normalizedLevels,
        adjust: 'QFQ',
        mainLevel: levelValidation.normalizedLevels.first,
        clockLevel: levelValidation.normalizedLevels.first,
        count: _count,
        startDate: startDate,
        endDate: endDate,
        runtimePath: RuntimePathController.current,
        config: <String, dynamic>{
          'bi_algo': 'normal',
          'seg_algo': 'chan',
          'zs_algo': 'normal',
          if (_mode == 'step') 'max_step_frames': _maxStepFrames,
        },
      );
      final temporal = _rebuildTemporalEvidence(analysis);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _temporalEvidence = temporal.evidence;
        _temporalSummary = temporal;
        _frameIndex = 0;
        _activeLevel = analysis.snapshot.safeActiveLevel;
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        _status = _buildStatus(analysis);
      });
      _showMessage('S12 replay loaded');
    } catch (e) {
      if (!mounted) return;
      final detail = _friendlyLoadError(e);
      setState(() => _status = detail);
      _showMessage(detail);
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyLoadError(Object error) {
    return 'S12 replay load failed: $error | request: symbol=${_symbolController.text.trim()} market=${_marketController.text.trim().toUpperCase()} mode=$_mode levels=${_normalizedLevels.join(',')} count=$_count window=${_startController.text.trim()}~${_endController.text.trim()} runtime_path=${RuntimePathController.current.wireName}';
  }

  _TemporalSummary _rebuildTemporalEvidence(PythonMultiLevelChanAnalysis analysis) {
    final frames = analysis.frames.isNotEmpty
        ? analysis.frames
        : <MultiLevelChanSnapshot>[analysis.snapshot];
    final evidence = <String, _TemporalEvidence>{};
    for (var step = 0; step < frames.length; step++) {
      final frame = frames[step];
      for (final entry in frame.snapshots.entries) {
        _collectSnapshotTemporalEvidence(
          target: evidence,
          level: entry.key,
          snapshot: entry.value,
          step: step,
        );
      }
    }
    final finalStep = frames.isEmpty ? 0 : frames.length - 1;
    for (final item in evidence.values) {
      item.finalize(finalStep);
    }
    return _TemporalSummary.fromEvidence(
      evidence: evidence,
      source: analysis.frames.isNotEmpty ? 'backend_step_frames' : 'once_snapshot',
      frameCount: frames.length,
    );
  }

  void _collectSnapshotTemporalEvidence({
    required Map<String, _TemporalEvidence> target,
    required String level,
    required ChanSnapshot snapshot,
    required int step,
  }) {
    for (final bsp in snapshot.bsps) {
      _recordTemporalEvidence(
        target,
        id: 'BSP:$level:${bsp.rawIndex}:${bsp.type}:${bsp.index}',
        type: 'BSP',
        level: level,
        rawIndex: bsp.rawIndex,
        label: '${bsp.type}#${bsp.index}',
        isSure: bsp.confirmed,
        step: step,
      );
    }
    for (final fx in snapshot.fxs) {
      _recordTemporalEvidence(
        target,
        id: 'FX:$level:${fx.rawIndex}:${fx.type}:${fx.index}',
        type: 'FX',
        level: level,
        rawIndex: fx.rawIndex,
        label: '${fx.type}#${fx.index}',
        isSure: fx.confirmed,
        step: step,
      );
    }
    for (final bi in snapshot.bis) {
      _recordTemporalEvidence(
        target,
        id: 'BI:$level:${bi.startRawIndex}-${bi.endRawIndex}:${bi.index}',
        type: 'BI',
        level: level,
        rawIndex: bi.endRawIndex,
        label: '${bi.direction}#${bi.index}',
        isSure: bi.isSure,
        step: step,
      );
    }
    for (final seg in snapshot.segs) {
      _recordTemporalEvidence(
        target,
        id: 'SEG:$level:${seg.startRawIndex}-${seg.endRawIndex}:${seg.index}',
        type: 'SEG',
        level: level,
        rawIndex: seg.endRawIndex,
        label: '${seg.direction}#${seg.index}',
        isSure: seg.isSure,
        step: step,
      );
    }
    for (final zs in snapshot.zss) {
      _recordTemporalEvidence(
        target,
        id: 'ZS:$level:${zs.startRawIndex}-${zs.endRawIndex}:${zs.index}',
        type: 'ZS',
        level: level,
        rawIndex: zs.endRawIndex,
        label: 'ZS#${zs.index}',
        isSure: zs.confirmed,
        step: step,
      );
    }
    for (final zs in snapshot.segZss) {
      _recordTemporalEvidence(
        target,
        id: 'SEGZS:$level:${zs.startRawIndex}-${zs.endRawIndex}:${zs.index}',
        type: 'segseg/二级线段/2段 ZS',
        level: level,
        rawIndex: zs.endRawIndex,
        label: 'SEGZS#${zs.index}',
        isSure: zs.confirmed,
        step: step,
      );
    }
  }

  void _recordTemporalEvidence(
    Map<String, _TemporalEvidence> target, {
    required String id,
    required String type,
    required String level,
    required int rawIndex,
    required String label,
    required bool isSure,
    required int step,
  }) {
    final item = target.putIfAbsent(
      id,
      () => _TemporalEvidence(
        id: id,
        type: type,
        level: level,
        rawIndex: rawIndex,
        label: label,
        firstSeenStep: step,
      ),
    );
    item.markSeen(step: step, isSure: isSure);
  }

  @override
  Widget build(BuildContext context) {
    final activeSnapshot = _activeSnapshot;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 10, 10, 10),
          child: Row(
            children: <Widget>[
              SizedBox(width: 430, child: _controlPanel()),
              const SizedBox(width: 10),
              Expanded(child: _chartPanel(activeSnapshot)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _panel(
          title: 'S12 single-stock replay / high_speed',
          expandChild: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _input(_backendUrlController, 'backend', width: 190, enabled: false),
                  _input(_symbolController, 'symbol', width: 92),
                  _input(_marketController, 'market', width: 68),
                  _input(_startController, 'start', width: 108),
                  _input(_endController, 'end', width: 108),
                  _dropdownInt('count', _count, _countOptions, (v) => setState(() => _count = v)),
                  _dropdownInt('step frames', _maxStepFrames, _stepFrameOptions, (v) => setState(() => _maxStepFrames = v), width: 124),
                  _modeChip('once'),
                  _modeChip('step'),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final level in _levelOptions) _levelChip(level)]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _loading ? null : _loadReplay,
                    icon: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow, size: 16),
                    label: const Text('载入复盘'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _analysis == null ? null : () => _copyText('复制复盘证据', _buildReplayEvidenceText(_analysis!)),
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('复制复盘证据'),
                    style: _copyButtonStyle(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _chip('level_validation', _lastLevelValidation, _lastLevelValidation.contains('有效') || _lastLevelValidation.contains('归一化')),
              const SizedBox(height: 6),
              _chip('runtime_path', RuntimePathController.current.wireName, RuntimePathController.current.isHighSpeed),
              const SizedBox(height: 6),
              _chip('temporal_state_counts', _temporalSummary.shortText, _temporalSummary.total > 0),
              const SizedBox(height: 6),
              Text(_status, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _evidencePreviewPanel()),
      ],
    );
  }

  Widget _evidencePreviewPanel() {
    final analysis = _analysis;
    return _panel(
      title: 'S12 replay evidence preview',
      child: analysis == null
          ? const Center(child: Text('载入后可复制 S12 复盘证据。', style: TextStyle(color: Colors.white54)))
          : SingleChildScrollView(child: SelectableText(_buildReplayEvidenceText(analysis), style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35))),
    );
  }

  Widget _chartPanel(dynamic snapshot) {
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      return _panel(title: 'Chart', child: const Center(child: Text('Load S12 replay to show chart.', style: TextStyle(color: Colors.white54))));
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
      showEasyTdxIndicators: _enabledEasyTdxIndicators.isNotEmpty,
      easyTdxSubPanelCount: 2,
      enabledEasyTdxIndicators: _enabledEasyTdxIndicators,
      onEasyTdxIndicatorToggled: _toggleEasyTdxIndicator,
      drawingStorageKey: 's12_${_symbolController.text}_$_activeLevel',
      symbolLabel: '${_symbolController.text.trim()} $_activeLevel',
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

  void _toggleEasyTdxIndicator(String name) {
    final key = name.trim().toUpperCase();
    if (key.isEmpty) return;
    setState(() {
      if (_enabledEasyTdxIndicators.contains(key)) {
        _enabledEasyTdxIndicators.remove(key);
      } else {
        _enabledEasyTdxIndicators.add(key);
      }
    });
  }

  void _panChartByBars(int bars) {
    final snapshot = _activeSnapshot;
    if (bars == 0 || snapshot == null || snapshot.rawBars.isEmpty) return;
    final maxEnd = snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  Widget _levelChip(String level) {
    final selected = _selectedLevels.contains(level);
    return FilterChip(
      label: Text(level),
      selected: selected,
      onSelected: _loading
          ? null
          : (value) => setState(() {
                if (value) {
                  if (!_selectedLevels.contains(level)) _selectedLevels.add(level);
                } else {
                  _selectedLevels.remove(level);
                }
                _lastLevelValidation = _validateSelectedLevels().message;
              }),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
    );
  }

  Widget _modeChip(String value) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(value),
      selected: selected,
      onSelected: _loading ? null : (_) => setState(() => _mode = value),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
    );
  }

  Widget _dropdownInt(String label, int value, List<int> options, ValueChanged<int> onChanged, {double width = 96}) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<int>(
        value: value,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _decoration(label),
        items: [for (final option in options) DropdownMenuItem<int>(value: option, child: Text('$option'))],
        onChanged: _loading
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    );
  }

  Widget _input(TextEditingController controller, String label, {required double width, bool enabled = true}) {
    return SizedBox(
      width: width,
      child: TextField(controller: controller, enabled: enabled && !_loading, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: _decoration(label)),
    );
  }

  Widget _panel({required String title, required Widget child, bool expandChild = true}) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xDD111722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (expandChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, bool ok) {
    final color = ok ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.45))),
      child: Text('$label: $value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
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

  ButtonStyle _copyButtonStyle() => OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8AB4FF),
        side: const BorderSide(color: Color(0x668AB4FF)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      );

  String _buildStatus(PythonMultiLevelChanAnalysis analysis) {
    final meta = analysis.meta;
    return 'S12 analyze_multi ${_mode.toUpperCase()} runtime_path:${_runtimePathText(analysis)} native:${meta['native_cchan_lv_list']} fallback:${meta['fallback_to_bridge'] ?? false} frames:${analysis.frames.length} levels:${analysis.snapshot.levels.join(',')} temporal:${_temporalSummary.shortText}';
  }

  String _runtimePathText(PythonMultiLevelChanAnalysis analysis) {
    final raw = '${analysis.meta['runtime_path'] ?? analysis.snapshot.meta['runtime_path'] ?? RuntimePathController.current.wireName}'.trim();
    return raw == 'slow_path' ? 'slow_path' : 'high_speed';
  }

  String _buildReplayEvidenceText(PythonMultiLevelChanAnalysis analysis) {
    final normalized = _normalizedLevels;
    final current = _currentSnapshot;
    final active = current?.snapshots.containsKey(_activeLevel) == true ? _activeLevel : (current?.safeActiveLevel ?? _activeLevel);
    return <String>[
      's12_phase: app_single_stock_replay_high_speed_path',
      'symbol: ${_symbolController.text.trim()}',
      'market: ${_marketController.text.trim().toUpperCase()}',
      'selected_levels: ${_selectedLevels.join(',')}',
      'normalized_levels: ${normalized.join(',')}',
      'level_validation: $_lastLevelValidation',
      'active_level: $active',
      'runtime_path: ${_runtimePathText(analysis)}',
      'replay_mode: $_mode',
      'current_step: ${_mode == 'step' ? _frameIndex : 'once'}',
      'visible_window: window_size=$_windowSize view_end_index=${_viewEndIndex ?? 'auto'} crosshair_index=${_crosshairIndex ?? 'none'}',
      'enabled_chan_overlays: FX,FX_LINE,FX_TEXT,BI,SEG,ZS,BI_BSP,SEG_BSP',
      'enabled_easy_tdx_indicators: ${_enabledEasyTdxIndicators.isEmpty ? 'none' : _enabledEasyTdxIndicators.join(',')}',
      'selected_marker_id: none',
      'selected_marker_type: none',
      'is_sure: ${_temporalSummary.sample?.confirmed ?? 'unknown'}',
      'temporal_source: ${_temporalSummary.source}',
      'temporal_state: ${_temporalSummary.stateLine}',
      'temporal_state_counts: provisional=${_temporalSummary.provisionalCount} confirmed=${_temporalSummary.confirmedCount} historical_provisional=${_temporalSummary.historicalProvisionalCount} total=${_temporalSummary.total}',
      'temporal_sample_id: ${_temporalSummary.sample?.id ?? 'none'}',
      'temporal_sample_type: ${_temporalSummary.sample?.type ?? 'none'}',
      'temporal_sample_level: ${_temporalSummary.sample?.level ?? 'none'}',
      'temporal_sample_state: ${_temporalSummary.sample?.state ?? 'none'}',
      'first_seen_step: ${_temporalSummary.sample?.firstSeenStep ?? 'unknown'}',
      'confirmed_step: ${_temporalSummary.sample?.confirmedStep ?? 'unknown'}',
      'last_seen_step: ${_temporalSummary.sample?.lastSeenStep ?? 'unknown'}',
      'parent_child_interval_link: not_tracked_in_s12c',
      'temporal_evidence_policy: preserve backend-exported structures across frames; do not recalculate Chan structures in Dart',
      'source_policy: python/chan.py via native CChan(lv_list); Flutter/Dart display, route, mark, and copy evidence only',
      'backend_authority: native CChan(lv_list) through /api/chan/analyze_multi',
      'native_cchan_lv_list: ${analysis.meta['native_cchan_lv_list'] ?? analysis.snapshot.meta['native_cchan_lv_list']}',
      'fallback_to_bridge: ${analysis.meta['fallback_to_bridge'] ?? analysis.snapshot.meta['fallback_to_bridge'] ?? false}',
      'dart_chan_calculation_authority: false',
      'candidate_policy: not a trading recommendation',
    ].join('\n');
  }

  Future<void> _copyText(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('$label copied');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }
}

class _LevelValidationResult {
  final bool ok;
  final List<String> normalizedLevels;
  final String message;

  const _LevelValidationResult(this.ok, this.normalizedLevels, this.message);
}

class _TemporalEvidence {
  final String id;
  final String type;
  final String level;
  final int rawIndex;
  final String label;
  final int firstSeenStep;
  int lastSeenStep;
  int? confirmedStep;
  bool confirmed;
  String state = 'provisional';

  _TemporalEvidence({
    required this.id,
    required this.type,
    required this.level,
    required this.rawIndex,
    required this.label,
    required this.firstSeenStep,
  })  : lastSeenStep = firstSeenStep,
        confirmed = false;

  void markSeen({required int step, required bool isSure}) {
    lastSeenStep = step;
    if (isSure) {
      confirmed = true;
      confirmedStep ??= step;
    }
  }

  void finalize(int finalStep) {
    if (confirmed) {
      state = 'confirmed';
    } else if (lastSeenStep < finalStep) {
      state = 'historical_provisional';
    } else {
      state = 'provisional';
    }
  }
}

class _TemporalSummary {
  final Map<String, _TemporalEvidence> evidence;
  final String source;
  final int frameCount;
  final int provisionalCount;
  final int confirmedCount;
  final int historicalProvisionalCount;
  final _TemporalEvidence? sample;

  const _TemporalSummary({
    required this.evidence,
    required this.source,
    required this.frameCount,
    required this.provisionalCount,
    required this.confirmedCount,
    required this.historicalProvisionalCount,
    required this.sample,
  });

  factory _TemporalSummary.empty() => const _TemporalSummary(
        evidence: <String, _TemporalEvidence>{},
        source: 'not_loaded',
        frameCount: 0,
        provisionalCount: 0,
        confirmedCount: 0,
        historicalProvisionalCount: 0,
        sample: null,
      );

  factory _TemporalSummary.fromEvidence({
    required Map<String, _TemporalEvidence> evidence,
    required String source,
    required int frameCount,
  }) {
    final values = evidence.values.toList(growable: false);
    final provisional = values.where((item) => item.state == 'provisional').length;
    final confirmed = values.where((item) => item.state == 'confirmed').length;
    final historical = values.where((item) => item.state == 'historical_provisional').length;
    _TemporalEvidence? sample;
    for (final state in const ['historical_provisional', 'provisional', 'confirmed']) {
      final matches = values.where((item) => item.state == state).toList(growable: false);
      if (matches.isNotEmpty) {
        sample = matches.first;
        break;
      }
    }
    return _TemporalSummary(
      evidence: evidence,
      source: source,
      frameCount: frameCount,
      provisionalCount: provisional,
      confirmedCount: confirmed,
      historicalProvisionalCount: historical,
      sample: sample,
    );
  }

  int get total => provisionalCount + confirmedCount + historicalProvisionalCount;

  String get stateLine => 'provisional=$provisionalCount confirmed=$confirmedCount historical_provisional=$historicalProvisionalCount';

  String get shortText => 'source=$source frames=$frameCount $stateLine';
}
