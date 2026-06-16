import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/services/replay_analysis_store.dart';

class CacheOptimizationPage extends StatefulWidget {
  const CacheOptimizationPage({super.key});

  static const Color bg = Color(0xFF0B0D10);
  static const Color panel = Color(0xFF131722);
  static const Color border = Color(0xFF2A2E39);
  static const Color blue = Color(0xFF2962FF);

  @override
  State<CacheOptimizationPage> createState() => _CacheOptimizationPageState();
}

class _CacheOptimizationPageState extends State<CacheOptimizationPage> {
  static const _availableLayers = <_LayerOption>[
    _LayerOption('bars', 'K线'),
    _LayerOption('merged_bars', '合并K'),
    _LayerOption('fx', '分型'),
    _LayerOption('bi', '笔'),
    _LayerOption('seg', '线段'),
    _LayerOption('zs', '中枢'),
    _LayerOption('bsp', '买卖点'),
    _LayerOption('indicators', '指标'),
  ];

  final _backendUrlController =
      TextEditingController(text: 'http://127.0.0.1:8000');
  final _symbolController = TextEditingController(text: '600340');
  final _marketController = TextEditingController(text: 'SH');
  final _levelsController = TextEditingController(text: 'DAILY,MIN30,MIN5');
  final _startController = TextEditingController(text: '2026-01-01');
  final _endController = TextEditingController(text: _todayMinusTwo());
  final _countController = TextEditingController(text: '900');
  final _scrollController = ScrollController();

  final Set<String> _selectedLayers = <String>{
    'bars',
    'merged_bars',
    'fx',
    'bi',
    'seg',
    'zs',
    'bsp',
  };

  bool _running = false;
  String _status = '选择图层后点击“请求 analyze_multi”，后端会按 chart_layers 裁剪返回 JSON。';
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _backendUrlController.dispose();
    _symbolController.dispose();
    _marketController.dispose();
    _levelsController.dispose();
    _startController.dispose();
    _endController.dispose();
    _countController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestAnalyzeMulti() async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = '请求 /api/chan/analyze_multi ...';
    });
    try {
      final payload = _buildPayload();
      final base =
          _backendUrlController.text.trim().replaceFirst(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/chan/analyze_multi');
      final response = await http
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 180));
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const FormatException('后端返回不是 JSON object');
      final result = Map<String, dynamic>.from(decoded);
      setState(() {
        _lastResult = result;
        _status = _summary(result);
      });
    } catch (e) {
      setState(() {
        _lastResult = <String, dynamic>{'ok': false, 'error': '$e'};
        _status = '请求失败：$e';
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    final levels = [
      for (final level
          in _levelsController.text.replaceAll('，', ',').split(','))
        if (level.trim().isNotEmpty) level.trim().toUpperCase(),
    ];
    final layers = [
      for (final option in _availableLayers)
        if (_selectedLayers.contains(option.key)) option.key,
    ];
    return <String, dynamic>{
      'mode': 'step',
      'symbol': _symbolController.text.trim(),
      'market': _marketController.text.trim().toUpperCase(),
      'lv_list': levels,
      'adjust': 'QFQ',
      'main_level': levels.isEmpty ? 'DAILY' : levels.first,
      'clock_level': levels.isEmpty ? 'DAILY' : levels.first,
      'count': int.tryParse(_countController.text.trim()) ?? 900,
      'start': _startController.text.trim(),
      'end': _endController.text.trim(),
      'chart_lazy_layers': true,
      'chart_layers': layers,
      'config': const <String, dynamic>{
        'bi_algo': 'normal',
        'seg_algo': 'chan',
        'zs_algo': 'normal',
        'max_step_frames': 80,
        'frame_policy': 'latest',
      },
    };
  }

  String _summary(Map<String, dynamic> result) {
    if (result['ok'] == false)
      return '接口返回失败：${result['error'] ?? 'unknown error'}';
    final meta = _metaOf(result);
    return '完成：contract=${_text(meta['chart_lazy_layers_contract'])} display=${_listText(meta['chart_lazy_layers_display_layers'])} transport=${_listText(meta['chart_lazy_layers_transport_layers'])} pruned=${_text(meta['chart_lazy_layers_pruned_counts'])}';
  }

  Future<void> _copyEvidence(LatestAnalysisJson? latest) async {
    await Clipboard.setData(ClipboardData(text: _evidenceJson(latest)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缓存优化证据已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LatestAnalysisJson?>(
      valueListenable: ReplayAnalysisStore.latestAnalysis,
      builder: (context, latest, _) {
        final analysis =
            _lastResult ?? latest?.analysis ?? const <String, dynamic>{};
        final meta = _metaOf(analysis);
        final bspTotal = _countBspRows(analysis);
        final bspFrozen = _countFrozenBspRows(analysis);
        final manifestLevels = _manifestLevels(meta);
        return Scaffold(
          backgroundColor: CacheOptimizationPage.bg,
          appBar: AppBar(
            title: const Text('缓存优化'),
            actions: <Widget>[
              TextButton.icon(
                onPressed: () => _copyEvidence(latest),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制证据'),
              ),
            ],
          ),
          body: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _header(latest),
                  const SizedBox(height: 12),
                  _sectionTitle('chart_lazy_layers 请求控制'),
                  _requestPanel(),
                  const SizedBox(height: 12),
                  Text(_status,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),
                  _sectionTitle('运行时缓存指标'),
                  _metricWrap(<Widget>[
                    _MetricCard(
                      title: 'K线缓存命中',
                      value: _text(_metaOrTimeLog(
                          meta, 'backend_session_kline_cache_hits')),
                      subtitle: 'raw K-line session cache hits',
                      icon: Icons.memory,
                    ),
                    _MetricCard(
                      title: 'K线缓存未命中',
                      value: _text(_metaOrTimeLog(
                          meta, 'backend_session_kline_cache_misses')),
                      subtitle: 'first request or key changed',
                      icon: Icons.cloud_download,
                    ),
                    _MetricCard(
                      title: '缓存 key 数',
                      value: _text(_metaOrTimeLog(
                          meta, 'backend_session_kline_cache_key_count')),
                      subtitle: 'symbol/market/period/adjust/count/start/end',
                      icon: Icons.key,
                    ),
                    _MetricCard(
                      title: 'TTL 秒数',
                      value: _text(_metaOrTimeLog(
                          meta, 'backend_session_kline_cache_ttl_seconds')),
                      subtitle: '默认 900，可由环境变量调整',
                      icon: Icons.timer,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _sectionTitle('复盘返回合同'),
                  _metricWrap(<Widget>[
                    _MetricCard(
                      title: 'Lazy contract',
                      value: _text(meta['chart_lazy_layers_contract']),
                      subtitle: manifestLevels.isEmpty
                          ? '等待返回 layer manifest'
                          : 'levels: ${manifestLevels.join(',')}',
                      icon: Icons.layers,
                    ),
                    _MetricCard(
                      title: 'Display layers',
                      value:
                          _listText(meta['chart_lazy_layers_display_layers']),
                      subtitle: 'Flutter 展示层',
                      icon: Icons.visibility,
                    ),
                    _MetricCard(
                      title: 'Transport layers',
                      value:
                          _listText(meta['chart_lazy_layers_transport_layers']),
                      subtitle: '后端实际返回层，含解析依赖',
                      icon: Icons.sync_alt,
                    ),
                    _MetricCard(
                      title: 'Pruned counts',
                      value: _text(meta['chart_lazy_layers_pruned_counts']),
                      subtitle: '已从返回 JSON 裁剪的层计数',
                      icon: Icons.content_cut,
                    ),
                    _MetricCard(
                      title: '防未来状态',
                      value: _text(meta['anti_future_status']),
                      subtitle:
                          'violations: ${_text(meta['anti_future_violation_count'])}',
                      icon: Icons.verified_user,
                    ),
                    _MetricCard(
                      title: 'BSP 冻结字段',
                      value: '$bspFrozen/$bspTotal',
                      subtitle: 'anchor/display/confirmed',
                      icon: Icons.ac_unit,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _sectionTitle('边界原则'),
                  _PolicyPanel(items: const <String>[
                    '请求参数 chart_layers 只影响后端返回 payload 裁剪，不改变 chan.py 计算。',
                    '后端会保留必要解析依赖，例如 seg 需要 bi，bi/fx 需要 merged_bars。',
                    'Flutter 只根据 manifest 决定展示哪些层，不计算 FX/BI/SEG/ZS/BSP。',
                    'BSP anchor/display/confirmed 由后端导出时冻结，Flutter 只展示。',
                    'K线缓存只缓存 raw K 线，不缓存 Chan 结构结果。',
                  ]),
                  const SizedBox(height: 14),
                  _sectionTitle('验收命令'),
                  const _CodePanel(
                    text: 'python tools/validate_hichanhuancun_contracts.py\n'
                        '# App 侧验收：本页取消某些图层 -> 请求 analyze_multi -> 查看 transport/display/pruned/manifest。',
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('返回 meta 预览'),
                  _CodePanel(text: _prettyJson(meta)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _requestPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _input(_backendUrlController, 'backend', width: 220),
              _input(_symbolController, 'symbol', width: 110),
              _input(_marketController, 'market', width: 82),
              _input(_levelsController, 'levels', width: 180),
              _input(_startController, 'start', width: 122),
              _input(_endController, 'end', width: 122),
              _input(_countController, 'count', width: 88),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final option in _availableLayers) _layerChip(option),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: _running ? null : _requestAnalyzeMulti,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
                label: const Text('请求 analyze_multi'),
              ),
              OutlinedButton.icon(
                onPressed: _running
                    ? null
                    : () => setState(() {
                          _selectedLayers
                            ..clear()
                            ..addAll(_availableLayers.map((e) => e.key));
                        }),
                icon: const Icon(Icons.select_all, size: 18),
                label: const Text('全选'),
              ),
              OutlinedButton.icon(
                onPressed: _running
                    ? null
                    : () => setState(() {
                          _selectedLayers
                            ..clear()
                            ..addAll(<String>{'bars', 'bi', 'seg', 'bsp'});
                        }),
                icon: const Icon(Icons.speed, size: 18),
                label: const Text('轻量'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _layerChip(_LayerOption option) {
    final selected = _selectedLayers.contains(option.key);
    return FilterChip(
      label: Text(option.label),
      selected: selected,
      onSelected: _running || option.key == 'bars'
          ? null
          : (value) => setState(() {
                if (value) {
                  _selectedLayers.add(option.key);
                } else {
                  _selectedLayers.remove(option.key);
                }
                _selectedLayers.add('bars');
              }),
      selectedColor: const Color(0xFFFFD54F),
      backgroundColor: const Color(0xFF20242E),
      labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white70, fontSize: 12),
    );
  }

  Widget _input(TextEditingController controller, String label,
      {required double width}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        enabled: !_running,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  Widget _header(LatestAnalysisJson? latest) {
    final title = latest == null
        ? '暂无已保存复盘数据'
        : '${latest.displaySymbol} ${latest.period} ${latest.adjust}';
    final subtitle = latest == null
        ? '可直接用本页请求 analyze_multi，也可先在“复盘/单股多级别”页加载后回来查看 meta。'
        : '最近保存：${_fmtTime(latest.savedAt)}；本页只请求/读取 JSON，不参与缠论计算。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CacheOptimizationPage.blue.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.speed, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: CacheOptimizationPage.panel,
        border: Border.all(color: CacheOptimizationPage.border),
        borderRadius: BorderRadius.circular(14),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
      );

  Widget _metricWrap(List<Widget> children) =>
      Wrap(spacing: 12, runSpacing: 12, children: children);

  Map<String, dynamic> _metaOf(Map<String, dynamic> analysis) {
    final meta = analysis['meta'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  }

  Map<String, dynamic> _timeLogOf(Map<String, dynamic> meta) {
    final timeLog = meta['time_log'];
    return timeLog is Map
        ? Map<String, dynamic>.from(timeLog)
        : <String, dynamic>{};
  }

  Object? _metaOrTimeLog(Map<String, dynamic> meta, String key) {
    final value = meta[key];
    if (value != null) return value;
    return _timeLogOf(meta)[key];
  }

  List<String> _manifestLevels(Map<String, dynamic> meta) {
    final manifest = meta['chart_lazy_layers_manifest'];
    if (manifest is! Map) return const <String>[];
    return manifest.keys.map((e) => '$e').toList(growable: false)..sort();
  }

  int _countBspRows(Object? node) {
    if (node is Map) {
      var count = 0;
      final bsp = node['bsp'] ?? node['bsps'];
      if (bsp is List) count += bsp.whereType<Map>().length;
      for (final entry in node.entries) {
        if (entry.key == 'bsp' || entry.key == 'bsps') continue;
        count += _countBspRows(entry.value);
      }
      return count;
    }
    if (node is List)
      return node.fold<int>(0, (sum, item) => sum + _countBspRows(item));
    return 0;
  }

  int _countFrozenBspRows(Object? node) {
    if (node is Map) {
      var count = 0;
      final bsp = node['bsp'] ?? node['bsps'];
      if (bsp is List) {
        count += bsp.whereType<Map>().where((row) {
          return row.containsKey('anchor_raw_index') &&
              row.containsKey('display_raw_index') &&
              row.containsKey('confirmed');
        }).length;
      }
      for (final entry in node.entries) {
        if (entry.key == 'bsp' || entry.key == 'bsps') continue;
        count += _countFrozenBspRows(entry.value);
      }
      return count;
    }
    if (node is List)
      return node.fold<int>(0, (sum, item) => sum + _countFrozenBspRows(item));
    return 0;
  }

  String _evidenceJson(LatestAnalysisJson? latest) {
    final analysis =
        _lastResult ?? latest?.analysis ?? const <String, dynamic>{};
    final meta = _metaOf(analysis);
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'page': '缓存优化',
      'branch_task': 'hichanhuancun chart_lazy_layers v2 transport pruning',
      'request_payload': _buildPayload(),
      'latest_analysis': latest == null
          ? null
          : <String, dynamic>{
              'saved_at': latest.savedAt.toIso8601String(),
              'symbol': latest.symbol,
              'market': latest.market,
              'period': latest.period,
              'adjust': latest.adjust,
            },
      'cache': <String, dynamic>{
        'hits': _metaOrTimeLog(meta, 'backend_session_kline_cache_hits'),
        'misses': _metaOrTimeLog(meta, 'backend_session_kline_cache_misses'),
        'key_count':
            _metaOrTimeLog(meta, 'backend_session_kline_cache_key_count'),
        'ttl_seconds':
            _metaOrTimeLog(meta, 'backend_session_kline_cache_ttl_seconds'),
        'policy':
            _metaOrTimeLog(meta, 'backend_session_kline_cache_key_policy'),
      },
      'contracts': <String, dynamic>{
        'chart_lazy_layers_contract': meta['chart_lazy_layers_contract'],
        'chart_lazy_layers_display_layers':
            meta['chart_lazy_layers_display_layers'],
        'chart_lazy_layers_transport_layers':
            meta['chart_lazy_layers_transport_layers'],
        'chart_lazy_layers_forced_transport_layers':
            meta['chart_lazy_layers_forced_transport_layers'],
        'chart_lazy_layers_omitted_layers':
            meta['chart_lazy_layers_omitted_layers'],
        'chart_lazy_layers_pruned_counts':
            meta['chart_lazy_layers_pruned_counts'],
        'anti_future_contract': meta['anti_future_contract'],
        'anti_future_status': meta['anti_future_status'],
        'anti_future_violation_count': meta['anti_future_violation_count'],
        'bsp_rows_total': _countBspRows(analysis),
        'bsp_rows_with_frozen_fields': _countFrozenBspRows(analysis),
      },
      'manifest': meta['chart_lazy_layers_manifest'],
      'boundary': <String>[
        'python/chan.py remains the only Chan calculation source',
        'Flutter sends desired layers and renders returned manifest only',
        'raw K-line cache only; no Chan result cache',
      ],
    });
  }

  String _prettyJson(Map<String, dynamic> data) {
    if (data.isEmpty) return '暂无 meta。';
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String _fmtTime(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _text(Object? value) {
    if (value == null) return '--';
    final text = '$value';
    return text.isEmpty || text == 'null' ? '--' : text;
  }

  String _listText(Object? value) {
    if (value is List) return value.join(',');
    return _text(value);
  }

  static String _todayMinusTwo() {
    final value = DateTime.now().subtract(const Duration(days: 2));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}

class _LayerOption {
  final String key;
  final String label;

  const _LayerOption(this.key, this.label);
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CacheOptimizationPage.panel,
          border: Border.all(color: CacheOptimizationPage.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyPanel extends StatelessWidget {
  final List<String> items;

  const _PolicyPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CacheOptimizationPage.panel,
        border: Border.all(color: CacheOptimizationPage.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check_circle,
                      color: Color(0xFF00C853), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  final String text;

  const _CodePanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF07090C),
        border: Border.all(color: CacheOptimizationPage.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
              color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}
