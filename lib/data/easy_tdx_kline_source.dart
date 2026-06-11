import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/models/raw_bar.dart';
import 'app_bundled_python_backend.dart';

class EasyTdxKlineSource {
  final String baseUrl;
  final http.Client _client;
  AppBundledPythonBackendProcess? _localProcess;

  EasyTdxKlineSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<List<RawBar>> loadKline({
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int? count,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw const FormatException(
          'Stock code must be 6 digits, for example 000001.');
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw const FormatException('Start date cannot be after end date.');
    }

    final query = {
      'symbol': normalizedCode,
      'market': market.trim().toUpperCase(),
      'freq': period.trim().toUpperCase(),
      'adjust': adjust.trim().toUpperCase(),
      if (count != null) 'count': '$count',
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    };

    if (Platform.isWindows) return _loadViaAutoLocalBackend(query);
    return _loadFromBase(baseUrl, query);
  }

  Future<List<RawBar>> _loadViaAutoLocalBackend(
      Map<String, String> query) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'App-managed bundled Python backend startup is only supported on Windows.',
      );
    }
    _localProcess = await AppBundledPythonBackend.start();
    return _loadFromBase(_localProcess!.baseUrl, query);
  }

  Future<List<RawBar>> _loadFromBase(
      String sourceBaseUrl, Map<String, String> query) async {
    await _assertCompatibleBackend(sourceBaseUrl);

    final uri = Uri.parse(_join(sourceBaseUrl, '/api/tdx/kline')).replace(
      queryParameters: query,
    );

    final response = await _client.get(uri);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 404 && _canAutoFallback(sourceBaseUrl)) {
        throw _EasyTdxBackendMismatch(
            'localhost service is not the expected easy-tdx backend: $body');
      }
      throw Exception('easy-tdx returned ${response.statusCode}: $body');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw _EasyTdxBackendMismatch('localhost response is not JSON: $body');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('easy-tdx response is not a JSON object.');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? 'easy-tdx request failed.');
    }
    final rows = decoded['bars'];
    if (rows is! List) {
      throw const FormatException('easy-tdx response is missing bars.');
    }

    final bars = <RawBar>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final bar = _parseBar(row, bars.length);
      if (bar == null) continue;
      bars.add(bar.copyWith(index: bars.length));
    }

    bars.sort((a, b) => a.time.compareTo(b.time));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  Future<void> _assertCompatibleBackend(String sourceBaseUrl) async {
    if (!_canAutoFallback(sourceBaseUrl)) return;

    final uri = Uri.parse(_join(sourceBaseUrl, '/health'));
    final response = await _client.get(uri).timeout(const Duration(seconds: 3));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _EasyTdxBackendMismatch(
          'localhost /health returned ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _EasyTdxBackendMismatch('localhost /health is not JSON.');
    }
    if (decoded['backend'] != 'origin_vespa_tdx' ||
        decoded['engine'] != 'chan.py') {
      throw _EasyTdxBackendMismatch(
          'localhost service is not origin_vespa_tdx chan.py backend: $body');
    }
  }

  bool _canAutoFallback(String sourceBaseUrl) {
    if (!Platform.isWindows) return false;
    final uri = Uri.tryParse(sourceBaseUrl);
    if (uri == null) return false;
    return uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' ||
            uri.host == 'localhost' ||
            uri.host == '::1');
  }

  void close() {
    _client.close();
    _localProcess?.dispose();
    _localProcess = null;
  }

  RawBar? _parseBar(Map row, int index) {
    final time =
        _parseTime(row['dt'] ?? row['datetime'] ?? row['date'] ?? row['time']);
    final open = _parseDouble(row['open'] ?? row['o']);
    final high = _parseDouble(row['high'] ?? row['h']);
    final low = _parseDouble(row['low'] ?? row['l']);
    final close = _parseDouble(row['close'] ?? row['c']);
    final volume = _parseDouble(row['vol'] ?? row['volume'] ?? row['v']) ?? 0.0;

    if (time == null ||
        open == null ||
        high == null ||
        low == null ||
        close == null) {
      return null;
    }
    return RawBar(
      index: index,
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  String _join(String base, String path) {
    final left = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$left$path';
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  DateTime? _parseTime(Object? value) {
    if (value is DateTime) return value;
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T');
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    final text = '${value ?? ''}'.trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'nan') return null;
    return double.tryParse(text);
  }
}

class _EasyTdxBackendMismatch implements Exception {
  final String message;

  const _EasyTdxBackendMismatch(this.message);

  @override
  String toString() => message;
}
