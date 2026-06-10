import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/models/bi.dart';
import '../core/models/chan_snapshot.dart';
import '../core/models/fx.dart';
import '../core/models/merged_bar.dart';
import '../core/models/raw_bar.dart';
import '../core/models/seg.dart';
import '../core/models/zs.dart';

class PythonChanEngineSource {
  static const MethodChannel _androidChanChannel = MethodChannel('chan_replay_app/python_chan');

  final String baseUrl;
  final http.Client _client;
  _LocalPythonChanProcess? _localProcess;

  PythonChanEngineSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<ChanSnapshot> analyze({
    required String mode,
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 800,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final payload = <String, dynamic>{
      'mode': mode,
      'symbol': code.trim(),
      'market': market.trim().toUpperCase(),
      'freq': period.trim().toUpperCase(),
      'adjust': adjust.trim().toUpperCase(),
      'count': count,
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    };

    if (Platform.isAndroid) {
      return _loadViaAndroidChannel(payload);
    }

    final query = payload.map((key, value) => MapEntry(key, '$value'));
    try {
      return await _loadFromBase(baseUrl, query);
    } on _PythonChanBackendMismatch catch (_) {
      return _loadViaAutoLocalBackend(query);
    } on SocketException catch (_) {
      return _loadViaAutoLocalBackend(query);
    } on http.ClientException catch (e) {
      if (!_looksLikeConnectionFailure(e)) rethrow;
      return _loadViaAutoLocalBackend(query);
    } on TimeoutException catch (_) {
      return _loadViaAutoLocalBackend(query);
    }
  }

  Future<ChanSnapshot> _loadViaAndroidChannel(Map<String, dynamic> payload) async {
    final result = await _androidChanChannel.invokeMethod<String>(
      'analyze',
      {'payload': jsonEncode(payload)},
    );
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
    return _parseSnapshot(decoded);
  }

  Future<ChanSnapshot> _loadViaAutoLocalBackend(Map<String, String> query) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('自动后台启动 Python chan.py 本地服务目前只支持 Windows');
    }
    _localProcess = await _LocalPythonChanProcess.start();
    return _loadFromBase(_localProcess!.baseUrl, query);
  }

  Future<ChanSnapshot> _loadFromBase(String sourceBaseUrl, Map<String, String> query) async {
    await _assertCompatibleBackend(sourceBaseUrl);
    final uri = Uri.parse(_join(sourceBaseUrl, '/api/chan/analyze')).replace(queryParameters: query);
    final response = await _client.get(uri).timeout(const Duration(seconds: 60));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 404 && _canAutoFallback(sourceBaseUrl)) {
        throw _PythonChanBackendMismatch('localhost 服务不是 origin_vespa_tdx chan.py 后端: $body');
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
    return _parseSnapshot(decoded);
  }

  Future<void> _assertCompatibleBackend(String sourceBaseUrl) async {
    if (!_canAutoFallback(sourceBaseUrl)) return;
    final uri = Uri.parse(_join(sourceBaseUrl, '/health'));
    final response = await _client.get(uri).timeout(const Duration(seconds: 3));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _PythonChanBackendMismatch('localhost /health 返回 ${response.statusCode}: $body');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _PythonChanBackendMismatch('localhost /health 不是 JSON 对象');
    }
    if (decoded['backend'] != 'origin_vespa_tdx' || decoded['engine'] != 'chan.py') {
      throw _PythonChanBackendMismatch('localhost 服务不是 origin_vespa_tdx chan.py 后端: $body');
    }
  }

  bool _canAutoFallback(String sourceBaseUrl) {
    if (!Platform.isWindows) return false;
    final uri = Uri.tryParse(sourceBaseUrl);
    if (uri == null) return false;
    return uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1');
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

  ChanSnapshot _parseSnapshot(Map<String, dynamic> data) {
    final bars = <RawBar>[];
    final rawRows = data['bars'];
    if (rawRows is List) {
      for (final row in rawRows) {
        if (row is Map) {
          final bar = _parseRawBar(row, bars.length);
          if (bar != null) bars.add(bar.copyWith(index: bars.length));
        }
      }
    }

    final mergedBars = <MergedBar>[];
    final mergedRows = data['merged_bars'] ?? data['mergedBars'];
    if (mergedRows is List) {
      for (final row in mergedRows) {
        if (row is Map) {
          final merged = _parseMergedBar(row, bars);
          if (merged != null) mergedBars.add(merged);
        }
      }
    }
    if (mergedBars.isEmpty) {
      mergedBars.addAll([for (final bar in bars) _dummyMergedBar(bar)]);
    }

    final fxs = <FX>[];
    final fxRows = data['fx'];
    if (fxRows is List) {
      for (final row in fxRows) {
        if (row is Map) {
          final fx = _parseFx(row, mergedBars);
          if (fx != null) fxs.add(fx);
        }
      }
    }

    final bis = <BI>[];
    final biRows = data['bi'];
    if (biRows is List) {
      for (final row in biRows) {
        if (row is Map) {
          final bi = _parseBi(row, bis.length, mergedBars);
          if (bi != null) bis.add(bi);
        }
      }
    }

    final linkedBis = [
      for (var i = 0; i < bis.length; i++)
        bis[i].copyWith(
          prevIndex: i > 0 ? i - 1 : null,
          clearPrevIndex: i == 0,
          nextIndex: i + 1 < bis.length ? i + 1 : null,
          clearNextIndex: i + 1 >= bis.length,
        ),
    ];

    final segs = <SEG>[];
    final segRows = data['seg'];
    if (segRows is List) {
      for (final row in segRows) {
        if (row is Map) {
          final seg = _parseSeg(row, segs.length, linkedBis);
          if (seg != null) segs.add(seg);
        }
      }
    }

    final zss = <ZS>[];
    final zsRows = data['zs'];
    if (zsRows is List) {
      for (final row in zsRows) {
        if (row is Map) {
          final zs = _parseZs(row, zss.length);
          if (zs != null) zss.add(zs);
        }
      }
    }

    return ChanSnapshot(
      rawBars: bars,
      mergedBars: mergedBars,
      fxs: fxs,
      bis: linkedBis,
      segs: segs,
      zss: zss,
    );
  }

  RawBar? _parseRawBar(Map row, int index) {
    final time = _parseTime(row['dt'] ?? row['datetime'] ?? row['date'] ?? row['time']);
    final open = _num(row['open'] ?? row['o']);
    final high = _num(row['high'] ?? row['h']);
    final low = _num(row['low'] ?? row['l']);
    final close = _num(row['close'] ?? row['c']);
    final volume = _num(row['vol'] ?? row['volume'] ?? row['v']) ?? 0.0;
    if (time == null || open == null || high == null || low == null || close == null) return null;
    return RawBar(index: index, time: time, open: open, high: high, low: low, close: close, volume: volume);
  }

  MergedBar? _parseMergedBar(Map row, List<RawBar> bars) {
    final index = _int(row['index']) ?? _int(row['idx']);
    final startRaw = _int(row['start_raw_index'] ?? row['startRawIndex']);
    final endRaw = _int(row['end_raw_index'] ?? row['endRawIndex']);
    final high = _num(row['high']);
    final low = _num(row['low']);
    if (index == null || startRaw == null || endRaw == null || high == null || low == null || bars.isEmpty) return null;
    final raw = bars[startRaw.clamp(0, bars.length - 1).toInt()];
    final highRaw = _int(row['high_raw_index'] ?? row['highRawIndex']) ?? startRaw;
    final lowRaw = _int(row['low_raw_index'] ?? row['lowRawIndex']) ?? startRaw;
    return MergedBar(
      index: index,
      startRawIndex: startRaw,
      endRawIndex: endRaw,
      highRawIndex: highRaw,
      lowRawIndex: lowRaw,
      time: _parseTime(row['time']) ?? raw.time,
      highTime: _parseTime(row['high_time'] ?? row['highTime']) ?? raw.time,
      lowTime: _parseTime(row['low_time'] ?? row['lowTime']) ?? raw.time,
      open: _num(row['open']) ?? raw.open,
      high: high,
      low: low,
      close: _num(row['close']) ?? raw.close,
      volume: _num(row['volume'] ?? row['vol']) ?? raw.volume,
    );
  }

  FX? _parseFx(Map row, List<MergedBar> mergedBars) {
    final rawIndex = _int(row['raw_index'] ?? row['rawIndex']);
    final price = _num(row['price']);
    if (rawIndex == null || price == null || mergedBars.isEmpty) return null;
    final typeText = '${row['type'] ?? ''}'.toLowerCase();
    final isTop = typeText.contains('top');
    final center = _mergedAt(mergedBars, rawIndex);
    return FX(
      index: _int(row['index']) ?? center.index,
      rawIndex: rawIndex,
      time: _parseTime(row['time']) ?? center.time,
      type: isTop ? FxType.top : FxType.bottom,
      price: price,
      left: center,
      center: center,
      right: center,
      confirmed: row['confirmed'] != false,
    );
  }

  BI? _parseBi(Map row, int index, List<MergedBar> mergedBars) {
    final startRaw = _int(row['start_raw_index'] ?? row['startRawIndex']);
    final endRaw = _int(row['end_raw_index'] ?? row['endRawIndex']);
    final startPrice = _num(row['start_price'] ?? row['startPrice']);
    final endPrice = _num(row['end_price'] ?? row['endPrice']);
    if (startRaw == null || endRaw == null || startPrice == null || endPrice == null || mergedBars.isEmpty) return null;
    final dirText = '${row['direction'] ?? ''}'.toLowerCase();
    final isDown = dirText.contains('down');
    final startMerged = _mergedAt(mergedBars, startRaw);
    final endMerged = _mergedAt(mergedBars, endRaw);
    final startFx = FX(
      index: startMerged.index,
      rawIndex: startRaw,
      time: _parseTime(row['start_time'] ?? row['startTime']) ?? startMerged.time,
      type: isDown ? FxType.top : FxType.bottom,
      price: startPrice,
      left: startMerged,
      center: startMerged,
      right: startMerged,
      confirmed: true,
    );
    final endFx = FX(
      index: endMerged.index,
      rawIndex: endRaw,
      time: _parseTime(row['end_time'] ?? row['endTime']) ?? endMerged.time,
      type: isDown ? FxType.bottom : FxType.top,
      price: endPrice,
      left: endMerged,
      center: endMerged,
      right: endMerged,
      confirmed: row['is_sure'] != false,
    );
    return BI(
      index: _int(row['index']) ?? index,
      start: startFx,
      end: endFx,
      direction: isDown ? BiDirection.down : BiDirection.up,
      isSure: row['is_sure'] != false,
    );
  }

  SEG? _parseSeg(Map row, int index, List<BI> bis) {
    final start = _int(row['start_bi_index'] ?? row['startBiIndex']);
    final end = _int(row['end_bi_index'] ?? row['endBiIndex']);
    if (start == null || end == null || start < 0 || end < start || end >= bis.length) return null;
    final dirText = '${row['direction'] ?? ''}'.toLowerCase();
    final items = bis.sublist(start, end + 1);
    return SEG(
      index: _int(row['index']) ?? index,
      startBi: bis[start],
      endBi: bis[end],
      direction: dirText.contains('down') ? SegDirection.down : SegDirection.up,
      isSure: row['is_sure'] == true,
      reason: '${row['reason'] ?? 'chan.py'}',
      biList: items,
    );
  }

  ZS? _parseZs(Map row, int index) {
    final startBi = _int(row['start_bi_index'] ?? row['startBiIndex']);
    final endBi = _int(row['end_bi_index'] ?? row['endBiIndex']);
    final zg = _num(row['zg']);
    final zd = _num(row['zd']);
    final gg = _num(row['gg']);
    final dd = _num(row['dd']);
    if (startBi == null || endBi == null || zg == null || zd == null || gg == null || dd == null) return null;
    return ZS(
      index: _int(row['index']) ?? index,
      startBiIndex: startBi,
      endBiIndex: endBi,
      startRawIndex: _int(row['start_raw_index'] ?? row['startRawIndex']) ?? 0,
      endRawIndex: _int(row['end_raw_index'] ?? row['endRawIndex']) ?? 0,
      zg: zg,
      zd: zd,
      gg: gg,
      dd: dd,
      confirmed: row['confirmed'] == true,
      biInIndex: _int(row['bi_in_index'] ?? row['biInIndex']),
      biOutIndex: _int(row['bi_out_index'] ?? row['biOutIndex']),
      startSegIndex: _int(row['start_seg_index'] ?? row['startSegIndex']),
      endSegIndex: _int(row['end_seg_index'] ?? row['endSegIndex']),
    );
  }

  MergedBar _dummyMergedBar(RawBar bar) {
    return MergedBar(
      index: bar.index,
      startRawIndex: bar.index,
      endRawIndex: bar.index,
      highRawIndex: bar.index,
      lowRawIndex: bar.index,
      time: bar.time,
      highTime: bar.time,
      lowTime: bar.time,
      open: bar.open,
      high: bar.high,
      low: bar.low,
      close: bar.close,
      volume: bar.volume,
    );
  }

  MergedBar _mergedAt(List<MergedBar> bars, int rawIndex) {
    if (bars.isEmpty) throw StateError('empty bars');
    for (final bar in bars) {
      if (rawIndex >= bar.startRawIndex && rawIndex <= bar.endRawIndex) return bar;
    }
    final index = rawIndex.clamp(0, bars.length - 1).toInt();
    return bars[index];
  }

  DateTime? _parseTime(Object? value) {
    if (value is DateTime) return value;
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T').replaceAll('/', '-');
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  double? _num(Object? value) {
    if (value is num) return value.toDouble();
    final text = '${value ?? ''}'.trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'nan' || text == 'null') return null;
    return double.tryParse(text);
  }

  int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim());
  }

  String _join(String base, String path) {
    final left = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$left$path';
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
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
          [
            appEngine.path,
            '--host',
            '127.0.0.1',
            '--port',
            '$port',
          ],
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

    throw Exception('无法后台启动 Python chan.py 本地服务。仅允许使用内置 Python：python/python.exe。最后错误：$lastError');
  }

  static Future<File> _findAppEngine() async {
    final checked = <String>{};
    final starts = <Directory>[Directory.current, File(Platform.resolvedExecutable).parent];
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
    throw Exception('找不到 python/app_engine.py；请从项目根目录运行 Flutter，或把 python 目录放到 exe 同级目录、exe/data 目录或项目根目录。');
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
      final exitCode = await process.exitCode.timeout(const Duration(milliseconds: 10), onTimeout: () => -999999);
      if (exitCode != -999999) {
        throw Exception('Python chan.py 本地服务提前退出，exitCode=$exitCode，stderr=${_stderr.toString()}');
      }
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse('$baseUrl/health')).timeout(const Duration(milliseconds: 700));
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
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    });
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
