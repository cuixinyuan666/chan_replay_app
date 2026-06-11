import 'package:flutter/material.dart';

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
  String _mode = 'once';
  int _count = 800;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  String _status = 'multi-level replay not loaded';

  @override
  void dispose() {
    _backendUrlController.dispose();
    _symbolController.dispose();
    _marketController.dispose();
    _levelsController.dispose();
    super.dispose();
  }

  MultiLevelChanSnapshot? get _full => _analysis?.snapshot;

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
        config: const {'bi_algo': 'normal', 'seg_algo': 'chan', 'zs_algo': 'normal'},
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _viewState = MultiLevelViewState.fromSnapshot(
          analysis.snapshot,
          clockMode: _mode == 'step' ? ReplayClockMode.strictMainLevel : ReplayClockMode.once,
        );
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        _status = _buildStatus(analysis);
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
    final activeLevel = _activeLevel;
    final snapshot = full?.of(activeLevel);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                if (_analysis != null) _manualP0Panel(_analysis!),
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
                top: _analysis == null ? 118 : 170,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: MultiLevelLayerStatusPanel(
                    fullSnapshot: full,
                    currentSnapshot: full,
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
        children: [
          _diagChip('manual P0', okNative ? 'native once ok' : 'needs check', okNative),
          _diagChip('native_cchan_lv_list', '$native', native == true),
          _diagChip('level_relation_mode', '$relationMode', relationMode == 'chan_parent_child'),
          _diagChip('fallback_to_bridge', '${fallback ?? false}', fallback != true),
          _diagChip('relations.length', '$relationsLength', relationsLength > 0),
          _diagChip('frames.length', '$framesLength', _mode != 'step' || framesLength > 0),
          if (nativeFailure != null) _diagChip('native_failure', '$nativeFailure', false),
        ],
      ),
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
      onSelected: _loading ? null : (_) => setState(() => _mode = value),
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

  void _panChartByBars(int bars) {
    final snapshot = _full?.of(_activeLevel);
    if (bars == 0 || snapshot == null || snapshot.rawBars.isEmpty) return;
    final maxEnd = snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  String _buildStatus(PythonMultiLevelChanAnalysis analysis) {
    final snapshot = analysis.snapshot;
    final meta = analysis.meta;
    final native = meta['native_cchan_lv_list'];
    final fallback = meta['fallback_to_bridge'];
    final relationMode = meta['level_relation_mode'];
    final parts = <String>[];
    for (final level in snapshot.levels) {
      final s = snapshot.of(level);
      if (s != null) parts.add('$level K:${s.rawBars.length} BI:${s.bis.length}');
    }
    return 'analyze_multi ${_mode.toUpperCase()} native:$native relation:$relationMode fallback:${fallback ?? false} relations:${snapshot.relations.length} frames:${analysis.frames.length} ${parts.join(' | ')}';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}
