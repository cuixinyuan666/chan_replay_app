import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/replay_analysis_store.dart';

class RunLogPage extends StatefulWidget {
  const RunLogPage({super.key});

  static const Color bg = Color(0xFF0B0D10);
  static const Color panel = Color(0xFF131722);
  static const Color border = Color(0xFF2A2E39);
  static const Color blue = Color(0xFF2962FF);
  static const Color green = Color(0xFF00C853);

  @override
  State<RunLogPage> createState() => _RunLogPageState();
}

class _RunLogPageState extends State<RunLogPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyEvidence(LatestAnalysisJson? latest) async {
    await Clipboard.setData(ClipboardData(text: _evidenceText(latest)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('运行日志证据已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LatestAnalysisJson?>(
      valueListenable: ReplayAnalysisStore.latestAnalysis,
      builder: (context, latest, _) {
        final analysis = latest?.analysis ?? const <String, dynamic>{};
        final meta = _metaOf(analysis);
        final timings = _timingRows(meta);
        final flows = _flowRows(meta);
        final logText = _evidenceText(latest);
        return Scaffold(
          backgroundColor: RunLogPage.bg,
          appBar: AppBar(
            title: const Text('运行日志'),
            actions: <Widget>[
              TextButton.icon(
                onPressed: () => _copyEvidence(latest),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('一键复制'),
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
                  _header(latest, meta),
                  const SizedBox(height: 12),
                  _sectionTitle('运行状态'),
                  _metricWrap(<Widget>[
                    _MetricCard(
                      title: '分析结果',
                      value: latest == null ? '未加载' : '已捕获',
                      subtitle: latest == null
                          ? '先在单股多级别页面加载一次'
                          : '${latest.displaySymbol} ${latest.period}',
                      icon: Icons.radar,
                    ),
                    _MetricCard(
                      title: '总耗时',
                      value: _msText(_value(meta, 'backend_route_total_before_response_ms')),
                      subtitle: '/api/chan/analyze_multi before response',
                      icon: Icons.timer,
                    ),
                    _MetricCard(
                      title: '后端合同',
                      value: _text(meta['contract_hardening']),
                      subtitle: '缓存/裁剪/BSP/防未来合同',
                      icon: Icons.verified_user,
                    ),
                    _MetricCard(
                      title: '防未来',
                      value: _text(meta['anti_future_status']),
                      subtitle:
                          'violations: ${_text(meta['anti_future_violation_count'])}',
                      icon: Icons.shield,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _sectionTitle('调用流程'),
                  _flowPanel(flows),
                  const SizedBox(height: 14),
                  _sectionTitle('方法耗时'),
                  timings.isEmpty
                      ? const _PolicyPanel(items: <String>[
                          '暂无 backend_*_ms 或 time_log 耗时字段。',
                          '完成一次复盘加载后，本页会自动读取最新 analyze_multi meta。',
                        ])
                      : _timingPanel(timings),
                  const SizedBox(height: 14),
                  _sectionTitle('缓存与传输合同'),
                  _metricWrap(<Widget>[
                    _MetricCard(
                      title: 'K线缓存命中',
                      value: _text(_value(meta, 'backend_session_kline_cache_hits')),
                      subtitle: 'raw K-line session cache hits',
                      icon: Icons.memory,
                    ),
                    _MetricCard(
                      title: 'K线缓存未命中',
                      value: _text(_value(meta, 'backend_session_kline_cache_misses')),
                      subtitle: 'first request or key changed',
                      icon: Icons.cloud_download,
                    ),
                    _MetricCard(
                      title: '缓存 key 数',
                      value: _text(_value(meta, 'backend_session_kline_cache_key_count')),
                      subtitle: 'symbol/market/period/adjust/count/start/end',
                      icon: Icons.key,
                    ),
                    _MetricCard(
                      title: 'Lazy layers',
                      value: _text(meta['chart_lazy_layers_contract']),
                      subtitle:
                          'transport: ${_listText(meta['chart_lazy_layers_transport_layers'])}',
                      icon: Icons.layers,
                    ),
                    _MetricCard(
                      title: 'Pruned counts',
                      value: _text(meta['chart_lazy_layers_pruned_counts']),
                      subtitle: '已从返回 JSON 裁剪的层计数',
                      icon: Icons.content_cut,
                    ),
                    _MetricCard(
                      title: 'BSP 冻结字段',
                      value: '${_countFrozenBspRows(analysis)}/${_countBspRows(analysis)}',
                      subtitle: 'anchor/display/confirmed',
                      icon: Icons.ac_unit,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _sectionTitle('日志输出框'),
                  _toolbarCopy(latest),
                  const SizedBox(height: 8),
                  _logBox(logText),
                  const SizedBox(height: 14),
                  _sectionTitle('边界原则'),
                  const _PolicyPanel(items: <String>[
                    '本页只读取 ReplayAnalysisStore.latestAnalysis 与后端 meta，不参与缠论计算。',
                    '后端缓存优化逻辑仍在 a_replay_contract_hardening.py，不随旧 UI 删除。',
                    '日志证据优先来自 analyze_multi 返回 meta，包括方法耗时、缓存命中、裁剪合同、防未来状态。',
                    'Flutter 仍不得计算 FX/BI/SEG/ZS/BSP，只展示后端返回结果。',
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _toolbarCopy(LatestAnalysisJson? latest) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.icon(
          onPressed: () => _copyEvidence(latest),
          icon: const Icon(Icons.copy_all, size: 18),
          label: const Text('复制全部调试证据'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final meta = _metaOf(latest?.analysis ?? const <String, dynamic>{});
            await Clipboard.setData(
              ClipboardData(text: const JsonEncoder.withIndent('  ').convert(meta)),
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('meta JSON 已复制')),
            );
          },
          icon: const Icon(Icons.data_object, size: 18),
          label: const Text('仅复制 meta JSON'),
        ),
      ],
    );
  }

  Widget _header(LatestAnalysisJson? latest, Map<String, dynamic> meta) {
    final title = latest == null ? '暂无运行日志' : '${latest.displaySymbol} ${latest.period} ${latest.adjust}';
    final subtitle = latest == null
        ? '加载一次“单股多级别复盘”后，这里会显示后端方法耗时、缓存状态、裁剪合同和防未来证据。'
        : '最近保存：${_fmtTime(latest.savedAt)}；engine=${_text(meta['engine'])} mode=${_text(meta['mode'])}';
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
              color: RunLogPage.green.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowPanel(List<_FlowRow> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final row in rows) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  row.present ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: row.present ? RunLogPage.green : Colors.white30,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        row.method,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row.key ?? '--'}：${row.valueText} · ${row.note}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _timingPanel(List<_TimingRow> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final row in rows.take(48))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 92,
                    child: Text(
                      row.source,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${row.ms} ms',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _logBox(String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 380),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        border: Border.all(color: RunLogPage.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          height: 1.42,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
        color: RunLogPage.panel,
        border: Border.all(color: RunLogPage.border),
        borderRadius: BorderRadius.circular(14),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _metricWrap(List<Widget> children) =>
      Wrap(spacing: 12, runSpacing: 12, children: children);

  String _evidenceText(LatestAnalysisJson? latest) {
    final analysis = latest?.analysis ?? const <String, dynamic>{};
    final meta = _metaOf(analysis);
    final payload = _evidencePayload(latest, analysis, meta);
    final lines = <String>[
      'RUN_LOG_EVIDENCE_V1',
      'generated_at: ${DateTime.now().toIso8601String()}',
      'latest_analysis_saved_at: ${latest?.savedAt.toIso8601String() ?? '--'}',
      'symbol: ${latest?.displaySymbol ?? _text(meta['symbol'])}',
      'period: ${latest?.period ?? _text(meta['period'])}',
      'adjust: ${latest?.adjust ?? _text(meta['adjust'])}',
      '',
      '[status]',
      'ok: ${_text(analysis['ok'])}',
      'engine: ${_text(meta['engine'])}',
      'mode: ${_text(meta['mode'])}',
      'contract_hardening: ${_text(meta['contract_hardening'])}',
      'chan_py_core_unchanged: ${_text(meta['chan_py_core_unchanged'])}',
      'flutter_chan_calculation_allowed: ${_text(meta['flutter_chan_calculation_allowed'])}',
      '',
      '[method_flow]',
      for (final row in _flowRows(meta))
        '- ${row.present ? 'OK' : 'WAIT'} ${row.method} | ${row.key ?? '--'}=${row.valueText} | ${row.note}',
      '',
      '[method_timings]',
      for (final row in _timingRows(meta)) '- ${row.source}.${row.name}: ${row.ms} ms',
      '',
      '[cache]',
      'backend_session_kline_cache_hits: ${_text(_value(meta, 'backend_session_kline_cache_hits'))}',
      'backend_session_kline_cache_misses: ${_text(_value(meta, 'backend_session_kline_cache_misses'))}',
      'backend_session_kline_cache_key_count: ${_text(_value(meta, 'backend_session_kline_cache_key_count'))}',
      'backend_session_kline_cache_ttl_seconds: ${_text(_value(meta, 'backend_session_kline_cache_ttl_seconds'))}',
      'backend_session_kline_cache_policy: ${_text(_value(meta, 'backend_session_kline_cache_key_policy'))}',
      '',
      '[chart_lazy_layers]',
      'contract: ${_text(meta['chart_lazy_layers_contract'])}',
      'enabled: ${_text(meta['chart_lazy_layers_enabled'])}',
      'display_layers: ${_listText(meta['chart_lazy_layers_display_layers'])}',
      'transport_layers: ${_listText(meta['chart_lazy_layers_transport_layers'])}',
      'forced_layers: ${_listText(meta['chart_lazy_layers_forced_transport_layers'])}',
      'omitted_layers: ${_listText(meta['chart_lazy_layers_omitted_layers'])}',
      'pruned_counts: ${_text(meta['chart_lazy_layers_pruned_counts'])}',
      '',
      '[anti_future]',
      'status: ${_text(meta['anti_future_status'])}',
      'violation_count: ${_text(meta['anti_future_violation_count'])}',
      'first_violation: ${_text(meta['anti_future_first_violation'])}',
      '',
      '[bsp_history]',
      'rows_total: ${_countBspRows(analysis)}',
      'rows_with_frozen_fields: ${_countFrozenBspRows(analysis)}',
      '',
      '[manifest]',
      _prettyJson(meta['chart_lazy_layers_manifest'] ?? analysis['layer_manifest']),
      '',
      '[payload_json]',
      const JsonEncoder.withIndent('  ').convert(payload),
    ];
    return lines.join('\n');
  }

  Map<String, dynamic> _evidencePayload(
    LatestAnalysisJson? latest,
    Map<String, dynamic> analysis,
    Map<String, dynamic> meta,
  ) {
    return <String, dynamic>{
      'page': '运行日志',
      'branch_task': 'replace cache optimization UI with runtime log evidence page',
      'generated_at': DateTime.now().toIso8601String(),
      'latest_analysis': latest == null
          ? null
          : <String, dynamic>{
              'saved_at': latest.savedAt.toIso8601String(),
              'symbol': latest.symbol,
              'market': latest.market,
              'display_symbol': latest.displaySymbol,
              'period': latest.period,
              'adjust': latest.adjust,
            },
      'status': <String, dynamic>{
        'ok': analysis['ok'],
        'engine': meta['engine'],
        'mode': meta['mode'],
        'contract_hardening': meta['contract_hardening'],
        'chan_py_core_unchanged': meta['chan_py_core_unchanged'],
        'flutter_chan_calculation_allowed': meta['flutter_chan_calculation_allowed'],
      },
      'method_flow': [for (final row in _flowRows(meta)) row.toJson()],
      'method_timings': [for (final row in _timingRows(meta)) row.toJson()],
      'cache': <String, dynamic>{
        'hits': _value(meta, 'backend_session_kline_cache_hits'),
        'misses': _value(meta, 'backend_session_kline_cache_misses'),
        'key_count': _value(meta, 'backend_session_kline_cache_key_count'),
        'ttl_seconds': _value(meta, 'backend_session_kline_cache_ttl_seconds'),
        'policy': _value(meta, 'backend_session_kline_cache_key_policy'),
      },
      'contracts': <String, dynamic>{
        'chart_lazy_layers_contract': meta['chart_lazy_layers_contract'],
        'chart_lazy_layers_display_layers': meta['chart_lazy_layers_display_layers'],
        'chart_lazy_layers_transport_layers': meta['chart_lazy_layers_transport_layers'],
        'chart_lazy_layers_forced_transport_layers': meta['chart_lazy_layers_forced_transport_layers'],
        'chart_lazy_layers_omitted_layers': meta['chart_lazy_layers_omitted_layers'],
        'chart_lazy_layers_pruned_counts': meta['chart_lazy_layers_pruned_counts'],
        'anti_future_contract': meta['anti_future_contract'],
        'anti_future_status': meta['anti_future_status'],
        'anti_future_violation_count': meta['anti_future_violation_count'],
        'bsp_rows_total': _countBspRows(analysis),
        'bsp_rows_with_frozen_fields': _countFrozenBspRows(analysis),
      },
      'manifest': meta['chart_lazy_layers_manifest'] ?? analysis['layer_manifest'],
      'raw_meta': meta,
      'boundary': <String>[
        'python/chan.py remains the only Chan calculation source',
        'runtime log page reads evidence only and does not calculate Chan structures',
        'backend raw K-line cache and chart_lazy_layers transport pruning remain installed',
      ],
    };
  }

  List<_FlowRow> _flowRows(Map<String, dynamic> meta) {
    final rows = <_FlowRow>[
      _flow(meta, 'FastAPI /api/chan/analyze_multi', 'backend_route_analyze_multi_ms', 'route analyze_multi'),
      _flow(meta, 'analyze_multi_native_timed_recursive', 'backend_native_total_ms', 'native CChan(lv_list) adapter'),
      _flow(meta, '_load_aligned_bars_by_level', 'backend_native_data_load_ms', 'load and align multi-level K-lines'),
      _flow(meta, '_prepare_native_chan', 'backend_native_prepare_chan_ms', 'prepare chan.py native engine'),
      _flow(meta, 'CChan.step_load export', 'backend_native_step_export_ms', 'step replay frame export'),
      _flow(meta, 'native once export', 'backend_native_once_export_ms', 'once final snapshot export'),
      _flow(meta, 'recursive segment export', 'backend_recursive_seg_export_ms', 'seg2/seg3/seg4 export-only layers'),
      _flow(meta, 'with_multilevel_rhythm_overlay', 'backend_route_rhythm_1382_overlay_ms', '1.382/rhythm overlay'),
      _flow(meta, '_compact_multilevel_step_result', 'backend_route_compact_transform_ms', 'transport-only step payload compact'),
      _flow(meta, 'apply_analyze_multi_contracts', 'backend_route_contract_hardening_ms', 'cache/lazy/BSP/anti-future contracts'),
      _flow(meta, 'json.dumps response probe', 'backend_route_json_serialize_probe_ms', 'response size serialization probe'),
    ];
    return rows;
  }

  _FlowRow _flow(Map<String, dynamic> meta, String method, String key, String note) {
    final value = _value(meta, key);
    return _FlowRow(
      method: method,
      key: key,
      value: value,
      note: note,
      present: value != null,
    );
  }

  List<_TimingRow> _timingRows(Map<String, dynamic> meta) {
    final rows = <_TimingRow>[];
    void collect(String source, Map<String, dynamic> node) {
      for (final entry in node.entries) {
        final key = '${entry.key}';
        if (!key.contains('_ms')) continue;
        final ms = _int(entry.value);
        if (ms == null) continue;
        rows.add(_TimingRow(source: source, name: key, ms: ms));
      }
    }

    collect('meta', meta);
    collect('time_log', _timeLogOf(meta));
    rows.sort((a, b) {
      final sourceCompare = a.source.compareTo(b.source);
      if (sourceCompare != 0) return sourceCompare;
      return a.name.compareTo(b.name);
    });
    return rows;
  }

  Map<String, dynamic> _metaOf(Map<String, dynamic> analysis) {
    final meta = analysis['meta'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  }

  Map<String, dynamic> _timeLogOf(Map<String, dynamic> meta) {
    final timeLog = meta['time_log'];
    return timeLog is Map ? Map<String, dynamic>.from(timeLog) : <String, dynamic>{};
  }

  Object? _value(Map<String, dynamic> meta, String key) {
    final value = meta[key];
    if (value != null) return value;
    return _timeLogOf(meta)[key];
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
    if (node is List) {
      return node.fold<int>(0, (sum, item) => sum + _countBspRows(item));
    }
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
    if (node is List) {
      return node.fold<int>(0, (sum, item) => sum + _countFrozenBspRows(item));
    }
    return 0;
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

  String _msText(Object? value) {
    final ms = _int(value);
    return ms == null ? '--' : '$ms ms';
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  String _prettyJson(Object? data) {
    if (data == null) return '--';
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

class _TimingRow {
  final String source;
  final String name;
  final int ms;

  const _TimingRow({required this.source, required this.name, required this.ms});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source,
        'name': name,
        'ms': ms,
      };
}

class _FlowRow {
  final String method;
  final String? key;
  final Object? value;
  final String note;
  final bool present;

  const _FlowRow({
    required this.method,
    required this.key,
    required this.value,
    required this.note,
    required this.present,
  });

  String get valueText {
    if (value == null) return '--';
    final text = '$value';
    return text.isEmpty || text == 'null' ? '--' : text;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'method': method,
        'key': key,
        'value': value,
        'note': note,
        'present': present,
      };
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
          color: RunLogPage.panel,
          border: Border.all(color: RunLogPage.border),
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
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
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

class _PolicyPanel extends StatelessWidget {
  final List<String> items;

  const _PolicyPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RunLogPage.panel,
        border: Border.all(color: RunLogPage.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '• $item',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
