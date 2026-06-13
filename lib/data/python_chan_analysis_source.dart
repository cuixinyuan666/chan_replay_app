import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/models/chan_snapshot.dart';
import '../core/models/raw_bar.dart';
import '../core/services/replay_analysis_store.dart';
import 'chan_snapshot_json_parser.dart';

class PythonChanAnalysis {
  final ChanSnapshot snapshot;
  final List<ChanSnapshot> frames;
  final Map<String, dynamic> meta;

  const PythonChanAnalysis({
    required this.snapshot,
    this.frames = const [],
    this.meta = const {},
  });
}

class PythonChanAnalysisSource {
  static const MethodChannel _androidChanChannel =
      MethodChannel('chan_replay_app/python_chan');

  final String baseUrl;
  final http.Client _client;
  _LocalPythonChanProcess? _localProcess;

  PythonChanAnalysisSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<PythonChanAnalysis> analyze({
    required String mode,
    required String market,
    required String code,
    required String period,
    required String adjust,
    required Map<String, dynamic> config,
    int? count,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final payload = <String, dynamic>{
      'mode': mode,
      'symbol': code.trim(),
      'market': market.trim().toUpperCase(),
      'freq': period.trim().toUpperCase(),
      'adjust': adjust.trim().toUpperCase(),
      'config': config,
      if (count != null) 'count': count,
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    };

    if (Platform.isAndroid) return _loadViaAndroid(payload);

    final query = <String, String>{
      for (final entry in payload.entries)
        if (entry.key != 'config') entry.key: '${entry.value}',
      for (final entry in config.entries) entry.key: '${entry.value}',
    };
    try {
      return await _loadFromBase(baseUrl, query);
    } on _PythonChanBackendMismatch catch (_) {
      return _loadViaAutoLocalBackend(query);
    } on SocketException catch (_) {
      return _loadViaAutoLocalBackend(query);
    } on TimeoutException catch (_) {
      return _loadViaAutoLocalBackend(query);
    } on http.ClientException catch (e) {
      if (!_looksLikeConnectionFailure(e)) rethrow;
      return _loadViaAutoLocalBackend(query);
    }
  }

  Future<PythonChanAnalysis> analyzeBars({
    required String mode,
    required String symbol,
    required String market,
    required String period,
    required String adjust,
    required List<RawBar> bars,
    required Map<String, dynamic> config,
  }) async {
    final payload = <String, dynamic>{
      'mode': mode,
      'symbol': symbol,
      'market': market,
      'freq': period,
      'adjust': adjust,
      'config': config,
      'bars': [for (final bar in bars) _barToJson(bar)],
    };
    if (Platform.isAndroid) return _loadViaAndroid(payload);

    final sourceBase = await _readyBaseUrl();
    final uri = Uri.parse(_join(sourceBase, '/api/chan/analyze_bars'));
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    return _decodeResponse(response);
  }

  Future<PythonChanAnalysis> _loadViaAndroid(
    Map<String, dynamic> payload,
  ) async {
    final result = await _androidChanChannel
        .invokeMethod<String>('analyze', {'payload': jsonEncode(payload)});
    if (result == null || result.trim().isEmpty) {
      throw Exception('Android Chaquopy chan.py 返回为空');
    }
    final decoded = jsonDecode(result);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Android Chaquopy chan.py 返回结构不是 JSON 对象');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? 'Android Chaquopy chan.py 计算失败');
    }
    return _parseAnalysis(decoded, saveLatest: true);
  }

  Future<String> _readyBaseUrl() async {
    try {
      await _assertCompatibleBackend(baseUrl);
      return baseUrl;
    } catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess = await _LocalPythonChanProcess.start();
      return _localProcess!.baseUrl;
    }
  }

  Future<PythonChanAnalysis> _loadViaAutoLocalBackend(
    Map<String, String> query,
  ) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('自动后台启动 Python chan.py 本地服务目前只支持 Windows');
    }
    _localProcess = await _LocalPythonChanProcess.start();
    return _loadFromBase(_localProcess!.baseUrl, query);
  }

  Future<PythonChanAnalysis> _loadFromBase(
    String sourceBaseUrl,
    Map<String, String> query,
  ) async {
    await _assertCompatibleBackend(sourceBaseUrl);
    final uri = Uri.parse(_join(sourceBaseUrl, '/api/chan/analyze'))
        .replace(queryParameters: query);
    final response = await _client.get(uri);
    return _decodeResponse(response, sourceBaseUrl: sourceBaseUrl);
  }

  Future<PythonChanAnalysis> _decodeResponse(
    http.Response response, {
    String? sourceBaseUrl,
  }) async {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (sourceBaseUrl != null &&
          response.statusCode == 404 &&
          _canAutoFallback(sourceBaseUrl)) {
        throw _PythonChanBackendMismatch(
            'localhost 服务不是 origin_vespa_tdx chan.py 后端: $body');
      }
      throw Exception('chan.py 引擎返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('chan.py 引擎返回结构不是 JSON 对象');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? 'chan.py 引擎计算失败');
    }
    return _parseAnalysis(decoded, saveLatest: true);
  }

  Future<void> _assertCompatibleBackend(String sourceBaseUrl) async {
    if (!_canAutoFallback(sourceBaseUrl)) return;
    final uri = Uri.parse(_join(sourceBaseUrl, '/health'));
    final response = await _client.get(uri).timeout(const Duration(seconds: 3));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _PythonChanBackendMismatch(
          'localhost /health 返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _PythonChanBackendMismatch('localhost /health 不是 JSON 对象');
    }
    if (decoded['backend'] != 'origin_vespa_tdx' ||
        decoded['engine'] != 'chan.py') {
      throw _PythonChanBackendMismatch(
          'localhost 服务不是 origin_vespa_tdx chan.py 后端: $body');
    }
  }

  PythonChanAnalysis _parseAnalysis(
    Map<String, dynamic> data, {
    bool saveLatest = false,
  }) {
    if (saveLatest) ReplayAnalysisStore.saveLatestAnalysis(data);
    final snapshot = ChanSnapshotJsonParser.parse(data);
    final frames = <ChanSnapshot>[];
    final rawFrames = data['frames'];
    if (rawFrames is List) {
      for (final frame in rawFrames) {
        if (frame is Map<String, dynamic>) {
          frames.add(ChanSnapshotJsonParser.parse(frame));
        } else if (frame is Map) {
          frames.add(ChanSnapshotJsonParser.parse(Map<String, dynamic>.from(frame)));
        }
      }
    }
    return PythonChanAnalysis(
      snapshot: snapshot,
      frames: frames,
      meta: data['meta'] is Map
          ? Map<String, dynamic>.from(data['meta'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> _barToJson(RawBar bar) => {
        'dt': _fmtDate(bar.time),
        'open': bar.open,
        'high': bar.high,
        'low': bar.low,
        'close': bar.close,
        'vol': bar.volume,
      };

  String _join(String base, String path) =>
      '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}$path';

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
        msg.contains('connection closed');
  }

  void close() {
    _client.close();
    _localProcess?.dispose();
    _localProcess = null;
  }
}

class _LocalPythonChanProcess {
  final Process process;
  final String baseUrl;
  final StringBuffer _stderr = StringBuffer();

  _LocalPythonChanProcess._(this.process, this.baseUrl) {
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
    process.stdout.transform(utf8.decoder).listen((_) {});
  }

  static Future<_LocalPythonChanProcess> start() async {
    final appEngine = await _findAppEngine();
    final port = await _pickFreePort();
    final baseUrl = 'http://127.0.0.1:$port';
    final candidates = _pythonCandidates(appEngine);
    Object? lastError;
    for (final candidate in candidates) {
      try {
        final process = await Process.start(
          candidate.executable,
          [appEngine.path, '--host', '127.0.0.1', '--port', '$port'],
          workingDirectory: appEngine.parent.parent.path,
          runInShell: false,
          environment: {'PYTHONIOENCODING': 'utf-8'},
          mode: ProcessStartMode.normal,
        );
        final runner = _LocalPythonChanProcess._(process, baseUrl);
        await runner._waitUntilReady();
        return runner;
      } catch (e) {
        lastError = '${candidate.executable}: $e';
      }
    }
    throw Exception(
        '无法后台启动 Python chan.py 本地服务。仅允许使用内置 Python：python/python.exe。最后错误：$lastError');
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

  static Future<int> _pickFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static List<_PythonCandidate> _pythonCandidates(File appEngine) {
    final sep = Platform.pathSeparator;
    final bundledPython = File('${appEngine.parent.path}${sep}python.exe');
    if (!bundledPython.existsSync()) {
      throw Exception('找不到内置 Python：${bundledPython.path}');
    }
    return [_PythonCandidate(bundledPython.path)];
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

class _PythonCandidate {
  final String executable;
  const _PythonCandidate(this.executable);
}

class _PythonChanBackendMismatch implements Exception {
  final String message;
  const _PythonChanBackendMismatch(this.message);
  @override
  String toString() => message;
}
