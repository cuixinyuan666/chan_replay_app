import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/raw_bar.dart';

class EastmoneyKlineSource {
  EastmoneyKlineSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<RawBar>> loadKline({
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 500,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw const FormatException('股票代码必须是6位数字，例如 000001');
    }

    final uri = Uri.https(
      'push2his.eastmoney.com',
      '/api/qt/stock/kline/get',
      {
        'secid': '${_marketPrefix(market)}.$normalizedCode',
        'fields1': 'f1,f2,f3,f4,f5,f6',
        'fields2': 'f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61',
        'klt': _klt(period),
        'fqt': _fqt(adjust),
        'end': '20500101',
        'lmt': count.toString(),
      },
    );

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
        'Referer': 'https://quote.eastmoney.com/',
      },
    ).timeout(timeout);

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception('东方财富请求失败：HTTP ${response.statusCode} $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('东方财富返回格式不正确：根节点不是对象');
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('东方财富未返回 data，可能是代码、市场或周期错误');
    }
    final klines = data['klines'];
    if (klines is! List) {
      throw const FormatException('东方财富未返回 klines 数组');
    }

    final bars = <RawBar>[];
    for (final item in klines) {
      final bar = _parseKline(item.toString(), bars.length);
      if (bar != null) bars.add(bar);
    }

    bars.sort((a, b) => a.time.compareTo(b.time));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  void close() => _client.close();

  static String _marketPrefix(String market) {
    final upper = market.trim().toUpperCase();
    if (upper == 'SH') return '1';
    if (upper == 'SZ') return '0';
    throw const FormatException('市场只支持 SH 或 SZ');
  }

  static String _klt(String period) {
    switch (period.trim().toUpperCase()) {
      case 'MIN1':
        return '1';
      case 'MIN5':
        return '5';
      case 'MIN15':
        return '15';
      case 'MIN30':
        return '30';
      case 'MIN60':
        return '60';
      case 'DAILY':
        return '101';
      case 'WEEKLY':
        return '102';
      case 'MONTHLY':
        return '103';
      default:
        throw const FormatException('不支持的周期');
    }
  }

  static String _fqt(String adjust) {
    switch (adjust.trim().toUpperCase()) {
      case 'NONE':
        return '0';
      case 'QFQ':
        return '1';
      case 'HFQ':
        return '2';
      default:
        throw const FormatException('复权只支持 NONE、QFQ、HFQ');
    }
  }

  static RawBar? _parseKline(String line, int index) {
    final row = line.split(',').map((e) => e.trim()).toList();
    if (row.length < 6) return null;

    final time = DateTime.tryParse(row[0]);
    final open = double.tryParse(row[1]);
    final close = double.tryParse(row[2]);
    final high = double.tryParse(row[3]);
    final low = double.tryParse(row[4]);
    final volume = double.tryParse(row[5]) ?? 0.0;

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
}
