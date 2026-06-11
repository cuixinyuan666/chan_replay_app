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
    final traceId = 'ml-${DateTime.now().microsecondsSinceEpoch}';
    final totalSw = Stopwatch()..start();
    final stages = <String, int>{};

    final requestBuildSw = Stopwatch()..start();
    final normalizedLevels = [
      for (final level in levels)
        if (level.trim().isNotEmpty) level.trim().toUpperCase(),
    ];
    final payload = <String, dynamic>{
      'mode': mode,
      'symbol': code.trim(),
      'market': market.trim().toUpperCase(),
      'lv_list': normalizedLevels,
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
    stages['frontend.request_build'] = requestBuildSw.elapsedMilliseconds;

    if (Platform.isAndroid) {
      throw UnsupportedError(
        'Multi-level analyze_multi is not wired to Android MethodChannel yet.',
      );
    }

    final readySw = Stopwatch()..start();
    final sourceBase =
        Platform.isWindows ? await _readyAppManagedBaseUrl() : baseUrl;
    stages['frontend.backend_ready'] = readySw.elapsedMilliseconds;

    return _postAnalyzeMulti(
      sourceBase,
      payload,
      traceId: traceId,
      totalSw: totalSw,
      stages: stages,
      requestContext: {
        'mode': mode,
        'symbol': code.trim(),
        'market': market.trim().toUpperCase(),
        'levels': normalizedLevels,
        'count': count,
        'max_step_frames': config['max_step_frames'],
        'start': startDate == null ? null : _fmtDate(startDate),
        'end': endDate == null ? null : _fmtDate(endDate),
      },
    );
  }

  Future<String> _readyAppManagedBaseUrl() async {
    _localProcess ??= await AppBundledPythonBackend.start(
      requireAnalyzeMulti: true,
    );
    return _localProcess!.baseUrl;
  }

  Future<PythonMultiLevelChanAnalysis> _postAnalyzeMulti(
    String sourceBaseUrl,
    Map<String, dynamic> payload, {
    required String traceId,
    required Stopwatch totalSw,
    required Map<String, int> stages,
    required Map<String, dynamic> requestContext,
  }) async {
    final sourceBase = _trimTrailingSlash(sourceBaseUrl);
    final uri = Uri.parse('$sourceBase/api/chan/analyze_multi');
    final timeout = _requestTimeout(payload);
    final httpSw = Stopwatch()..start();
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
    stages['frontend.http_round_trip'] = httpSw.elapsedMilliseconds;
    return _decodeResponse(
      response,
      sourceBaseUrl: sourceBase,
      backendDiagnostics: _localProcess?.diagnostics,
      traceId: traceId,
      totalSw: totalSw,
      stages: stages,
      requestContext: requestContext,
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
    required String traceId,
    required Stopwatch totalSw,
    required Map<String, int> stages,
    required Map<String, dynamic> requestContext,
  }) {
    final bodySw = Stopwatch()..start();
    final body = utf8.decode(response.bodyBytes);
    stages['frontend.body_decode'] = bodySw.elapsedMilliseconds;
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
    final jsonSw = Stopwatch()..start();
    final decoded = jsonDecode(body);
    stages['frontend.json_decode'] = jsonSw.elapsedMilliseconds;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'chan.py multi-level engine did not return a JSON object.',
      );
    }
    if (decoded['ok'] == false) {
      throw Exception(
          decoded['error'] ?? 'chan.py multi-level calculation failed.');
    }
    final parseSw = Stopwatch()..start();
    final analysis = parse(decoded);
    stages['frontend.parse.snapshot_frames_relations_bsp'] = parseSw.elapsedMilliseconds;

    final meta = Map<String, dynamic>.from(analysis.meta);
    if (backendDiagnostics != null) {
      meta['backend_runtime'] = backendDiagnostics;
      meta['backend_url'] = backendDiagnostics['backend_url'];
      meta['python_runtime'] = backendDiagnostics['python_runtime'];
    }
    totalSw.stop();
    stages['frontend.total'] = totalSw.elapsedMilliseconds;
    final timeLog = _buildTimeLog(
      traceId: traceId,
      meta: meta,
      stages: stages,
      requestContext: requestContext,
      sourceBaseUrl: sourceBaseUrl,
      backendDiagnostics: backendDiagnostics,
    );
    meta['time_log'] = timeLog;
    final enrichedSnapshot = _snapshotWithMeta(analysis.snapshot, {'time_log': timeLog});
    final enrichedFrames = [
      for (var i = 0; i < analysis.frames.length; i++)
        _snapshotWithMeta(analysis.frames[i], {
          'time_log': timeLog,
          'time_log_frame_index': i,
        }),
    ];
    return PythonMultiLevelChanAnalysis(
      snapshot: enrichedSnapshot,
      frames: enrichedFrames,
      intervalNestSignals: analysis.intervalNestSignals,
      meta: meta,
    );
  }

  MultiLevelChanSnapshot _snapshotWithMeta(
    MultiLevelChanSnapshot snapshot,
    Map<String, dynamic> extraMeta,
  ) {
    final meta = Map<String, dynamic>.from(snapshot.meta)..addAll(extraMeta);
    return MultiLevelChanSnapshot(
      mainLevel: snapshot.mainLevel,
      levels: snapshot.levels,
      snapshots: snapshot.snapshots,
      relations: snapshot.relations,
      meta: meta,
    );
  }

  Map<String, dynamic> _buildTimeLog({
    required String traceId,
    required Map<String, dynamic> meta,
    required Map<String, int> stages,
    required Map<String, dynamic> requestContext,
    String? sourceBaseUrl,
    Map<String, dynamic>? backendDiagnostics,
  }) {
    final frontendTotal = stages['frontend.total'] ?? 0;
    final backendElapsed = _numToInt(meta['backend_elapsed_ms']) ?? stages['frontend.http_round_trip'] ?? 0;
    final runtime = backendDiagnostics ?? const <String, dynamic>{};
    return {
      'trace_id': traceId,
      'mode': requestContext['mode'],
      'symbol': requestContext['symbol'],
      'market': requestContext['market'],
      'levels': requestContext['levels'],
      'count': requestContext['count'],
      'max_step_frames': requestContext['max_step_frames'],
      'start': requestContext['start'],
      'end': requestContext['end'],
      'backend_url': meta['backend_url'] ?? runtime['backend_url'] ?? sourceBaseUrl ?? '',
      'python_runtime': meta['python_runtime'] ?? runtime['python_runtime'] ?? '',
      'process_source': runtime['process_source'] ?? '',
      'total_elapsed_ms': frontendTotal,
      'backend_elapsed_ms': backendElapsed,
      'frontend_elapsed_ms': frontendTotal,
      'stages': Map<String, int>.from(stages),
      'used_app_bundled_python': (meta['python_runtime'] ?? runtime['python_runtime']) == 'app_bundled',
      'native_cchan_lv_list': meta['native_cchan_lv_list'],
      'fallback_to_bridge': meta['fallback_to_bridge'] ?? false,
      'status': 'ok',
    };
  }

  int? _numToInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return null;
  }

  static PythonMultiLevelChanAnalysis parse(Map<String, dynamic> data) {
    final snapshot = MultiLevelChanAnalysisParser.parseSnapshot(
      data,
      parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
    );
    if (snapshot == null) {
      throw const FormatException('chan.py multi-level response missing levels structure');
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
