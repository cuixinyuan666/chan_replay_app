import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/analysis/chip_distribution.dart';
import '../core/models/raw_bar.dart';
import 'app_bundled_python_backend.dart';

/// Lightweight easy-tdx K-line source.
///
/// The S13 chip distribution layer uses [loadListingChipBars] to call
/// `/api/tdx/kline` directly instead of reusing the S13 replay window. That
/// gives the chip engine the first easy-tdx-available bar through the current
/// display cutoff bar.
class EasyTdxKlineSource {
  static AppBundledPythonBackendProcess? _sharedLocalProcess;
  static Future<AppBundledPythonBackendProcess>? _sharedStartup;

  final String baseUrl;
  final http.Client _client;

  EasyTdxKlineSource({this.baseUrl = 'app-managed bundled Python', http.Client? client})
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
    final rows = await _loadRows(
      symbol: code,
      market: market,
      period: period,
      adjust: adjust,
      count: count,
      startDate: startDate,
      endDate: endDate,
    );
    final bars = <RawBar>[];
    for (final row in rows) {
      final bar = _parseBar(row, bars.length);
      if (bar == null) continue;
      bars.add(bar.copyWith(index: bars.length));
    }
    bars.sort((a, b) => a.time.compareTo(b.time));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  Future<List<ChipDistributionBar>> loadListingChipBars({
    required String symbol,
    String? market,
    required String period,
    required DateTime endDate,
    String adjust = 'QFQ',
    int count = 200000,
  }) async {
    final rows = await _loadRows(
      symbol: symbol,
      market: market,
      period: period,
      adjust: adjust,
      count: count,
      endDate: endDate,
    );
    final bars = <ChipDistributionBar>[];
    for (final row in rows) {
      bars.add(ChipDistributionBar.fromJson(row, bars.length));
    }
    return bars
        .where((bar) =>
            bar.time != null &&
            bar.high > 0 &&
            bar.low > 0 &&
            bar.close > 0 &&
            !bar.high.isNaN &&
            !bar.low.isNaN &&
            !bar.close.isNaN)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _loadRows({
    required String symbol,
    String? market,
    required String period,
    String adjust = 'QFQ',
    int? count,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final normalizedCode = symbol.trim();
    if (normalizedCode.isEmpty) {
      throw const FormatException('Stock code is required.');
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw const FormatException('Start date cannot be after end date.');
    }

    final query = <String, String>{
      'symbol': normalizedCode,
      if (market != null && market.trim().isNotEmpty)
        'market': market.trim().toUpperCase(),
      'period': period.trim().toUpperCase(),
      'adjust': adjust.trim().toUpperCase(),
      if (count != null) 'count': '${count.clamp(1000, 500000)}',
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    };

    final trimmedBaseUrl = baseUrl.trim();
    final appManaged = _isAppManagedBaseUrl(trimmedBaseUrl);
    if (Platform.isWindows && appManaged) {
      return _loadViaAutoLocalBackend(query);
    }

    try {
      return await _loadFromBase(trimmedBaseUrl, query);
    } on _EasyTdxBackendMismatch {
      if (Platform.isWindows && _canAutoFallback(trimmedBaseUrl)) {
        return _loadViaSharedAppBackend(query);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _loadViaAutoLocalBackend(
      Map<String, String> query) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'App-managed bundled Python backend startup is only supported on Windows.',
      );
    }
    final sourceBase = await _readyAppManagedBaseUrl();
    return _loadFromBase(sourceBase, query);
  }

  Future<List<Map<String, dynamic>>> _loadViaSharedAppBackend(
      Map<String, String> query) async {
    final sourceBase = await _readyAppManagedBaseUrl(forceRestart: true);
    return _loadFromBase(sourceBase, query);
  }

  Future<String> _readyAppManagedBaseUrl({bool forceRestart = false}) async {
    if (!Platform.isWindows) return baseUrl;
    if (forceRestart) {
      _sharedLocalProcess?.dispose();
      _sharedLocalProcess = null;
      _sharedStartup = null;
    }
    if (_sharedLocalProcess == null) {
      _sharedStartup ??= AppBundledPythonBackend.start(requireAnalyzeMulti: true);
      try {
        _sharedLocalProcess = await _sharedStartup;
      } finally {
        _sharedStartup = null;
      }
    } else {
      try {
        await _sharedLocalProcess!.refreshHealth();
      } catch (_) {
        _sharedLocalProcess?.dispose();
        _sharedLocalProcess = null;
        _sharedStartup = AppBundledPythonBackend.start(requireAnalyzeMulti: true);
        try {
          _sharedLocalProcess = await _sharedStartup;
        } finally {
          _sharedStartup = null;
        }
      }
    }
    return _sharedLocalProcess!.baseUrl;
  }

  Future<List<Map<String, dynamic>>> _loadFromBase(
      String sourceBaseUrl, Map<String, String> query) async {
    if (sourceBaseUrl.trim().isEmpty) {
      throw const FormatException('easy-tdx backend baseUrl is empty.');
    }
    await _assertCompatibleBackend(sourceBaseUrl);

    final uri = Uri.parse(_join(sourceBaseUrl, '/api/tdx/kline')).replace(
      queryParameters: query,
    );

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 180),
          onTimeout: () => throw TimeoutException(
            'easy-tdx kline timed out after 180s, uri=$uri',
            const Duration(seconds: 180),
          ),
        );
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

    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          row
        else if (row is Map)
          Map<String, dynamic>.from(row),
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
    if (decoded['backend'] != 'origin_vespa_tdx' || decoded['engine'] != 'chan.py') {
      throw _EasyTdxBackendMismatch(
          'localhost service is not origin_vespa_tdx chan.py backend: $body');
    }
  }

  bool _canAutoFallback(String sourceBaseUrl) {
    if (!Platform.isWindows) return false;
    final uri = Uri.tryParse(sourceBaseUrl);
    if (uri == null) return false;
    return uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1');
  }

  bool _isAppManagedBaseUrl(String raw) {
    final text = raw.trim();
    return text.isEmpty || text == 'app-managed bundled Python' || text == 'app-managed';
  }

  void close() {
    _client.close();
  }

  RawBar? _parseBar(Map row, int index) {
    final chipBar = ChipDistributionBar.fromJson(Map<String, dynamic>.from(row), index);
    if (chipBar.time == null || chipBar.high <= 0 || chipBar.low <= 0 || chipBar.close <= 0) {
      return null;
    }
    return RawBar(
      index: index,
      time: chipBar.time!,
      open: chipBar.open,
      high: chipBar.high,
      low: chipBar.low,
      close: chipBar.close,
      volume: chipBar.volume,
      chipTickBins: ChipTickBins(
        sellByPrice: chipBar.priceSellVolume,
        buyByPrice: chipBar.priceBuyVolume,
        totalByPrice: chipBar.priceVolume,
      ),
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
}

class _EasyTdxBackendMismatch implements Exception {
  final String message;

  const _EasyTdxBackendMismatch(this.message);

  @override
  String toString() => message;
}
