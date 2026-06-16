import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/runtime/runtime_path.dart';
import '../../data/python_multi_level_chan_analysis_source.dart';
import '../../data/stock_selection_backend_client.dart';
import '../drawing/drawing_object.dart';
import '../drawing/tradingview_drawing_tool.dart';
import '../widgets/origin_kline_chart.dart';

class S8StrategyBatchPage extends StatefulWidget {
  const S8StrategyBatchPage({super.key});

  @override
  State<S8StrategyBatchPage> createState() => _S8StrategyBatchPageState();
}

class _S8StrategyBatchPageState extends State<S8StrategyBatchPage> {
  final TextEditingController _backendController = TextEditingController(text: StockSelectionBackendClient.defaultBaseUrl);
  final TextEditingController _symbolsController = TextEditingController(text: '600340.SH,000001.SZ,000002.SZ,600519.SH,300750.SZ');
  final TextEditingController _levelsController = TextEditingController(text: 'DAILY,MIN30,MIN5');
  final TextEditingController _startController = TextEditingController(text: '2022-01-01');
  final TextEditingController _endController = TextEditingController(text: '2025-12-31');
  final TextEditingController _countController = TextEditingController(text: '900');
  final TextEditingController _limitController = TextEditingController(text: '50');
  final TextEditingController _maxCandidatesController = TextEditingController(text: '20');

  final List<_S8RealtimeCandidate> _candidates = <_S8RealtimeCandidate>[];
  PythonMultiLevelChanAnalysis? _analysis;
  _S8RealtimeCandidate? _selected;
  bool _scanning = false;
  bool _loadingReplay = false;
  bool _stepConfirm = false;
  String _status = 'S8 realtime candidates not scanned';
  String _activeLevel = 'MIN30';
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;

  @override
  void dispose() {
    for (final controller in [_backendController, _symbolsController, _levelsController, _startController, _endController, _countController, _limitController, _maxCandidatesController]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _levels => _levelsController.text
      .replaceAll('，', ',')
      .split(',')
      .map((item) => item.trim().toUpperCase())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Future<void> _scanRealtime() async {
    if (_scanning) return;
    final client = StockSelectionBackendClient(baseUrl: _backendController.text);
    setState(() {
      _scanning = true;
      _status = 'running realtime S8 market scan...';
      _candidates.clear();
      _selected = null;
      _analysis = null;
    });
    try {
      final result = await client.scanS8(<String, dynamic>{
        'symbols': _symbolsController.text.trim().isEmpty ? null : _symbolsController.text.trim(),
        'levels': _levels,
        'start': _startController.text.trim(),
        'end': _endController.text.trim(),
        'count': int.tryParse(_countController.text.trim()) ?? 900,
        'limit': int.tryParse(_limitController.text.trim()) ?? 50,
        'max_candidates': int.tryParse(_maxCandidatesController.text.trim()) ?? 20,
        'step_confirm': _stepConfirm,
        'rules': const ['DAILY_2B_MIN30_1B', 'DAILY_3B_MIN30_1B', 'DAILY_3B_MIN30_2B'],
      });
      final rows = result['candidates'];
      final parsed = rows is List
          ? rows.whereType<Map>().map((item) => _S8RealtimeCandidate.fromJson(Map<String, dynamic>.from(item), result)).toList(growable: false)
          : <_S8RealtimeCandidate>[];
      if (!mounted) return;
      setState(() {
        _candidates
          ..clear()
          ..addAll(parsed);
        _selected = parsed.isEmpty ? null : parsed.first;
        _activeLevel = _selected?.jumpTargetLevel ?? 'MIN30';
        final summary = result['summary'];
        _status = 'S8 realtime scan done: candidates=${parsed.length}, summary=${summary is Map ? jsonEncode(summary) : summary}';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'S8 realtime scan failed: $e');
        _showMessage(_status);
      }
    } finally {
      client.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _openCandidate(_S8RealtimeCandidate candidate) async {
    if (_loadingReplay) return;
    setState(() {
      _loadingReplay = true;
      _selected = candidate;
      _activeLevel = candidate.jumpTargetLevel;
      _status = 'loading multi-level replay for ${candidate.code} ${candidate.ruleModeName}...';
    });
    final source = PythonMultiLevelChanAnalysisSource(baseUrl: _backendController.text.trim());
    try {
      final analysis = await source.analyzeMulti(
        mode: 'once',
        market: candidate.market,
        code: candidate.symbol,
        levels: candidate.levels,
        adjust: candidate.adjust,
        mainLevel: candidate.levels.first,
        clockLevel: candidate.levels.first,
        count: candidate.count,
        startDate: candidate.startDate,
        endDate: candidate.endDate,
        runtimePath: RuntimePathController.current,
        config: const {'bi_algo': 'normal', 'seg_algo': 'chan', 'zs_algo': 'normal'},
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        _priceScale = 1.0;
        _locateCandidate(candidate, analysis.snapshot);
        _status = 'S8 realtime candidate opened: ${candidate.code} ${candidate.ruleModeName} ${candidate.jumpTargetLevel} raw:${candidate.jumpRawIndex}';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'S8 candidate open failed: $e');
        _showMessage(_status);
      }
    } finally {
      source.close();
      if (mounted) setState(() => _loadingReplay = false);
    }
  }

  void _locateCandidate(_S8RealtimeCandidate candidate, MultiLevelChanSnapshot snapshot) {
    final levelSnapshot = snapshot.of(candidate.jumpTargetLevel);
    if (levelSnapshot == null || levelSnapshot.rawBars.isEmpty) {
      _viewEndIndex = null;
      _crosshairIndex = null;
      return;
    }
    final index = _barListIndexForRawIndex(levelSnapshot, candidate.jumpRawIndex);
    _activeLevel = candidate.jumpTargetLevel;
    _viewEndIndex = index.clamp(0, levelSnapshot.rawBars.length - 1).toInt();
    _crosshairIndex = _viewEndIndex;
    _windowSize = _windowSize.clamp(60, 180).toInt();
  }

  int _barListIndexForRawIndex(dynamic snapshot, int rawIndex) {
    final bars = snapshot.rawBars;
    for (var i = 0; i < bars.length; i++) {
      if (bars[i].index == rawIndex) return i;
    }
    if (rawIndex >= 0 && rawIndex < bars.length) return rawIndex;
    return bars.isEmpty ? 0 : bars.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedSnapshot = _analysis?.snapshot.of(_activeLevel);
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 10, 10, 10),
          child: Row(children: [
            SizedBox(width: 560, child: _leftPanel()),
            const SizedBox(width: 10),
            Expanded(child: _chartPanel(selectedSnapshot)),
          ]),
        ),
      ),
    );
  }

  Widget _leftPanel() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _headerPanel(),
        const SizedBox(height: 8),
        Expanded(child: _candidatesPanel()),
        const SizedBox(height: 8),
        _selectedEvidencePanel(),
      ]);

  Widget _headerPanel() => _panel(
        title: 'S8 realtime candidates',
        expandChild: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 210, child: _input(_backendController, 'backend')),
            SizedBox(width: 260, child: _input(_symbolsController, 'symbols; blank = backend pool')),
            SizedBox(width: 210, child: _input(_levelsController, 'levels')),
            SizedBox(width: 120, child: _input(_startController, 'start')),
            SizedBox(width: 120, child: _input(_endController, 'end')),
            SizedBox(width: 80, child: _input(_countController, 'count')),
            SizedBox(width: 80, child: _input(_limitController, 'limit')),
            SizedBox(width: 96, child: _input(_maxCandidatesController, 'max hits')),
            FilterChip(label: const Text('step确认'), selected: _stepConfirm, onSelected: _scanning ? null : (v) => setState(() => _stepConfirm = v)),
            FilledButton.icon(
              onPressed: _scanning ? null : _scanRealtime,
              icon: _scanning ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.radar, size: 16),
              label: const Text('实时扫描'),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip('candidates', '${_candidates.length}', _candidates.isNotEmpty),
            _chip('selected', _selected?.code ?? 'none', _selected != null),
            _chip('source', 'backend realtime', true),
            _chip('dart calc', 'false', true),
          ]),
          const SizedBox(height: 8),
          Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );

  Widget _candidatesPanel() => _panel(
        title: '候选列表：点击后载入多级别图表并跳转',
        child: _candidates.isEmpty
            ? const Center(child: Text('点击“实时扫描”后显示候选。', style: TextStyle(color: Colors.white54)))
            : Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowHeight: 34,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 44,
                      columnSpacing: 16,
                      columns: const [DataColumn(label: Text('代码')), DataColumn(label: Text('阶段')), DataColumn(label: Text('规则')), DataColumn(label: Text('状态')), DataColumn(label: Text('跳转'))],
                      rows: [
                        for (final c in _candidates)
                          DataRow(
                            selected: c.sameIdentity(_selected),
                            onSelectChanged: (_) => _openCandidate(c),
                            cells: [DataCell(Text(c.code)), DataCell(Text(c.phase)), DataCell(Text(c.ruleModeName)), DataCell(Text(c.state)), DataCell(Text('${c.jumpTargetLevel}#${c.jumpRawIndex}'))],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      );

  Widget _selectedEvidencePanel() => SizedBox(
        height: 190,
        child: _panel(
          title: 'S8 traceability evidence',
          child: SingleChildScrollView(
            child: SelectableText(_selected == null ? 'No S8 candidate selected.' : _selected!.toEvidenceText(), style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35)),
          ),
        ),
      );

  Widget _chartPanel(dynamic levelSnapshot) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: levelSnapshot == null || levelSnapshot.rawBars.isEmpty
              ? const Center(child: Text('点击 S8 候选后显示多级别 replay 图表。', style: TextStyle(color: Colors.white60)))
              : OriginKlineChart(
                  snapshot: levelSnapshot,
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
                  drawingObjects: _candidateDrawingObjects(_activeLevel),
                  drawingStorageKey: 's8_rt_${_selected?.code ?? 'empty'}_$_activeLevel',
                  symbolLabel: '${_selected?.code ?? 'S8'} $_activeLevel',
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
      );

  void _panChartByBars(int bars) {
    final levelSnapshot = _analysis?.snapshot.of(_activeLevel);
    if (bars == 0 || levelSnapshot == null || levelSnapshot.rawBars.isEmpty) return;
    final maxEnd = levelSnapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next != current) setState(() => _viewEndIndex = next);
  }

  List<DrawingObject> _candidateDrawingObjects(String activeLevel) {
    final selected = _selected;
    final levelSnapshot = _analysis?.snapshot.of(activeLevel);
    if (selected == null || levelSnapshot == null || activeLevel != selected.jumpTargetLevel) return const [];
    final index = _barListIndexForRawIndex(levelSnapshot, selected.jumpRawIndex);
    if (levelSnapshot.rawBars.isEmpty) return const [];
    final bar = levelSnapshot.rawBars[index.clamp(0, levelSnapshot.rawBars.length - 1).toInt()];
    final now = DateTime.now();
    return [
      DrawingObject(
        id: 's8_realtime_candidate_marker_${selected.code}_${selected.ruleModeName}_${selected.jumpTargetLevel}_${selected.jumpRawIndex}',
        tool: TradingViewDrawingTool.priceLabel,
        anchors: [DrawingAnchor.chart(rawIndex: selected.jumpRawIndex, price: bar.close)],
        style: const DrawingStyle(colorValue: 0xFFFFD54F, fontSize: 12.0, filled: true, fillColorValue: 0x332962FF, fillOpacity: 0.22),
        text: 'S8 ${selected.ruleModeName}',
        locked: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  Widget _panel({required String title, required Widget child, Widget? trailing, bool expandChild = true}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))), if (trailing != null) trailing]),
          const SizedBox(height: 8),
          if (expandChild) Expanded(child: child) else child,
        ]),
      );

  Widget _input(TextEditingController controller, String label) => TextField(
        controller: controller,
        enabled: !_scanning && !_loadingReplay,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      );

  Widget _chip(String label, String value, bool ok) {
    final color = ok ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.45))), child: Text('$label: $value', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }
}

class _S8RealtimeCandidate {
  final String symbol;
  final String market;
  final String code;
  final String phase;
  final String ruleModeName;
  final String sourceBspIdentifiers;
  final String sourceTargetLevels;
  final String nativeRelationRange;
  final String strictStepVisibility;
  final String state;
  final String jumpTargetLevel;
  final int jumpRawIndex;
  final List<String> levels;
  final String adjust;
  final DateTime? startDate;
  final DateTime? endDate;
  final int count;

  const _S8RealtimeCandidate({required this.symbol, required this.market, required this.code, required this.phase, required this.ruleModeName, required this.sourceBspIdentifiers, required this.sourceTargetLevels, required this.nativeRelationRange, required this.strictStepVisibility, required this.state, required this.jumpTargetLevel, required this.jumpRawIndex, required this.levels, required this.adjust, required this.startDate, required this.endDate, required this.count});

  factory _S8RealtimeCandidate.fromJson(Map<String, dynamic> json, Map<String, dynamic> root) {
    final request = root['request'] is Map ? Map<String, dynamic>.from(root['request'] as Map) : <String, dynamic>{};
    final jump = json['jump_target'] is Map ? Map<String, dynamic>.from(json['jump_target'] as Map) : <String, dynamic>{};
    final levelsRaw = request['levels'];
    final levels = levelsRaw is List ? levelsRaw.map((item) => '$item'.trim().toUpperCase()).where((item) => item.isNotEmpty).toList(growable: false) : const ['DAILY', 'MIN30', 'MIN5'];
    final symbol = _string(json['symbol']);
    final market = _string(json['market']).isEmpty ? _inferMarket(symbol) : _string(json['market']).toUpperCase();
    return _S8RealtimeCandidate(
      symbol: symbol,
      market: market,
      code: _string(json['code']).isEmpty ? '$symbol.$market' : _string(json['code']),
      phase: _string(json['phase']),
      ruleModeName: _string(json['rule_mode_name']),
      sourceBspIdentifiers: _string(json['source_bsp_identifiers']),
      sourceTargetLevels: _string(json['source_target_levels']),
      nativeRelationRange: _string(json['native_relation_range']),
      strictStepVisibility: _string(json['strict_step_visibility']),
      state: _string(json['state']),
      jumpTargetLevel: _string(jump['target_level']).isEmpty ? 'MIN30' : _string(jump['target_level']).toUpperCase(),
      jumpRawIndex: _int(jump['raw_index']) ?? 0,
      levels: levels.isEmpty ? const ['DAILY', 'MIN30', 'MIN5'] : levels,
      adjust: _string(request['adjust']).isEmpty ? 'QFQ' : _string(request['adjust']).toUpperCase(),
      startDate: _date(request['start']),
      endDate: _date(request['end']),
      count: _int(request['count']) ?? 900,
    );
  }

  bool sameIdentity(_S8RealtimeCandidate? other) => other != null && code == other.code && ruleModeName == other.ruleModeName && jumpTargetLevel == other.jumpTargetLevel && jumpRawIndex == other.jumpRawIndex;

  String toEvidenceText() => [
        'code: $code',
        'symbol: $symbol',
        'market: $market',
        'phase: $phase',
        'rule_mode_name: $ruleModeName',
        'source_bsp_identifiers: $sourceBspIdentifiers',
        'source_target_levels: $sourceTargetLevels',
        'native_relation_range: $nativeRelationRange',
        'strict_step_visibility: $strictStepVisibility',
        'state: $state',
        'jump_target: $jumpTargetLevel raw_index=$jumpRawIndex',
        'levels: ${levels.join(',')}',
        'start: ${_fmtDate(startDate)}',
        'end: ${_fmtDate(endDate)}',
        'count: $count',
        'candidate_policy: candidate signal only; not a trading recommendation',
        'source_policy: original chan.py BSP + native LevelRelation only',
        'dart_chan_calculation_authority: false',
      ].join('\n');

  static String _string(Object? value) => '${value ?? ''}'.trim();
  static int? _int(Object? value) => value is int ? value : int.tryParse('${value ?? ''}'.trim());
  static DateTime? _date(Object? value) {
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T').replaceAll('/', '-');
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return DateTime.tryParse(text);
  }

  static String _fmtDate(DateTime? value) => value == null ? '' : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static String _inferMarket(String code) => code.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ';
}
