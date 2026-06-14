import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/level_relation.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/runtime/runtime_path.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../widgets/origin_kline_chart.dart';

class S13SingleStockReplayPage extends StatefulWidget {
  const S13SingleStockReplayPage({super.key});

  @override
  State<S13SingleStockReplayPage> createState() => _S13SingleStockReplayPageState();
}

enum _S13Panel { stock, levels, replay, chart, evidence }

class _S13SingleStockReplayPageState extends State<S13SingleStockReplayPage> {
  static const List<String> _levelOptions = <String>['DAILY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1'];
  static const Set<String> _levelOptionSet = <String>{'DAILY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1'};
  static const List<int> _stepFrameOptions = <int>[24, 40, 60, 120, 391];
  static final DateTime _defaultStartDate = DateTime(1990, 1, 1);

  final TextEditingController _backendUrlController = TextEditingController(text: 'app-managed bundled Python');
  final TextEditingController _symbolController = TextEditingController(text: '600340');
  final TextEditingController _marketController = TextEditingController(text: 'SH');
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  final List<String> _selectedLevels = <String>['DAILY', 'MIN30', 'MIN5'];
  final Set<String> _enabledEasyTdxIndicators = <String>{};

  PythonMultiLevelChanAnalysis? _analysis;
  _S13Panel _panel = _S13Panel.stock;
  String _mode = 'once';
  String _activeLevel = 'DAILY';
  String _status = '未加载；start 空=1990-01-01，end 空=系统当前时间，count 已删除';
  String _lastLevelValidation = '级别组合待校验';
  bool _loading = false;
  int _maxStepFrames = 60;
  int _frameIndex = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;

  @override
  void dispose() {
    _backendUrlController.dispose();
    _symbolController.dispose();
    _marketController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  DateTime get _defaultEndDate => DateTime.now();

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

  ChanSnapshot? get _activeSnapshot {
    final current = _currentSnapshot;
    if (current == null) return null;
    final level = current.snapshots.containsKey(_activeLevel) ? _activeLevel : current.safeActiveLevel;
    return current.of(level);
  }

  List<LevelRelation> get _visibleDownRelations {
    final current = _currentSnapshot;
    if (current == null || current.relations.isEmpty) return const <LevelRelation>[];
    final parent = _activeLevel.trim().toUpperCase();
    final loadedLevels = current.snapshots.keys.map((v) => v.trim().toUpperCase()).toSet();
    final seen = <String>{};
    final links = <LevelRelation>[];
    final sorted = current.relations.toList(growable: false)
      ..sort((a, b) {
        final parentCmp = a.parentRawIndex.compareTo(b.parentRawIndex);
        if (parentCmp != 0) return parentCmp;
        return a.childStartRawIndex.compareTo(b.childStartRawIndex);
      });
    for (final relation in sorted) {
      final relationParent = relation.parentLevel.trim().toUpperCase();
      final child = relation.childLevel.trim().toUpperCase();
      if (relationParent != parent || !loadedLevels.contains(child)) continue;
      final key = '$relationParent:${relation.parentRawIndex}:$child:${relation.childStartRawIndex}:${relation.childEndRawIndex}';
      if (!seen.add(key)) continue;
      links.add(relation);
      if (links.length >= 8) break;
    }
    return links;
  }

  DateTime _dateOrDefault(TextEditingController controller, String label, DateTime fallback) {
    final text = controller.text.trim();
    if (text.isEmpty) return fallback;
    final parsed = DateTime.tryParse(text.replaceAll('/', '-'));
    if (parsed == null) throw FormatException('$label must be yyyy-MM-dd, current=$text');
    return parsed;
  }

  String _fmtDate(DateTime value) => value.toIso8601String().split('T').first;

  String get _effectiveWindowText {
    try {
      final start = _dateOrDefault(_startController, 'start', _defaultStartDate);
      final end = _dateOrDefault(_endController, 'end', _defaultEndDate);
      return '${_fmtDate(start)}~${_fmtDate(end)}';
    } catch (_) {
      return 'invalid';
    }
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

  Future<void> _loadReplay() async {
    if (_loading) return;
    final levelValidation = _validateSelectedLevels();
    setState(() => _lastLevelValidation = levelValidation.message);
    if (!levelValidation.ok) {
      _showMessage(levelValidation.message);
      return;
    }

    late final DateTime startDate;
    late final DateTime endDate;
    try {
      startDate = _dateOrDefault(_startController, 'start', _defaultStartDate);
      endDate = _dateOrDefault(_endController, 'end', _defaultEndDate);
    } catch (e) {
      _showMessage('$e');
      return;
    }
    if (startDate.isAfter(endDate)) {
      _showMessage('时间窗口无效：开始时间不能晚于结束时间');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'S13 loading analyze_multi ${_mode.toUpperCase()} levels:${levelValidation.normalizedLevels.join(',')} window:${_fmtDate(startDate)}~${_fmtDate(endDate)} runtime:${RuntimePathController.current.wireName}';
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
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _frameIndex = 0;
        _activeLevel = analysis.snapshot.safeActiveLevel;
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
        _status = _buildStatus(analysis, startDate, endDate);
      });
      _showMessage('S13 replay loaded');
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
    return 'S13 replay load failed: $error | request: symbol=${_symbolController.text.trim()} market=${_marketController.text.trim().toUpperCase()} mode=$_mode levels=${_normalizedLevels.join(',')} window=$_effectiveWindowText runtime_path=${RuntimePathController.current.wireName}';
  }

  void _jumpDownRelation(LevelRelation relation) {
    final current = _currentSnapshot;
    if (current == null) return;
    final child = relation.childLevel.trim().toUpperCase();
    if (!current.snapshots.containsKey(child)) {
      _showMessage('区间套子级别未加载：$child');
      return;
    }
    final childSnapshot = current.of(child);
    final maxEnd = childSnapshot.rawBars.isEmpty ? 0 : childSnapshot.rawBars.length - 1;
    setState(() {
      _activeLevel = child;
      _viewEndIndex = relation.childEndRawIndex.clamp(0, maxEnd).toInt();
      _crosshairIndex = relation.childStartRawIndex.clamp(0, maxEnd).toInt();
      _priceScale = 1.0;
      _panel = _S13Panel.levels;
    });
    _showMessage('区间套跳转：${relation.parentLevel}@${relation.parentRawIndex} ↓ $child ${relation.childStartRawIndex}-${relation.childEndRawIndex}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Row(
          children: <Widget>[
            _leftToolbar(),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0x223C4658)),
            SizedBox(width: 430, child: Padding(padding: const EdgeInsets.all(10), child: _settingsPanel())),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0x223C4658)),
            Expanded(child: Padding(padding: const EdgeInsets.all(10), child: _chartPanel(_activeSnapshot))),
          ],
        ),
      ),
    );
  }

  Widget _leftToolbar() {
    return Container(
      width: 52,
      color: const Color(0xEE111722),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: <Widget>[
          _tool(Icons.settings, '股票基础设置', _S13Panel.stock),
          _tool(Icons.layers, '多级别设置', _S13Panel.levels),
          _tool(Icons.play_circle, '复盘执行', _S13Panel.replay),
          _tool(Icons.show_chart, '图层指标', _S13Panel.chart),
          _tool(Icons.article, '复盘证据', _S13Panel.evidence),
          const Spacer(),
          IconButton(
            tooltip: '载入复盘',
            onPressed: _loading ? null : _loadReplay,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            color: const Color(0xFFFFD54F),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String tip, _S13Panel panel) {
    final selected = _panel == panel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IconButton(
        tooltip: tip,
        onPressed: () => setState(() => _panel = panel),
        icon: Icon(icon, size: 19),
        color: selected ? Colors.black : Colors.white70,
        style: IconButton.styleFrom(
          backgroundColor: selected ? const Color(0xFFFFD54F) : const Color(0xFF1C2330),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _settingsPanel() {
    return switch (_panel) {
      _S13Panel.stock => _stockPanel(),
      _S13Panel.levels => _levelsPanel(),
      _S13Panel.replay => _replayPanel(),
      _S13Panel.chart => _chartSettingsPanel(),
      _S13Panel.evidence => _evidencePanel(),
    };
  }

  Widget _stockPanel() {
    return _panelBox(
      '股票基础设置',
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _input(_backendUrlController, 'backend', width: 210, enabled: false),
                _input(_symbolController, 'symbol', width: 104),
                _input(_marketController, 'market', width: 78),
                _input(_startController, 'start 可空', width: 132),
                _input(_endController, 'end 可空', width: 132),
              ],
            ),
            const SizedBox(height: 10),
            _chip('window_policy', 'start 空=1990-01-01；end 空=系统当前时间；count 已删除', true),
            const SizedBox(height: 8),
            _chip('effective_window', _effectiveWindowText, _effectiveWindowText != 'invalid'),
            const SizedBox(height: 8),
            Text(_status, maxLines: 7, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _levelsPanel() {
    return _panelBox(
      '多级别设置',
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('加载级别', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final level in _levelOptions) _levelChip(level)]),
            const SizedBox(height: 12),
            const Text('当前图表级别', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final level in _normalizedLevels) _activeLevelChip(level)]),
            const SizedBox(height: 10),
            _chip('level_validation', _lastLevelValidation, _lastLevelValidation.contains('有效') || _lastLevelValidation.contains('归一化')),
            const SizedBox(height: 8),
            _chip('normalized_levels', _normalizedLevels.join(','), _normalizedLevels.length >= 2),
          ],
        ),
      ),
    );
  }

  Widget _replayPanel() {
    return _panelBox(
      '复盘执行设置',
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _modeChip('once'),
              _modeChip('step'),
              _dropdownInt('step frames', _maxStepFrames, _stepFrameOptions, (v) => setState(() => _maxStepFrames = v), width: 132),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _loading ? null : _loadReplay, icon: const Icon(Icons.play_arrow, size: 16), label: const Text('载入复盘')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _analysis == null ? null : () => _copyText('复制复盘证据', _buildReplayEvidenceText(_analysis!)), icon: const Icon(Icons.copy, size: 14), label: const Text('复制复盘证据'), style: _copyButtonStyle()),
            const SizedBox(height: 10),
            _chip('runtime_path', RuntimePathController.current.wireName, RuntimePathController.current.isHighSpeed),
            const SizedBox(height: 8),
            _chip('replay_mode', _mode, true),
            const SizedBox(height: 8),
            _chip('chart_interval_links', '${_visibleDownRelations.length}', _visibleDownRelations.isNotEmpty),
          ],
        ),
      ),
    );
  }

  Widget _chartSettingsPanel() {
    const indicators = <String>['MA', 'BOLL', 'VOL', 'MACD'];
    return _panelBox(
      '图层与指标设置',
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('指标默认隐藏，可在这里或 K 线图工具箱中打开。', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final name in indicators) _indicatorChip(name)]),
          ],
        ),
      ),
    );
  }

  Widget _evidencePanel() {
    final analysis = _analysis;
    return _panelBox(
      '复盘证据',
      analysis == null
          ? const Center(child: Text('载入后可复制复盘证据。', style: TextStyle(color: Colors.white54)))
          : SingleChildScrollView(child: SelectableText(_buildReplayEvidenceText(analysis), style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35))),
    );
  }

  Widget _chartPanel(ChanSnapshot? snapshot) {
    if (snapshot == null || snapshot.rawBars.isEmpty) {
      return _panelBox('Chart', const Center(child: Text('Load replay to show chart.', style: TextStyle(color: Colors.white54))));
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: OriginKlineChart(
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
            drawingStorageKey: 's13_${_symbolController.text}_$_activeLevel',
            symbolLabel: '${_symbolController.text.trim()} $_activeLevel',
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
        _intervalLinkOverlay(),
      ],
    );
  }

  Widget _intervalLinkOverlay() {
    final links = _visibleDownRelations;
    if (links.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xEE111722),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x88FFD54F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('区间套链接', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final relation in links) _intervalLinkButton(relation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intervalLinkButton(LevelRelation relation) {
    final child = relation.childLevel.trim().toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _jumpDownRelation(relation),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.arrow_downward, size: 14, color: Color(0xFFFFD54F)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${relation.parentLevel}@${relation.parentRawIndex} → $child ${relation.childStartRawIndex}-${relation.childEndRawIndex}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  if (_activeLevel == level && _selectedLevels.isNotEmpty) _activeLevel = _normalizedLevels.first;
                }
                _lastLevelValidation = _validateSelectedLevels().message;
              }),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
    );
  }

  Widget _activeLevelChip(String level) {
    final selected = _activeLevel == level;
    return ChoiceChip(
      label: Text(level),
      selected: selected,
      onSelected: _activeSnapshot == null ? null : (_) => setState(() {
        _activeLevel = level;
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;
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

  Widget _indicatorChip(String name) {
    final selected = _enabledEasyTdxIndicators.contains(name);
    return FilterChip(
      label: Text(name),
      selected: selected,
      onSelected: (_) => _toggleEasyTdxIndicator(name),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 12),
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

  Widget _dropdownInt(String label, int value, List<int> options, ValueChanged<int> onChanged, {double width = 96}) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<int>(
        value: value,
        dropdownColor: const Color(0xFF20242E),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: _decoration(label),
        items: [for (final option in options) DropdownMenuItem<int>(value: option, child: Text('$option'))],
        onChanged: _loading ? null : (v) { if (v != null) onChanged(v); },
      ),
    );
  }

  Widget _input(TextEditingController controller, String label, {required double width, bool enabled = true}) {
    return SizedBox(width: width, child: TextField(controller: controller, enabled: enabled && !_loading, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: _decoration(label)));
  }

  Widget _panelBox(String title, Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xDD111722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.14))),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Expanded(child: child)]),
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

  ButtonStyle _copyButtonStyle() => OutlinedButton.styleFrom(foregroundColor: const Color(0xFF8AB4FF), side: const BorderSide(color: Color(0x668AB4FF)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700));

  String _buildStatus(PythonMultiLevelChanAnalysis analysis, DateTime startDate, DateTime endDate) {
    final meta = analysis.meta;
    return 'S13 analyze_multi ${_mode.toUpperCase()} runtime_path:${_runtimePathText(analysis)} native:${meta['native_cchan_lv_list']} fallback:${meta['fallback_to_bridge'] ?? false} frames:${analysis.frames.length} levels:${analysis.snapshot.levels.join(',')} window:${_fmtDate(startDate)}~${_fmtDate(endDate)} links:${_visibleDownRelations.length}';
  }

  String _runtimePathText(PythonMultiLevelChanAnalysis analysis) {
    final raw = '${analysis.meta['runtime_path'] ?? analysis.snapshot.meta['runtime_path'] ?? RuntimePathController.current.wireName}'.trim();
    return raw == 'slow_path' ? 'slow_path' : 'high_speed';
  }

  String _buildReplayEvidenceText(PythonMultiLevelChanAnalysis analysis) {
    return <String>[
      's13_phase: single_stock_multilevel_replay_time_window_and_toolbar',
      'symbol: ${_symbolController.text.trim()}',
      'market: ${_marketController.text.trim().toUpperCase()}',
      'selected_levels: ${_selectedLevels.join(',')}',
      'normalized_levels: ${_normalizedLevels.join(',')}',
      'level_validation: $_lastLevelValidation',
      'active_level: $_activeLevel',
      'runtime_path: ${_runtimePathText(analysis)}',
      'replay_mode: $_mode',
      'current_step: ${_mode == 'step' ? _frameIndex : 'once'}',
      'request_window: $_effectiveWindowText',
      'date_window_policy: start empty defaults to 1990-01-01; end empty defaults to system current time; count parameter removed',
      'settings_layout: left_vertical_toolbar_with_stock_basic_settings_panel',
      'chart_interval_link_policy: show downward arrow links on chart for backend parent-child LevelRelation records',
      'chart_interval_link_count: ${_visibleDownRelations.length}',
      'enabled_easy_tdx_indicators: ${_enabledEasyTdxIndicators.isEmpty ? 'none' : _enabledEasyTdxIndicators.join(',')}',
      'source_policy: python/chan.py via native CChan(lv_list); Flutter/Dart display, route, request, and copy evidence only',
      'backend_authority: native CChan(lv_list) through /api/chan/analyze_multi',
      'native_cchan_lv_list: ${analysis.meta['native_cchan_lv_list'] ?? analysis.snapshot.meta['native_cchan_lv_list']}',
      'fallback_to_bridge: ${analysis.meta['fallback_to_bridge'] ?? analysis.snapshot.meta['fallback_to_bridge'] ?? false}',
      'dart_chan_calculation_authority: false',
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
