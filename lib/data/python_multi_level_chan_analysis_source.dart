import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_bundled_python_backend.dart';
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
  AppBundledPythonBackendProcess? _localProcess;

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
      throw UnsupportedError(
        'Multi-level analyze_multi is not wired to Android MethodChannel yet.',
      );
    }

    final sourceBase =
        Platform.isWindows ? await _readyAppManagedBaseUrl() : baseUrl;
    return _postAnalyzeMulti(sourceBase, payload);
  }

  Future<String> _readyAppManagedBaseUrl() async {
    _localProcess ??= await AppBundledPythonBackend.start(
      requireAnalyzeMulti: true,
    );
    return _localProcess!.baseUrl;
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
            'analyze_multi ${payload['mode'] ?? ''} timed out after ${timeout.inSeconds}s, uri=$uri. '
            'For step replay, lower count/max_step_frames; for signal search, use Scan Signal once mode.',
            timeout,
          ),
        );
    return _decodeResponse(
      response,
      sourceBaseUrl: sourceBase,
      backendDiagnostics: _localProcess?.diagnostics,
    );
  }

  Duration _requestTimeout(Map<String, dynamic> payload) {
    final mode = '${payload['mode'] ?? ''}'.toLowerCase();
    final count = payload['count'] is int ? payload['count'] as int : 0;
    if (mode == 'step') return const Duration(seconds: 180);
    if (count >= 300) return const Duration(seconds: 180);
    return const Duration(seconds: 90);
  }

  PythonMultiLevelChanAnalysis _decodeResponse(
    http.Response response, {
    String? sourceBaseUrl,
    Map<String, dynamic>? backendDiagnostics,
  }) {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 404) {
        throw Exception(
          'Blocked: backend is missing /api/chan/analyze_multi: ${sourceBaseUrl ?? baseUrl}. Response: $body',
        );
      }
      throw Exception(
        'chan.py multi-level engine returned ${response.statusCode}: $body',
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'chan.py multi-level engine did not return a JSON object.',
      );
    }
    if (decoded['ok'] == false) {
      throw Exception(
          decoded['error'] ?? 'chan.py multi-level calculation failed.');
    }
    final analysis = parse(decoded);
    if (backendDiagnostics == null) return analysis;
    final meta = Map<String, dynamic>.from(analysis.meta);
    meta['backend_runtime'] = backendDiagnostics;
    meta['backend_url'] = backendDiagnostics['backend_url'];
    meta['python_runtime'] = backendDiagnostics['python_runtime'];
    return PythonMultiLevelChanAnalysis(
      snapshot: analysis.snapshot,
      frames: analysis.frames,
      intervalNestSignals: analysis.intervalNestSignals,
      meta: meta,
    );
  }

  static PythonMultiLevelChanAnalysis parse(Map<String, dynamic> data) {
    final snapshot = MultiLevelChanAnalysisParser.parseSnapshot(
      data,
      parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
    );
    if (snapshot == null) {
      throw const FormatException('chan.py 澶氱骇鍒繑鍥炵己灏?levels 缁撴瀯');
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
        result
            .add(IntervalNestSignal.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _trimTrailingSlash(String raw) =>
      raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

  void close() {
    _client.close();
    _localProcess?.dispose();
    _localProcess = null;
  }
}
