import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/stock_selection_backend_client.dart';

class StockSelectionPage extends StatefulWidget {
  const StockSelectionPage({super.key});

  @override
  State<StockSelectionPage> createState() => _StockSelectionPageState();
}

class _StockSelectionPageState extends State<StockSelectionPage> {
  final TextEditingController _backend = TextEditingController(text: StockSelectionBackendClient.defaultBaseUrl);
  final TextEditingController _symbol = TextEditingController(text: '000001');
  final TextEditingController _symbols = TextEditingController(text: '000001,000002,600000');
  final TextEditingController _levels = TextEditingController(text: 'DAILY,MIN30,MIN5');
  final TextEditingController _start = TextEditingController(text: '2022-01-01');
  final TextEditingController _end = TextEditingController(text: '2025-12-31');
  final TextEditingController _count = TextEditingController(text: '900');
  final TextEditingController _limit = TextEditingController(text: '300');
  final TextEditingController _horizon = TextEditingController(text: '5');

  final List<_Condition> _conditions = <_Condition>[
    _Condition(id: 'c1', level: 'DAILY', domain: 'bi', side: 'buy', type: '1', recentBars: 3, recentDays: 3),
  ];

  bool _running = false;
  String _status = '就绪：支持单标的分析、规则回测、条件扫描。';
  String _jump = '';
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [_backend, _symbol, _symbols, _levels, _start, _end, _count, _limit, _horizon]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _levelList => _levels.text
      .replaceAll('，', ',')
      .split(',')
      .map((v) => v.trim().toUpperCase())
      .where((v) => v.isNotEmpty)
      .toList(growable: false);

  Map<String, dynamic> _group() => <String, dynamic>{
        'operator': 'all',
        'conditions': [for (final condition in _conditions) condition.toJson()],
      };

  Map<String, dynamic> _payload() => <String, dynamic>{
        'symbol': _symbol.text.trim(),
        'levels': _levelList,
        'start': _start.text.trim(),
        'end': _end.text.trim(),
        'count': int.tryParse(_count.text.trim()) ?? 900,
        'adjust': 'QFQ',
        'condition_group': _group(),
      };

  Future<void> _run(String mode) async {
    if (_running) return;
    final client = StockSelectionBackendClient(baseUrl: _backend.text);
    setState(() {
      _running = true;
      _status = '正在运行 $mode ...';
      _jump = '';
    });
    try {
      final base = _payload();
      final Map<String, dynamic> result;
      if (mode == 'single') {
        result = await client.analyzeSingle(base);
      } else if (mode == 'backtest') {
        result = await client.backtest(<String, dynamic>{
          ...base,
          'horizon': int.tryParse(_horizon.text.trim()) ?? 5,
          'rules': [
            {
              'name': 'xg_rule_1',
              'entry': _group(),
              'exit': {'horizon': int.tryParse(_horizon.text.trim()) ?? 5},
            },
          ],
        });
      } else {
        result = await client.scan(<String, dynamic>{
          ...base,
          'symbols': _symbols.text.trim().isEmpty ? null : _symbols.text.trim(),
          'limit': int.tryParse(_limit.text.trim()) ?? 300,
        });
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = _statusFor(mode, result);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = '运行失败：$e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_status)));
      }
    } finally {
      client.close();
      if (mounted) setState(() => _running = false);
    }
  }

  String _statusFor(String mode, Map<String, dynamic> result) {
    if (mode == 'scan') return '扫描完成：发现 ${result['found_count'] ?? 0} / ${result['total'] ?? 0}。';
    if (mode == 'backtest') return '回测完成：规则数 ${(result['ranking'] as List?)?.length ?? 0}。';
    final match = result['match'];
    return match is Map && match['ok'] == true ? '单标的命中条件。' : '单标的未命中条件。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(52, 10, 10, 10),
          child: Row(children: [
            SizedBox(width: 560, child: _left()),
            const SizedBox(width: 10),
            Expanded(child: _right()),
          ]),
        ),
      ),
    );
  }

  Widget _left() => Column(children: [
        _panel('基础参数', Column(children: [
          _input(_backend, 'Python 后端地址'),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _input(_symbol, '单标的代码')), const SizedBox(width: 8), Expanded(child: _input(_levels, '周期列表'))]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _input(_start, 'start')), const SizedBox(width: 8), Expanded(child: _input(_end, 'end')), const SizedBox(width: 8), SizedBox(width: 88, child: _input(_count, 'count'))]),
        ]), expand: false),
        const SizedBox(height: 8),
        Expanded(child: _conditionsPanel()),
        const SizedBox(height: 8),
        _panel('运行', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: _input(_horizon, '回测持有K数')), const SizedBox(width: 8), Expanded(child: _input(_limit, '扫描上限'))]),
          const SizedBox(height: 8),
          _input(_symbols, '扫描代码池；留空走后端股票池'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: _running ? null : () => _run('single'), icon: const Icon(Icons.analytics, size: 16), label: const Text('单标的分析')),
            FilledButton.icon(onPressed: _running ? null : () => _run('backtest'), icon: const Icon(Icons.rule, size: 16), label: const Text('规则回测')),
            FilledButton.icon(onPressed: _running ? null : () => _run('scan'), icon: const Icon(Icons.radar, size: 16), label: const Text('条件扫描')),
          ]),
          const SizedBox(height: 8),
          Text(_status, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]), expand: false),
      ]);

  Widget _conditionsPanel() => _panel(
        '通用条件组合器',
        ListView.separated(
          itemCount: _conditions.length,
          separatorBuilder: (_, __) => const Divider(height: 10, color: Colors.white12),
          itemBuilder: (context, index) => _conditionRow(index),
        ),
        trailing: TextButton.icon(
          onPressed: _running ? null : () => setState(() => _conditions.add(_Condition(id: 'c${_conditions.length + 1}', level: 'DAILY', domain: 'bi', side: 'buy', type: '1', recentBars: 3, recentDays: 3))),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加'),
        ),
      );

  Widget _conditionRow(int index) {
    final c = _conditions[index];
    return Column(children: [
      Row(children: [
        Expanded(child: _drop('周期', c.level, _levelOptions(), (v) => setState(() => c.level = v))),
        const SizedBox(width: 6),
        Expanded(child: _drop('域', c.domain, const ['bi', 'seg', 'seg2', 'seg3', 'seg4', 'seg5', 'seg6', 'seg7', 'seg8', 'seg9'], (v) => setState(() => c.domain = v))),
        const SizedBox(width: 6),
        Expanded(child: _drop('方向', c.side, const ['buy', 'sell', 'any'], (v) => setState(() => c.side = v))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _drop('类型', c.type, const ['1', '1p', '2', '2s', '3a', '3b', 'B1', 'B2', 'B3a', 'S1', 'S2', 'S3a'], (v) => setState(() => c.type = v))),
        const SizedBox(width: 6),
        SizedBox(width: 100, child: _intInput('近K', c.recentBars, (v) => c.recentBars = v)),
        const SizedBox(width: 6),
        SizedBox(width: 100, child: _intInput('近天', c.recentDays, (v) => c.recentDays = v)),
        IconButton(onPressed: _conditions.length <= 1 ? null : () => setState(() => _conditions.removeAt(index)), icon: const Icon(Icons.delete_outline, color: Colors.white60, size: 18)),
      ]),
    ]);
  }

  Widget _right() => Column(children: [
        _panel('跳转证据', SelectableText(_jump.isEmpty ? '点击扫描结果或交易记录后显示 symbol/market/raw_index。' : _jump, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12)), expand: false),
        const SizedBox(height: 8),
        if (_running) const LinearProgressIndicator(),
        Expanded(child: _resultPanel()),
      ]);

  Widget _resultPanel() {
    final result = _result;
    if (result == null) return _panel('运行结果', const Center(child: Text('暂无结果', style: TextStyle(color: Colors.white54))));
    if (result['results'] is List) return _panel('扫描结果', _scanTable(result['results'] as List));
    if (result['ranking'] is List) return _panel('回测结果', _backtestView(result));
    return _panel('单标的分析 JSON', _jsonView(result));
  }

  Widget _scanTable(List rows) => rows.isEmpty
      ? const Center(child: Text('没有命中条件的股票。', style: TextStyle(color: Colors.white54)))
      : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(showCheckboxColumn: false, columns: const [DataColumn(label: Text('代码')), DataColumn(label: Text('名称')), DataColumn(label: Text('级别')), DataColumn(label: Text('域')), DataColumn(label: Text('类型')), DataColumn(label: Text('raw'))], rows: [for (final item in rows.whereType<Map>().take(300)) DataRow(onSelectChanged: (_) => _setJump(item['jump'] ?? item), cells: [DataCell(Text('${item['code'] ?? ''}')), DataCell(Text('${item['name'] ?? ''}')), DataCell(Text('${item['latest_level'] ?? ''}')), DataCell(Text('${item['latest_domain'] ?? ''}')), DataCell(Text('${item['latest_type'] ?? ''}')), DataCell(Text('${item['latest_raw_index'] ?? ''}'))])])));

  Widget _backtestView(Map<String, dynamic> result) {
    final ranking = (result['ranking'] as List?) ?? const [];
    final trades = <Map>[];
    final rules = result['rules'];
    if (rules is List) {
      for (final rule in rules.whereType<Map>()) {
        final rows = rule['trades'];
        if (rows is List) trades.addAll(rows.whereType<Map>());
      }
    }
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('规则')), DataColumn(label: Text('交易')), DataColumn(label: Text('胜率')), DataColumn(label: Text('盈亏比')), DataColumn(label: Text('分数'))], rows: [for (final item in ranking.whereType<Map>()) DataRow(cells: [DataCell(Text('${item['rule_name'] ?? ''}')), DataCell(Text('${item['trade_count'] ?? 0}')), DataCell(Text(_fmtPct(item['win_rate'])),), DataCell(Text(_fmtNum(item['profit_loss_ratio']))), DataCell(Text(_fmtNum(item['model_score'])))])])),
      const SizedBox(height: 12),
      const Text('交易记录', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(showCheckboxColumn: false, columns: const [DataColumn(label: Text('规则')), DataColumn(label: Text('入场raw')), DataColumn(label: Text('出场raw')), DataColumn(label: Text('收益%')), DataColumn(label: Text('原因'))], rows: [for (final item in trades.take(300)) DataRow(onSelectChanged: (_) => _setJump(item['jump'] ?? item), cells: [DataCell(Text('${item['rule_name'] ?? ''}')), DataCell(Text('${item['entry_raw_index'] ?? ''}')), DataCell(Text('${item['exit_raw_index'] ?? ''}')), DataCell(Text(_fmtNum(item['return_pct']))), DataCell(Text('${item['exit_reason'] ?? ''}'))])]))),
    ]));
  }

  Widget _jsonView(Map<String, dynamic> value) => SingleChildScrollView(child: SelectableText(const JsonEncoder.withIndent('  ').convert(value), style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35)));

  void _setJump(Object? value) => setState(() => _jump = const JsonEncoder.withIndent('  ').convert(value ?? <String, dynamic>{}));

  List<String> _levelOptions() => <String>{..._levelList, 'DAILY', 'WEEKLY', 'MONTHLY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1'}.toList(growable: false);

  Widget _panel(String title, Widget child, {Widget? trailing, bool expand = true}) => Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF131722), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.08))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))), if (trailing != null) trailing]), const SizedBox(height: 8), if (expand) Expanded(child: child) else child]));

  Widget _input(TextEditingController controller, String label) => TextField(controller: controller, enabled: !_running, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))));

  Widget _drop(String label, String value, List<String> values, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, isExpanded: true, items: [for (final item in values) DropdownMenuItem<String>(value: item, child: Text(item))], onChanged: _running ? null : (v) => onChanged(v ?? value), decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))));

  Widget _intInput(String label, int value, ValueChanged<int> onChanged) => TextFormField(initialValue: '$value', enabled: !_running, style: const TextStyle(color: Colors.white, fontSize: 12), keyboardType: TextInputType.number, onChanged: (v) => onChanged(int.tryParse(v) ?? value), decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: const Color(0xFF1C2330), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))));

  String _fmtNum(Object? value) {
    final number = value is num ? value : double.tryParse('$value');
    return number == null ? '-' : number.toStringAsFixed(2);
  }

  String _fmtPct(Object? value) {
    final number = value is num ? value : double.tryParse('$value');
    return number == null ? '-' : '${(number * 100).toStringAsFixed(1)}%';
  }
}

class _Condition {
  final String id;
  String level;
  String domain;
  String side;
  String type;
  int recentBars;
  int recentDays;

  _Condition({required this.id, required this.level, required this.domain, required this.side, required this.type, required this.recentBars, required this.recentDays});

  Map<String, dynamic> toJson() => {'id': id, 'level': level, 'domain': domain, 'side': side, 'types': [type], 'recent_bars': recentBars, 'recent_days': recentDays};
}
