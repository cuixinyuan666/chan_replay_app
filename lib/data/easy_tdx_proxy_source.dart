import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/raw_bar.dart';

class EasyTdxProxySource {
  EasyTdxProxySource({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<RawBar>> loadKline({
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 500,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.isEmpty) {
      throw const FormatException('EasyTDX 服务地址不能为空');
    }

    final uri = Uri.parse('$root/kline').replace(
      queryParameters: {
        'market': market.trim().toUpperCase(),
        'code': code.trim(),
        'period': period.trim().toUpperCase(),
        'adjust': adjust.trim().toUpperCase(),
        'count': count.toString(),
      },
    );

    final response = await _client.get(uri).timeout(timeout);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception('EasyTDX 请求失败：HTTP ${response.statusCode} $body');
    }

    final decoded = jsonDecode(body);
    final rows = _extractRows(decoded);
    final bars = <RawBar>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final bar = _parseBar(row.cast<String, dynamic>(), bars.length);
      if (bar != null) bars.add(bar);
    }

    bars.sort((a, b) => a.time.compareTo(b.time));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  void close() => _client.close();

  static List<dynamic> _extractRows(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in const ['data', 'bars', 'items', 'rows', 'klines']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    throw const FormatException('EasyTDX 返回格式不正确：未找到 data 数组');
  }

  static RawBar? _parseBar(Map<String, dynamic> row, int index) {
    final time = _parseTime(_first(row, const ['time', 'datetime', 'date']));
    final open = _parseDouble(_first(row, const ['open', 'o']));
    final high = _parseDouble(_first(row, const ['high', 'h']));
    final low = _parseDouble(_first(row, const ['low', 'l']));
    final close = _parseDouble(_first(row, const ['close', 'c']));
    final volume = _parseDouble(
          _first(row, const ['volume', 'vol', 'v']),
        ) ??
        0.0;

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

  static dynamic _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (row.containsKey(key)) return row[key];
    }
    return null;
  }

  static DateTime? _parseTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      final raw = value.toInt();
      final millis = raw > 20000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }

    var text = value.toString().trim();
    if (text.isEmpty) return null;
    if (RegExp(r'^\d{8}$').hasMatch(text)) {
      text = '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6, 8)}';
    }
    return DateTime.tryParse(text);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'nan') return null;
    return double.tryParse(text);
  }
}
