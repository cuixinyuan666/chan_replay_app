import 'dart:async';
import 'dart:collection';
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

class _LazyMultiLevelFrameList extends ListBase<MultiLevelChanSnapshot> {
  final List<dynamic> rawFrames;
  final Object? baseLevels;
  final Map<String, dynamic> timeLog;
  final Map<int, MultiLevelChanSnapshot> _cache = <int, MultiLevelChanSnapshot>{};

  _LazyMultiLevelFrameList({
    required this.rawFrames,
    required this.baseLevels,
    required this.timeLog,
  });

  @override
  int get length => rawFrames.length;

  @override
  set length(int newLength) => throw UnsupportedError('Lazy frame list length is fixed.');

  @override
  MultiLevelChanSnapshot operator [](int index) {
    final cached = _cache[index];
    if (cached != null) {
      timeLog['lazy_frame_cache_hits'] = _toInt(timeLog['lazy_frame_cache_hits']) + 1;
      return cached;
    }
    if (index < 0 || index >= rawFrames.length) {
      throw RangeError.index(index, this, 'index', null, rawFrames.length);
    }
    final sw = Stopwatch()..start();
    final parsed = MultiLevelChanAnalysisParser.parseFrame(
      rawFrames[index],
      baseLevels: baseLevels,
      parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
    );
    sw.stop();
    if (parsed == null) {
      throw StateError('Failed to parse compact frame at index $index');
    }
    final enriched = _withMeta(parsed, {
      'time_log': timeLog,
      'time_log_frame_index': index,
      'lazy_frame_cache_hit': false,
    });
    _cache[index] = enriched;
    timeLog['lazy_frame_cache_misses'] = _toInt(timeLog['lazy_frame_cache_misses']) + 1;
    timeLog['parsed_frame_count'] = _cache.length;
    timeLog['lazy_frame_parse_ms'] = _toInt(timeLog['lazy_frame_parse_ms']) + sw.elapsedMilliseconds;
    timeLog['lazy_frame_last_index'] = index;
    timeLog['lazy_frame_last_parse_ms'] = sw.elapsedMilliseconds;
    return enriched;
  }

  @override
  void operator []=(int index, MultiLevelChanSnapshot value) {
    throw UnsupportedError('Lazy frame list is read-only.');
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static MultiLevelChanSnapshot _withMeta(
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
}

class PythonMultiLevelChanAnalysisSource {
  static AppBundledPythonBackendProcess? _sharedLocalProcess;
  static Future<AppBundledPythonBackendProcess>? _sharedStartup;

  final String baseUrl;
  final http.Client _client;

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
    final sourceBase = Platform.isWindows
        ? await _readyAppManagedBaseUrl(stages)
        : baseUrl;
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

  Future<String> _readyAppManagedBaseUrl(Map<String, int> stages) async {
    final readySw = Stopwatch()..start();
    var reused = _sharedLocalProcess != null;
    final startOrReuseSw = Stopwatch()..start();
    if (!reused) {
      _sharedStartup ??= AppBundledPythonBackend.start(
        requireAnalyzeMulti: true,
      );
      try {
        _sharedLocalProcess = await _sharedStartup;
      } catch (_) {
        _sharedLocalProcess = null;
        rethrow;
      } finally {
        _sharedStartup = null;
      }
    }
    startOrReuseSw.stop();
    stages['frontend.backend_ready.start_or_reuse'] = startOrReuseSw.elapsedMilliseconds;

    final healthSw = Stopwatch()..start();
    if (reused) {
      try {
        await _sharedLocalProcess!.refreshHealth();
      } catch (_) {
        _sharedLocalProcess?.dispose();
        _sharedLocalProcess = null;
        reused = false;
        _sharedStartup = AppBundledPythonBackend.start(
          requireAnalyzeMulti: true,
        );
        try {
          _sharedLocalProcess = await _sharedStartup;
        } finally {
          _sharedStartup = null;
        }
      }
    }
    healthSw.stop();
    stages['frontend.backend_ready.health_check'] = healthSw.elapsedMilliseconds;

    readySw.stop();
    _sharedLocalProcess!.markRequest(
      reused: reused,
      backendReadyElapsedMs: readySw.elapsedMilliseconds,
    );
    return _sharedLocalProcess!.baseUrl;
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
      backendDiagnostics: _sharedLocalProcess?.diagnostics,
      traceId: traceId,
      totalSw: totalSw,
      stages: stages,
      requestContext: requestContext,
      responseBytes: response.bodyBytes.length,
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
    required int responseBytes,
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
    final topParseSw = Stopwatch()..start();
    final snapshot = MultiLevelChanAnalysisParser.parseSnapshot(
      decoded,
      parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
    );
    stages['frontend.parse.top_snapshot'] = topParseSw.elapsedMilliseconds;
    if (snapshot == null) {
      throw const FormatException('chan.py multi-level response missing levels structure');
    }

    final decodedMeta = decoded['meta'] is Map
        ? Map<String, dynamic>.from(decoded['meta'] as Map)
        : const <String, dynamic>{};
    final rawFrames = decoded['frames'];
    final rawFrameCount = rawFrames is List ? rawFrames.length : 0;
    final useLazyFrames = rawFrameCount > 0 &&
        '${decodedMeta['step_frame_format'] ?? ''}'.trim() == 'compact_v1';

    late final List<MultiLevelChanSnapshot> frames;
    final framesParseSw = Stopwatch()..start();
    if (useLazyFrames) {
      frames = _LazyMultiLevelFrameList(
        rawFrames: List<dynamic>.from(rawFrames as List),
        baseLevels: decoded['levels'],
        timeLog: <String, dynamic>{},
      );
    } else {
      frames = MultiLevelChanAnalysisParser.parseFrames(
        rawFrames,
        baseLevels: decoded['levels'],
        parseSingleLevelSnapshot: ChanSnapshotJsonParser.parse,
      );
    }
    stages['frontend.parse.frames'] = framesParseSw.elapsedMilliseconds;

    final signalsParseSw = Stopwatch()..start();
    final intervalSignals = _parseIntervalNestSignals(
      decoded['interval_nest_signals'] ?? decoded['intervalNestSignals'],
    );
    stages['frontend.parse.interval_signals'] = signalsParseSw.elapsedMilliseconds;
    stages['frontend.parse.snapshot_frames_relations_bsp'] = parseSw.elapsedMilliseconds;

    final meta = Map<String, dynamic>.from(decodedMeta);
    meta['raw_frame_count'] = rawFrameCount;
    meta['parsed_frame_count'] = useLazyFrames ? 0 : frames.length;
    meta['parsed_level_count'] = snapshot.levels.length;
    meta['lazy_frame_parsing'] = useLazyFrames;
    meta['lazy_frame_cache_hits'] = 0;
    meta['lazy_frame_cache_misses'] = 0;
    meta['lazy_frame_parse_ms'] = 0;
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
      responseBytes: responseBytes,
    );
    meta['time_log'] = timeLog;
    final enrichedSnapshot = _snapshotWithMeta(snapshot, {'time_log': timeLog});
    final List<MultiLevelChanSnapshot> enrichedFrames;
    if (frames is _LazyMultiLevelFrameList) {
      final lazyFrames = frames as _LazyMultiLevelFrameList;
      lazyFrames.timeLog.addAll(timeLog);
      enrichedFrames = lazyFrames;
    } else {
      enrichedFrames = [
        for (var i = 0; i < frames.length; i++)
          _snapshotWithMeta(frames[i], {
            'time_log': timeLog,
            'time_log_frame_index': i,
          }),
      ];
    }
    return PythonMultiLevelChanAnalysis(
      snapshot: enrichedSnapshot,
      frames: enrichedFrames,
      intervalNestSignals: intervalSignals,
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
    required int responseBytes,
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
      'response_bytes': responseBytes,
      'raw_frame_count': meta['raw_frame_count'],
      'parsed_frame_count': meta['parsed_frame_count'],
      'parsed_level_count': meta['parsed_level_count'],
      'lazy_frame_parsing': meta['lazy_frame_parsing'],
      'lazy_frame_cache_hits': meta['lazy_frame_cache_hits'],
      'lazy_frame_cache_misses': meta['lazy_frame_cache_misses'],
      'lazy_frame_parse_ms': meta['lazy_frame_parse_ms'],
      'backend_process_pid': runtime['backend_process_pid'],
      'backend_process_start_count': runtime['backend_process_start_count'],
      'backend_process_started_at': runtime['backend_process_started_at'],
      'backend_process_ready_at': runtime['backend_process_ready_at'],
      'backend_process_uptime_ms': runtime['backend_process_uptime_ms'],
      'backend_startup_elapsed_ms': runtime['backend_startup_elapsed_ms'],
      'backend_last_health_check_elapsed_ms': runtime['backend_last_health_check_elapsed_ms'],
      'backend_health_check_count': runtime['backend_health_check_count'],
      'backend_request_count': runtime['backend_request_count'],
      'backend_last_request_reused': runtime['backend_last_request_reused'],
      'backend_last_ready_elapsed_ms': runtime['backend_last_ready_elapsed_ms'],
      'stages': Map<String, int>.from(stages),
      'used_app_bundled_python': (meta['python_runtime'] ?? runtime['python_runtime']) == 'app_bundled',
      'native_cchan_lv_list': meta['native_cchan_lv_list'],
      'fallback_to_bridge': meta['fallback_to_bridge'] ?? false,
      'step_frame_format': meta['step_frame_format'],
      'frame_policy': meta['frame_policy'],
      'frame_stride': meta['frame_stride'],
      'frames_total': meta['frames_total'],
      'frames_returned': meta['frames_returned'],
      'frames_truncated': meta['frames_truncated'],
      'include_bars_in_frames': meta['include_bars_in_frames'],
      'include_indicators_in_frames': meta['include_indicators_in_frames'],
      'compact_validation_status': meta['compact_validation_status'],
      'compact_validation_mismatch_count': meta['compact_validation_mismatch_count'],
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
      baseLevels: data['levels'],
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
    // The app-managed Python backend is intentionally shared across source/page
    // rebuilds during the app session so F1d warm backend reuse can work.
  }
}
