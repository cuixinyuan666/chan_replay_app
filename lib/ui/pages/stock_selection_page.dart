import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/stock_selection_backend_client.dart';

class StockSelectionPage extends StatefulWidget {
  const StockSelectionPage({super.key});

  @override
  State<StockSelectionPage> createState() => _StockSelectionPageState();
}

class _StockSelectionPageState extends State<StockSelectionPage> {
  final TextEditingController _backendController = TextEditingController(text: StockSelectionBackendClient.defaultBaseUrl);
  final TextEditingController _symbolController = TextEditingController(text: '000001');
  final TextEditingController _symbolsController = TextEditingController(text: '000001,000002,600000');
  final TextEditingController _levelsController = TextEditingController(text: 'DAILY,MIN30,MIN5');
  final TextEditingController _startController = TextEditingController(text: '2022-01-01');
  final TextEditingController _endController = TextEditingController(text: '2025-12-31');
  final TextEditingController _countController = TextEditingController(text: '900');
  final TextEditingController _limitController = TextEditingController(text: '300');
  final TextEditingController _horizonController = TextEditingController(text: '5');

  final List<_XgCondition> _conditions = <_XgCondition>[
    _XgCondition(id: 'c1', level: 'DAILY', domain: 'bi', side: 'buy', type: '1', recentBars: 3, recentDays: 3),
  ];

  bool _running = false;
  String _status = '就绪：构造条件后可运行单标的分析、回测或全市场扫描。';
  Map<String, dynamic>? _result;
  String _selectedJump = '';

  @override
  void dispose() {
    _backendController.dispose();
    _symbolController.dispose();
    _symbolsController.dispose();
    _levelsController.dispose();
    _startController.dispose();
    _endController.dispose();
    _countController.dispose();
    _limitController.dispose();
    _horizonController.dispose();
    super.dispose();
  }

  List<String> get _levels => _levelsController.text
      .replaceAll('，', ',')
      .split(',')
      .map((item) => item.trim().toUpperCase())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Map<String, dynamic> _conditionGroup() => <String, dynamic>{
        'operator': 'all',
        'conditions': [for (final condition in _conditions) condition.toJson()],
      };

  Map<String, dynamic> _basePayload() => <String, dynamic>{
        'symbol': _symbolController.text.trim(),
        'levels': _levels,
        'start': _startController.text.trim(),
        'end': _endController.text.trim(),
        'count': int.tryParse(_countController.text.trim()) ?? 900,
        'adjust': 'QFQ',
        'condition_group': _conditionGroup(),
      };

  Future<void> _run(String mode) async {
    if (_running) return;
    final client = StockSelectionBackendClient(baseUrl: _backendController.text);
    setState(() {
      _running = true;
      _status = '正在运行 $mode ...';
      _selectedJump = '';
    });
    try {
      Map<String, dynamic> result;
      if (mode == 'single') {
        result = await client.analyzeSingle(_basePayload());
      } else if (mode == 'backtest') {
        result = await client.backtest(<String, dynamic>{
          ..._basePayload(),
          'horizon': int.tryParse(_horizonController.text.trim()) ?? 5,
          'rules': [
            <String, dynamic>{
              'name': 'xg_rule_1',
              'entry': _conditionGroup(),
              'exit': {'horizon': int.tryParse(_horizonController.text.trim()) ?? 5},
            },
          ],
        });
      } else {
        result = await client.scan(<String, dynamic>{
          ..._basePayload(),
          'symbols': _symbolsController.text.trim().isEmpty ? null : _symbolsController.text.trim(),
          'limit': int.tryParse(_limitController.text.trim()) ?? 300,
        });
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = _statusText(mode, result);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = '运行失败：$e');
        _showMessage(_status);
      }
    } finally {
      client.close();
      if (mounted) setState(() => _running = false);
    }
  }

  String _statusText(String mode, Map<String, dynamic> result) {
    if (mode == 'scan') return '扫描完成：发现 ${result['found_count'] ?? 0} / 总数 ${result['total'] ?? 0}，失败 ${result['fail_count'] ?? 0}。';
    if (mode == 'backtest') {
      final ranking = result['ranking'];
      final count = ranking is List ? ranking.length : 0;
      return '回测完成：规则 $count 个，按 model_score 降序显示。';
    }
    final match = result['match'];
    final ok = match is Map && match['ok'] == true;
    return ok ? '单标的命中条件。' : '单标的未命中条件。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 10, 10, 10),
          child: Row(
            children: [
              SizedBox(width: 560, child: _leftPanel()),
              const SizedBox(width: 10),
              Expanded(child: _rightPanel()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leftPanel() => Column(
        children: [
          _panel(
            title: '选股条件组合器',
            expandChild: false,
            child: Column(
              children: [
                _input(_backendController, 'Python 后端地址'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _input(_symbolController, '单标的代码')),
                  const SizedBox(width: 8),
                  Expanded(child: _input(_levelsController, '周期列表')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _input(_startController, 'start')),
                  const SizedBox(width: 8),
                  Expanded(child: _input(_endController, 'end')),
                  const SizedBox(width: 8),
                  SizedBox(width: 88, child: _input(_countController, 'count')),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _conditionsPanel()),
          const SizedBox(height: 8),
          _panel(
            title: '运行',
            expandChild: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _input(_horizonController, '回测持有K数')),
                  const SizedBox(width: 8),
                  Expanded(child: _input(_limitController, '扫描上限')),
                ]),
                const SizedBox(height: 8),
                _input(_symbolsController, '扫描代码池；留空走后端股票池'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(onPressed: _running ? null : () => _run('single'), icon: const Icon(Icons.analytics, size: 16), label: const Text('单标的分析')),
                    FilledButton.icon(onPressed: _running ? null : () => _run('backtest'), icon: const Icon(Icons.rule, size: 16), label: const Text('规则回测')),
                    FilledButton.icon(onPressed: _running ? null : () => _run('scan'), icon: const Icon(Icons.radar, size: 16), label: const Text('全市场/代码池扫描')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      );

  Widget _conditionsPanel() => _panel(
        title: '通用条件：周期 → 买卖点域 → 买/卖 → 类型',
        trailing: TextButton.icon(
          onPressed: _running
              ? null
              : () => setState(() => _conditions.add(_XgCondition(id: 'c${_conditions.length + 1}', level: 'DAILY', domain: 'bi', side: 'buy', type: '1', recentBars: 3, recentDays: 3))),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加'),
        ),
        child: ListView.separated(
          itemCount: _conditions.length,
          separatorBuilder: (_, __) => const Divider(height: 10, color: Colors.white12),
          itemBuilder: (context, index) => _conditionRow(index),
        ),
      );

  Widget _conditionRow(int index) {
    final condition = _conditions[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _dropdown('周期', condition.level, _levelOptions(), (v) => setState(() => condition.level = v))),
          const SizedBox(width: 6),
          Expanded(child: _dropdown('域', condition.domain, const ['bi', 'seg', 'seg2', 'seg3', 'seg4', 'seg5', 'seg6', 'seg7', 'seg8', 'seg9'], (v) => setState(() => condition.domain = v))),
          const SizedBox(width: 6),
          Expanded(child: _dropdown('方向', condition.side, const ['buy', 'sell', 'any'], (v) => setState(() => condition.side = v))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _dropdown('类型', condition.type, const ['1', '1p', '2', '2s', '3a', '3b', 'B1', 'B2', 'B3a', 'S1', 'S2', 'S3a'], (v) => setState(() => condition.type = v))),
          const SizedBox(width: 6),
          SizedBox(width: 110, child: _smallInt('近K', condition.recentBars, (v) => condition.recentBars = v)),
          const SizedBox(width: 6),
          SizedBox(width: 110, child: _smallInt('近天', condition.recentDays, (v) => condition.recentDays = v)),
          IconButton(
            tooltip: '删除条件',
            onPressed: _conditions.length <= 1 || _running ? null : () => setState(() => _conditions.removeAt(index)),
            icon: const Icon(Icons.delete_outline, color: Colors.white60, size: 18),
          ),
        ]),
      ],
    );
  }

  List<String> _levelOptions() {
    final values = <String>{..._levels, 'DAILY', 'WEEKLY', 'MONTHLY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1'};
    return values.toList(growable: false);
  }

  Widget _rightPanel() => Column(
        children: [
          _panel(
            title: '结果摘要 / 跳转证据',
            expandChild: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_running) const LinearProgressIndicator(),
              if (_selectedJump.isNotEmpty) SelectableText(_selectedJump, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12)),
              if (_selectedJump.isEmpty) const Text('点击扫描结果或交易记录后，这里显示可用于跳转单股多级别的 symbol/market/raw_index 证据。', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(child: _resultPanel()),
        ],
      );

  Widget _resultPanel() {
    final result = _result;
    if (result == null) {
      return _panel(title: '运行结果', child: const Center(child: Text('暂无结果', style: TextStyle(color: Colors.white54))));
    }
    final scanRows = result['results'];
    final ranking = result['ranking'];
    final rules = result['rules'];
    if (scanRows is List) return _panel(title: '扫描结果', child: _scanTable(scanRows));
    if (ranking is List) return _panel(title: '回测排名 / 交易记录', child: _backtestView(ranking, rules));
    return _panel(title: '单标的分析 JSON', child: _jsonView(result));
  }

  Widget _scanTable(List<dynamic> rows) => rows.isEmpty
      ? const Center(child: Text('没有命中条件的股票。', style: TextStyle(color: Colors.white54)))
      : SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 34,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 42,
              columns: const [
                DataColumn(label: Text('代码')),
                DataColumn(label: Text('名称')),
                DataColumn(label: Text('级别')),
                DataColumn(label: Text('域')),
                DataColumn(label: Text('类型')),
                DataColumn(label: Text('raw')),
              ],
              rows: [
                for (final item in rows.whereType<Map>().take(300))
                  DataRow(
                    onSelectChanged: (_) => _setJump(item['jump'] ?? item),
                    cells: [
                      DataCell(Text('${item['code'] ?? ''}')),
                      DataCell(Text('${item['name'] ?? ''}')),
                      DataCell(Text('${item['latest_level'] ?? ''}')),
                      DataCell(Text('${item['latest_domain'] ?? ''}')),
                      DataCell(Text('${item['latest_type'] ?? ''}')),
                      DataCell(Text('${item['latest_raw_index'] ?? ''}')),
                    ],
                  ),
              ],
            ),
          ),
        );

  Widget _backtestView(List<dynamic> ranking, dynamic rules) {
    final tradeRows = <Map>[];
    if (rules is List) {
      for (final rule in rules.whereType<Map>()) {
        final trades = rule['trades'];
        if (trades is List) tradeRows.addAll(trades.whereType<Map>());
      }
    }
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 34,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 42,
            columns: const [
              DataColumn(label: Text('规则')),
              DataColumn(label: Text('交易')),
              DataColumn(label: Text('胜率')),
              DataColumn(label: Text('盈亏比')),
              DataColumn(label: Text('分数')),
            ],
            rows: [
              for (final item in ranking.whereType<Map>())
                DataRow(cells: [
                  DataCell(Text('${item['rule_name'] ?? ''}')),
                  DataCell(Text('${item['trade_count'] ?? 0}')),
                  DataCell(Text(_fmtPct(item['win_rate']))),
                  DataCell(Text(_fmtNum(item['profit_loss_ratio']))),
                  DataCell(Text(_fmtNum(item['model_score']))),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('交易记录', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowHeight: 34,
            dataRowMinHeight: 34,
            dataRowMaxHeight: 42,
            columns: const [
              DataColumn(label: Text('规则')),
              DataColumn(label: Text('入场raw')),
              DataColumn(label: Text('出场raw')),
              DataColumn(label: Text('收益%')),
              DataColumn(label: Text('原因')),
            ],
            rows: [
              for (final item in tradeRows.take(300))
                DataRow(
                  onSelectChanged: (_) => _setJump(item['jump'] ?? item),
                  cells: [
                    DataCell(Text('${item['rule_name'] ?? ''}')),
                    DataCell(Text('${item['entry_raw_index'] ?? ''}')),
                    DataCell(Text('${item['exit_raw_index'] ?? ''}')),
                    DataCell(Text(_fmtNum(item['return_pct']))),
                    DataCell(Text('${item['exit_reason'] ?? ''}')),
                  ],
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _jsonView(Map<String, dynamic> value) => SingleChildScrollView(
        child: SelectableText(const JsonEncoder.withIndent('  ').convert(value), style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35)),
      );

  void _setJump(Object? value) {
    setState(() => _selectedJump = const JsonEncoder.withIndent('  ').convert(value ?? <String, dynamic>{}));
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
        enabled: !_running,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      );

  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String> onChanged) {
    final normalized = values.contains(value) ? value : values.first;
    return DropdownButtonFormField<String>(
      value: normalized,
      isExpanded: true,
      items: [for (final item in values) DropdownMenuItem<String>(value: item, child: Text(item))],
      onChanged: _running ? null : (v) => onChanged(v ?? normalized),
      decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  Widget _smallInt(String label, int value, ValueChanged<int> onChanged) => TextFormField(
        initialValue: '$value',
        enabled: !_running,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        keyboardType: TextInputType.number,
        onChanged: (v) => onChanged(int.tryParse(v) ?? value),
        decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
      );

  String _fmtNum(Object? value) {
    final number = value is num ? value : num.tryParse('$value');
    return number == null ? '-' : number.toStringAsFixed(2);
  }

  String _fmtPct(Object? value) {
    final number = value is num ? value : num.tryParse('$value');
    return number == null ? '-' : '${(number * 100).toStringAsFixed(1)}%';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }
}

class _XgCondition {
  final String id;
  String level;
  String domain;
  String side;
  String type;
  int recentBars;
  int recentDays;

  _XgCondition({required this.id, required this.level, required this.domain, required this.side, required this.type, required this.recentBars, required this.recentDays});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'level': level,
        'domain': domain,
        'side': side,
        'types': [type],
        'recent_bars': recentBars,
        'recent_days': recentDays,
      };
}
