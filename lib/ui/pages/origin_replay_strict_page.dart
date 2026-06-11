import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/chan_snapshot.dart';
import '../../data/python_chan_analysis_source.dart';
import '../widgets/origin_kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

class OriginReplayStrictPage extends StatefulWidget {
  const OriginReplayStrictPage({super.key});

  @override
  State<OriginReplayStrictPage> createState() => _OriginReplayStrictPageState();
}

class _OriginReplayStrictPageState extends State<OriginReplayStrictPage> {
  final _backendUrlController = TextEditingController(text: 'http://127.0.0.1:8000');
  final _symbolController = TextEditingController(text: '600340');

  PythonChanAnalysis? _analysis;
  ChanSnapshot _snapshot = ChanSnapshot.empty();
  bool _loading = false;
  bool _playing = false;
  String _mode = 'step';
  String _market = 'SH';
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  final DateTime _startDate = DateTime(2026, 1, 1);
  final DateTime _endDate = DateTime(2026, 6, 11);
  int _frameIndex = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  Timer? _timer;
  Timer? _initialLoadTimer;
  String _status = 'single-level strict replay not loaded';

  bool get _isStepMode => _mode == 'step';
  bool get _hasFrame => _analysis != null && _analysis!.frames.isNotEmpty;
  bool get _strictStepBlocked => _isStepMode && _analysis != null && _analysis!.frames.isEmpty;
  int get _stepTotal => _analysis?.frames.length ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoadTimer = Timer(const Duration(milliseconds: 420), () {
        if (mounted && !_loading && _analysis == null) _load();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _initialLoadTimer?.cancel();
    _backendUrlController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _status = 'loading single-level chan.py $_mode...';
      _playing = false;
      _timer?.cancel();
    });
    final source = PythonChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    try {
      final analysis = await source.analyze(
        mode: _mode,
        market: _market,
        code: _symbolController.text.trim(),
        period: _period,
        adjust: _adjust,
        startDate: _startDate,
        endDate: _endDate,
        config: const {
          'bi_algo': 'normal',
          'seg_algo': 'chan',
          'zs_algo': 'normal',
        },
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _frameIndex = 0;
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        if (_isStepMode) {
          if (analysis.frames.isNotEmpty) {
            _snapshot = analysis.frames.first;
            _status = _statusFor(analysis, frame: _snapshot);
          } else {
            _snapshot = ChanSnapshot.empty();
            _status = _blockedStatus(analysis);
          }
        } else {
          _snapshot = analysis.snapshot;
          _status = _statusFor(analysis, frame: analysis.snapshot);
        }
      });
      _showMessage(_status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analysis = null;
        _snapshot = ChanSnapshot.empty();
        _status = 'single-level load failed: $e';
      });
      _showMessage(_status);
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setMode(String mode) {
    if (_loading || _mode == mode) return;
    setState(() {
      _mode = mode;
      _frameIndex = 0;
      _playing = false;
      _timer?.cancel();
      final analysis = _analysis;
      if (analysis == null) return;
      if (_isStepMode) {
        _snapshot = analysis.frames.isNotEmpty ? analysis.frames.first : ChanSnapshot.empty();
        _status = analysis.frames.isNotEmpty ? _statusFor(analysis, frame: _snapshot) : _blockedStatus(analysis);
      } else {
        _snapshot = analysis.snapshot;
        _status = _statusFor(analysis, frame: _snapshot);
      }
    });
  }

  void _setFrameIndex(int next) {
    final analysis = _analysis;
    if (!_isStepMode || analysis == null || analysis.frames.isEmpty) return;
    final safe = next.clamp(0, analysis.frames.length - 1).toInt();
    setState(() {
      _frameIndex = safe;
      _snapshot = analysis.frames[safe];
      _viewEndIndex = null;
      _crosshairIndex = null;
      _status = _statusFor(analysis, frame: _snapshot);
    });
  }

  void _togglePlay() {
    if (!_hasFrame) return;
    setState(() {
      _playing = !_playing;
      _timer?.cancel();
      _timer = _playing
          ? Timer.periodic(const Duration(milliseconds: 450), (_) {
              final next = _frameIndex + 1;
              if (next >= _stepTotal) {
                setState(() => _playing = false);
                _timer?.cancel();
              } else {
                _setFrameIndex(next);
              }
            })
          : null;
    });
  }

  void _panChartByBars(int bars) {
    if (bars == 0 || _snapshot.rawBars.isEmpty) return;
    final maxEnd = _snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _header(),
                if (_analysis != null) _diagnosticPanel(),
                Expanded(
                  child: _strictStepBlocked
                      ? _blockedPanel()
                      : _snapshot.rawBars.isEmpty
                          ? const Center(
                              child: Text('Load single-level chan.py data.', style: TextStyle(color: Colors.white60)),
                            )
                          : OriginKlineChart(
                              snapshot: _snapshot,
                              symbolLabel: '${_symbolController.text.trim()} $_period',
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
                              drawingStorageKey: 'strict_${_symbolController.text.trim()}_${_period}_$_adjust',
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
                if (_isStepMode)
                  ReplayControllerBar(
                    enabled: _hasFrame,
                    playing: _playing,
                    cursor: _hasFrame ? _frameIndex + 1 : 0,
                    total: _stepTotal,
                    onReset: () => _setFrameIndex(0),
                    onStepBack: () => _setFrameIndex(math.max(0, _frameIndex - 1)),
                    onStepForward: () => _setFrameIndex(_frameIndex + 1),
                    onTogglePlay: _togglePlay,
                    onSliderChanged: (v) => _setFrameIndex(v.round() - 1),
                  ),
              ],
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
              const Icon(Icons.candlestick_chart, color: Color(0xFFFFD54F), size: 18),
              const SizedBox(width: 8),
              const Text('Single-level strict replay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const Spacer(),
              _modeButton('once'),
              const SizedBox(width: 6),
              _modeButton('step'),
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
              _smallDropdown('market', _market, const ['SH', 'SZ'], (v) => setState(() => _market = v ?? _market), width: 74),
              const SizedBox(width: 8),
              _smallDropdown('period', _period, const ['DAILY', 'MIN30', 'MIN5'], (v) => setState(() => _period = v ?? _period), width: 96),
              const SizedBox(width: 8),
              _smallDropdown('adjust', _adjust, const ['QFQ', 'HFQ', 'NONE'], (v) => setState(() => _adjust = v ?? _adjust), width: 96),
            ],
          ),
          const SizedBox(height: 5),
          Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _modeButton(String value) {
    final selected = _mode == value;
    return ChoiceChip(
      label: Text(value),
      selected: selected,
      onSelected: _loading ? null : (_) => _setMode(value),
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

  Widget _smallDropdown(String label, String value, List<String> values, ValueChanged<String?> onChanged, {required double width}) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF1C2330),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _decoration(label),
        items: [for (final v in values) DropdownMenuItem(value: v, child: Text(v))],
        onChanged: _loading ? null : onChanged,
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

  Widget _diagnosticPanel() {
    final analysis = _analysis!;
    final ok = !_isStepMode || analysis.frames.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(48, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? const Color(0x332E7D32) : const Color(0x33424242),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ok ? const Color(0xFF66BB6A) : Colors.white24),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chip('strict_step_blocked', '$_strictStepBlocked', !_strictStepBlocked),
          _chip('frames.length', '${analysis.frames.length}', !_isStepMode || analysis.frames.isNotEmpty),
          _chip('frame_source', _hasFrame ? 'chan_step_frame' : (_isStepMode ? 'none' : 'once'), ok),
          _chip('K', '${_snapshot.rawBars.length}', !_isStepMode || _snapshot.rawBars.isNotEmpty),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _copyStepText()));
              _showMessage('Single-level Copy Step copied');
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy Step'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8AB4FF),
              side: const BorderSide(color: Color(0x668AB4FF)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, bool ok) {
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

  Widget _blockedPanel() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0x332C1D1D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFB74D)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D), size: 32),
            SizedBox(height: 10),
            Text(
              'Strict step blocked: frames.length = 0',
              style: TextStyle(color: Color(0xFFFFB74D), fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              '当前是单级别 step 模式，但后端未返回原生 step frames。页面不会用最终完整快照切片伪装逐K结果。请点击 Copy Step 复制诊断。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _copyStepText() {
    final analysis = _analysis;
    final frame = _hasFrame ? _snapshot : null;
    final meta = analysis?.meta ?? const <String, dynamic>{};
    return [
      'single-level step diagnostics',
      'button: Copy Step',
      'mode: $_mode',
      'symbol: ${_symbolController.text.trim()}',
      'market: $_market',
      'period: $_period',
      'adjust: $_adjust',
      'strict_step_blocked: $_strictStepBlocked',
      'frame_source: ${_hasFrame ? 'chan_step_frame' : (_isStepMode ? 'none' : 'once')}',
      'final_snapshot_rendered_as_step: false',
      'frames.length: ${analysis?.frames.length ?? 0}',
      'frame.index.local: ${_hasFrame ? _frameIndex : ''}',
      'frame.number.local: ${_hasFrame ? '${_frameIndex + 1}/${analysis!.frames.length}' : '0/${analysis?.frames.length ?? 0}'}',
      'frame.current_time: ${frame?.rawBars.isNotEmpty == true ? frame!.rawBars.last.time.toIso8601String() : ''}',
      'level_summary.current_frame: ${frame == null ? '<none; strict step blocked>' : _summary(frame)}',
      'level_summary.final_snapshot_for_diagnostics: ${analysis == null ? '' : _summary(analysis.snapshot)}',
      'meta: $meta',
    ].join('\n');
  }

  String _statusFor(PythonChanAnalysis analysis, {required ChanSnapshot frame}) {
    return 'single-level ${_mode.toUpperCase()} frames:${analysis.frames.length} ${_summary(frame)}';
  }

  String _blockedStatus(PythonChanAnalysis analysis) {
    return 'single-level STEP strict_step_blocked:true frames:${analysis.frames.length} final_snapshot_not_rendered';
  }

  String _summary(ChanSnapshot s) {
    return 'K:${s.rawBars.length} FX:${s.fxs.length} BI:${s.bis.length} SEG:${s.segs.length} ZS:${s.zss.length} BSP:${s.bsps.length}';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}
