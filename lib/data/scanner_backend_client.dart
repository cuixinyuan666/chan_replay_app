import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ScannerBackendClient {
  final String baseUrl;
  final http.Client _client;
  _ScannerLocalPythonProcess? _localProcess;

  ScannerBackendClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<Map<String, dynamic>> scanBsp({
    required int limit,
    required int days,
    required int recentDays,
    required bool biStrict,
    required Map<String, dynamic> config,
  }) async {
    if (Platform.isAndroid) {
      throw UnsupportedError('扫描器当前需要 FastAPI 后端；Android Chaquopy 暂未接入批量 BSP 扫描');
    }
    final payload = <String, dynamic>{
      'days': days,
      'recent_days': recentDays,
      'limit': limit,
      'bi_strict': biStrict,
      'config': config,
    };
    final sourceBase = await _readyBaseUrl();
    try {
      return await _postScan(sourceBase, payload);
    } on _ScannerBackendMismatch catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess = await _ScannerLocalPythonProcess.start();
      return _postScan(_localProcess!.baseUrl, payload);
    } on SocketException catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess = await _ScannerLocalPythonProcess.start();
      return _postScan(_localProcess!.baseUrl, payload);
    } on TimeoutException catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess = await _ScannerLocalPythonProcess.start();
      return _postScan(_localProcess!.baseUrl, payload);
    } on http.ClientException catch (e) {
      if (!Platform.isWindows || !_looksLikeConnectionFailure(e)) rethrow;
      _localProcess = await _ScannerLocalPythonProcess.start();
      return _postScan(_localProcess!.baseUrl, payload);
    }
  }

  Future<String> _readyBaseUrl() async {
    try {
      await _assertCompatibleBackend(baseUrl);
      return baseUrl;
    } catch (_) {
      if (!Platform.isWindows) rethrow;
      _localProcess = await _ScannerLocalPythonProcess.start();
      return _localProcess!.baseUrl;
    }
  }

  Future<Map<String, dynamic>> _postScan(String sourceBaseUrl, Map<String, dynamic> payload) async {
    await _assertCompatibleBackend(sourceBaseUrl);
    final uri = Uri.parse(_join(sourceBaseUrl, '/api/scanner/bsp/scan'));
    final response = await _client
        .post(
          uri,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(minutes: 8));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 404 && _canAutoFallback(sourceBaseUrl)) {
      throw _ScannerBackendMismatch('localhost 后端缺少扫描器接口: $body');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('扫描器后端返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('扫描器后端返回结构不是 JSON 对象');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? '扫描器后端执行失败');
    }
    return decoded;
  }

  Future<void> _assertCompatibleBackend(String sourceBaseUrl) async {
    if (!_canAutoFallback(sourceBaseUrl)) return;
    final uri = Uri.parse(_join(sourceBaseUrl, '/health'));
    final response = await _client.get(uri).timeout(const Duration(seconds: 3));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _ScannerBackendMismatch('localhost /health 返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _ScannerBackendMismatch('localhost /health 不是 JSON 对象');
    }
    if (decoded['backend'] != 'origin_vespa_tdx' || decoded['engine'] != 'chan.py') {
      throw _ScannerBackendMismatch('localhost 服务不是 origin_vespa_tdx chan.py 后端: $body');
    }
  }

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

class _ScannerLocalPythonProcess {
  final Process process;
  final String baseUrl;
  final StringBuffer _stderr = StringBuffer();

  _ScannerLocalPythonProcess._(this.process, this.baseUrl) {
    process.stderr.transform(utf8.decoder).listen(_stderr.write);
    process.stdout.transform(utf8.decoder).listen((_) {});
  }

  static Future<_ScannerLocalPythonProcess> start() async {
    final appEngine = await _findAppEngine();
    final port = await _pickFreePort();
    final baseUrl = 'http://127.0.0.1:$port';
    final candidates = _pythonCandidates(appEngine);
    Object? lastError;
    for (final candidate in candidates) {
      try {
        final process = await Process.start(
          candidate.executable,
          [...candidate.prefixArgs, appEngine.path, '--host', '127.0.0.1', '--port', '$port'],
          workingDirectory: appEngine.parent.parent.path,
          runInShell: false,
          environment: {'PYTHONIOENCODING': 'utf-8'},
          mode: ProcessStartMode.normal,
        );
        final runner = _ScannerLocalPythonProcess._(process, baseUrl);
        await runner._waitUntilReady();
        return runner;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('无法后台启动 Python chan.py 本地服务。最后错误：$lastError');
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

  static List<_ScannerPythonCandidate> _pythonCandidates(File appEngine) {
    final sep = Platform.pathSeparator;
    final root = appEngine.parent.parent;
    final result = <_ScannerPythonCandidate>[];
    final bundledPython = File('${appEngine.parent.path}${sep}python.exe');
    final venvPython = File('${root.path}${sep}backend${sep}.venv${sep}Scripts${sep}python.exe');
    if (bundledPython.existsSync()) result.add(_ScannerPythonCandidate(bundledPython.path));
    if (venvPython.existsSync()) result.add(_ScannerPythonCandidate(venvPython.path));
    result.add(const _ScannerPythonCandidate('python'));
    result.add(const _ScannerPythonCandidate('py', ['-3']));
    return result;
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
        throw Exception('Python chan.py 本地服务提前退出，exitCode=$exitCode，stderr=${_stderr.toString()}');
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
    throw Exception('Python chan.py 本地服务启动超时：$lastError，stderr=${_stderr.toString()}');
  }

  void dispose() {
    try {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {}
  }
}

class _ScannerPythonCandidate {
  final String executable;
  final List<String> prefixArgs;

  const _ScannerPythonCandidate(this.executable, [this.prefixArgs = const []]);
}

class _ScannerBackendMismatch implements Exception {
  final String message;

  const _ScannerBackendMismatch(this.message);

  @override
  String toString() => message;
}
