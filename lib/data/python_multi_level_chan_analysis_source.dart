import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/models/interval_nest_signal.dart';
import '../core/models/multi_level_chan_snapshot.dart';
import 'chan_snapshot_json_parser.dart';
import 'multi_level_chan_analysis_parser.dart';

class PythonMultiLevelChanAnalysis {
  final MultiLevelChanSnapshot snapshot;
  final List<MultiLevelChanSnapshot> frames;
  final List<IntervalNestSignal> intervalNestSignals;
  final Map<String, dynamic> meta;

  const PythonMultiLevelChanAnalysis({
    required this.snapshot,
    this.frames = const [],
    this.intervalNestSignals = const [],
    this.meta = const {},
  });

  bool get hasFrames => frames.isNotEmpty;
  bool get hasSignals => intervalNestSignals.isNotEmpty;
}

class PythonMultiLevelChanAnalysisSource {
  final String baseUrl;
  final http.Client _client;
  _LocalPythonMultiLevelChanProcess? _localProcess;

  PythonMultiLevelChanAnalysisSource({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<PythonMultiLevelChanAnalysis> analyzeMulti({
    required String mode,
    required String market,
    required String code,
    required List<String> levels,
    required String adjust,
    required Map<String, dynamic> config,
    String? mainLevel,
    String? clockLevel,
    int? count,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final payload = <String, dynamic>{
      'mode': mode,
      'symbol': code.trim(),
      'market': market.trim().toUpperCase(),
      'lv_list': [
        for (final level in levels)
          if (level.trim().isNotEmpty) level.trim().toUpperCase(),
      ],
      'adjust': adjust.trim().toUpperCase(),
      'config': config,
      if (mainLevel != null && mainLevel.trim().isNotEmpty)
        'main_level': mainLevel.trim().toUpperCase(),
      if (clockLevel != null && clockLevel.trim().isNotEmpty)
        'clock_level': clockLevel.trim().toUpperCase(),
      if (count != null) 'count': count,
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    };

    if (Platform.isAndroid) {
      throw UnsupportedError('多级别 analyze_multi 尚未接入 Android MethodChannel');
    }

    try {
      final sourceBase = await _readyBaseUrl(baseUrl);
      return await _postAnalyzeMulti(sourceBase, payload);
    } on _PythonMultiLevelBackendMismatch catch (_) {
      return _loadViaAutoLocalBackend(payload);
    } on SocketException catch (_) {
      return _loadViaAutoLocalBackend(payload);
    } on TimeoutException catch (_) {
      return _loadViaAutoLocalBackend(payload);
    } on http.ClientException catch (e) {
      if (!_looksLikeConnectionFailure(e)) rethrow;
      return _loadViaAutoLocalBackend(payload);
    }
  }

  Future<String> _readyBaseUrl(String sourceBaseUrl) async {
    try {
      await _assertCompatibleBackend(sourceBaseUrl);
      return sourceBaseUrl;
    } catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess = await _LocalPythonMultiLevelChanProcess.start();
      return _localProcess!.baseUrl;
    }
  }

  Future<PythonMultiLevelChanAnalysis> _loadViaAutoLocalBackend(
      Map<String, dynamic> payload) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('自动后台启动 Python chan.py 本地服务目前只支持 Windows');
    }
    _localProcess = await _LocalPythonMultiLevelChanProcess.start();
    return _postAnalyzeMulti(_localProcess!.baseUrl, payload);
  }

  Future<PythonMultiLevelChanAnalysis> _postAnalyzeMulti(
    String sourceBaseUrl,
    Map<String, dynamic> payload,
  ) async {
    final sourceBase = _trimTrailingSlash(sourceBaseUrl);
    final uri = Uri.parse('$sourceBase/api/chan/analyze_multi');
    final response = await _client
        .post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60));
    return _decodeResponse(response, sourceBaseUrl: sourceBase);
  }

  PythonMultiLevelChanAnalysis _decodeResponse(http.Response response,
      {String? sourceBaseUrl}) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (sourceBaseUrl != null &&
          response.statusCode == 404 &&
          _canAutoFallback(sourceBaseUrl)) {
        throw _PythonMultiLevelBackendMismatch(
            'localhost 服务没有 /api/chan/analyze_multi: $body');
      }
      throw Exception('chan.py 多级别引擎返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('chan.py 多级别引擎返回结构不是 JSON 对象');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? 'chan.py 多级别引擎计算失败');
    }
    return parse(decoded);
  }

  Future<void> _assertCompatibleBackend(String sourceBaseUrl) async {
    if (!_canAutoFallback(sourceBaseUrl)) return;
    final uri = Uri.parse('${_trimTrailingSlash(sourceBaseUrl)}/health');
    final response = await _client.get(uri).timeout(const Duration(seconds: 3));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _PythonMultiLevelBackendMismatch(
          'localhost /health 返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _PythonMultiLevelBackendMismatch('localhost /health 不是 JSON 对象');
    }
    if (decoded['backend'] != 'origin_vespa_tdx' || decoded['engine'] != 'chan.py') {
      throw _PythonMultiLevelBackendMismatch(
          'localhost 服务不是 origin_vespa_tdx chan.py 后端: $body');
    }
  }

  static PythonMultiLevelChanAnalysis parse(Map<String, dynamic> data) {
    final snapshot = MultiLevelChanAnalysisParser.parseSnapshot(
      data,
      parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
    );
    if (snapshot == null) {
      throw const FormatException('chan.py 多级别返回缺少 levels 结构');
    }

    final frames = MultiLevelChanAnalysisParser.parseFrames(
      data['frames'],
      parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
    );

    return PythonMultiLevelChanAnalysis(
      snapshot: snapshot,
      frames: frames,
      intervalNestSignals: _parseIntervalNestSignals(
        data['interval_nest_signals'] ?? data['intervalNestSignals'],
      ),
      meta: data['meta'] is Map
          ? Map<String, dynamic>.from(data['meta'] as Map)
          : const {},
    );
  }

  static List<IntervalNestSignal> _parseIntervalNestSignals(Object? raw) {
    if (raw is! List) return const [];
    final result = <IntervalNestSignal>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        result.add(IntervalNestSignal.fromJson(item));
      } else if (item is Map) {
        result.add(IntervalNestSignal.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _trimTrailingSlash(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  bool _canAutoFallback(String sourceBaseUrl) {
    if (!Platform.isWindows) return false;
    final uri = Uri.tryParse(sourceBaseUrl);
    return uri != null &&
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1');
  }

  bool _looksLikeConnectionFailure(http.ClientException e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('connection refused') ||
        msg.contains('connection failed') ||
        msg.contains('failed host lookup') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('socketexception') ||
        msg.contains('refused') ||
        msg.contains('errno = 1225') ||
        msg.contains('拒绝') ||
        msg.contains('远程计算机拒绝');
  }

  void close() {
    _client.close();
    _localProcess?.dispose();
    _localProcess = null;
  }
}

class _LocalPythonMultiLevelChanProcess {
  final Process process;
  final String baseUrl;
  final StringBuffer _stderr = StringBuffer();

  _LocalPythonMultiLevelChanProcess._(this.process, this.baseUrl) {
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
    process.stdout.transform(utf8.decoder).listen((_) {});
  }

  static Future<_LocalPythonMultiLevelChanProcess> start() async {
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
        final runner = _LocalPythonMultiLevelChanProcess._(process, baseUrl);
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
      final exitCode = await process.exitCode
          .timeout(const Duration(milliseconds: 10), onTimeout: () => -999999);
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
    throw Exception('Python chan.py 本地服务启动超时：$lastError，stderr=${_stderr.toString()}');
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

class _PythonMultiLevelBackendMismatch implements Exception {
  final String message;
  const _PythonMultiLevelBackendMismatch(this.message);
  @override
  String toString() => message;
}
