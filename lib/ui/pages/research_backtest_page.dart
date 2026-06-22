import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/replay_analysis_store.dart';
import '../../data/research_backend_client.dart';

class ResearchBacktestPage extends StatefulWidget {
  final ValueChanged<int>? onOpenRoute;

  const ResearchBacktestPage({super.key, this.onOpenRoute});

  @override
  State<ResearchBacktestPage> createState() => _ResearchBacktestPageState();
}

class _ResearchBacktestPageState extends State<ResearchBacktestPage> {
  final TextEditingController _backendUrlController =
      TextEditingController(text: 'http://127.0.0.1:8000');
  final TextEditingController _jsonController = TextEditingController(text: '''{
  "analysis": {}
}''');
  final ScrollController _resultScrollController = ScrollController();
  final ScrollController _recordScrollController = ScrollController();
  final TextEditingController _segSymbolController =
      TextEditingController(text: '600340');
  final TextEditingController _segMarketController =
      TextEditingController(text: 'SH');
  final TextEditingController _segStartController =
      TextEditingController(text: '2025-09-01');
  final TextEditingController _segEndController =
      TextEditingController(text: '2026-06-18');
  final TextEditingController _holdDaysController =
      TextEditingController(text: '10');

  final List<_SegRuleCondition> _entryConditions = [
    _SegRuleCondition(layer: 2, side: 'buy', type: '1'),
    _SegRuleCondition(layer: 3, side: 'buy', type: '3a'),
  ];
  final List<_SegRuleCondition> _exitConditions = [
    _SegRuleCondition(layer: 2, side: 'sell', type: '1'),
  ];

  bool _running = false;
  bool _segVisualMode = false;
  bool _useExitConditions = true;
  bool _useHoldDays = true;
  String _segLevel = 'MIN5';
  String _status = '粘贴 chan.py analysis JSON，或点击“使用当前复盘数据”。';
  Map<String, dynamic>? _lastResult;
  ResearchBackendClient? _backendClient;

  @override
  void dispose() {
    _backendUrlController.dispose();
    _backendClient?.close();
    _jsonController.dispose();
    _resultScrollController.dispose();
    _recordScrollController.dispose();
    _segSymbolController.dispose();
    _segMarketController.dispose();
    _segStartController.dispose();
    _segEndController.dispose();
    _holdDaysController.dispose();
    super.dispose();
  }

  void _useLatestReplayAnalysis() {
    final latest = ReplayAnalysisStore.latestAnalysis.value;
    if (latest == null) {
      setState(() => _status = '暂无当前复盘数据：请先在复盘页成功加载一次数据。');
      return;
    }
    _jsonController.text = latest.toPrettyPayloadJson();
    setState(() {
      _segVisualMode = false;
      _status =
          '已载入当前复盘数据：${latest.displaySymbol} ${latest.period}，保存时间 ${_timeText(latest.savedAt)}。';
    });
  }

  void _useSegCompositeTemplate() {
    setState(() {
      _segVisualMode = true;
      _status = '已载入 segN 组合模板：条件之间为 AND；信号按 step 当时状态计算。';
    });
  }

  Map<String, dynamic> _segCompositePayload() {
    final allLayers = <int>{
      for (final condition in _entryConditions) condition.layer,
      for (final condition in _exitConditions) condition.layer,
    };
    final maxLayer = allLayers.isEmpty
        ? 2
        : allLayers.reduce((left, right) => left > right ? left : right);
    Map<String, dynamic> ruleOf(List<_SegRuleCondition> conditions) => {
          'conditions': [
            for (final condition in conditions) condition.toJson()
          ],
          'dedupe': true,
        };
    return {
      'symbol': _segSymbolController.text.trim(),
      'market': _segMarketController.text.trim().toUpperCase(),
      'levels': [_segLevel],
      'level': _segLevel,
      'adjust': 'QFQ',
      'start': _segStartController.text.trim(),
      'end': _segEndController.text.trim(),
      'count': 50000,
      'config': {
        'bi_algo': 'fx',
        'seg_algo': 'chan',
        'zs_algo': 'normal',
        'recursive_seg_max_level': maxLayer,
      },
      'entry_rule': ruleOf(_entryConditions),
      if (_useExitConditions) 'exit_rule': ruleOf(_exitConditions),
      'options': {
        if (_useHoldDays)
          'max_hold_days': int.tryParse(_holdDaysController.text.trim()) ?? 10,
        'fee_bps': 3,
        'slippage_bps': 2,
      },
    };
  }

  Future<void> _call(String endpoint,
      {Map<String, dynamic>? overridePayload}) async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = '请求 $endpoint ...';
    });
    try {
      final payload = overridePayload ?? _parsePayload();
      final baseUrl = _backendUrlController.text.trim();
      final client = _backendClient;
      if (client == null || client.baseUrl != baseUrl) {
        client?.close();
        _backendClient = ResearchBackendClient(baseUrl: baseUrl);
      }
      final result = await _backendClient!.post(endpoint, payload);
      if (endpoint.endsWith('/pipeline') && result['ok'] != false) {
        ReplayAnalysisStore.addBacktestRecord(BacktestRecord.fromPipeline(
          result: result,
          latestAnalysis: ReplayAnalysisStore.latestAnalysis.value,
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

  void _locateResult(Map<String, dynamic> row, {String label = '回测结果'}) {
    final raw = row['raw_index'] ??
        row['entry_signal_raw_index'] ??
        row['entry_raw_index'] ??
        row['exit_raw_index'];
    final rawIndex = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (rawIndex == null) return;
    final timeText =
        '${row['time'] ?? row['entry_signal_time'] ?? row['entry_time'] ?? ''}';
    ReplayAnalysisStore.requestKlineLocation(
      symbol: _segSymbolController.text.trim(),
      market: _segMarketController.text.trim().toUpperCase(),
      level: _segLevel,
      rawIndex: rawIndex,
      time: DateTime.tryParse(timeText.replaceFirst(' ', 'T')),
      startDate: DateTime.tryParse(_segStartController.text.trim()),
      endDate: DateTime.tryParse(_segEndController.text.trim()),
      label: label,
    );
    widget.onOpenRoute?.call(1);
  }

  Map<String, dynamic> _parsePayload() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) return {'analysis': {}};
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('请输入 JSON 对象，不能是数组或纯文本');
    return Map<String, dynamic>.from(decoded);
  }

  String _summaryOf(String endpoint, Map<String, dynamic> result) {
    if (result['ok'] == false)
      return '接口返回失败：${result['error'] ?? 'unknown error'}';
    if (endpoint.endsWith('/pipeline')) {
      final backtest = result['backtest'];
      final summary = backtest is Map ? backtest['summary'] : null;
      if (summary is Map) {
        return 'Pipeline 完成并已生成记录：特征 ${_rowsFrom(result['features'], nestedKey: 'features').length}，评分 ${_rowsFrom(result['scores'], nestedKey: 'scores').length}，交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return 'Pipeline 完成并已生成记录。';
    }
    if (endpoint.endsWith('/features')) {
      return 'BSP 特征提取完成：${_rowsFrom(result['features'], nestedKey: 'features').length} 行。';
    }
    if (endpoint.endsWith('/score')) {
      return 'ML 打分完成：${_rowsFrom(result['scores'], nestedKey: 'scores').length} 行。';
    }
    if (endpoint.endsWith('/seg-composite/backtest')) {
      final summary = result['summary'];
      final meta = result['meta'];
      if (summary is Map) {
        final frames = meta is Map ? meta['evaluated_step_frames'] : null;
        return 'segN 组合回测完成：逐帧 ${frames ?? '--'}，入场信号 ${_rowsFrom(result['entry_events']).length}，交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return 'segN 组合回测完成。';
    }
    if (endpoint.endsWith('/backtest')) {
      final summary = result['summary'];
      if (summary is Map) {
        return '回测完成：交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return '回测完成。';
    }
    return '请求完成。';
  }

  String _pct(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '--';
    return '${(number * 100).toStringAsFixed(2)}%';
  }

  String _numText(Object? value, {int fractionDigits = 4}) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '--';
    return number.toStringAsFixed(fractionDigits);
  }

  String _valueText(Object? value) {
    if (value == null) return '--';
    if (value is num) return _numText(value);
    if (value is bool) return value ? '是' : '否';
    final text = '$value';
    return text.length > 28 ? '${text.substring(0, 28)}…' : text;
  }

  String get _prettyResult {
    final result = _lastResult;
    if (result == null) return '暂无结果';
    return const JsonEncoder.withIndent('  ').convert(result);
  }

  List<Map<String, dynamic>> _rowsFrom(Object? value, {String? nestedKey}) {
    final source = value is Map && nestedKey != null ? value[nestedKey] : value;
    if (source is! List) return const [];
    return [
      for (final row in source)
        if (row is Map) Map<String, dynamic>.from(row)
    ];
  }

  Map<String, dynamic> _mapFrom(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _prettyResult));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('研究结果已复制')));
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
            TextField(
              controller: _backendUrlController,
              decoration: const InputDecoration(
                labelText: 'Python 后端地址',
                hintText: 'http://127.0.0.1:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ValueListenableBuilder<LatestAnalysisJson?>(
                  valueListenable: ReplayAnalysisStore.latestAnalysis,
                  builder: (context, latest, _) {
                    return OutlinedButton.icon(
                      onPressed: latest == null || _running
                          ? null
                          : _useLatestReplayAnalysis,
                      icon: const Icon(Icons.input, size: 18),
                      label: Text(latest == null
                          ? '暂无复盘数据'
                          : '使用当前复盘数据：${latest.displaySymbol} ${latest.period}'),
                    );
                  },
                ),
                _ActionButton(
                  label: 'BSP 特征',
                  icon: Icons.table_chart,
                  running: _running,
                  onPressed: () => _call('/api/research/bsp/features'),
                ),
                _ActionButton(
                  label: 'ML 打分',
                  icon: Icons.psychology,
                  running: _running,
                  onPressed: () => _call('/api/research/ml/score'),
                ),
                _ActionButton(
                  label: '回测',
                  icon: Icons.show_chart,
                  running: _running,
                  onPressed: () => _call('/api/research/backtest'),
                ),
                OutlinedButton.icon(
                  onPressed: _running ? null : _useSegCompositeTemplate,
                  icon: const Icon(Icons.rule, size: 18),
                  label: const Text('载入 segN 模板'),
                ),
                _ActionButton(
                  label: 'segN 组合回测',
                  icon: Icons.layers,
                  running: _running,
                  onPressed: () => _call('/api/research/seg-composite/backtest',
                      overridePayload: _segCompositePayload()),
                ),
                _ActionButton(
                  label: '一键 Pipeline',
                  icon: Icons.account_tree,
                  running: _running,
                  onPressed: () => _call('/api/research/pipeline'),
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
                    child: _segVisualMode
                        ? _JsonPanel(
                            title: 'segN 多级联组合规则（同组条件为 AND）',
                            child: _SegCompositeRuleEditor(
                              symbolController: _segSymbolController,
                              marketController: _segMarketController,
                              startController: _segStartController,
                              endController: _segEndController,
                              holdDaysController: _holdDaysController,
                              level: _segLevel,
                              entryConditions: _entryConditions,
                              exitConditions: _exitConditions,
                              useExitConditions: _useExitConditions,
                              useHoldDays: _useHoldDays,
                              onLevelChanged: (value) =>
                                  setState(() => _segLevel = value),
                              onUseExitConditionsChanged: (value) =>
                                  setState(() => _useExitConditions = value),
                              onUseHoldDaysChanged: (value) =>
                                  setState(() => _useHoldDays = value),
                              onChanged: () => setState(() {}),
                              onShowJson: () =>
                                  setState(() => _segVisualMode = false),
                            ),
                          )
                        : _JsonPanel(
                            title: '输入 analysis JSON',
                            child: TextField(
                              controller: _jsonController,
                              expands: true,
                              maxLines: null,
                              minLines: null,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12),
                              decoration: const InputDecoration(
                                alignLabelWithHint: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(12),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _JsonPanel(
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
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: _JsonPanel(
                            title: 'Pipeline 回测记录',
                            child: _BacktestRecordList(
                              scrollController: _recordScrollController,
                              pctText: _pct,
                              valueText: _valueText,
                              timeText: _timeText,
                            ),
                          ),
                        ),
                      ],
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

class _SegRuleCondition {
  int layer;
  String side;
  String type;

  _SegRuleCondition(
      {required this.layer, required this.side, required this.type});

  Map<String, dynamic> toJson() => {
        'layer': layer,
        'side': side,
        'types': [type],
      };
}

class _SegCompositeRuleEditor extends StatelessWidget {
  static const _levels = ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY'];
  static const _types = ['1', '1p', '2', '2s', '3a', '3b'];
  static const _otherLayerValue = -1;

  final TextEditingController symbolController;
  final TextEditingController marketController;
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController holdDaysController;
  final String level;
  final List<_SegRuleCondition> entryConditions;
  final List<_SegRuleCondition> exitConditions;
  final bool useExitConditions;
  final bool useHoldDays;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<bool> onUseExitConditionsChanged;
  final ValueChanged<bool> onUseHoldDaysChanged;
  final VoidCallback onChanged;
  final VoidCallback onShowJson;

  const _SegCompositeRuleEditor({
    required this.symbolController,
    required this.marketController,
    required this.startController,
    required this.endController,
    required this.holdDaysController,
    required this.level,
    required this.entryConditions,
    required this.exitConditions,
    required this.useExitConditions,
    required this.useHoldDays,
    required this.onLevelChanged,
    required this.onUseExitConditionsChanged,
    required this.onUseHoldDaysChanged,
    required this.onChanged,
    required this.onShowJson,
  });

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
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: level,
                  decoration: const InputDecoration(labelText: 'K线周期'),
                  items: [
                    for (final value in _levels)
                      DropdownMenuItem(value: value, child: Text(value)),
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
          _ruleSection(
            title: '入场组合',
            subtitle: '每行依次选择 N段 → 买/卖 → 买卖点类型；所有行同时满足才入场。',
            rows: entryConditions,
            allowEmpty: false,
          ),
          const Divider(height: 26),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: useExitConditions,
            onChanged: onUseExitConditionsChanged,
            title: const Text('启用买卖点组合出场'),
          ),
          if (useExitConditions)
            _ruleSection(
              title: '出场组合',
              subtitle: '入场后按 step 当时状态判断；与 N 天退出取先发生者。',
              rows: exitConditions,
              allowEmpty: false,
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: useHoldDays,
            onChanged: onUseHoldDaysChanged,
            title: const Text('启用入场后 N 天退出'),
          ),
          if (useHoldDays) _field(holdDaysController, '持有天数', 130),
          const SizedBox(height: 12),
          const Text(
            '数据口径：仅使用 CBSPointList 真实买卖点；候选端点不参与。信号在首次识别 K 线冻结，下一根 K 线成交。',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onShowJson,
            icon: const Icon(Icons.code),
            label: const Text('切换到通用 JSON 工具'),
          ),
        ],
      ),
    );
  }

  Widget _ruleSection({
    required String title,
    required String subtitle,
    required List<_SegRuleCondition> rows,
    required bool allowEmpty,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _conditionRow(rows, index, allowEmpty: allowEmpty),
          ),
        OutlinedButton.icon(
          onPressed: () {
            rows.add(_SegRuleCondition(
              layer:
                  rows.isEmpty ? 2 : (rows.last.layer + 1).clamp(2, 6).toInt(),
              side: title.contains('入场') ? 'buy' : 'sell',
              type: '1',
            ));
            onChanged();
          },
          icon: const Icon(Icons.add, size: 17),
          label: const Text('增加 AND 条件'),
        ),
      ],
    );
  }

  Widget _conditionRow(List<_SegRuleCondition> rows, int index,
      {required bool allowEmpty}) {
    final row = rows[index];
    return Row(
      children: [
        SizedBox(
          width: row.layer > 6 ? 190 : 105,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue:
                      row.layer >= 2 && row.layer <= 6 ? row.layer : _otherLayerValue,
                  decoration: const InputDecoration(labelText: '结构层'),
                  items: [
                    for (var layer = 2; layer <= 6; layer++)
                      DropdownMenuItem(value: layer, child: Text('$layer段')),
                    const DropdownMenuItem(value: _otherLayerValue, child: Text('other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      row.layer = value == _otherLayerValue
                          ? (row.layer > 6 ? row.layer : 7)
                          : value;
                      onChanged();
                    }
                  },
                ),
              ),
              if (row.layer > 6) const SizedBox(width: 8),
              if (row.layer > 6)
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    key: ValueKey('seg-layer-${row.hashCode}-${row.layer}'),
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
                  ),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Icon(Icons.chevron_right, color: Colors.white38),
        ),
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<String>(
            initialValue: row.side,
            decoration: const InputDecoration(labelText: '方向'),
            items: const [
              DropdownMenuItem(value: 'buy', child: Text('买点')),
              DropdownMenuItem(value: 'sell', child: Text('卖点')),
            ],
            onChanged: (value) {
              if (value != null) {
                row.side = value;
                onChanged();
              }
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Icon(Icons.chevron_right, color: Colors.white38),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: row.type,
            decoration: const InputDecoration(labelText: '类型'),
            items: [
              for (final type in _types)
                DropdownMenuItem(
                  value: type,
                  child: Text('${row.side == 'buy' ? 'B' : 'S'}$type'),
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
          onPressed: rows.length == 1 && !allowEmpty
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

  static Widget _field(
      TextEditingController controller, String label, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _BacktestCharts extends StatelessWidget {
  final List<Map<String, dynamic>> equityCurve;
  final List<Map<String, dynamic>> trades;

  const _BacktestCharts({required this.equityCurve, required this.trades});

  @override
  Widget build(BuildContext context) {
    final equity = [
      for (final row in equityCurve)
        if (row['equity'] is num) (row['equity'] as num).toDouble(),
    ];
    final drawdown = [
      for (final row in equityCurve)
        if (row['drawdown'] is num) (row['drawdown'] as num).toDouble(),
    ];
    final returns = [
      for (final row in trades)
        if (row['net_return'] is num) (row['net_return'] as num).toDouble(),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MiniSeriesChart(
            title: '权益曲线',
            values: equity,
            color: const Color(0xFF4ADE80),
          ),
          _MiniSeriesChart(
            title: '回撤曲线',
            values: drawdown,
            color: const Color(0xFFF87171),
            baseline: 0,
          ),
          _MiniSeriesChart(
            title: '单笔收益',
            values: returns,
            color: const Color(0xFF60A5FA),
            baseline: 0,
            bars: true,
          ),
        ],
      ),
    );
  }
}

class _MiniSeriesChart extends StatelessWidget {
  final String title;
  final List<double> values;
  final Color color;
  final double? baseline;
  final bool bars;

  const _MiniSeriesChart({
    required this.title,
    required this.values,
    required this.color,
    this.baseline,
    this.bars = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 150,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Expanded(
            child: values.isEmpty
                ? const Center(
                    child: Text('无数据',
                        style: TextStyle(color: Colors.white38, fontSize: 11)))
                : CustomPaint(
                    painter: _SeriesPainter(
                      values: values,
                      color: color,
                      baseline: baseline,
                      bars: bars,
                    ),
                    size: Size.infinite,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SeriesPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double? baseline;
  final bool bars;

  const _SeriesPainter({
    required this.values,
    required this.color,
    required this.baseline,
    required this.bars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);
    if (baseline != null) {
      minValue = minValue < baseline! ? minValue : baseline!;
      maxValue = maxValue > baseline! ? maxValue : baseline!;
    }
    if ((maxValue - minValue).abs() < 1e-12) maxValue = minValue + 1;
    double yOf(double value) =>
        size.height - (value - minValue) / (maxValue - minValue) * size.height;
    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    if (baseline != null) {
      final y = yOf(baseline!);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final step =
        values.length <= 1 ? size.width : size.width / (values.length - 1);
    if (bars) {
      final zeroY = yOf(baseline ?? 0);
      final barPaint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      for (var index = 0; index < values.length; index++) {
        final x = values.length == 1 ? size.width / 2 : index * step;
        canvas.drawLine(Offset(x, zeroY), Offset(x, yOf(values[index])),
            barPaint..strokeWidth = (step * 0.55).clamp(2, 10));
      }
      return;
    }
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final point = Offset(index * step, yOf(values[index]));
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SeriesPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.baseline != baseline ||
      oldDelegate.bars != bars;
}

class _BacktestRecordList extends StatelessWidget {
  final ScrollController scrollController;
  final String Function(Object? value) pctText;
  final String Function(Object? value) valueText;
  final String Function(DateTime value) timeText;

  const _BacktestRecordList({
    required this.scrollController,
    required this.pctText,
    required this.valueText,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BacktestRecord>>(
      valueListenable: ReplayAnalysisStore.backtestRecords,
      builder: (context, records, _) {
        if (records.isEmpty) {
          return const Center(
            child: Text('暂无 Pipeline 回测记录',
                style: TextStyle(color: Colors.white54)),
          );
        }
        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 34,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columnSpacing: 18,
                columns: const [
                  DataColumn(
                      label: Text('时间',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))),
                  DataColumn(
                      label: Text('标的',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))),
                  DataColumn(
                      label: Text('周期',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))),
                  DataColumn(
                      label: Text('交易数',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))),
                  DataColumn(
                      label: Text('胜率',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))),
                  DataColumn(
                      label: Text('总收益',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))),
                  DataColumn(
                      label: Text('最终权益',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12))),
                ],
                rows: [
                  for (final record in records)
                    DataRow(cells: [
                      DataCell(Text(timeText(record.createdAt),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12))),
                      DataCell(Text(record.symbol,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12))),
                      DataCell(Text(record.period,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12))),
                      DataCell(Text('${record.tradeCount}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12))),
                      DataCell(Text(pctText(record.winRate),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12))),
                      DataCell(Text(pctText(record.totalReturn),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12))),
                      DataCell(Text(valueText(record.finalEquity),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12))),
                    ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResearchResultView extends StatelessWidget {
  final Map<String, dynamic>? result;
  final String rawJson;
  final ScrollController scrollController;
  final String Function(Object? value) valueText;
  final String Function(Object? value) pctText;
  final List<Map<String, dynamic>> Function(Object? value, {String? nestedKey})
      rowsFrom;
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
      return const Center(
        child: Text('暂无结果', style: TextStyle(color: Colors.white54)),
      );
    }
    final features = rowsFrom(data['features'], nestedKey: 'features');
    final scores = rowsFrom(data['scores'], nestedKey: 'scores');
    final backtest = data['backtest'] is Map ? mapFrom(data['backtest']) : data;
    final trades = rowsFrom(backtest['trades'], nestedKey: 'trades');
    final entryEvents = rowsFrom(backtest['entry_events']);
    final exitEvents = rowsFrom(backtest['exit_events']);
    final equityCurve = rowsFrom(backtest['equity_curve']);
    final summary = mapFrom(backtest['summary']);

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
                _SummaryCardData(
                    'Features', '${features.length}', Icons.table_chart),
                _SummaryCardData(
                    'Scores', '${scores.length}', Icons.psychology),
                _SummaryCardData(
                    'Trades',
                    '${summary['trade_count'] ?? trades.length}',
                    Icons.show_chart),
                _SummaryCardData(
                    'Win rate', pctText(summary['win_rate']), Icons.percent),
                _SummaryCardData('Total return',
                    pctText(summary['total_return']), Icons.trending_up),
                _SummaryCardData(
                    'Final equity',
                    valueText(summary['final_equity']),
                    Icons.account_balance_wallet),
                _SummaryCardData('Payoff', valueText(summary['payoff_ratio']),
                    Icons.balance),
                _SummaryCardData('Profit factor',
                    valueText(summary['profit_factor']), Icons.functions),
                _SummaryCardData('Max drawdown',
                    pctText(summary['max_drawdown']), Icons.trending_down),
              ]),
              const SizedBox(height: 12),
              if (equityCurve.length > 1 || trades.isNotEmpty)
                _BacktestCharts(
                  equityCurve: equityCurve,
                  trades: trades,
                ),
              if (entryEvents.isNotEmpty)
                _PreviewTable(
                  title: '入场信号（点击定位K线）',
                  rows: entryEvents,
                  columns: const [
                    'time',
                    'raw_index',
                    'signature',
                    'level',
                  ],
                  valueText: valueText,
                  onRowTap: (row) => onLocate(row, label: '入场信号'),
                ),
              if (exitEvents.isNotEmpty)
                _PreviewTable(
                  title: '出场信号（点击定位K线）',
                  rows: exitEvents,
                  columns: const [
                    'time',
                    'raw_index',
                    'signature',
                    'level',
                  ],
                  valueText: valueText,
                  onRowTap: (row) => onLocate(row, label: '出场信号'),
                ),
              if (features.isNotEmpty)
                _PreviewTable(
                  title: 'BSP 特征预览',
                  rows: features,
                  columns: const [
                    'raw_index',
                    'time',
                    'level',
                    'type',
                    'is_buy',
                    'price',
                    'close'
                  ],
                  valueText: valueText,
                ),
              if (scores.isNotEmpty)
                _PreviewTable(
                  title: 'ML Score 预览',
                  rows: scores,
                  columns: const [
                    'raw_index',
                    'time',
                    'level',
                    'type',
                    'is_buy',
                    'ml_score',
                    'ml_signal'
                  ],
                  valueText: valueText,
                ),
              if (trades.isNotEmpty)
                _PreviewTable(
                  title: '回测交易预览',
                  rows: trades,
                  columns: const [
                    'entry_time',
                    'exit_time',
                    'net_return',
                    'exit_reason',
                    'hold_bars',
                    'ml_score'
                  ],
                  valueText: valueText,
                  onRowTap: (row) => onLocate(row, label: '交易入场'),
                ),
              if (features.isEmpty &&
                  scores.isEmpty &&
                  trades.isEmpty &&
                  entryEvents.isEmpty &&
                  exitEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('接口已返回 JSON，但没有可表格化的 features / scores / trades。',
                      style: TextStyle(color: Colors.white54)),
                ),
            ],
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              collapsedIconColor: Colors.white54,
              iconColor: Colors.white70,
              title: const Text('原始 JSON',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    rawJson,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white70),
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
        for (final card in cards) _SummaryCard(card: card),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData card;

  const _SummaryCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(card.label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 3),
                Text(card.value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title（显示 ${previewRows.length}/${rows.length}）',
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration:
                  BoxDecoration(border: Border.all(color: Colors.white10)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 40,
                  columnSpacing: 18,
                  columns: [
                    for (final col in columns)
                      DataColumn(
                          label: Text(col,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12))),
                  ],
                  rows: [
                    for (final row in previewRows)
                      DataRow(
                          onSelectChanged:
                              onRowTap == null ? null : (_) => onRowTap!(row),
                          cells: [
                            for (final col in columns)
                              DataCell(Text(valueText(row[col]),
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12))),
                          ]),
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
        border:
            Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.32)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool running;
  final VoidCallback onPressed;

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
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _JsonPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _JsonPanel({required this.title, required this.child});

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
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

String _timeText(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
