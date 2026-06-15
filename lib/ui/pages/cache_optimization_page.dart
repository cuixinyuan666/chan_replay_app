import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/replay_analysis_store.dart';

class CacheOptimizationPage extends StatelessWidget {
  const CacheOptimizationPage({super.key});

  static const Color _bg = Color(0xFF0B0D10);
  static const Color _panel = Color(0xFF131722);
  static const Color _border = Color(0xFF2A2E39);
  static const Color _blue = Color(0xFF2962FF);

  Future<void> _copyEvidence(
      BuildContext context, LatestAnalysisJson? latest) async {
    await Clipboard.setData(ClipboardData(text: _evidenceJson(latest)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缓存优化证据已复制')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LatestAnalysisJson?>(
      valueListenable: ReplayAnalysisStore.latestAnalysis,
      builder: (context, latest, _) {
        final analysis = latest?.analysis ?? const <String, dynamic>{};
        final meta = _metaOf(analysis);
        final bspTotal = _countBspRows(analysis);
        final bspFrozen = _countFrozenBspRows(analysis);
        final manifestLevels = _manifestLevels(meta);
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            title: const Text('缓存优化'),
            actions: <Widget>[
              TextButton.icon(
                onPressed: () => _copyEvidence(context, latest),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('复制证据'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _header(latest),
                const SizedBox(height: 12),
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
                    title: 'Lazy layers',
                    value: _text(meta['chart_lazy_layers_contract']),
                    subtitle: manifestLevels.isEmpty
                        ? '等待 analyze_multi 返回 layer manifest'
                        : 'levels: ${manifestLevels.join(',')}',
                    icon: Icons.layers,
                  ),
                  _MetricCard(
                    title: '防未来状态',
                    value: _text(meta['anti_future_status']),
                    subtitle:
                        'violations: ${_text(meta['anti_future_violation_count'])}',
                    icon: Icons.verified_user,
                  ),
                  _MetricCard(
                    title: 'Step frames',
                    value:
                        '${_text(meta['frames_returned'])}/${_text(meta['frames_total'])}',
                    subtitle: 'transport compact result',
                    icon: Icons.view_timeline,
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
                  '只缓存后端 raw K 线，不缓存 chan.py 结构结果。',
                  'chart_lazy_layers 是传输/绘图合同，不承诺减少 chan.py 计算。',
                  'BSP anchor/display/confirmed 由后端导出时冻结，Flutter 只展示。',
                  'anti_future meta 只做返回结构校验，不重写缠论算法。',
                  'Flutter/Dart 不计算 FX/BI/SEG/ZS/BSP/segseg。',
                ]),
                const SizedBox(height: 14),
                _sectionTitle('验收命令'),
                const _CodePanel(
                  text: 'python tools/validate_hichanhuancun_contracts.py\n'
                      '# App 侧验收：先在“单股多级别”载入一次 step 复盘，再打开本页复制证据。',
                ),
                const SizedBox(height: 14),
                _sectionTitle('当前复盘 meta 预览'),
                _CodePanel(text: _prettyJson(meta)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(LatestAnalysisJson? latest) {
    final title = latest == null
        ? '暂无可用复盘数据'
        : '${latest.displaySymbol} ${latest.period} ${latest.adjust}';
    final subtitle = latest == null
        ? '先在“复盘”或“单股多级别”页完成一次加载，再回来查看缓存合同与防未来 meta。'
        : '最近保存：${_fmtTime(latest.savedAt)}；本页只读取 JSON/meta，不参与缠论计算。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.22),
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
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800)),
      );

  Widget _metricWrap(List<Widget> children) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children,
      );

  Map<String, dynamic> _metaOf(Map<String, dynamic> analysis) {
    final meta = analysis['meta'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  }

  Map<String, dynamic> _timeLogOf(Map<String, dynamic> meta) {
    final timeLog = meta['time_log'];
    return timeLog is Map ? Map<String, dynamic>.from(timeLog) : <String, dynamic>{};
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
      final bsp = node['bsp'];
      if (bsp is List) count += bsp.whereType<Map>().length;
      for (final entry in node.entries) {
        if (entry.key == 'bsp') continue;
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
      final bsp = node['bsp'];
      if (bsp is List) {
        count += bsp.whereType<Map>().where((row) {
          return row.containsKey('anchor_raw_index') &&
              row.containsKey('display_raw_index') &&
              row.containsKey('confirmed');
        }).length;
      }
      for (final entry in node.entries) {
        if (entry.key == 'bsp') continue;
        count += _countFrozenBspRows(entry.value);
      }
      return count;
    }
    if (node is List) {
      return node.fold<int>(0, (sum, item) => sum + _countFrozenBspRows(item));
    }
    return 0;
  }

  String _evidenceJson(LatestAnalysisJson? latest) {
    final analysis = latest?.analysis ?? const <String, dynamic>{};
    final meta = _metaOf(analysis);
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'page': '缓存优化',
      'branch_task': 'hichanhuancun cache optimization page',
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
        'key_count': _metaOrTimeLog(meta, 'backend_session_kline_cache_key_count'),
        'ttl_seconds': _metaOrTimeLog(meta, 'backend_session_kline_cache_ttl_seconds'),
        'policy': _metaOrTimeLog(meta, 'backend_session_kline_cache_key_policy'),
      },
      'contracts': <String, dynamic>{
        'chart_lazy_layers_contract': meta['chart_lazy_layers_contract'],
        'anti_future_contract': meta['anti_future_contract'],
        'anti_future_status': meta['anti_future_status'],
        'anti_future_violation_count': meta['anti_future_violation_count'],
        'bsp_rows_total': _countBspRows(analysis),
        'bsp_rows_with_frozen_fields': _countFrozenBspRows(analysis),
      },
      'boundary': <String>[
        'python/chan.py remains the only Chan calculation source',
        'Flutter renders and diagnoses returned JSON only',
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
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _text(Object? value) {
    if (value == null) return '--';
    final text = '$value';
    return text.isEmpty || text == 'null' ? '--' : text;
  }
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
          color: CacheOptimizationPage._panel,
          border: Border.all(color: CacheOptimizationPage._border),
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
        color: CacheOptimizationPage._panel,
        border: Border.all(color: CacheOptimizationPage._border),
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
                            color: Colors.white70, fontSize: 12)),
                  ),
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
        border: Border.all(color: CacheOptimizationPage._border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
