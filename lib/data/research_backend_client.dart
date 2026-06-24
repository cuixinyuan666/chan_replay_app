import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/services/replay_analysis_store.dart';

class ResearchBackendClient {
  final String baseUrl;
  final http.Client _client;
  _ResearchLocalPythonProcess? _localProcess;

  ResearchBackendClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> payload) async {
    final sourceBase = await _readyBaseUrl();
    try {
      final result = await _postToBase(sourceBase, endpoint, payload);
      return _finalizeResult(endpoint, payload, result);
    } on _ResearchBackendMismatch catch (_) {
      final result = await _postViaAutoLocalBackend(endpoint, payload);
      return _finalizeResult(endpoint, payload, result);
    } on SocketException catch (_) {
      final result = await _postViaAutoLocalBackend(endpoint, payload);
      return _finalizeResult(endpoint, payload, result);
    } on TimeoutException catch (_) {
      final result = await _postViaAutoLocalBackend(endpoint, payload);
      return _finalizeResult(endpoint, payload, result);
    } on http.ClientException catch (e) {
      if (!_looksLikeConnectionFailure(e)) rethrow;
      final result = await _postViaAutoLocalBackend(endpoint, payload);
      return _finalizeResult(endpoint, payload, result);
    }
  }

  Map<String, dynamic> _finalizeResult(
    String endpoint,
    Map<String, dynamic> payload,
    Map<String, dynamic> result,
  ) {
    if (result['ok'] != false) {
      _cacheAnalyzeMultiIfNeeded(endpoint, payload, result);
    }
    _recordBacktestIfNeeded(endpoint, payload, result);
    return result;
  }

  void _cacheAnalyzeMultiIfNeeded(
    String endpoint,
    Map<String, dynamic> payload,
    Map<String, dynamic> result,
  ) {
    if (!endpoint.endsWith('/chan/analyze_multi')) return;
    final levels = result['levels'];
    if (levels is! Map) return;
    final level = _payloadLevel(payload);
    final rawLevel = _levelPayload(levels, level);
    if (rawLevel is! Map) return;
    final analysis = Map<String, dynamic>.from(rawLevel);
    final meta = analysis['meta'] is Map
        ? Map<String, dynamic>.from(analysis['meta'] as Map)
        : <String, dynamic>{};
    final symbol = _payloadString(payload, const ['symbol']) ??
        _payloadString(result, const ['meta', 'symbol']) ??
        _payloadString(result, const ['symbol']) ??
        '';
    final market = _payloadString(payload, const ['market']) ??
        _payloadString(result, const ['meta', 'market']) ??
        _payloadString(result, const ['market']) ??
        '';
    final adjust = _payloadString(payload, const ['adjust']) ??
        _payloadString(result, const ['meta', 'adjust']) ??
        _payloadString(result, const ['adjust']) ??
        'QFQ';
    meta.addAll({
      'symbol': symbol,
      'market': market,
      'freq': level,
      'period': level,
      'adjust': adjust,
      'levels': _payloadLevels(payload, fallback: level),
      'main_level': level,
      'source': 'research_backend_client.analyze_multi_cache',
      'research_cache_from_analyze_multi': true,
      'chan_py_polluted': false,
    });
    analysis['meta'] = meta;
    analysis['symbol'] = symbol;
    analysis['market'] = market;
    analysis['freq'] = level;
    analysis['period'] = level;
    analysis['adjust'] = adjust;
    if (analysis['bsp'] is! List && analysis['bsps'] is List) {
      analysis['bsp'] = analysis['bsps'];
    }
    if (analysis['seg_bsp_history_layers'] == null &&
        analysis['seg_bsp_layers'] != null) {
      analysis['seg_bsp_history_layers'] = analysis['seg_bsp_layers'];
    }
    ReplayAnalysisStore.saveLatestAnalysis(analysis);
  }

  void _recordBacktestIfNeeded(
      String endpoint, Map<String, dynamic> payload, Map<String, dynamic> result) {
    if (result['ok'] == false) return;
    if (!endpoint.endsWith('/backtest')) return;
    // Pipeline records are still added by the research page so the UI can label
    // them as a complete features -> scores -> backtest run without duplicates.
    if (endpoint.endsWith('/pipeline')) return;
    final isSegComposite = endpoint.endsWith('/seg-composite/backtest');
    ReplayAnalysisStore.addBacktestRecord(BacktestRecord.fromResearchResult(
      result: result,
      latestAnalysis: ReplayAnalysisStore.latestAnalysis.value,
      source: isSegComposite ? 'seg-composite' : 'bsp-backtest',
      symbol: _payloadString(payload, const ['symbol']) ??
          _payloadString(payload, const ['analysis', 'symbol']) ??
          _payloadString(payload, const ['analysis', 'meta', 'symbol']),
      market: _payloadString(payload, const ['market']) ??
          _payloadString(payload, const ['analysis', 'market']) ??
          _payloadString(payload, const ['analysis', 'meta', 'market']),
      period: _payloadString(payload, const ['level']) ??
          _payloadString(payload, const ['period']) ??
          _payloadString(payload, const ['freq']) ??
          _payloadString(payload, const ['analysis', 'period']) ??
          _payloadString(payload, const ['analysis', 'freq']) ??
          _payloadString(payload, const ['analysis', 'meta', 'period']) ??
          _payloadString(payload, const ['analysis', 'meta', 'freq']),
    ));
  }

  Future<String> _readyBaseUrl() async {
    try {
      await _assertCompatibleBackend(baseUrl);
      return baseUrl;
    } catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess = await _ResearchLocalPythonProcess.start();
      return _localProcess!.baseUrl;
    }
  }

  Future<Map<String, dynamic>> _postViaAutoLocalBackend(
      String endpoint, Map<String, dynamic> payload) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
          'Automatic local Python backend startup is only supported on Windows');
    }
    _localProcess = await _ResearchLocalPythonProcess.start();
    return _postToBase(_localProcess!.baseUrl, endpoint, payload);
  }

  Future<Map<String, dynamic>> _postToBase(String sourceBaseUrl,
      String endpoint, Map<String, dynamic> payload) async {
    await _assertCompatibleBackend(sourceBaseUrl);
    final uri = Uri.parse(_join(sourceBaseUrl, endpoint));
    final timeout = endpoint.endsWith('/seg-composite/backtest') ||
            endpoint.endsWith('/chan/analyze_multi')
        ? const Duration(minutes: 5)
        : const Duration(seconds: 60);
    final response = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 404 && _canAutoFallback(sourceBaseUrl)) {
      throw _ResearchBackendMismatch(
          'localhost backend does not expose research API: $body');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Research API response is not a JSON object');
  }

  Future<void> _assertCompatibleBackend(String sourceBaseUrl) async {
    if (!_canAutoFallback(sourceBaseUrl)) return;
    final uri = Uri.parse(_join(sourceBaseUrl, '/health'));
    final response = await _client.get(uri).timeout(const Duration(seconds: 3));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _ResearchBackendMismatch(
          'localhost /health returned ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _ResearchBackendMismatch(
          'localhost /health is not a JSON object');
    }
    if (decoded['backend'] != 'origin_vespa_tdx' ||
        decoded['engine'] != 'chan.py' ||
        decoded['research_api'] != true) {
      throw _ResearchBackendMismatch(
          'localhost backend is not the origin_vespa_tdx research backend: $body');
    }
  }

  bool _canAutoFallback(String sourceBaseUrl) {
    if (!Platform.isWindows) return false;
    final uri = Uri.tryParse(sourceBaseUrl);
    return uri != null &&
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' ||
            uri.host == 'localhost' ||
            uri.host == '::1');
  }

  bool _looksLikeConnectionFailure(http.ClientException e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('connection refused') ||
        msg.contains('connection failed') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('remote computer refused') ||
        msg.contains('远程计算机拒绝网络连接');
  }

  String _join(String base, String path) =>
      '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path';

  void close() {
    _client.close();
    _localProcess?.dispose();
    _localProcess = null;
  }
}

String? _payloadString(Map<String, dynamic> payload, List<String> path) {
  Object? cursor = payload;
  for (final part in path) {
    if (cursor is! Map) return null;
    cursor = cursor[part];
  }
  final text = '${cursor ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String _payloadLevel(Map<String, dynamic> payload) {
  final direct = _payloadString(payload, const ['level']) ??
      _payloadString(payload, const ['freq']) ??
      _payloadString(payload, const ['period']) ??
      _payloadString(payload, const ['main_level']) ??
      _payloadString(payload, const ['mainLevel']);
  if (direct != null) return direct.trim().toUpperCase();
  final levels = payload['levels'] ?? payload['lv_list'] ?? payload['level_order'];
  if (levels is List && levels.isNotEmpty) {
    final first = '${levels.first}'.trim();
    if (first.isNotEmpty && first != 'null') return first.toUpperCase();
  }
  return 'MIN5';
}

List<String> _payloadLevels(Map<String, dynamic> payload, {required String fallback}) {
  final levels = payload['levels'] ?? payload['lv_list'] ?? payload['level_order'];
  if (levels is List) {
    final rows = [
      for (final level in levels)
        if ('${level}'.trim().isNotEmpty && '${level}'.trim() != 'null')
          '${level}'.trim().toUpperCase(),
    ];
    if (rows.isNotEmpty) return rows;
  }
  return [fallback];
}

Object? _levelPayload(Map levels, String level) {
  final direct = levels[level] ?? levels[level.toUpperCase()] ?? levels[level.toLowerCase()];
  if (direct != null) return direct;
  for (final entry in levels.entries) {
    if ('${entry.key}'.trim().toUpperCase() == level) return entry.value;
  }
  return null;
}

class _ResearchBackendMismatch implements Exception {
  final String message;

  const _ResearchBackendMismatch(this.message);

  @override
  String toString() => message;
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
    final backendMain = await _findBackendMain();
    final repoRoot = backendMain.parent.parent.parent.path;
    final port = await _pickFreePort();
    final baseUrl = 'http://127.0.0.1:$port';
    final candidates = _pythonCandidates(repoRoot);
    Object? lastError;
    for (final candidate in candidates) {
      try {
        final process = await Process.start(
          candidate.executable,
          [
            '-m',
            'uvicorn',
            'backend.app.main:app',
            '--host',
            '127.0.0.1',
            '--port',
            '$port',
          ],
          workingDirectory: repoRoot,
          runInShell: false,
          environment: {'PYTHONIOENCODING': 'utf-8'},
          mode: ProcessStartMode.normal,
        );
        final runner = _ResearchLocalPythonProcess._(process, baseUrl);
        await runner._waitUntilReady();
        return runner;
      } catch (e) {
        lastError = '${candidate.executable}: $e';
      }
    }
    throw Exception(
        'Unable to start bundled Python backend via uvicorn. Last error: $lastError');
  }

  static Future<File> _findBackendMain() async {
    final checked = <String>{};
    final starts = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in starts) {
      var dir = start.absolute;
      for (var i = 0; i < 12; i++) {
        if (!checked.add(dir.path)) break;
        for (final candidate in _backendMainCandidatesFrom(dir)) {
          if (await candidate.exists()) return candidate;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    throw const FileSystemException('Cannot locate backend/app/main.py');
  }

  static Iterable<File> _backendMainCandidatesFrom(Directory dir) sync* {
    yield File('${dir.path}/backend/app/main.py');
    yield File('${dir.path}/../backend/app/main.py');
    yield File('${dir.path}/../../backend/app/main.py');
  }

  static List<_PythonCandidate> _pythonCandidates(String repoRoot) {
    final localVenv = File('$repoRoot/.venv/Scripts/python.exe');
    return [
      _PythonCandidate(localVenv.path),
      const _PythonCandidate('python'),
      const _PythonCandidate('py'),
    ];
  }

  static Future<int> _pickFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<void> _waitUntilReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final client = http.Client();
        try {
          final response = await client
              .get(Uri.parse('$baseUrl/health'))
              .timeout(const Duration(milliseconds: 800));
          if (response.statusCode == 200) return;
        } finally {
          client.close();
        }
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    dispose();
    throw TimeoutException(
        'Bundled Python backend did not become ready: $lastError\n$_stderr');
  }

  void dispose() {
    process.kill();
  }
}

class _PythonCandidate {
  final String executable;
  const _PythonCandidate(this.executable);
}
