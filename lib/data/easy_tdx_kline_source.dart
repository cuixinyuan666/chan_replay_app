import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/models/raw_bar.dart';

class EasyTdxKlineSource {
  final String baseUrl;
  final http.Client _client;
  _LocalEasyTdxProcess? _localProcess;

  EasyTdxKlineSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<List<RawBar>> loadKline({
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 800,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw const FormatException('股票代码必须是6位数字，例如 000001');
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw const FormatException('开始日期不能晚于结束日期');
    }

    final query = {
      'symbol': normalizedCode,
      'market': market.trim().toUpperCase(),
      'freq': period.trim().toUpperCase(),
      'adjust': adjust.trim().toUpperCase(),
      'count': '$count',
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    };

    try {
      return await _loadFromBase(baseUrl, query);
    } on SocketException catch (_) {
      return _loadViaAutoLocalBackend(query);
    } on http.ClientException catch (e) {
      if (!_looksLikeConnectionFailure(e)) rethrow;
      return _loadViaAutoLocalBackend(query);
    } on TimeoutException catch (_) {
      return _loadViaAutoLocalBackend(query);
    }
  }

  Future<List<RawBar>> _loadViaAutoLocalBackend(Map<String, String> query) async {
    if (!Platform.isWindows) {
      rethrow;
    }
    _localProcess = await _LocalEasyTdxProcess.start();
    return _loadFromBase(_localProcess!.baseUrl, query);
  }

  Future<List<RawBar>> _loadFromBase(String sourceBaseUrl, Map<String, String> query) async {
    final uri = Uri.parse(_join(sourceBaseUrl, '/api/tdx/kline')).replace(
      queryParameters: query,
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 30));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('easy-tdx 返回 ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('easy-tdx 返回结构不是 JSON 对象');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? 'easy-tdx 获取失败');
    }
    final rows = decoded['bars'];
    if (rows is! List) {
      throw const FormatException('easy-tdx 未返回 bars 数组');
    }

    final bars = <RawBar>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final bar = _parseBar(row, bars.length);
      if (bar == null) continue;
      bars.add(bar.copyWith(index: bars.length));
    }

    bars.sort((a, b) => a.time.compareTo(b.time));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  bool _looksLikeConnectionFailure(http.ClientException e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('connection refused') ||
        msg.contains('connection failed') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed');
  }

  void close() {
    _client.close();
    _localProcess?.dispose();
    _localProcess = null;
  }

  RawBar? _parseBar(Map row, int index) {
    final time = _parseTime(row['dt'] ?? row['datetime'] ?? row['date'] ?? row['time']);
    final open = _parseDouble(row['open'] ?? row['o']);
    final high = _parseDouble(row['high'] ?? row['h']);
    final low = _parseDouble(row['low'] ?? row['l']);
    final close = _parseDouble(row['close'] ?? row['c']);
    final volume = _parseDouble(row['vol'] ?? row['volume'] ?? row['v']) ?? 0.0;

    if (time == null || open == null || high == null || low == null || close == null) {
      return null;
    }
    return RawBar(
      index: index,
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  String _join(String base, String path) {
    final left = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$left$path';
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  DateTime? _parseTime(Object? value) {
    if (value is DateTime) return value;
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T');
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    final text = '${value ?? ''}'.trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'nan') return null;
    return double.tryParse(text);
  }
}

class _LocalEasyTdxProcess {
  final Process process;
  final String baseUrl;
  final StringBuffer _stderr = StringBuffer();

  _LocalEasyTdxProcess._(this.process, this.baseUrl) {
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
    process.stdout.transform(utf8.decoder).listen((_) {});
  }

  static Future<_LocalEasyTdxProcess> start() async {
    final backendDir = await _findBackendDir();
    final port = await _pickFreePort();
    final baseUrl = 'http://127.0.0.1:$port';
    final candidates = _pythonCandidates(backendDir);
    Object? lastError;

    for (final candidate in candidates) {
      try {
        final process = await Process.start(
          candidate.executable,
          [
            ...candidate.prefixArgs,
            '-m',
            'uvicorn',
            'app.main:app',
            '--host',
            '127.0.0.1',
            '--port',
            '$port',
          ],
          workingDirectory: backendDir.path,
          runInShell: false,
          environment: {
            'PYTHONIOENCODING': 'utf-8',
          },
          mode: ProcessStartMode.normal,
        );
        final runner = _LocalEasyTdxProcess._(process, baseUrl);
        await runner._waitUntilReady();
        return runner;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      '无法后台启动 easy-tdx 本地服务。请确认已安装 Python，并在 backend 目录执行过：pip install -r requirements.txt。最后错误：$lastError',
    );
  }

  static Future<Directory> _findBackendDir() async {
    final checked = <String>{};
    final starts = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];

    for (final start in starts) {
      var dir = start.absolute;
      for (var i = 0; i < 8; i++) {
        if (!checked.add(dir.path)) break;
        final candidate = Directory('${dir.path}${Platform.pathSeparator}backend');
        final mainPy = File('${candidate.path}${Platform.pathSeparator}app${Platform.pathSeparator}main.py');
        if (await mainPy.exists()) return candidate;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    throw Exception('找不到 backend/app/main.py；请从项目根目录运行 Flutter，或把 backend 目录放到 exe 上级目录。');
  }

  static Future<int> _pickFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static List<_PythonCandidate> _pythonCandidates(Directory backendDir) {
    final sep = Platform.pathSeparator;
    final venvPython = File('${backendDir.path}$sep.venv${sep}Scripts${sep}python.exe');
    final result = <_PythonCandidate>[];
    if (venvPython.existsSync()) {
      result.add(_PythonCandidate(venvPython.path));
    }
    result.add(const _PythonCandidate('python'));
    result.add(const _PythonCandidate('py', ['-3']));
    return result;
  }

  Future<void> _waitUntilReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      final exitFuture = process.exitCode.timeout(
        const Duration(milliseconds: 10),
        onTimeout: () => -999999,
      );
      final exitCode = await exitFuture;
      if (exitCode != -999999) {
        throw Exception('easy-tdx 本地服务提前退出，exitCode=$exitCode，stderr=${_stderr.toString()}');
      }

      try {
        final client = HttpClient();
        final request = await client
            .getUrl(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(milliseconds: 700));
        final response = await request.close().timeout(const Duration(milliseconds: 700));
        client.close(force: true);
        if (response.statusCode >= 200 && response.statusCode < 300) return;
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    dispose();
    throw Exception('easy-tdx 本地服务启动超时：$lastError，stderr=${_stderr.toString()}');
  }

  void dispose() {
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    });
  }
}

class _PythonCandidate {
  final String executable;
  final List<String> prefixArgs;

  const _PythonCandidate(this.executable, [this.prefixArgs = const []]);
}
