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
    final timeout = _requestTimeout(payload);
    final response = await _client
        .post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'analyze_multi ${payload['mode'] ?? ''} 请求超时：${timeout.inSeconds}s，uri=$uri。'
            'step 回放请降低 count / max_step_frames；找信号请使用 Scan Signal/once 扫描，避免返回大量 step frames。',
            timeout,
          ),
        );
    return _decodeResponse(response, sourceBaseUrl: sourceBase);
  }

  Duration _requestTimeout(Map<String, dynamic> payload) {
    final mode = '${payload['mode'] ?? ''}'.toLowerCase();
    final count = payload['count'] is int ? payload['count'] as int : 0;
    if (mode == 'step') return const Duration(seconds: 180);
    if (count >= 300) return const Duration(seconds: 180);
    return const Duration(seconds: 90);
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
    final script = File('python/a_server.py');
    if (!await script.exists()) {
      throw StateError('找不到 python/a_server.py，无法启动本地 chan.py 后端');
    }
    final port = 3714;
    final process = await Process.start(
      'python',
      [script.path, '--host', '127.0.0.1', '--port', '$port'],
      runInShell: true,
    );
    final instance = _LocalPythonMultiLevelChanProcess._(
      process,
      'http://127.0.0.1:$port',
    );
    await Future<void>.delayed(const Duration(milliseconds: 850));
    return instance;
  }

  void dispose() {
    process.kill();
  }
}
