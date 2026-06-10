import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ResearchBacktestPage extends StatefulWidget {
  const ResearchBacktestPage({super.key});

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
  _ResearchLocalPythonProcess? _localProcess;

  bool _running = false;
  String _status = '粘贴 chan.py analysis JSON 后，可调用研究接口。';
  Map<String, dynamic>? _lastResult;

  @override
  void dispose() {
    _backendUrlController.dispose();
    _jsonController.dispose();
    _resultScrollController.dispose();
    _localProcess?.dispose();
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
      final sourceBaseUrl = await _readyBaseUrl();
      final uri = Uri.parse(_join(sourceBaseUrl, endpoint));
      final response = await http
          .post(uri,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode(payload))
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
    if (result['ok'] == false)
      return '接口返回失败：${result['error'] ?? 'unknown error'}';
    if (endpoint.endsWith('/pipeline')) {
      final backtest = result['backtest'];
      final summary = backtest is Map ? backtest['summary'] : null;
      if (summary is Map) {
        return 'Pipeline 完成：特征 ${_rowsFrom(result['features'], nestedKey: 'features').length}，评分 ${_rowsFrom(result['scores'], nestedKey: 'scores').length}，交易 ${summary['trade_count'] ?? 0}，胜率 ${_pct(summary['win_rate'])}，总收益 ${_pct(summary['total_return'])}';
      }
      return 'Pipeline 完成。';
    }
    if (endpoint.endsWith('/features')) {
      return 'BSP 特征提取完成：${_rowsFrom(result['features'], nestedKey: 'features').length} 行。';
    }
    if (endpoint.endsWith('/score')) {
      return 'ML 打分完成：${_rowsFrom(result['scores'], nestedKey: 'scores').length} 行。';
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

  String _join(String base, String path) =>
      '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path';

  Future<String> _readyBaseUrl() async {
    final configured = _backendUrlController.text.trim();
    try {
      await _assertCompatibleBackend(configured);
      return configured;
    } catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess?.dispose();
      _localProcess = await _ResearchLocalPythonProcess.start();
      return _localProcess!.baseUrl;
    }
  }

  Future<void> _assertCompatibleBackend(String sourceBaseUrl) async {
    final uri = Uri.tryParse(sourceBaseUrl);
    if (uri == null ||
        uri.scheme != 'http' ||
        !(uri.host == '127.0.0.1' ||
            uri.host == 'localhost' ||
            uri.host == '::1')) {
      return;
    }
    final response = await http
        .get(Uri.parse(_join(sourceBaseUrl, '/health')))
        .timeout(const Duration(seconds: 3));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('localhost /health 返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded['backend'] != 'origin_vespa_tdx' ||
        decoded['engine'] != 'chan.py') {
      throw Exception('localhost 服务不是 origin_vespa_tdx chan.py 后端: $body');
    }
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
      value is Map ? Map<String, dynamic>.from(value) : const {};

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

class _ResearchResultView extends StatelessWidget {
  final Map<String, dynamic>? result;
  final String rawJson;
  final ScrollController scrollController;
  final String Function(Object? value) valueText;
  final String Function(Object? value) pctText;
  final List<Map<String, dynamic>> Function(Object? value, {String? nestedKey})
      rowsFrom;
  final Map<String, dynamic> Function(Object? value) mapFrom;

  const _ResearchResultView({
    required this.result,
    required this.rawJson,
    required this.scrollController,
    required this.valueText,
    required this.pctText,
    required this.rowsFrom,
    required this.mapFrom,
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
              ]),
              const SizedBox(height: 12),
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
                ),
              if (features.isEmpty && scores.isEmpty && trades.isEmpty)
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

  const _PreviewTable({
    required this.title,
    required this.rows,
    required this.columns,
    required this.valueText,
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
                      DataRow(cells: [
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

class _ResearchLocalPythonProcess {
  final Process process;
  final String baseUrl;
  final StringBuffer _stderr = StringBuffer();

  _ResearchLocalPythonProcess._(this.process, this.baseUrl) {
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
    process.stdout.transform(utf8.decoder).listen((_) {});
  }

  static Future<_ResearchLocalPythonProcess> start() async {
    final appEngine = await _findAppEngine();
    final port = await _pickFreePort();
    final baseUrl = 'http://127.0.0.1:$port';
    final python = _bundledPython(appEngine);
    try {
      final process = await Process.start(
        python.path,
        [appEngine.path, '--host', '127.0.0.1', '--port', '$port'],
        workingDirectory: appEngine.parent.parent.path,
        runInShell: false,
        environment: {'PYTHONIOENCODING': 'utf-8'},
        mode: ProcessStartMode.normal,
      );
      final runner = _ResearchLocalPythonProcess._(process, baseUrl);
      await runner._waitUntilReady();
      return runner;
    } catch (e) {
      throw Exception(
          '无法后台启动 Python chan.py 本地服务。仅允许使用内置 Python：python/python.exe。最后错误：${python.path}: $e');
    }
  }

  static Future<File> _findAppEngine() async {
    final checked = <String>{};
    final starts = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in starts) {
      var dir = start.absolute;
      for (var i = 0; i < 8; i++) {
        if (!checked.add(dir.path)) break;
        for (final candidate in _appEngineCandidatesFrom(dir)) {
          if (await candidate.exists()) return candidate;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    throw Exception('找不到 python/app_engine.py');
  }

  static List<File> _appEngineCandidatesFrom(Directory dir) {
    final sep = Platform.pathSeparator;
    return [
      File('${dir.path}${sep}python${sep}app_engine.py'),
      File('${dir.path}${sep}data${sep}python${sep}app_engine.py'),
      File('${dir.path}${sep}app_engine.py'),
    ];
  }

  static File _bundledPython(File appEngine) {
    final sep = Platform.pathSeparator;
    final python = File('${appEngine.parent.path}${sep}python.exe');
    if (!python.existsSync()) throw Exception('找不到内置 Python：${python.path}');
    return python;
  }

  static Future<int> _pickFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<void> _waitUntilReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 10),
        onTimeout: () => -999999,
      );
      if (exitCode != -999999) {
        throw Exception(
            'Python chan.py 本地服务提前退出，exitCode=$exitCode，stderr=${_stderr.toString()}');
      }
      try {
        final client = HttpClient();
        final request = await client
            .getUrl(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(milliseconds: 700));
        final response =
            await request.close().timeout(const Duration(milliseconds: 700));
        client.close(force: true);
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    dispose();
    throw Exception(
        'Python chan.py 本地服务启动超时：$lastError，stderr=${_stderr.toString()}');
  }

  void dispose() {
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
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
