import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/replay_analysis_store.dart';
import '../../data/research_backend_client.dart';
import '../registries/research_backtest_registry.dart';

class ResearchBacktestPage extends StatefulWidget {
  final ValueChanged<int>? onOpenRoute;

  const ResearchBacktestPage({super.key, this.onOpenRoute});

  @override
  State<ResearchBacktestPage> createState() => _ResearchBacktestPageState();
}

class _ResearchBacktestPageState extends State<ResearchBacktestPage> {
  static const _backendUrl = 'http://127.0.0.1:8000';

  final _resultScrollController = ScrollController();
  final _segSymbolController = TextEditingController(text: '600340');
  final _segMarketController = TextEditingController(text: 'SH');
  final _segStartController = TextEditingController(text: '2025-09-01');
  final _segEndController = TextEditingController(text: '2026-06-18');
  final _holdDaysController = TextEditingController(text: '10');

  final List<_RuleCondition> _entryConditions = [
    _RuleCondition(structure: 'nseg', layer: 2, side: 'buy', type: 'endpoint'),
  ];
  final List<_RuleCondition> _exitConditions = [
    _RuleCondition(structure: 'nseg', layer: 2, side: 'sell', type: 'endpoint'),
  ];

  ResearchBackendClient? _backendClient;
  bool _running = false;
  bool _useOtherTarget = false;
  bool _useExitConditions = true;
  bool _useHoldDays = true;
  String _segLevel = 'MIN5';
  String _executionMode = 'step';
  String _status = '默认使用当前K线图缓存的 analysis 数据。';
  Map<String, dynamic>? _lastResult;
  Map<String, dynamic>? _lastAnalyzeMultiPayload;

  ResearchBacktestRegistry get _registry => ResearchBacktestRegistry.instance;

  @override
  void dispose() {
    _backendClient?.close();
    _resultScrollController.dispose();
    _segSymbolController.dispose();
    _segMarketController.dispose();
    _segStartController.dispose();
    _segEndController.dispose();
    _holdDaysController.dispose();
    super.dispose();
  }

  ResearchBackendClient _client() {
    final client = _backendClient;
    if (client == null || client.baseUrl != _backendUrl) {
      client?.close();
      _backendClient = ResearchBackendClient(baseUrl: _backendUrl);
    }
    return _backendClient!;
  }

  void _useCurrentKlineTarget() {
    final latest = ReplayAnalysisStore.latestAnalysis.value;
    setState(() {
      _useOtherTarget = false;
      _status = latest == null
          ? '暂无当前K线缓存：请先在K线图/复盘页加载一次标的。'
          : '已切换为当前K线标的：${latest.displaySymbol} ${latest.period}。';
    });
  }

  void _switchToOtherTarget() {
    final latest = ReplayAnalysisStore.latestAnalysis.value;
    if (latest != null && _segSymbolController.text.trim() == '600340') {
      _segSymbolController.text = latest.symbol;
      _segMarketController.text = latest.market;
      _segLevel = latest.period;
    }
    setState(() {
      _useOtherTarget = true;
      _status = '其它标的模式：按 once/step、笔/线段/N段、买卖点类型设计入场和出场。';
    });
  }

  int _maxRecursiveSegLayer() {
    final layers = <int>{
      for (final condition in _entryConditions) condition.layer,
      for (final condition in _exitConditions) condition.layer,
    };
    if (layers.isEmpty) return 4;
    final maxLayer = layers.reduce((left, right) => left > right ? left : right);
    return maxLayer < 4 ? 4 : maxLayer;
  }

  Map<String, dynamic> _otherTargetBasePayload() => {
        'symbol': _segSymbolController.text.trim(),
        'market': _segMarketController.text.trim().toUpperCase(),
        'levels': [_segLevel],
        'level': _segLevel,
        'main_level': _segLevel,
        'clock_level': _segLevel,
        'mode': _executionMode,
        'adjust': 'QFQ',
        if (_segStartController.text.trim().isNotEmpty)
          'start': _segStartController.text.trim(),
        if (_segEndController.text.trim().isNotEmpty)
          'end': _segEndController.text.trim(),
        'count': 50000,
        'config': {
          'bi_algo': 'fx',
          'seg_algo': 'chan',
          'zs_algo': 'normal',
          'recursive_seg_max_level': _maxRecursiveSegLayer(),
        },
      };

  Map<String, dynamic> _analyzeMultiPayload() => {
        ..._otherTargetBasePayload(),
        'mode': _executionMode,
      };

  Map<String, dynamic> _ruleOf(List<_RuleCondition> conditions) => {
        'conditions': [
          for (final condition in conditions) condition.toJson(),
        ],
        'dedupe': true,
      };

  String _effectiveSignalSource() {
    final rows = [..._entryConditions, if (_useExitConditions) ..._exitConditions];
    final needsRealBsp = rows.any((condition) => condition.isRealBsp);
    final needsCandidate = rows.any((condition) => condition.isEndpointCandidate);
    if (needsRealBsp && needsCandidate) return 'auto';
    if (needsCandidate) return 'endpoint_candidate';
    return 'real_bsp';
  }

  Map<String, dynamic> _segCompositePayload() {
    final signalSource = _effectiveSignalSource();
    return {
      ..._otherTargetBasePayload(),
      'entry_rule': _ruleOf(_entryConditions),
      if (_useExitConditions) 'exit_rule': _ruleOf(_exitConditions),
      'preset': 'custom_mode_structure_type',
      'preset_label': '自定义：once/step | 笔/线段/N段 | 买卖点类型',
      'options': {
        if (_useHoldDays)
          'max_hold_days': int.tryParse(_holdDaysController.text.trim()) ?? 10,
        'fee_bps': 3,
        'slippage_bps': 2,
        'signal_source': signalSource,
        'execution_mode': _executionMode,
        'preset': 'custom_mode_structure_type',
        'preset_label': '自定义：once/step | 笔/线段/N段 | 买卖点类型',
      },
    };
  }

  Map<String, dynamic>? _currentKlinePayload() {
    final latest = ReplayAnalysisStore.latestAnalysis.value;
    if (latest == null) {
      setState(() => _status = '暂无当前K线缓存：请先在K线图/复盘页加载一次标的。');
      return null;
    }
    return latest.toPayload();
  }

  Future<Map<String, dynamic>?> _payloadForEndpoint(
    String endpoint,
    ResearchBackendClient client,
  ) async {
    if (!_useOtherTarget) return _currentKlinePayload();
    if (endpoint.endsWith('/seg-composite/backtest')) return _segCompositePayload();
    final analysis = await _loadOtherTargetAnalysis(client);
    return {'analysis': analysis};
  }

  Future<Map<String, dynamic>> _loadOtherTargetAnalysis(
    ResearchBackendClient client,
  ) async {
    final symbol = _segSymbolController.text.trim();
    final market = _segMarketController.text.trim().toUpperCase();
    final level = _segLevel.trim().toUpperCase();
    if (symbol.isEmpty) throw const FormatException('其它标的代码不能为空');
    if (mounted) {
      setState(() => _status = '其它标的：正在自动 analyze_multi $market$symbol $level $_executionMode ...');
    }
    final response = await client.post('/api/chan/analyze_multi', _analyzeMultiPayload());
    if (response['ok'] == false) {
      throw Exception('analyze_multi 失败：${response['error'] ?? 'unknown error'}');
    }
    _lastAnalyzeMultiPayload = Map<String, dynamic>.from(response);
    return _analysisFromAnalyzeMultiResponse(response);
  }

  Map<String, dynamic> _analysisFromAnalyzeMultiResponse(Map<String, dynamic> response) {
    final level = _segLevel.trim().toUpperCase();
    final rawLevels = response['levels'];
    if (rawLevels is! Map) throw const FormatException('analyze_multi 响应缺少 levels');
    final rawLevel = rawLevels[level] ?? rawLevels[level.toUpperCase()] ?? rawLevels[level.toLowerCase()];
    if (rawLevel is! Map) throw FormatException('analyze_multi 响应缺少 $level 级别数据');
    final analysis = Map<String, dynamic>.from(rawLevel);
    final meta = analysis['meta'] is Map
        ? Map<String, dynamic>.from(analysis['meta'] as Map)
        : <String, dynamic>{};
    final symbol = _segSymbolController.text.trim();
    final market = _segMarketController.text.trim().toUpperCase();
    meta.addAll({
      'symbol': symbol,
      'market': market,
      'freq': level,
      'period': level,
      'adjust': 'QFQ',
      'main_level': level,
      'levels': [level],
      'mode': _executionMode,
      'source': 'research_page.other_target.analyze_multi',
      'research_other_target': true,
      'chan_py_polluted': false,
    });
    analysis
      ..['meta'] = meta
      ..['symbol'] = symbol
      ..['market'] = market
      ..['freq'] = level
      ..['period'] = level
      ..['adjust'] = 'QFQ';
    if (analysis['bsp'] is! List && analysis['bsps'] is List) {
      analysis['bsp'] = analysis['bsps'];
    }
    if (analysis['seg_bsp_history_layers'] == null && analysis['seg_bsp_layers'] != null) {
      analysis['seg_bsp_history_layers'] = analysis['seg_bsp_layers'];
    }
    return analysis;
  }

  Future<void> _callAction(ResearchActionRegistration action) async {
    switch (action.kind) {
      case ResearchActionKind.endpoint:
        return _call(action.endpoint);
      case ResearchActionKind.segComposite:
        return _callSegComposite(action.endpoint);
    }
  }

  Future<void> _call(String endpoint, {Map<String, dynamic>? overridePayload}) async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = _useOtherTarget && overridePayload == null
          ? '其它标的：准备自动 analyze_multi 后请求 $endpoint ...'
          : '请求 $endpoint ...';
    });
    try {
      final client = _client();
      final payload = overridePayload ?? await _payloadForEndpoint(endpoint, client);
      if (payload == null) return;
      final result = await client.post(endpoint, payload);
      if (endpoint.endsWith('/pipeline') && result['ok'] != false) {
        ReplayAnalysisStore.addBacktestRecord(BacktestRecord.fromResearchResult(
          result: result,
          latestAnalysis: _useOtherTarget ? null : ReplayAnalysisStore.latestAnalysis.value,
          source: 'pipeline',
          symbol: _useOtherTarget ? _segSymbolController.text.trim() : null,
          market: _useOtherTarget ? _segMarketController.text.trim().toUpperCase() : null,
          period: _useOtherTarget ? _segLevel : null,
        ));
      }
      setState(() {
        _lastResult = result;
        _status = _summaryOf(endpoint, result);
      });
    } catch (e) {
      setState(() {
        _lastResult = {'ok': false, 'error': '$e'};
        _status = '调用失败：$e';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _callSegComposite(String endpoint) async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = '其它标的：准备研究K线缓存并执行组合回测 ...';
    });
    try {
      final client = _client();
      if (_useOtherTarget) {
        await _loadOtherTargetAnalysis(client);
      }
      final result = await client.post(endpoint, _segCompositePayload());
      setState(() {
        _lastResult = result;
        _status = _summaryOf(endpoint, result);
      });
    } catch (e) {
      setState(() {
        _lastResult = {'ok': false, 'error': '$e'};
        _status = '调用失败：$e';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _locateResult(Map<String, dynamic> row, {String label = '回测结果'}) {
    final raw = row['raw_index'] ?? row['entry_signal_raw_index'] ?? row['entry_raw_index'] ?? row['exit_raw_index'];
    final rawIndex = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (rawIndex == null) return;
    final timeText = '${row['time'] ?? row['entry_signal_time'] ?? row['entry_time'] ?? ''}';
    final latest = ReplayAnalysisStore.latestAnalysis.value;
    final useLatest = !_useOtherTarget && latest != null;
    final window = _jumpWindow(row, rawIndex);
    ReplayAnalysisStore.requestKlineLocation(
      symbol: useLatest ? latest.symbol : _segSymbolController.text.trim(),
      market: useLatest ? latest.market : _segMarketController.text.trim().toUpperCase(),
      level: useLatest ? latest.period : _segLevel,
      rawIndex: rawIndex,
      time: DateTime.tryParse(timeText.replaceFirst(' ', 'T')),
      startDate: useLatest ? null : DateTime.tryParse(_segStartController.text.trim()),
      endDate: useLatest ? null : DateTime.tryParse(_segEndController.text.trim()),
      label: label,
      mode: _useOtherTarget ? _executionMode : 'once',
      frameIndex: _rowInt(row['frame_index']),
      visibleStartRawIndex: window.$1,
      visibleEndRawIndex: window.$2,
      analysisPayload: _useOtherTarget ? _lastAnalyzeMultiPayload : null,
      source: 'research/backtest',
    );
    widget.onOpenRoute?.call(1);
  }

  (int, int) _jumpWindow(Map<String, dynamic> row, int fallbackRaw) {
    final candidates = <int>[
      fallbackRaw,
      if (_rowInt(row['entry_signal_raw_index']) != null) _rowInt(row['entry_signal_raw_index'])!,
      if (_rowInt(row['entry_raw_index']) != null) _rowInt(row['entry_raw_index'])!,
      if (_rowInt(row['exit_raw_index']) != null) _rowInt(row['exit_raw_index'])!,
      if (_rowInt(row['raw_index']) != null) _rowInt(row['raw_index'])!,
    ];
    candidates.sort();
    return (candidates.first, candidates.last);
  }

  int? _rowInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String _summaryOf(String endpoint, Map<String, dynamic> result) {
    if (result['ok'] == false) return '接口返回失败：${result['error'] ?? 'unknown error'}';
    final prefix = _useOtherTarget && !endpoint.endsWith('/seg-composite/backtest')
        ? '其它标的自动 analyze_multi + '
        : '';
    if (endpoint.endsWith('/pipeline')) {
      final backtest = result['backtest'];
      final summary = backtest is Map ? backtest['summary'] : null;
      if (summary is Map) {
        return '${prefix}Pipeline 完成：交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return '${prefix}Pipeline 完成。';
    }
    if (endpoint.endsWith('/features')) {
      return '${prefix}BSP 特征提取完成：${_rowsFrom(result['features'], nestedKey: 'features').length} 行。';
    }
    if (endpoint.endsWith('/score')) {
      return '${prefix}ML 打分完成：${_rowsFrom(result['scores'], nestedKey: 'scores').length} 行。';
    }
    if (endpoint.endsWith('/seg-composite/backtest')) {
      final summary = result['summary'];
      final meta = result['meta'];
      if (summary is Map) {
        final frames = meta is Map ? meta['evaluated_step_frames'] : null;
        final source = meta is Map ? meta['seg_composite_signal_source'] : null;
        return '组合回测完成：模式 $_executionMode，信号 ${source ?? _effectiveSignalSource()}，逐帧 ${frames ?? '--'}，入场 ${_rowsFrom(result['entry_events']).length}，交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return '组合回测完成。';
    }
    if (endpoint.endsWith('/backtest')) {
      final summary = result['summary'];
      if (summary is Map) {
        return '${prefix}回测完成：交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return '${prefix}回测完成。';
    }
    return '请求完成。';
  }

  String _pct(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '--';
    return '${(number * 100).toStringAsFixed(2)}%';
  }

  String _valueText(Object? value) {
    if (value == null) return '--';
    if (value is num) return value.toStringAsFixed(4);
    if (value is bool) return value ? '是' : '否';
    final text = '$value';
    return text.length > 42 ? '${text.substring(0, 42)}…' : text;
  }

  List<Map<String, dynamic>> _rowsFrom(Object? value, {String? nestedKey}) {
    final source = value is Map && nestedKey != null ? value[nestedKey] : value;
    if (source is! List) return const [];
    return [
      for (final row in source)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  Map<String, dynamic> _mapFrom(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String get _prettyResult {
    final result = _lastResult;
    if (result == null) return '暂无结果';
    return const JsonEncoder.withIndent('  ').convert(result);
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _prettyResult));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('研究结果已复制')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        title: const Text('研究 / 回测'),
        actions: [
          TextButton.icon(
            onPressed: _lastResult == null ? null : _copyResult,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制结果'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _running ? null : _useCurrentKlineTarget,
                  icon: const Icon(Icons.candlestick_chart, size: 18),
                  label: const Text('当前K线标的'),
                ),
                OutlinedButton.icon(
                  onPressed: _running ? null : _switchToOtherTarget,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('其它标的'),
                ),
                for (final action in _registry.actions)
                  _ActionButton(
                    label: action.label,
                    icon: action.icon,
                    running: _running,
                    onPressed: () => _callAction(action),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_status, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _Panel(
                      title: _useOtherTarget ? '其它标的 / 出入场设计' : '当前K线缓存',
                      child: _useOtherTarget
                          ? _SimpleRuleEditor(
                              symbolController: _segSymbolController,
                              marketController: _segMarketController,
                              startController: _segStartController,
                              endController: _segEndController,
                              holdDaysController: _holdDaysController,
                              level: _segLevel,
                              executionMode: _executionMode,
                              entryConditions: _entryConditions,
                              exitConditions: _exitConditions,
                              useExitConditions: _useExitConditions,
                              useHoldDays: _useHoldDays,
                              onLevelChanged: (value) => setState(() => _segLevel = value),
                              onExecutionModeChanged: (value) => setState(() => _executionMode = value),
                              onUseExitConditionsChanged: (value) => setState(() => _useExitConditions = value),
                              onUseHoldDaysChanged: (value) => setState(() => _useHoldDays = value),
                              onChanged: () => setState(() {}),
                            )
                          : const _CurrentKlinePanel(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Panel(
                      title: '结构化结果',
                      child: _ResearchResultView(
                        result: _lastResult,
                        rawJson: _prettyResult,
                        scrollController: _resultScrollController,
                        valueText: _valueText,
                        pctText: _pct,
                        rowsFrom: _rowsFrom,
                        mapFrom: _mapFrom,
                        onLocate: _locateResult,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCondition {
  String structure;
  int layer;
  String side;
  String type;

  _RuleCondition({
    required this.structure,
    required this.layer,
    required this.side,
    required this.type,
  });

  ResearchBspTypeRegistration get _typeRegistration =>
      ResearchBacktestRegistry.instance.bspTypeOf(type);

  bool get isEndpointCandidate => _typeRegistration.endpointCandidate;
  bool get isRealBsp => !isEndpointCandidate;

  Map<String, dynamic> toJson() =>
      ResearchBacktestRegistry.instance.buildConditionPayload(
        structure: structure,
        layer: layer,
        side: side,
        type: type,
      );
}

class _SimpleRuleEditor extends StatelessWidget {
  final TextEditingController symbolController;
  final TextEditingController marketController;
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController holdDaysController;
  final String level;
  final String executionMode;
  final List<_RuleCondition> entryConditions;
  final List<_RuleCondition> exitConditions;
  final bool useExitConditions;
  final bool useHoldDays;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onExecutionModeChanged;
  final ValueChanged<bool> onUseExitConditionsChanged;
  final ValueChanged<bool> onUseHoldDaysChanged;
  final VoidCallback onChanged;

  const _SimpleRuleEditor({
    required this.symbolController,
    required this.marketController,
    required this.startController,
    required this.endController,
    required this.holdDaysController,
    required this.level,
    required this.executionMode,
    required this.entryConditions,
    required this.exitConditions,
    required this.useExitConditions,
    required this.useHoldDays,
    required this.onLevelChanged,
    required this.onExecutionModeChanged,
    required this.onUseExitConditionsChanged,
    required this.onUseHoldDaysChanged,
    required this.onChanged,
  });

  ResearchBacktestRegistry get _registry => ResearchBacktestRegistry.instance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _field(symbolController, '标的', 120),
              _field(marketController, '市场', 90),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: executionMode,
                  decoration: const InputDecoration(labelText: '执行模式'),
                  items: [
                    for (final mode in _registry.executionModes)
                      DropdownMenuItem(value: mode.value, child: Text(mode.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) onExecutionModeChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'K线周期'),
                  items: [
                    for (final item in _registry.levels)
                      DropdownMenuItem(value: item.value, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) onLevelChanged(value);
                  },
                ),
              ),
              _field(startController, '开始日期', 140),
              _field(endController, '结束日期', 140),
            ],
          ),
          const SizedBox(height: 14),
          const _RuleHelp(),
          const SizedBox(height: 14),
          _ruleSection(title: '入场组合', rows: entryConditions, entry: true),
          const Divider(height: 26),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: useExitConditions,
            onChanged: onUseExitConditionsChanged,
            title: const Text('启用出场组合'),
          ),
          if (useExitConditions)
            _ruleSection(title: '出场组合', rows: exitConditions, entry: false),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: useHoldDays,
            onChanged: onUseHoldDaysChanged,
            title: const Text('启用入场后 N 天退出'),
          ),
          if (useHoldDays) _field(holdDaysController, '持有天数', 130),
        ],
      ),
    );
  }

  Widget _ruleSection({
    required String title,
    required List<_RuleCondition> rows,
    required bool entry,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _conditionRow(rows, index),
          ),
        OutlinedButton.icon(
          onPressed: () {
            rows.add(_RuleCondition(
              structure: _registry.defaultStructure.value,
              layer: 2,
              side: entry ? 'buy' : 'sell',
              type: _registry.defaultBspType.value,
            ));
            onChanged();
          },
          icon: const Icon(Icons.add, size: 17),
          label: const Text('增加 AND 条件'),
        ),
      ],
    );
  }

  Widget _conditionRow(List<_RuleCondition> rows, int index) {
    final row = rows[index];
    final structureRegistration = _registry.structureOf(row.structure);
    final isNseg = structureRegistration.recursiveLayer;
    final types = _registry.bspTypes;
    if (!_registry.hasBspType(row.type)) row.type = _registry.defaultBspType.value;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<String>(
            initialValue: structureRegistration.value,
            decoration: const InputDecoration(labelText: '结构'),
            items: [
              for (final structure in _registry.structures)
                DropdownMenuItem(value: structure.value, child: Text(structure.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              final nextStructure = _registry.structureOf(value);
              row.structure = nextStructure.value;
              if (!nextStructure.recursiveLayer) row.layer = nextStructure.fixedLayer;
              onChanged();
            },
          ),
        ),
        SizedBox(
          width: 105,
          child: isNseg
              ? TextFormField(
                  key: ValueKey('layer-${row.hashCode}-${row.layer}'),
                  initialValue: '${row.layer}',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'N段'),
                  onChanged: (value) {
                    final next = int.tryParse(value.trim());
                    if (next != null && next >= 2) {
                      row.layer = next;
                      onChanged();
                    }
                  },
                )
              : InputDecorator(
                  decoration: const InputDecoration(labelText: '层级'),
                  child: Text(structureRegistration.label),
                ),
        ),
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<String>(
            initialValue: row.side,
            decoration: const InputDecoration(labelText: '方向'),
            items: [
              for (final side in _registry.sides)
                DropdownMenuItem(value: side.value, child: Text(side.label)),
            ],
            onChanged: (value) {
              if (value != null) {
                row.side = value;
                onChanged();
              }
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: row.type,
            decoration: const InputDecoration(labelText: '买卖点类型'),
            items: [
              for (final type in types)
                DropdownMenuItem(
                  value: type.value,
                  child: Text(type.labelForSide(row.side)),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                row.type = value;
                onChanged();
              }
            },
          ),
        ),
        IconButton(
          tooltip: '删除条件',
          onPressed: rows.length <= 1
              ? null
              : () {
                  rows.removeAt(index);
                  onChanged();
                },
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }

  static Widget _field(TextEditingController controller, String label, double width) {
    return SizedBox(
      width: width,
      child: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
    );
  }
}

class _RuleHelp extends StatelessWidget {
  const _RuleHelp();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: const Text(
        '只保留三轴：执行模式 once/step；结构 笔/线段/N段；买卖点类型。三种结构都会显示完整买卖点类型下拉；笔/线段选择终点候选时走端点候选，选择 B/S 类型时走已验证的真实 BSP 事件源；N段走递归段真实 BSP 或递归段端点候选。上述选项由 ResearchBacktestRegistry 统一注册。',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _CurrentKlinePanel extends StatelessWidget {
  const _CurrentKlinePanel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LatestAnalysisJson?>(
      valueListenable: ReplayAnalysisStore.latestAnalysis,
      builder: (context, latest, _) {
        if (latest == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '暂无当前K线缓存。\n请先在K线图/复盘页加载一次标的，再回到这里直接研究。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }
        final bars = latest.analysis['bars'];
        final bsp = latest.analysis['bsp'];
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('默认数据源', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _InfoLine('标的', latest.displaySymbol),
              _InfoLine('周期', latest.period),
              _InfoLine('复权', latest.adjust.isEmpty ? '--' : latest.adjust),
              _InfoLine('缓存时间', _timeText(latest.savedAt)),
              _InfoLine('K线数量', bars is List ? '${bars.length}' : '--'),
              _InfoLine('BSP数量', bsp is List ? '${bsp.length}' : '--'),
              const SizedBox(height: 14),
              const Text(
                'BSP 特征、ML 打分、回测、Pipeline 默认使用当前K线图缓存。\n点击“其它标的”后可使用 once/step 出入场设计。',
                style: TextStyle(color: Colors.white54, height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 86, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }
}

class _ResearchResultView extends StatelessWidget {
  final Map<String, dynamic>? result;
  final String rawJson;
  final ScrollController scrollController;
  final String Function(Object? value) valueText;
  final String Function(Object? value) pctText;
  final List<Map<String, dynamic>> Function(Object? value, {String? nestedKey}) rowsFrom;
  final Map<String, dynamic> Function(Object? value) mapFrom;
  final void Function(Map<String, dynamic> row, {String label}) onLocate;

  const _ResearchResultView({
    required this.result,
    required this.rawJson,
    required this.scrollController,
    required this.valueText,
    required this.pctText,
    required this.rowsFrom,
    required this.mapFrom,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    final data = result;
    if (data == null) {
      return const Center(child: Text('暂无结果', style: TextStyle(color: Colors.white54)));
    }
    final backtest = data['backtest'] is Map ? mapFrom(data['backtest']) : data;
    final summary = mapFrom(backtest['summary']);
    final meta = mapFrom(backtest['meta']);
    final features = rowsFrom(data['features'], nestedKey: 'features');
    final scores = rowsFrom(data['scores'], nestedKey: 'scores');
    final entryEvents = rowsFrom(backtest['entry_events']);
    final exitEvents = rowsFrom(backtest['exit_events']);
    final trades = rowsFrom(backtest['trades']);
    final sourceCounts = mapFrom(meta['structure_source_counts']);

    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['ok'] == false)
              _ErrorBanner(message: '${data['error'] ?? 'unknown error'}')
            else ...[
              _SummaryGrid(cards: [
                _SummaryCardData('Features', '${features.length}', Icons.table_chart),
                _SummaryCardData('Scores', '${scores.length}', Icons.psychology),
                _SummaryCardData('Entry', '${entryEvents.length}', Icons.login),
                _SummaryCardData('Exit', '${exitEvents.length}', Icons.logout),
                _SummaryCardData('Trades', '${summary['trade_count'] ?? trades.length}', Icons.show_chart),
                _SummaryCardData('Win rate', pctText(summary['win_rate']), Icons.percent),
                _SummaryCardData('Total return', pctText(summary['total_return']), Icons.trending_up),
                _SummaryCardData('Signal source', '${meta['seg_composite_signal_source'] ?? '--'}', Icons.layers),
              ]),
              if (sourceCounts.isNotEmpty)
                _PreviewTable(
                  title: '结构源计数',
                  rows: [
                    for (final entry in sourceCounts.entries) {'source': entry.key, 'count': entry.value},
                  ],
                  columns: const ['source', 'count'],
                  valueText: valueText,
                ),
              if (entryEvents.isNotEmpty)
                _PreviewTable(
                  title: '入场信号（点击定位K线）',
                  rows: entryEvents,
                  columns: const ['time', 'raw_index', 'signature', 'level'],
                  valueText: valueText,
                  onRowTap: (row) => onLocate(row, label: '入场信号'),
                ),
              if (exitEvents.isNotEmpty)
                _PreviewTable(
                  title: '出场信号（点击定位K线）',
                  rows: exitEvents,
                  columns: const ['time', 'raw_index', 'signature', 'level'],
                  valueText: valueText,
                  onRowTap: (row) => onLocate(row, label: '出场信号'),
                ),
              if (features.isNotEmpty)
                _PreviewTable(
                  title: 'BSP 特征预览',
                  rows: features,
                  columns: const ['raw_index', 'time', 'level', 'type', 'is_buy', 'price', 'close'],
                  valueText: valueText,
                ),
              if (scores.isNotEmpty)
                _PreviewTable(
                  title: 'ML Score 预览',
                  rows: scores,
                  columns: const ['raw_index', 'time', 'level', 'type', 'is_buy', 'ml_score', 'ml_signal'],
                  valueText: valueText,
                ),
              if (trades.isNotEmpty)
                _PreviewTable(
                  title: '回测交易预览',
                  rows: trades,
                  columns: const ['entry_time', 'exit_time', 'net_return', 'exit_reason', 'hold_bars'],
                  valueText: valueText,
                  onRowTap: (row) => onLocate(row, label: '交易入场'),
                ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              collapsedIconColor: Colors.white54,
              iconColor: Colors.white70,
              title: const Text('原始 JSON', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    rawJson,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  final String Function(Object? value) valueText;
  final ValueChanged<Map<String, dynamic>>? onRowTap;

  const _PreviewTable({
    required this.title,
    required this.rows,
    required this.columns,
    required this.valueText,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewRows = rows.take(30).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title（显示 ${previewRows.length}/${rows.length}）', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: Colors.white10)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 40,
                  columnSpacing: 18,
                  columns: [for (final col in columns) DataColumn(label: Text(col, style: _headerStyle))],
                  rows: [
                    for (final row in previewRows)
                      DataRow(
                        onSelectChanged: onRowTap == null ? null : (_) => onRowTap!(row),
                        cells: [for (final col in columns) DataCell(Text(valueText(row[col]), style: _cellStyle))],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCardData(this.label, this.value, this.icon);
}

class _SummaryGrid extends StatelessWidget {
  final List<_SummaryCardData> cards;

  const _SummaryGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final card in cards)
          Container(
            width: 132,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(card.icon, size: 18, color: Colors.white60),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 3),
                      Text(card.value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool running;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.running,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: running ? null : onPressed,
      icon: running
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.32)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
  }
}

const _headerStyle = TextStyle(color: Colors.white70, fontSize: 12);
const _cellStyle = TextStyle(color: Colors.white60, fontSize: 12);

String _timeText(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
