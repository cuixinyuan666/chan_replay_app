import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ResearchBacktestPage extends StatefulWidget {
  const ResearchBacktestPage({super.key});

  @override
  State<ResearchBacktestPage> createState() => _ResearchBacktestPageState();
}

class _ResearchBacktestPageState extends State<ResearchBacktestPage> {
  final TextEditingController _backendUrlController = TextEditingController(text: 'http://127.0.0.1:8000');
  final TextEditingController _jsonController = TextEditingController(text: '''{
  "analysis": {}
}''');
  final ScrollController _resultScrollController = ScrollController();

  bool _running = false;
  String _status = '粘贴 chan.py analysis JSON 后，可调用研究接口。';
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _backendUrlController.dispose();
    _jsonController.dispose();
    _resultScrollController.dispose();
    super.dispose();
  }

  Future<void> _call(String endpoint) async {
    if (_running) return;
    setState(() {
      _running = true;
      _status = '请求 $endpoint ...';
    });
    try {
      final payload = _parsePayload();
      final uri = Uri.parse(_join(_backendUrlController.text.trim(), endpoint));
      final response = await http
          .post(uri, headers: const {'content-type': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 60));
      final body = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const FormatException('研究接口返回不是 JSON 对象');
      setState(() {
        _lastResult = Map<String, dynamic>.from(decoded);
        _status = _summaryOf(endpoint, _lastResult!);
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

  Map<String, dynamic> _parsePayload() {
    final text = _jsonController.text.trim();
    if (text.isEmpty) return {'analysis': {}};
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw const FormatException('请输入 JSON 对象，不能是数组或纯文本');
    return Map<String, dynamic>.from(decoded);
  }

  String _summaryOf(String endpoint, Map<String, dynamic> result) {
    if (result['ok'] == false) return '接口返回失败：${result['error'] ?? 'unknown error'}';
    if (endpoint.endsWith('/pipeline')) {
      final backtest = result['backtest'];
      final summary = backtest is Map ? backtest['summary'] : null;
      if (summary is Map) {
        return 'Pipeline 完成：特征 ${_len(result['features'])}，评分 ${_len(result['scores'])}，交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return 'Pipeline 完成。';
    }
    if (endpoint.endsWith('/features')) return 'BSP 特征提取完成：${_len(result['features'])} 行。';
    if (endpoint.endsWith('/score')) return 'ML 打分完成：${_len(result['scores'])} 行。';
    if (endpoint.endsWith('/backtest')) {
      final summary = result['summary'];
      if (summary is Map) {
        return '回测完成：交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return '回测完成。';
    }
    return '请求完成。';
  }

  int _len(Object? value) => value is List ? value.length : 0;

  String _pct(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return '--';
    return '${(number * 100).toStringAsFixed(2)}%';
  }

  String _join(String base, String path) => '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path';

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
              children: [
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
                    child: _JsonPanel(
                      title: '输入 analysis JSON',
                      child: TextField(
                        controller: _jsonController,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
                    child: _JsonPanel(
                      title: '接口结果',
                      child: Scrollbar(
                        controller: _resultScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _resultScrollController,
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _prettyResult,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70),
                          ),
                        ),
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
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
