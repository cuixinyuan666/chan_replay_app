import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/raw_bar.dart';

class EasyTdxKlineSource {
  final String baseUrl;
  final http.Client _client;

  EasyTdxKlineSource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<List<RawBar>> loadKline({
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 800,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw const FormatException('股票代码必须是6位数字，例如 000001');
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw const FormatException('开始日期不能晚于结束日期');
    }

    final uri = Uri.parse(_join(baseUrl, '/api/tdx/kline')).replace(
      queryParameters: {
        'symbol': normalizedCode,
        'market': market.trim().toUpperCase(),
        'freq': period.trim().toUpperCase(),
        'adjust': adjust.trim().toUpperCase(),
        'count': '$count',
        if (startDate != null) 'start': _fmtDate(startDate),
        if (endDate != null) 'end': _fmtDate(endDate),
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 30));
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('easy-tdx 后端返回 ${response.statusCode}: $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('easy-tdx 后端返回结构不是 JSON 对象');
    }
    final rows = decoded['bars'];
    if (rows is! List) {
      throw const FormatException('easy-tdx 后端未返回 bars 数组');
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

  void close() => _client.close();

  RawBar? _parseBar(Map row, int index) {
    final time = _parseTime(row['dt'] ?? row['datetime'] ?? row['date'] ?? row['time']);
    final open = _parseDouble(row['open'] ?? row['o']);
    final high = _parseDouble(row['high'] ?? row['h']);
    final low = _parseDouble(row['low'] ?? row['l']);
    final close = _parseDouble(row['close'] ?? row['c']);
    final volume = _parseDouble(row['vol'] ?? row['volume'] ?? row['v']) ?? 0.0;

    if (time == null || open == null || high == null || low == null || close == null) {
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
