import 'dart:async';
import 'dart:convert';
import 'dart:io';

class AppBundledPythonBackend {
  static int _startCount = 0;

  static Future<AppBundledPythonBackendProcess> start({
    bool requireAnalyzeMulti = false,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'App-managed bundled Python backend startup is only supported on Windows.',
      );
    }
    final startupSw = Stopwatch()..start();
    final startSequence = ++_startCount;
    final startedAt = DateTime.now();
    final appEngine = await _findAppEngine();
    final python = _findBundledPython(appEngine);
    final port = await _pickFreePort();
    final baseUrl = 'http://127.0.0.1:$port';
    final process = await Process.start(
      python.path,
      [appEngine.path, '--host', '127.0.0.1', '--port', '$port'],
      workingDirectory: appEngine.parent.parent.path,
      runInShell: false,
      environment: {'PYTHONIOENCODING': 'utf-8'},
      mode: ProcessStartMode.normal,
    );
    final runner = AppBundledPythonBackendProcess._(
      process: process,
      baseUrl: baseUrl,
      pythonPath: python.path,
      appEnginePath: appEngine.path,
      requireAnalyzeMulti: requireAnalyzeMulti,
      startSequence: startSequence,
      startedAt: startedAt,
    );
    try {
      await runner.waitUntilReady();
      startupSw.stop();
      runner.markStartupReady(startupSw.elapsedMilliseconds);
      return runner;
    } catch (_) {
      runner.dispose();
      rethrow;
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
    throw Exception(
      'Blocked: cannot find App-bundled python/app_engine.py. No external Python fallback is allowed.',
    );
  }

  static List<File> _appEngineCandidatesFrom(Directory dir) {
    final sep = Platform.pathSeparator;
    return [
      File('${dir.path}${sep}python${sep}app_engine.py'),
      File('${dir.path}${sep}data${sep}python${sep}app_engine.py'),
    ];
  }

  static File _findBundledPython(File appEngine) {
    final sep = Platform.pathSeparator;
    final bundledPython = File('${appEngine.parent.path}${sep}python.exe');
    if (!bundledPython.existsSync()) {
      throw Exception(
        'Blocked: cannot find App-bundled Python runtime: ${bundledPython.path}. No external Python fallback is allowed.',
      );
    }
    return bundledPython;
  }

  static Future<int> _pickFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }
}

class AppBundledPythonBackendProcess {
  final Process process;
  final String baseUrl;
  final String pythonPath;
  final String appEnginePath;
  final bool requireAnalyzeMulti;
  final int startSequence;
  final DateTime startedAt;
  final StringBuffer _stderr = StringBuffer();
  Map<String, dynamic> _health = const {};
  DateTime? _readyAt;
  int _startupElapsedMs = 0;
  int _lastHealthCheckElapsedMs = 0;
  int _healthCheckCount = 0;
  int _requestCount = 0;
  int _lastBackendReadyElapsedMs = 0;
  bool _lastRequestReused = false;

  AppBundledPythonBackendProcess._({
    required this.process,
    required this.baseUrl,
    required this.pythonPath,
    required this.appEnginePath,
    required this.requireAnalyzeMulti,
    required this.startSequence,
    required this.startedAt,
  }) {
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
    process.stdout.transform(utf8.decoder).listen((_) {});
  }

  Map<String, dynamic> get diagnostics => {
        'backend_url': baseUrl,
        'process_source': 'app_managed',
        'python_runtime': 'app_bundled',
        'python_runtime_path': pythonPath,
        'app_engine_path': appEnginePath,
        'backend_health': _health,
        'is_app_bundled': true,
        'requires_analyze_multi': requireAnalyzeMulti,
        'backend_process_pid': process.pid,
        'backend_process_start_count': startSequence,
        'backend_process_started_at': startedAt.toIso8601String(),
        'backend_process_ready_at': _readyAt?.toIso8601String() ?? '',
        'backend_process_uptime_ms': DateTime.now().difference(startedAt).inMilliseconds,
        'backend_startup_elapsed_ms': _startupElapsedMs,
        'backend_last_health_check_elapsed_ms': _lastHealthCheckElapsedMs,
        'backend_health_check_count': _healthCheckCount,
        'backend_request_count': _requestCount,
        'backend_last_request_reused': _lastRequestReused,
        'backend_last_ready_elapsed_ms': _lastBackendReadyElapsedMs,
      };

  void markStartupReady(int elapsedMs) {
    _startupElapsedMs = elapsedMs;
    _readyAt = DateTime.now();
  }

  void markRequest({
    required bool reused,
    required int backendReadyElapsedMs,
  }) {
    _requestCount += 1;
    _lastRequestReused = reused;
    _lastBackendReadyElapsedMs = backendReadyElapsedMs;
  }

  Future<void> waitUntilReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 10),
        onTimeout: () => -999999,
      );
      if (exitCode != -999999) {
        throw Exception(
          'Blocked: App-bundled Python backend exited early, exitCode=$exitCode, stderr=${_stderr.toString()}',
        );
      }
      try {
        final health = await refreshHealth();
        if (health['backend'] == 'origin_vespa_tdx' &&
            health['engine'] == 'chan.py') {
          if (requireAnalyzeMulti) {
            await _assertAnalyzeMultiEndpoint();
          }
          return;
        }
        lastError = 'unexpected /health payload: $health';
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw Exception(
      'Blocked: App-bundled Python backend startup timed out: $lastError, stderr=${_stderr.toString()}',
    );
  }

  Future<Map<String, dynamic>> refreshHealth() async {
    final sw = Stopwatch()..start();
    final health = await _getJson('/health');
    sw.stop();
    _health = Map<String, dynamic>.from(health);
    _lastHealthCheckElapsedMs = sw.elapsedMilliseconds;
    _healthCheckCount += 1;
    return _health;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(milliseconds: 700));
      final response =
          await request.close().timeout(const Duration(milliseconds: 700));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('$path returned ${response.statusCode}: $body');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('$path did not return a JSON object');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _assertAnalyzeMultiEndpoint() async {
    final root = await _getJson('/');
    final endpoints = root['endpoints'];
    if (endpoints is List && endpoints.contains('/api/chan/analyze_multi')) {
      return;
    }
    throw Exception(
      'Blocked: App-bundled backend does not expose /api/chan/analyze_multi.',
    );
  }

  void dispose() {
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
  }
}
