import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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
      return await _postToBase(sourceBase, endpoint, payload);
    } on _ResearchBackendMismatch catch (_) {
      return _postViaAutoLocalBackend(endpoint, payload);
    } on SocketException catch (_) {
      return _postViaAutoLocalBackend(endpoint, payload);
    } on TimeoutException catch (_) {
      return _postViaAutoLocalBackend(endpoint, payload);
    } on http.ClientException catch (e) {
      if (!_looksLikeConnectionFailure(e)) rethrow;
      return _postViaAutoLocalBackend(endpoint, payload);
    }
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
    final response = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60));
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
        final runner = _ResearchLocalPythonProcess._(process, baseUrl);
        await runner._waitUntilReady();
        return runner;
      } catch (e) {
        lastError = '${candidate.executable}: $e';
      }
    }
    throw Exception(
        'Unable to start bundled Python backend. Last error: $lastError');
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
    throw Exception('Cannot find python/app_engine.py');
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

  static List<_ResearchPythonCandidate> _pythonCandidates(File appEngine) {
    final sep = Platform.pathSeparator;
    final bundledPython = File('${appEngine.parent.path}${sep}python.exe');
    if (!bundledPython.existsSync()) {
      throw Exception('Cannot find bundled Python: ${bundledPython.path}');
    }
    return [_ResearchPythonCandidate(bundledPython.path)];
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
            'Python backend exited early, exitCode=$exitCode, stderr=${_stderr.toString()}');
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
        'Python backend startup timed out: $lastError, stderr=${_stderr.toString()}');
  }

  void dispose() {
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
  }
}

class _ResearchPythonCandidate {
  final String executable;

  const _ResearchPythonCandidate(this.executable);
}

class _ResearchBackendMismatch implements Exception {
  final String message;

  const _ResearchBackendMismatch(this.message);

  @override
  String toString() => message;
}
